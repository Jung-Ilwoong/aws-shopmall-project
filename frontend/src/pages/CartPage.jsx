import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import client from "../api/client";
import { useAuth } from "../context/AuthContext";

export default function CartPage() {
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const { isLoggedIn } = useAuth();
  const navigate = useNavigate();

  const loadCart = () => {
    client.get("/cart").then((res) => setItems(res.data)).finally(() => setLoading(false));
  };

  useEffect(() => {
    if (!isLoggedIn) {
      navigate("/login");
      return;
    }
    loadCart();
  }, [isLoggedIn]);

  const removeItem = async (itemId) => {
    await client.delete(`/cart/${itemId}`);
    loadCart();
  };

  const changeQuantity = async (item, delta) => {
    const nextQuantity = item.quantity + delta;
    if (nextQuantity < 1) return;

    setError("");
    try {
      const res = await client.put(`/cart/${item.id}`, { quantity: nextQuantity });
      setItems((prev) => prev.map((i) => (i.id === item.id ? res.data : i)));
    } catch (err) {
      setError(err.response?.data?.detail || "수량 변경에 실패했습니다.");
    }
  };

  const checkout = async () => {
    setError("");
    try {
      const res = await client.post("/orders");
      navigate(`/orders/${res.data.id}`);
    } catch (err) {
      setError(err.response?.data?.detail || "주문에 실패했습니다.");
    }
  };

  if (loading) {
    return (
      <div className="flex justify-center py-20">
        <span className="loading loading-spinner loading-lg" />
      </div>
    );
  }

  const total = items.reduce((sum, i) => sum + i.product.price * i.quantity, 0);

  return (
    <div>
      <h1 className="text-2xl font-bold mb-4">장바구니</h1>

      {items.length === 0 ? (
        <p className="text-gray-500">장바구니가 비어있습니다.</p>
      ) : (
        <>
          <div className="flex flex-col gap-3">
            {items.map((item) => (
              <div key={item.id} className="flex items-center justify-between border-b pb-3">
                <div>
                  <p className="font-medium">{item.product.name}</p>
                  <p className="text-sm text-gray-500">{item.product.price.toLocaleString()}원</p>
                </div>

                <div className="flex items-center gap-4">
                  <div className="join">
                    <button
                      className="btn btn-sm join-item"
                      onClick={() => changeQuantity(item, -1)}
                      disabled={item.quantity <= 1}
                    >
                      -
                    </button>
                    <span className="btn btn-sm join-item pointer-events-none">{item.quantity}</span>
                    <button
                      className="btn btn-sm join-item"
                      onClick={() => changeQuantity(item, 1)}
                      disabled={item.quantity >= item.product.stock}
                    >
                      +
                    </button>
                  </div>

                  <p className="font-medium w-24 text-right">
                    {(item.product.price * item.quantity).toLocaleString()}원
                  </p>

                  <button className="btn btn-sm btn-ghost text-error" onClick={() => removeItem(item.id)}>
                    삭제
                  </button>
                </div>
              </div>
            ))}
          </div>

          <div className="flex justify-between items-center mt-6">
            <p className="text-xl font-bold">합계: {total.toLocaleString()}원</p>
            <button className="btn btn-primary" onClick={checkout}>
              주문하기
            </button>
          </div>

          {error && <p className="text-error text-sm mt-2">{error}</p>}
        </>
      )}
    </div>
  );
}
