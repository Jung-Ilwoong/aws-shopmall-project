import { useEffect, useState } from "react";
import { useParams, useNavigate } from "react-router-dom";
import client from "../api/client";
import { useAuth } from "../context/AuthContext";

export default function ProductDetailPage() {
  const { id } = useParams();
  const [product, setProduct] = useState(null);
  const [quantity, setQuantity] = useState(1);
  const [message, setMessage] = useState("");
  const { isLoggedIn } = useAuth();
  const navigate = useNavigate();

  useEffect(() => {
    client.get(`/products/${id}`).then((res) => setProduct(res.data));
  }, [id]);

  const addToCart = async () => {
    if (!isLoggedIn) {
      navigate("/login");
      return;
    }
    try {
      await client.post("/cart", { product_id: Number(id), quantity });
      setMessage("장바구니에 담았습니다.");
    } catch (err) {
      setMessage(err.response?.data?.detail || "장바구니 담기에 실패했습니다.");
    }
  };

  if (!product) {
    return (
      <div className="flex justify-center py-20">
        <span className="loading loading-spinner loading-lg" />
      </div>
    );
  }

  return (
    <div className="p-6 max-w-2xl mx-auto">
      <div className="h-64 bg-base-200 rounded-lg flex items-center justify-center mb-4">
        {product.image_url ? (
          <img src={product.image_url} alt={product.name} className="object-cover w-full h-full rounded-lg" />
        ) : (
          <span className="text-6xl">📦</span>
        )}
      </div>

      <h1 className="text-2xl font-bold">{product.name}</h1>
      <p className="text-xl font-bold my-2">{product.price.toLocaleString()}원</p>
      <p className="text-gray-500 mb-1">재고: {product.stock}개</p>
      <p className="text-gray-600 my-4">{product.description}</p>

      <div className="flex items-center gap-3 mb-4">
        <input
          type="number"
          min="1"
          max={product.stock}
          value={quantity}
          onChange={(e) => setQuantity(Number(e.target.value))}
          className="input input-bordered w-24"
        />
        <button className="btn btn-primary" onClick={addToCart} disabled={product.stock === 0}>
          장바구니 담기
        </button>
      </div>

      {message && <p className="text-sm text-info">{message}</p>}
    </div>
  );
}
