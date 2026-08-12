import { Routes, Route } from "react-router-dom";
import Header from "./components/Header";
import ChatWidget from "./components/ChatWidget";
import EmailVerifyGate from "./components/EmailVerifyGate";
import LoginPage from "./pages/LoginPage";
import RegisterPage from "./pages/RegisterPage";
import ProductListPage from "./pages/ProductListPage";
import ProductDetailPage from "./pages/ProductDetailPage";
import CartPage from "./pages/CartPage";
import OrderHistoryPage from "./pages/OrderHistoryPage";
import OrderDetailPage from "./pages/OrderDetailPage";
import AdminProductsPage from "./pages/AdminProductsPage";

function App() {
  return (
    <>
      <Header />
      <EmailVerifyGate />
      <main className="max-w-4xl mx-auto w-full px-4 sm:px-6 lg:px-8 py-6">
        <Routes>
          <Route path="/" element={<ProductListPage />} />
          <Route path="/login" element={<LoginPage />} />
          <Route path="/register" element={<RegisterPage />} />
          <Route path="/products/:id" element={<ProductDetailPage />} />
          <Route path="/cart" element={<CartPage />} />
          <Route path="/orders" element={<OrderHistoryPage />} />
          <Route path="/orders/:id" element={<OrderDetailPage />} />
          <Route path="/admin/products" element={<AdminProductsPage />} />
        </Routes>
      </main>
      <ChatWidget />
    </>
  );
}

export default App;
