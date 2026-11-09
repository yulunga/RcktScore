import React, { createContext, useCallback, useEffect, useMemo, useState } from "react";

import { getSessionStatus, login as loginRequest, logout as logoutRequest, setWebCsrfToken } from "../services/api";

const SESSION_KEY = "rcktscore.auth";
export const AuthContext = createContext(null);

function withoutSecrets(value) {
  if (!value || typeof value !== "object") return value;
  if (Array.isArray(value)) return value.map(withoutSecrets);
  return Object.fromEntries(Object.entries(value)
    .filter(([key]) => !["session_token", "sessionToken", "csrf_token", "csrfToken"].includes(key))
    .map(([key, item]) => [key, withoutSecrets(item)]));
}

function readStoredAuthState() {
  if (typeof window === "undefined") return { session: null, pendingSelection: null };
  try {
    const parsed = JSON.parse(window.sessionStorage.getItem(SESSION_KEY) || "null");
    const cleaned = withoutSecrets(parsed);
    if (parsed) window.sessionStorage.setItem(SESSION_KEY, JSON.stringify(cleaned));
    if (cleaned?.username) return { session: cleaned, pendingSelection: null };
    return {
      session: cleaned?.session?.username ? cleaned.session : null,
      pendingSelection: cleaned?.pendingSelection?.memberships?.length ? cleaned.pendingSelection : null,
    };
  } catch {
    window.sessionStorage.removeItem(SESSION_KEY);
    return { session: null, pendingSelection: null };
  }
}

function writeStoredAuthState(nextState) {
  if (typeof window === "undefined") return;
  const cleaned = withoutSecrets(nextState);
  if (!cleaned?.session && !cleaned?.pendingSelection) {
    window.sessionStorage.removeItem(SESSION_KEY);
    return;
  }
  window.sessionStorage.setItem(SESSION_KEY, JSON.stringify(cleaned));
}

function consumeSessionPayload(payload, preferredOrganizationId = null) {
  setWebCsrfToken(payload?.csrf_token || "");
  const cleanPayload = withoutSecrets(payload);
  const memberships = cleanPayload?.available_memberships || cleanPayload?.memberships || (cleanPayload ? [cleanPayload] : []);
  const selected = memberships.find((item) => Number(item?.organization_id) === Number(preferredOrganizationId)) || cleanPayload;
  return selected ? { ...selected, available_memberships: memberships } : null;
}

export function AuthProvider({ children }) {
  const [authState, setAuthState] = useState({ session: null, pendingSelection: null });
  const [loading, setLoading] = useState(true);
  const [restoringSession, setRestoringSession] = useState(true);
  const session = authState.session;
  const pendingSelection = authState.pendingSelection;

  useEffect(() => {
    const stored = readStoredAuthState();
    let cancelled = false;
    getSessionStatus().then((response) => {
      if (cancelled) return;
      const restored = consumeSessionPayload(response?.session, stored.session?.organization_id);
      const nextState = { session: restored, pendingSelection: null };
      writeStoredAuthState(nextState);
      setAuthState(nextState);
    }).catch(() => {
      if (cancelled) return;
      setWebCsrfToken("");
      writeStoredAuthState({ session: null, pendingSelection: null });
      setAuthState({ session: null, pendingSelection: null });
    }).finally(() => {
      if (!cancelled) {
        setLoading(false);
        setRestoringSession(false);
      }
    });
    return () => { cancelled = true; };
  }, []);

  useEffect(() => { writeStoredAuthState({ session, pendingSelection }); }, [pendingSelection, session]);

  useEffect(() => {
    if (typeof window === "undefined") return undefined;
    const handleSessionInvalidated = (event) => {
      if (event?.detail?.code === "SESSION_REPLACED") {
        window.sessionStorage.setItem("rcktscore.session-message", "You were signed out because this account was used to sign in on another device.");
      }
      setWebCsrfToken("");
      setAuthState({ session: null, pendingSelection: null });
    };
    window.addEventListener("rcktscore:session-invalidated", handleSessionInvalidated);
    return () => window.removeEventListener("rcktscore:session-invalidated", handleSessionInvalidated);
  }, []);

  useEffect(() => {
    if (!session || typeof window === "undefined") return undefined;
    let cancelled = false;
    async function validateSession() {
      if (cancelled || document.visibilityState === "hidden") return;
      try {
        const response = await getSessionStatus();
        if (response?.session?.csrf_token) setWebCsrfToken(response.session.csrf_token);
      } catch {
        // Rejected sessions emit the shared invalidation event. Network errors
        // leave the non-secret interface state available for offline recovery.
      }
    }
    const intervalId = window.setInterval(validateSession, 30000);
    const validateOnFocus = () => validateSession();
    const validateOnVisibility = () => { if (document.visibilityState === "visible") validateSession(); };
    window.addEventListener("focus", validateOnFocus);
    document.addEventListener("visibilitychange", validateOnVisibility);
    return () => {
      cancelled = true;
      window.clearInterval(intervalId);
      window.removeEventListener("focus", validateOnFocus);
      document.removeEventListener("visibilitychange", validateOnVisibility);
    };
  }, [session]);

  const login = useCallback(async (username, password, options = {}) => {
    const trimmedUsername = username.trim();
    const trimmedPassword = password.trim();
    if (!trimmedUsername || !trimmedPassword) return { ok: false, message: "Username and password are required." };
    setLoading(true);
    try {
      const response = await loginRequest({ username: trimmedUsername, password: trimmedPassword, client_type: "web_app", force_logout_other: Boolean(options.forceLogoutOther) });
      if (response.session) {
        const nextSession = { ...consumeSessionPayload(response.session), loggedInAt: new Date().toISOString() };
        setAuthState({ session: nextSession, pendingSelection: null });
        return { ok: true, session: nextSession };
      }
      if (response.organizationSelection?.memberships?.length) {
        setWebCsrfToken(response.organizationSelection.csrf_token || "");
        const nextPendingSelection = withoutSecrets({
          username: response.organizationSelection.username || trimmedUsername,
          memberships: response.organizationSelection.memberships,
          session_expires_at: response.organizationSelection.session_expires_at || null,
          loggedInAt: new Date().toISOString(),
        });
        setAuthState({ session: null, pendingSelection: nextPendingSelection });
        return { ok: true, requiresOrganizationSelection: true };
      }
      return { ok: false, message: "Login failed." };
    } catch (requestError) {
      if (requestError.code === "ACTIVE_SESSION_EXISTS") {
        return { ok: false, requiresSessionReplacement: true, message: requestError.message || "This account is already signed in on the web app.", clientLabel: requestError.details?.client_label || "web app" };
      }
      return { ok: false, message: requestError.message || "Login failed." };
    } finally {
      setLoading(false);
    }
  }, []);

  const selectOrganization = useCallback((membership) => {
    if (!membership?.username || !membership?.organization_id) return;
    const nextSession = withoutSecrets({ ...membership, available_memberships: pendingSelection?.memberships || [membership], session_expires_at: pendingSelection?.session_expires_at || null, loggedInAt: new Date().toISOString() });
    setAuthState({ session: nextSession, pendingSelection: null });
  }, [pendingSelection]);

  const switchOrganization = useCallback((membership) => {
    if (!session || !membership?.username || !membership?.organization_id) return false;
    const availableMemberships = session.available_memberships || session.memberships || [session];
    const allowed = availableMemberships.find((item) => Number(item?.organization_id) === Number(membership.organization_id));
    if (!allowed) return false;
    setAuthState({ session: withoutSecrets({ ...allowed, available_memberships: availableMemberships, session_expires_at: session.session_expires_at, loggedInAt: session.loggedInAt || new Date().toISOString() }), pendingSelection: null });
    return true;
  }, [session]);

  const logout = useCallback(() => {
    logoutRequest().catch(() => {}).finally(() => setWebCsrfToken(""));
    setAuthState({ session: null, pendingSelection: null });
  }, []);
  const cancelOrganizationSelection = useCallback(() => logout(), [logout]);

  const contextValue = useMemo(() => ({
    isAuthenticated: Boolean(session), session, pendingSelection,
    requiresOrganizationSelection: Boolean(pendingSelection), loading, restoringSession,
    setSession: (nextSession) => setAuthState({ session: withoutSecrets(nextSession), pendingSelection: null }),
    login, selectOrganization, switchOrganization, cancelOrganizationSelection, logout,
  }), [loading, login, logout, pendingSelection, restoringSession, selectOrganization, switchOrganization, cancelOrganizationSelection, session]);

  return <AuthContext.Provider value={contextValue}>{children}</AuthContext.Provider>;
}
