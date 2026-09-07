import React, { createContext, useCallback, useEffect, useMemo, useState } from "react";

import {
  rootAdminLogin as rootAdminLoginRequest,
  rootAdminLogout as rootAdminLogoutRequest,
} from "../services/api";

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
    if (!parsedValue?.username || !parsedValue?.session_token) {
      return null;
    }

    if (parsedValue.expires_at && new Date(parsedValue.expires_at).getTime() <= Date.now()) {
      window.sessionStorage.removeItem(ROOT_ADMIN_SESSION_KEY);
      return null;
    }

    return parsedValue;
  } catch {
    return null;
  }
}

function writeStoredSession(nextSession) {
  if (typeof window === "undefined") {
    return;
  }

  if (!nextSession) {
    window.sessionStorage.removeItem(ROOT_ADMIN_SESSION_KEY);
    return;
  }

  window.sessionStorage.setItem(ROOT_ADMIN_SESSION_KEY, JSON.stringify(nextSession));
}

export function RootAdminProvider({ children }) {
  const [session, setSession] = useState(() => readStoredSession());
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    writeStoredSession(session);
  }, [session]);

  useEffect(() => {
    if (typeof window === "undefined") {
      return undefined;
    }

    const handleSessionInvalidated = () => {
      writeStoredSession(null);
      setSession(null);
    };

    window.addEventListener("rcktscore:root-admin-session-invalidated", handleSessionInvalidated);
    return () => {
      window.removeEventListener("rcktscore:root-admin-session-invalidated", handleSessionInvalidated);
    };
  }, []);

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
      const nextSession = {
        ...response.rootAdminSession,
        loggedInAt: new Date().toISOString(),
      };
      writeStoredSession(nextSession);
      setSession(nextSession);

      return { ok: true, session: nextSession };
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
    const token = session?.session_token || null;
    if (token) {
      rootAdminLogoutRequest(token).catch(() => {});
    }
    writeStoredSession(null);
    setSession(null);
  }, [session]);

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
