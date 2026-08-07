import { useEffect, useState } from "react";
import { useParams, useNavigate } from "react-router-dom";
import client from "../api/client";
import { useAuth } from "../context/AuthContext";

export default function OrderDetailPage() {
  const { id } = useParams();
  const [order, setOrder] = useState(null);
  const { isLoggedIn } = useAuth();
  const navigate = useNavigate();

  useEffect(() => {
    if (!isLoggedIn) {
      navigate("/login");
      return;
    }
    client.get(`/orders/${id}`).then((res) => setOrder(res.data));
  }, [id, isLoggedIn]);

  if (!order) {
    return (
      <div className="flex justify-center py-20">
        <span className="loading loading-spinner loading-lg" />
      </div>
    );
  }

  return (
    <div>
      <h1 className="text-2xl font-bold mb-1">주문 #{order.id}</h1>
      <p className="text-sm text-gray-500 mb-4">{new Date(order.created_at).toLocaleString()}</p>

      <span className="badge badge-primary mb-4">{order.status}</span>

      <div className="flex flex-col gap-2 border-t pt-4">
        {order.items.map((item, idx) => (
          <div key={idx} className="flex justify-between">
            <span>상품 #{item.product_id} x {item.quantity}</span>
            <span>{(item.price_at_order * item.quantity).toLocaleString()}원</span>
          </div>
        ))}
      </div>

      <p className="text-xl font-bold text-right mt-4">합계: {order.total_price.toLocaleString()}원</p>
    </div>
  );
}
