import { useEffect, useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import client from "../api/client";
import { useAuth } from "../context/AuthContext";

export default function OrderHistoryPage() {
  const [orders, setOrders] = useState([]);
  const [loading, setLoading] = useState(true);
  const { isLoggedIn } = useAuth();
  const navigate = useNavigate();

  useEffect(() => {
    if (!isLoggedIn) {
      navigate("/login");
      return;
    }
    client.get("/orders").then((res) => setOrders(res.data)).finally(() => setLoading(false));
  }, [isLoggedIn]);

  if (loading) {
    return (
      <div className="flex justify-center py-20">
        <span className="loading loading-spinner loading-lg" />
      </div>
    );
  }

  return (
    <div>
      <h1 className="text-2xl font-bold mb-4">주문내역</h1>

      {orders.length === 0 ? (
        <p className="text-gray-500">주문 내역이 없습니다.</p>
      ) : (
        <div className="flex flex-col gap-3">
          {orders.map((o) => (
            <Link
              key={o.id}
              to={`/orders/${o.id}`}
              className="border rounded-lg p-4 flex justify-between items-center hover:bg-base-200"
            >
              <div>
                <p className="font-medium">주문 #{o.id}</p>
                <p className="text-sm text-gray-500">{new Date(o.created_at).toLocaleString()}</p>
              </div>
              <div className="text-right">
                <p className="font-bold">{o.total_price.toLocaleString()}원</p>
                <span className="badge badge-outline">{o.status}</span>
              </div>
            </Link>
          ))}
        </div>
      )}
    </div>
  );
}
