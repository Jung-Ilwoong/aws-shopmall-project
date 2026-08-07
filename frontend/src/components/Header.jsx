import { Link } from "react-router-dom";
import { useAuth } from "../context/AuthContext";

export default function Header() {
  const { isLoggedIn, isAdmin, logout } = useAuth();

  return (
    <div className="navbar bg-base-100 shadow-sm px-4">
      <div className="flex-1">
        <Link to="/" className="btn btn-ghost text-xl">
          🛒 Shopmall
        </Link>
      </div>
      <div className="flex-none gap-2">
        <Link to="/cart" className="btn btn-ghost btn-circle">
          🛍️
        </Link>
        {isLoggedIn ? (
          <>
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
          <Link to="/login" className="btn btn-primary">
            로그인
          </Link>
        )}
      </div>
    </div>
  );
}
