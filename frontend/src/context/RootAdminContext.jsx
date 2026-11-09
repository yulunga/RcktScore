import React, { createContext, useCallback, useEffect, useMemo, useState } from "react";

import {
  getRootAdminSessionStatus,
  rootAdminLogin as rootAdminLoginRequest,
  rootAdminLogout as rootAdminLogoutRequest,
  setRootAdminCsrfToken,
} from "../services/api";

const ROOT_ADMIN_SESSION_KEY = "rcktscore.root_admin";
export const RootAdminContext = createContext(null);

function cleanSession(value) {
  if (!value) return null;
  const { session_token: _legacyToken, sessionToken: _legacyCamelToken, csrf_token: _csrf, ...session } = value;
  return session;
}

function clearLegacyStorage() {
  if (typeof window !== "undefined") window.sessionStorage.removeItem(ROOT_ADMIN_SESSION_KEY);
}

export function RootAdminProvider({ children }) {
  const [session, setSession] = useState(null);
  const [restoringSession, setRestoringSession] = useState(true);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    clearLegacyStorage();
    let cancelled = false;
    getRootAdminSessionStatus().then((response) => {
      if (cancelled) return;
      setRootAdminCsrfToken(response?.rootAdminSession?.csrf_token || "");
      setSession(cleanSession(response?.rootAdminSession));
    }).catch(() => {
      if (!cancelled) {
        setRootAdminCsrfToken("");
        setSession(null);
      }
    }).finally(() => {
      if (!cancelled) setRestoringSession(false);
    });
    return () => { cancelled = true; };
  }, []);

  useEffect(() => {
    if (typeof window === "undefined") return undefined;
    const handleSessionInvalidated = () => {
      setRootAdminCsrfToken("");
      clearLegacyStorage();
      setSession(null);
    };
    window.addEventListener("rcktscore:root-admin-session-invalidated", handleSessionInvalidated);
    return () => window.removeEventListener("rcktscore:root-admin-session-invalidated", handleSessionInvalidated);
  }, []);

  const login = useCallback(async (username, password) => {
    const trimmedUsername = username.trim();
    const trimmedPassword = password.trim();
    if (!trimmedUsername || !trimmedPassword) return { ok: false, message: "Username and password are required." };
    setLoading(true);
    try {
      const response = await rootAdminLoginRequest({ username: trimmedUsername, password: trimmedPassword });
      setRootAdminCsrfToken(response?.rootAdminSession?.csrf_token || "");
      const nextSession = { ...cleanSession(response.rootAdminSession), loggedInAt: new Date().toISOString() };
      clearLegacyStorage();
      setSession(nextSession);
      return { ok: true, session: nextSession };
    } catch (requestError) {
      return { ok: false, message: requestError.message || "Login failed." };
    } finally {
      setLoading(false);
    }
  }, []);

  const logout = useCallback(() => {
    rootAdminLogoutRequest().catch(() => {}).finally(() => setRootAdminCsrfToken(""));
    clearLegacyStorage();
    setSession(null);
  }, []);

  const contextValue = useMemo(() => ({
    isAuthenticated: Boolean(session), session, restoringSession, loading, setSession, login, logout,
  }), [loading, login, logout, restoringSession, session]);

  return <RootAdminContext.Provider value={contextValue}>{children}</RootAdminContext.Provider>;
}
