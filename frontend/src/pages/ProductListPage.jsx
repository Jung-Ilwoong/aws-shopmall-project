import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import client from "../api/client";

export default function ProductListPage() {
  const [products, setProducts] = useState([]);
  const [categories, setCategories] = useState([]);
  const [search, setSearch] = useState("");
  const [category, setCategory] = useState("");
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    client.get("/products/meta/categories").then((res) => setCategories(res.data));
  }, []);

  useEffect(() => {
    setLoading(true);
    const params = {};
    if (search) params.search = search;
    if (category) params.category = category;

    const timeout = setTimeout(() => {
      client
        .get("/products", { params })
        .then((res) => setProducts(res.data))
        .finally(() => setLoading(false));
    }, 300);

    return () => clearTimeout(timeout);
  }, [search, category]);

  return (
    <div>
      <div className="sticky top-16 z-40 bg-base-100 flex flex-col sm:flex-row gap-2 py-3 mb-3">
        <input
          type="text"
          placeholder="상품명 검색"
          className="input input-bordered flex-1"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
        <select
          className="select select-bordered"
          value={category}
          onChange={(e) => setCategory(e.target.value)}
        >
          <option value="">전체 카테고리</option>
          {categories.map((c) => (
            <option key={c} value={c}>
              {c}
            </option>
          ))}
        </select>
      </div>

      {loading ? (
        <div className="flex justify-center py-20">
          <span className="loading loading-spinner loading-lg" />
        </div>
      ) : products.length === 0 ? (
        <p className="text-center py-20 text-gray-500">조건에 맞는 상품이 없습니다.</p>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
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
      )}
    </div>
  );
}
