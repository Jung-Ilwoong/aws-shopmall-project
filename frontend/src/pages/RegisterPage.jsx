import { useState } from "react";
import { useNavigate, Link } from "react-router-dom";
import client from "../api/client";

export default function RegisterPage() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const navigate = useNavigate();

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError("");
    setLoading(true);
    try {
      await client.post("/auth/register", { email, password });
      navigate("/login");
    } catch (err) {
      setError(err.response?.data?.detail || "회원가입에 실패했습니다.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-[80vh] flex items-center justify-center">
      <div className="card w-full max-w-sm bg-base-100 shadow-md">
        <div className="card-body">
          <h1 className="text-2xl font-bold text-center mb-4">회원가입</h1>

          <form onSubmit={handleSubmit} className="flex flex-col gap-3">
            <input
              type="email"
              placeholder="이메일"
              className="input input-bordered w-full"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
            />
            <input
              type="password"
              placeholder="비밀번호 (8자 이상)"
              className="input input-bordered w-full"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              minLength={8}
              required
            />

            {error && <p className="text-error text-sm">{error}</p>}

            <button type="submit" className="btn btn-primary mt-2" disabled={loading}>
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
