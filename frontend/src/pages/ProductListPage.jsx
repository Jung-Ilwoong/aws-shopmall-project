import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import client from "../api/client";

export default function ProductListPage() {
  const [products, setProducts] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    client
      .get("/products")
      .then((res) => setProducts(res.data))
      .finally(() => setLoading(false));
  }, []);

  if (loading) {
    return (
      <div className="flex justify-center py-20">
        <span className="loading loading-spinner loading-lg" />
      </div>
    );
  }

  if (products.length === 0) {
    return <p className="text-center py-20 text-gray-500">등록된 상품이 없습니다.</p>;
  }

  return (
    <div className="p-6 grid grid-cols-1 sm:grid-cols-2 md:grid-cols-4 gap-4">
      {products.map((p) => (
        <Link
          key={p.id}
          to={`/products/${p.id}`}
          className="card bg-base-100 shadow-sm hover:shadow-md transition-shadow"
        >
          <figure className="h-40 bg-base-200">
            {p.image_url ? (
              <img src={p.image_url} alt={p.name} className="object-cover w-full h-full" />
            ) : (
              <span className="text-4xl">📦</span>
            )}
          </figure>
          <div className="card-body p-4">
            <h2 className="card-title text-base">{p.name}</h2>
            <p className="text-lg font-bold">{p.price.toLocaleString()}원</p>
          </div>
        </Link>
      ))}
    </div>
  );
}
