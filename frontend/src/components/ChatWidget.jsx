import { useEffect, useRef, useState } from "react";
import client from "../api/client";

export default function ChatWidget() {
  const [open, setOpen] = useState(false);
  const [messages, setMessages] = useState([
    { role: "assistant", text: "안녕하세요! 상품에 대해 궁금한 점을 물어보세요." },
  ]);
  const [input, setInput] = useState("");
  const [loading, setLoading] = useState(false);
  const bottomRef = useRef(null);

  useEffect(() => {
    if (open) {
      bottomRef.current?.scrollIntoView({ behavior: "smooth" });
    }
  }, [messages, open]);

  const sendMessage = async (e) => {
    e.preventDefault();
    const text = input.trim();
    if (!text || loading) return;

    setMessages((prev) => [...prev, { role: "user", text }]);
    setInput("");
    setLoading(true);

    try {
      const res = await client.post("/chat", { message: text });
      setMessages((prev) => [...prev, { role: "assistant", text: res.data.reply }]);
    } catch {
      setMessages((prev) => [...prev, { role: "assistant", text: "죄송해요, 응답을 받아오지 못했습니다." }]);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="fixed bottom-4 right-4 z-50 flex flex-col items-end gap-3">
      {open && (
        <div className="card w-80 h-96 bg-base-100 shadow-xl flex flex-col">
          <div className="bg-primary text-primary-content px-4 py-3 rounded-t-2xl flex justify-between items-center">
            <span className="font-bold">쇼핑 도우미</span>
            <button className="btn btn-ghost btn-xs text-primary-content" onClick={() => setOpen(false)}>
              ✕
            </button>
          </div>

          <div className="flex-1 overflow-y-auto p-3 flex flex-col gap-2">
            {messages.map((m, idx) => (
              <div
                key={idx}
                className={`chat ${m.role === "user" ? "chat-end" : "chat-start"}`}
              >
                <div className={`chat-bubble ${m.role === "user" ? "chat-bubble-primary" : ""}`}>
                  {m.text}
                </div>
              </div>
            ))}
            {loading && (
              <div className="chat chat-start">
                <div className="chat-bubble">
                  <span className="loading loading-dots loading-sm" />
                </div>
              </div>
            )}
            <div ref={bottomRef} />
          </div>

          <form onSubmit={sendMessage} className="p-2 border-t flex gap-2">
            <input
              className="input input-bordered input-sm flex-1"
              placeholder="메시지를 입력하세요"
              value={input}
              onChange={(e) => setInput(e.target.value)}
              disabled={loading}
            />
            <button type="submit" className="btn btn-primary btn-sm" disabled={loading}>
              전송
            </button>
          </form>
        </div>
      )}

      <button
        className="btn btn-circle btn-primary btn-lg shadow-lg"
        onClick={() => setOpen((v) => !v)}
      >
        {open ? "✕" : "💬"}
      </button>
    </div>
  );
}
