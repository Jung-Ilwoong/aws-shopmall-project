import { useState } from "react";
import { useNavigate, Link } from "react-router-dom";
import client from "../api/client";
import EmailVerifyForm from "../components/EmailVerifyForm";

function extractErrorMessage(err, fallback) {
  const detail = err.response?.data?.detail;
  if (Array.isArray(detail)) {
    return detail.map((d) => d.msg).join(", ");
  }
  return detail || fallback;
}

const initialForm = {
  email: "",
  password: "",
  passwordConfirm: "",
  name: "",
  phone: "",
  postcode: "",
  address: "",
  addressDetail: "",
  termsAgreed: false,
  privacyAgreed: false,
  marketingAgreed: false,
};

export default function RegisterPage() {
  const [step, setStep] = useState("form"); // "form" | "verify"
  const [form, setForm] = useState(initialForm);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const [submitAttempted, setSubmitAttempted] = useState(false);
  const [verified, setVerified] = useState(false);
  const navigate = useNavigate();

  const allAgreed = form.termsAgreed && form.privacyAgreed && form.marketingAgreed;

  const passwordIssues = form.password
    ? [
        form.password.length < 8 && "8자 이상",
        !/[A-Za-z]/.test(form.password) && "영문 포함",
        !/\d/.test(form.password) && "숫자 포함",
        !/[^A-Za-z0-9]/.test(form.password) && "특수문자 포함",
      ].filter(Boolean)
    : [];
  const passwordMismatch = form.passwordConfirm.length > 0 && form.password !== form.passwordConfirm;

  const updateField = (field) => (e) => {
    const value = e.target.type === "checkbox" ? e.target.checked : e.target.value;
    setForm((prev) => ({ ...prev, [field]: value }));
  };

  const updatePhone = (e) => {
    const digitsOnly = e.target.value.replace(/\D/g, "").slice(0, 11);
    setForm((prev) => ({ ...prev, phone: digitsOnly }));
  };

  const toggleAllAgreed = (e) => {
    const checked = e.target.checked;
    setForm((prev) => ({
      ...prev,
      termsAgreed: checked,
      privacyAgreed: checked,
      marketingAgreed: checked,
    }));
  };

  const openPostcodeSearch = () => {
    if (!window.daum?.Postcode) {
      setError("주소 검색 스크립트를 불러오지 못했습니다. 새로고침 후 다시 시도해주세요.");
      return;
    }
    new window.daum.Postcode({
      oncomplete: (data) => {
        setForm((prev) => ({
          ...prev,
          postcode: data.zonecode,
          address: data.roadAddress || data.jibunAddress,
        }));
        document.getElementById("address-detail-input")?.focus();
      },
    }).open();
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError("");
    setSubmitAttempted(true);

    if (!form.name || !form.phone || !form.addressDetail) {
      return;
    }
    if (form.password !== form.passwordConfirm) {
      setError("비밀번호가 일치하지 않습니다");
      return;
    }
    if (!form.termsAgreed || !form.privacyAgreed) {
      setError("필수 약관에 동의해주세요");
      return;
    }

    setLoading(true);
    try {
      await client.post("/auth/register", {
        email: form.email,
        password: form.password,
        password_confirm: form.passwordConfirm,
        name: form.name,
        phone: form.phone,
        postcode: form.postcode,
        address: form.address,
        address_detail: form.addressDetail,
        terms_agreed: form.termsAgreed,
        privacy_agreed: form.privacyAgreed,
        marketing_agreed: form.marketingAgreed,
      });
      setStep("verify");
    } catch (err) {
      setError(extractErrorMessage(err, "회원가입에 실패했습니다."));
    } finally {
      setLoading(false);
    }
  };

  const handleVerified = () => {
    setVerified(true);
    setTimeout(() => navigate("/login"), 1500);
  };

  if (step === "verify" && verified) {
    return (
      <div className="min-h-[80vh] flex items-center justify-center">
        <div className="card w-full max-w-sm bg-base-100 shadow-md">
          <div className="card-body items-center text-center gap-2">
            <div className="text-success text-5xl">✓</div>
            <h1 className="text-xl font-bold">이메일 인증 완료</h1>
            <p className="text-sm text-base-content/70">
              잠시 후 로그인 페이지로 이동합니다
            </p>
            <span className="loading loading-spinner loading-sm text-success mt-2" />
          </div>
        </div>
      </div>
    );
  }

  if (step === "verify") {
    return (
      <div className="min-h-[80vh] flex items-center justify-center">
        <div className="card w-full max-w-sm bg-base-100 shadow-md">
          <div className="card-body">
            <h1 className="text-2xl font-bold text-center mb-4">이메일 인증</h1>
            <EmailVerifyForm email={form.email} onVerified={handleVerified} />
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-[80vh] flex items-center justify-center py-8">
      <div className="card w-full max-w-md bg-base-100 shadow-md">
        <div className="card-body">
          <h1 className="text-2xl font-bold text-center mb-4">회원가입</h1>

          <form onSubmit={handleSubmit} noValidate className="flex flex-col gap-3">
            <div className="flex flex-col gap-1">
              <label htmlFor="email" className="text-sm font-medium">
                이메일
              </label>
              <input
                id="email"
                type="email"
                placeholder="example@shopmall.com"
                className="input input-bordered w-full"
                value={form.email}
                onChange={updateField("email")}
                required
              />
            </div>

            <div className="flex flex-col gap-1">
              <label htmlFor="password" className="text-sm font-medium">
                비밀번호
              </label>
              <input
                id="password"
                type="password"
                placeholder="영문+숫자+특수문자 8자 이상"
                className={`input input-bordered w-full ${passwordIssues.length ? "input-error" : ""}`}
                value={form.password}
                onChange={updateField("password")}
                required
              />
              {passwordIssues.length > 0 && (
                <p className="text-error text-xs">{passwordIssues.join(" · ")} 필요</p>
              )}
            </div>

            <div className="flex flex-col gap-1">
              <label htmlFor="passwordConfirm" className="text-sm font-medium">
                비밀번호 확인
              </label>
              <input
                id="passwordConfirm"
                type="password"
                placeholder="비밀번호를 한 번 더 입력"
                className={`input input-bordered w-full ${passwordMismatch ? "input-error" : ""}`}
                value={form.passwordConfirm}
                onChange={updateField("passwordConfirm")}
                required
              />
              {passwordMismatch && (
                <p className="text-error text-xs">비밀번호가 일치하지 않습니다</p>
              )}
            </div>

            <div className="flex flex-col gap-1">
              <label htmlFor="name" className="text-sm font-medium">
                이름 (수령인)
              </label>
              <input
                id="name"
                type="text"
                placeholder="홍길동"
                className={`input input-bordered w-full ${submitAttempted && !form.name ? "input-error" : ""}`}
                value={form.name}
                onChange={updateField("name")}
                required
              />
              {submitAttempted && !form.name && (
                <p className="text-error text-xs">이름을 입력해주세요</p>
              )}
            </div>

            <div className="flex flex-col gap-1">
              <label htmlFor="phone" className="text-sm font-medium">
                휴대폰번호
              </label>
              <input
                id="phone"
                type="tel"
                inputMode="numeric"
                placeholder="'-' 없이 숫자만, 최대 11자"
                className={`input input-bordered w-full ${submitAttempted && !form.phone ? "input-error" : ""}`}
                value={form.phone}
                onChange={updatePhone}
                maxLength={11}
                required
              />
              {submitAttempted && !form.phone && (
                <p className="text-error text-xs">휴대폰번호를 입력해주세요</p>
              )}
            </div>

            <div className="flex flex-col gap-1">
              <label className="text-sm font-medium">주소</label>
              <div className="flex gap-2">
                <input
                  type="text"
                  placeholder="우편번호"
                  className="input input-bordered flex-1"
                  value={form.postcode}
                  readOnly
                  required
                />
                <button type="button" className="btn btn-outline" onClick={openPostcodeSearch}>
                  주소 검색
                </button>
              </div>
            </div>
            <input
              type="text"
              placeholder="기본주소 (주소 검색으로 자동 입력)"
              className="input input-bordered w-full"
              value={form.address}
              readOnly
              required
            />
            <div className="flex flex-col gap-1">
              <input
                id="address-detail-input"
                type="text"
                placeholder="상세주소 (동/호수 등)"
                className={`input input-bordered w-full ${submitAttempted && !form.addressDetail ? "input-error" : ""}`}
                value={form.addressDetail}
                onChange={updateField("addressDetail")}
                required
              />
              {submitAttempted && !form.addressDetail && (
                <p className="text-error text-xs">상세주소를 입력해주세요</p>
              )}
            </div>

            <div className="divider my-1" />

            <label className="flex items-center gap-2 cursor-pointer">
              <input
                type="checkbox"
                className="checkbox checkbox-sm"
                checked={allAgreed}
                onChange={toggleAllAgreed}
              />
              <span className="font-semibold">전체 동의</span>
            </label>
            <label className="flex items-center gap-2 cursor-pointer pl-1 text-sm">
              <input
                type="checkbox"
                className="checkbox checkbox-xs"
                checked={form.termsAgreed}
                onChange={updateField("termsAgreed")}
              />
              <span>[필수] 이용약관 동의</span>
            </label>
            <label className="flex items-center gap-2 cursor-pointer pl-1 text-sm">
              <input
                type="checkbox"
                className="checkbox checkbox-xs"
                checked={form.privacyAgreed}
                onChange={updateField("privacyAgreed")}
              />
              <span>[필수] 개인정보 수집·이용 동의</span>
            </label>
            <label className="flex items-center gap-2 cursor-pointer pl-1 text-sm">
              <input
                type="checkbox"
                className="checkbox checkbox-xs"
                checked={form.marketingAgreed}
                onChange={updateField("marketingAgreed")}
              />
              <span>[선택] 마케팅 정보 수신 동의</span>
            </label>

            {error && <p className="text-error text-sm">{error}</p>}

            <button
              type="submit"
              className="btn btn-primary mt-2"
              disabled={loading || passwordIssues.length > 0 || passwordMismatch}
            >
              {loading ? <span className="loading loading-spinner" /> : "가입하기"}
            </button>
          </form>

          <p className="text-center text-sm mt-4">
            이미 계정이 있으신가요?{" "}
            <Link to="/login" className="link link-primary">
              로그인
            </Link>
          </p>
        </div>
      </div>
    </div>
  );
}
