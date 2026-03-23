import React, { createContext, useCallback, useEffect, useMemo, useState } from "react";

import { rootAdminLogin as rootAdminLoginRequest } from "../services/api";

const ROOT_ADMIN_SESSION_KEY = "rcktscore.root_admin";

export const RootAdminContext = createContext(null);

function readStoredSession() {
  if (typeof window === "undefined") {
    return null;
  }

  try {
    const rawValue = window.sessionStorage.getItem(ROOT_ADMIN_SESSION_KEY);
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

export function RootAdminProvider({ children }) {
  const [session, setSession] = useState(() => readStoredSession());
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (typeof window === "undefined") {
      return;
    }

    if (!session) {
      window.sessionStorage.removeItem(ROOT_ADMIN_SESSION_KEY);
      return;
    }

    window.sessionStorage.setItem(ROOT_ADMIN_SESSION_KEY, JSON.stringify(session));
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
      const response = await rootAdminLoginRequest({
        username: trimmedUsername,
        password: trimmedPassword,
      });
      setSession({
        ...response.rootAdminSession,
        loggedInAt: new Date().toISOString(),
      });

      return { ok: true, session: response.rootAdminSession };
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

  return <RootAdminContext.Provider value={contextValue}>{children}</RootAdminContext.Provider>;
}
