import React, { createContext, useCallback, useEffect, useMemo, useState } from "react";

import { login as loginRequest } from "../services/api";

const SESSION_KEY = "rcktscore.auth";

export const AuthContext = createContext(null);

function readStoredSession() {
  if (typeof window === "undefined") {
    return null;
  }

  try {
    const rawValue = window.sessionStorage.getItem(SESSION_KEY);
    if (!rawValue) {
      return null;
    }

    const parsedValue = JSON.parse(rawValue);
    if (!parsedValue?.username) {
      return null;
    }

    return parsedValue;
  } catch {
    return null;
  }
}

export function AuthProvider({ children }) {
  const [session, setSession] = useState(() => readStoredSession());
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (typeof window === "undefined") {
      return;
    }

    if (!session) {
      window.sessionStorage.removeItem(SESSION_KEY);
      return;
    }

    window.sessionStorage.setItem(SESSION_KEY, JSON.stringify(session));
  }, [session]);

  const login = useCallback(async (username, password) => {
    const trimmedUsername = username.trim();
    const trimmedPassword = password.trim();

    if (!trimmedUsername || !trimmedPassword) {
      return {
        ok: false,
        message: "Username and password are required.",
      };
    }

    setLoading(true);
    try {
      const response = await loginRequest({
        username: trimmedUsername,
        password: trimmedPassword,
      });
      setSession({
        ...response.session,
        loggedInAt: new Date().toISOString(),
      });

      return { ok: true, session: response.session };
    } catch (requestError) {
      return {
        ok: false,
        message: requestError.message || "Login failed.",
      };
    } finally {
      setLoading(false);
    }
  }, []);

  const logout = useCallback(() => {
    setSession(null);
  }, []);

  const contextValue = useMemo(
    () => ({
      isAuthenticated: Boolean(session),
      session,
      loading,
      setSession,
      login,
      logout,
    }),
    [loading, login, logout, session],
  );

  return <AuthContext.Provider value={contextValue}>{children}</AuthContext.Provider>;
}
