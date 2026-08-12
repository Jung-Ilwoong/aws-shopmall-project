import { Link } from "react-router-dom";
import { useAuth } from "../context/AuthContext";

export default function Header() {
  const { isLoggedIn, isAdmin, logout } = useAuth();

  return (
    <div className="bg-base-100 shadow-sm sticky top-0 z-50">
      <div className="navbar max-w-4xl mx-auto w-full px-4 sm:px-6 lg:px-8">
        <div className="flex-1">
          <Link to="/" className="btn btn-ghost text-xl">
            🛒 Shopmall
          </Link>
        </div>
        <div className="flex-none gap-2">
          {isLoggedIn ? (
            <>
              <Link to="/cart" className="btn btn-ghost">
                장바구니
              </Link>
              {isAdmin && (
                <Link to="/admin/products" className="btn btn-ghost">
                  상품 관리
                </Link>
              )}
              <Link to="/orders" className="btn btn-ghost">
                주문내역
              </Link>
              <button onClick={logout} className="btn btn-ghost">
                로그아웃
              </button>
            </>
          ) : (
            <Link to="/login" className="btn btn-ghost">
              로그인/회원가입
            </Link>
          )}
        </div>
      </div>
    </div>
  );
}
