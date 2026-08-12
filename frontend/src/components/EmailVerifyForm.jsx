import { useEffect, useRef, useState } from "react";
import client from "../api/client";

const RESEND_COOLDOWN_SECONDS = 60;

function extractErrorMessage(err, fallback) {
  const detail = err.response?.data?.detail;
  if (Array.isArray(detail)) {
    return detail.map((d) => d.msg).join(", ");
  }
  return detail || fallback;
}

export default function EmailVerifyForm({ email, onVerified, requireSendFirst = false }) {
  const [sent, setSent] = useState(!requireSendFirst);
  const [code, setCode] = useState("");
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const [loading, setLoading] = useState(false);
  const [cooldown, setCooldown] = useState(0);
  const intervalRef = useRef(null);

  useEffect(() => () => clearInterval(intervalRef.current), []);

  const startCooldown = (seconds = RESEND_COOLDOWN_SECONDS) => {
    setCooldown(seconds);
    clearInterval(intervalRef.current);
    intervalRef.current = setInterval(() => {
      setCooldown((prev) => {
        if (prev <= 1) {
          clearInterval(intervalRef.current);
          return 0;
        }
        return prev - 1;
      });
    }, 1000);
  };

  const handleVerify = async (e) => {
    e.preventDefault();
    setError("");
    setLoading(true);
    try {
      await client.post("/auth/verify-email", { email, code });
      onVerified();
    } catch (err) {
      setError(extractErrorMessage(err, "인증에 실패했습니다."));
      setLoading(false);
    }
  };

  const handleSend = async () => {
    setError("");
    setLoading(true);
    try {
      await client.post("/auth/resend-verification", { email });
      setNotice("인증 코드를 보냈습니다.");
      setSent(true);
      startCooldown();
    } catch (err) {
      const detail = err.response?.data?.detail;
      const cooldownMatch = typeof detail === "string" && detail.match(/(\d+)초 후/);
      if (cooldownMatch) {
        // 이전에 보낸 코드가 아직 유효한 상태 - 코드 입력 화면으로 넘어가고 남은 시간만 표시
        setSent(true);
        startCooldown(parseInt(cooldownMatch[1], 10));
      } else {
        setError(extractErrorMessage(err, "발송에 실패했습니다."));
      }
    } finally {
      setLoading(false);
    }
  };

  if (!sent) {
    return (
      <div className="flex flex-col gap-2 items-center">
        <p className="text-sm text-center text-base-content/70">
          {email}로 인증 코드를 보낼게요
        </p>
        {error && <p className="text-error text-xs">{error}</p>}
        <button type="button" className="btn btn-primary btn-sm" onClick={handleSend} disabled={loading}>
          {loading ? <span className="loading loading-spinner loading-xs" /> : "인증코드 보내기"}
        </button>
      </div>
    );
  }

  return (
    <form onSubmit={handleVerify} className="flex flex-col gap-2">
      <p className="text-xs text-center text-base-content/70">
        {email}로 보낸 인증 코드를 입력해주세요
      </p>

      <input
        type="text"
        placeholder="인증 코드 6자리"
        className="input input-bordered input-sm w-full text-center tracking-widest"
        value={code}
        onChange={(e) => setCode(e.target.value)}
        maxLength={6}
        required
      />

      <div className="flex items-center justify-between text-xs min-h-4">
        {error ? (
          <span className="text-error">{error}</span>
        ) : notice ? (
          <span className="text-success">{notice}</span>
        ) : (
          <span />
        )}
        <button
          type="button"
          className="link link-hover"
          onClick={handleSend}
          disabled={loading || cooldown > 0}
        >
          {cooldown > 0 ? `${cooldown}초 후 재전송` : "코드 다시 받기"}
        </button>
      </div>

      <button type="submit" className="btn btn-primary btn-sm" disabled={loading}>
        {loading ? <span className="loading loading-spinner loading-xs" /> : "인증하기"}
      </button>
    </form>
  );
}
