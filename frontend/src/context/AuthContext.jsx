import React, { createContext, useCallback, useEffect, useMemo, useState } from "react";

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

  const login = useCallback((username, password) => {
    const trimmedUsername = username.trim();
    const trimmedPassword = password.trim();

    if (!trimmedUsername || !trimmedPassword) {
      return {
        ok: false,
        message: "Username and password are required.",
      };
    }

    setSession({
      username: trimmedUsername,
      loggedInAt: new Date().toISOString(),
    });

    return { ok: true };
  }, []);

  const logout = useCallback(() => {
    setSession(null);
  }, []);

  const contextValue = useMemo(
    () => ({
      isAuthenticated: Boolean(session),
      session,
      login,
      logout,
    }),
    [login, logout, session],
  );

  return <AuthContext.Provider value={contextValue}>{children}</AuthContext.Provider>;
}
