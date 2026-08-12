import { createContext, useContext, useEffect, useState } from "react";
import client from "../api/client";

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [token, setToken] = useState(localStorage.getItem("token"));
  const [user, setUser] = useState(null);
  const [verifyModalOpen, setVerifyModalOpen] = useState(false);

  const fetchMe = async () => {
    try {
      const res = await client.get("/auth/me");
      setUser(res.data);
    } catch {
      logout();
    }
  };

  useEffect(() => {
    if (token) fetchMe();
  }, [token]);

  const login = async (email, password) => {
    const form = new URLSearchParams();
    form.append("username", email);
    form.append("password", password);

    const res = await client.post("/auth/login", form, {
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
    });

    localStorage.setItem("token", res.data.access_token);
    setToken(res.data.access_token);
  };

  const logout = () => {
    localStorage.removeItem("token");
    setToken(null);
    setUser(null);
  };

  const value = {
    token,
    user,
    isLoggedIn: !!token,
    isAdmin: !!user?.is_admin,
    isEmailVerified: !!user?.is_email_verified,
    login,
    logout,
    refreshUser: fetchMe,
    verifyModalOpen,
    openVerifyModal: () => setVerifyModalOpen(true),
    closeVerifyModal: () => setVerifyModalOpen(false),
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  return useContext(AuthContext);
}
