import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import client from "../api/client";
import { useAuth } from "../context/AuthContext";

const emptyForm = { name: "", description: "", price: "", stock: "", image_url: "", category: "" };

export default function AdminProductsPage() {
  const [products, setProducts] = useState([]);
  const [form, setForm] = useState(emptyForm);
  const [editingId, setEditingId] = useState(null);
  const [generating, setGenerating] = useState(false);
  const { isLoggedIn, isAdmin, user } = useAuth();
  const navigate = useNavigate();

  const loadProducts = () => {
    client.get("/products").then((res) => setProducts(res.data));
  };

  useEffect(() => {
    if (!isLoggedIn) {
      navigate("/login");
      return;
    }
    if (user && !isAdmin) {
      navigate("/");
      return;
    }
    loadProducts();
  }, [isLoggedIn, isAdmin, user]);

  const handleGenerateDescription = async () => {
    if (!form.name) return;
    setGenerating(true);
    try {
      const res = await client.post("/products/generate-description", {
        name: form.name,
        category: form.category || null,
      });
      setForm((f) => ({ ...f, description: res.data.description }));
    } finally {
      setGenerating(false);
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    const payload = {
      ...form,
      price: Number(form.price),
      stock: Number(form.stock),
      category: form.category || null,
    };

    if (editingId) {
      await client.put(`/products/${editingId}`, payload);
    } else {
      await client.post("/products", payload);
    }
    setForm(emptyForm);
    setEditingId(null);
    loadProducts();
  };

  const handleEdit = (p) => {
    setForm({
      name: p.name,
      description: p.description || "",
      price: p.price,
      stock: p.stock,
      image_url: p.image_url || "",
      category: p.category || "",
    });
    setEditingId(p.id);
  };

  const handleDelete = async (id) => {
    await client.delete(`/products/${id}`);
    loadProducts();
  };

  return (
    <div>
      <h1 className="text-2xl font-bold mb-4">상품 관리</h1>

      <form onSubmit={handleSubmit} className="card bg-base-100 shadow-sm p-4 mb-8 flex flex-col gap-3">
        <h2 className="font-bold">{editingId ? "상품 수정" : "새 상품 등록"}</h2>

        <div className="flex gap-3">
          <input
            className="input input-bordered w-full"
            placeholder="상품명"
            value={form.name}
            onChange={(e) => setForm({ ...form, name: e.target.value })}
            required
          />
          <input
            className="input input-bordered w-full"
            placeholder="카테고리 (선택)"
            value={form.category}
            onChange={(e) => setForm({ ...form, category: e.target.value })}
          />
        </div>

        <div className="flex gap-2">
          <textarea
            className="textarea textarea-bordered w-full"
            placeholder="상품 설명"
            value={form.description}
            onChange={(e) => setForm({ ...form, description: e.target.value })}
          />
          <button
            type="button"
            className="btn btn-outline btn-secondary whitespace-nowrap"
            onClick={handleGenerateDescription}
            disabled={!form.name || generating}
          >
            {generating ? <span className="loading loading-spinner loading-sm" /> : "AI로 설명 생성"}
          </button>
        </div>

        <div className="flex gap-3">
          <input
            type="number"
            className="input input-bordered w-full"
            placeholder="가격"
            value={form.price}
            onChange={(e) => setForm({ ...form, price: e.target.value })}
            required
          />
          <input
            type="number"
            className="input input-bordered w-full"
            placeholder="재고"
            value={form.stock}
            onChange={(e) => setForm({ ...form, stock: e.target.value })}
            required
          />
        </div>

        <input
          className="input input-bordered w-full"
          placeholder="이미지 URL (선택)"
          value={form.image_url}
          onChange={(e) => setForm({ ...form, image_url: e.target.value })}
        />

        <div className="flex gap-2">
          <button type="submit" className="btn btn-primary">
            {editingId ? "수정 완료" : "등록"}
          </button>
          {editingId && (
            <button
              type="button"
              className="btn btn-ghost"
              onClick={() => {
                setForm(emptyForm);
                setEditingId(null);
              }}
            >
              취소
            </button>
          )}
        </div>
      </form>

      <div className="flex flex-col gap-2">
        {products.map((p) => (
          <div key={p.id} className="flex justify-between items-center border-b pb-2">
            <div>
              <p className="font-medium">
                {p.name} {p.category && <span className="badge badge-sm badge-outline ml-1">{p.category}</span>}
              </p>
              <p className="text-sm text-gray-500">
                {p.price.toLocaleString()}원 · 재고 {p.stock}개
              </p>
            </div>
            <div className="flex gap-2">
              <button className="btn btn-sm" onClick={() => handleEdit(p)}>
                수정
              </button>
              <button className="btn btn-sm btn-error btn-outline" onClick={() => handleDelete(p.id)}>
                삭제
              </button>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
