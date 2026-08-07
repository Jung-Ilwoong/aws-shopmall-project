import { useState } from "react";
import { useNavigate, Link } from "react-router-dom";
import { useAuth } from "../context/AuthContext";

export default function LoginPage() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const { login } = useAuth();
  const navigate = useNavigate();

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError("");
    setLoading(true);
    try {
      await login(email, password);
      navigate("/");
    } catch {
      setError("이메일 또는 비밀번호가 올바르지 않습니다.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-[80vh] flex items-center justify-center">
      <div className="card w-full max-w-sm bg-base-100 shadow-md">
        <div className="card-body">
          <h1 className="text-2xl font-bold text-center mb-4">로그인</h1>

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
              placeholder="비밀번호"
              className="input input-bordered w-full"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
            />

            {error && <p className="text-error text-sm">{error}</p>}

            <button type="submit" className="btn btn-primary mt-2" disabled={loading}>
              {loading ? <span className="loading loading-spinner" /> : "로그인"}
            </button>
          </form>

          <p className="text-center text-sm mt-4">
            계정이 없으신가요?{" "}
            <Link to="/register" className="link link-primary">
              회원가입
            </Link>
          </p>
        </div>
      </div>
    </div>
  );
}
