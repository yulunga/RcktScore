import React, { createContext, useCallback, useEffect, useMemo, useState } from "react";

import { getSessionStatus, login as loginRequest, logout as logoutRequest } from "../services/api";

const SESSION_KEY = "rcktscore.auth";

export const AuthContext = createContext(null);

function readStoredAuthState() {
  if (typeof window === "undefined") {
    return { session: null, pendingSelection: null };
  }

  try {
    const rawValue = window.sessionStorage.getItem(SESSION_KEY);
    if (!rawValue) {
      return { session: null, pendingSelection: null };
    }

    const parsedValue = JSON.parse(rawValue);
    if (parsedValue?.username) {
      return {
        session: parsedValue,
        pendingSelection: null,
      };
    }

    return {
      session: parsedValue?.session?.username ? parsedValue.session : null,
      pendingSelection: parsedValue?.pendingSelection?.memberships?.length ? parsedValue.pendingSelection : null,
    };
  } catch {
    return { session: null, pendingSelection: null };
  }
}

function writeStoredAuthState(nextState) {
  if (typeof window === "undefined") {
    return;
  }

  const session = nextState?.session || null;
  const pendingSelection = nextState?.pendingSelection || null;

  if (!session && !pendingSelection) {
    window.sessionStorage.removeItem(SESSION_KEY);
    return;
  }

  window.sessionStorage.setItem(
    SESSION_KEY,
    JSON.stringify({
      session,
      pendingSelection,
    }),
  );
}

export function AuthProvider({ children }) {
  const [authState, setAuthState] = useState(() => readStoredAuthState());
  const [loading, setLoading] = useState(false);
  const session = authState.session;
  const pendingSelection = authState.pendingSelection;

  useEffect(() => {
    writeStoredAuthState({
      session,
      pendingSelection,
    });
  }, [pendingSelection, session]);

  useEffect(() => {
    if (typeof window === "undefined") {
      return undefined;
    }

    const handleSessionInvalidated = (event) => {
      if (event?.detail?.code === "SESSION_REPLACED") {
        window.sessionStorage.setItem(
          "rcktscore.session-message",
          "You were signed out because this account was used to sign in on another device.",
        );
      }
      setAuthState({
        session: null,
        pendingSelection: null,
      });
    };

    window.addEventListener("rcktscore:session-invalidated", handleSessionInvalidated);
    return () => {
      window.removeEventListener("rcktscore:session-invalidated", handleSessionInvalidated);
    };
  }, []);

  useEffect(() => {
    if (!session?.session_token || typeof window === "undefined") {
      return undefined;
    }

    let cancelled = false;
    async function validateSession() {
      if (cancelled || document.visibilityState === "hidden") return;
      try {
        await getSessionStatus();
      } catch {
        // apiRequest emits the shared invalidation event for rejected sessions.
        // Transport failures leave the current session intact for offline recovery.
      }
    }

    validateSession();
    const intervalId = window.setInterval(validateSession, 30000);
    const validateOnFocus = () => validateSession();
    const validateOnVisibility = () => {
      if (document.visibilityState === "visible") validateSession();
    };
    window.addEventListener("focus", validateOnFocus);
    document.addEventListener("visibilitychange", validateOnVisibility);

    return () => {
      cancelled = true;
      window.clearInterval(intervalId);
      window.removeEventListener("focus", validateOnFocus);
      document.removeEventListener("visibilitychange", validateOnVisibility);
    };
  }, [session?.session_token]);

  const login = useCallback(async (username, password, options = {}) => {
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
        client_type: "web_app",
        force_logout_other: Boolean(options.forceLogoutOther),
      });
      if (response.session) {
        const nextSession = {
          ...response.session,
          loggedInAt: new Date().toISOString(),
        };
        writeStoredAuthState({
          session: nextSession,
          pendingSelection: null,
        });
        setAuthState({
          session: nextSession,
          pendingSelection: null,
        });
        return { ok: true, session: nextSession };
      }

      if (response.organizationSelection?.memberships?.length) {
        const nextPendingSelection = {
          username: response.organizationSelection.username || trimmedUsername,
          memberships: response.organizationSelection.memberships,
          session_token: response.organizationSelection.session_token || null,
          session_expires_at: response.organizationSelection.session_expires_at || null,
          loggedInAt: new Date().toISOString(),
        };
        writeStoredAuthState({
          session: null,
          pendingSelection: nextPendingSelection,
        });
        setAuthState({
          session: null,
          pendingSelection: nextPendingSelection,
        });
        return { ok: true, requiresOrganizationSelection: true };
      }

      return {
        ok: false,
        message: "Login failed.",
      };
    } catch (requestError) {
      if (requestError.code === "ACTIVE_SESSION_EXISTS") {
        return {
          ok: false,
          requiresSessionReplacement: true,
          message: requestError.message || "This account is already signed in on the web app.",
          clientLabel: requestError.details?.client_label || "web app",
        };
      }

      return {
        ok: false,
        message: requestError.message || "Login failed.",
      };
    } finally {
      setLoading(false);
    }
  }, []);

  const selectOrganization = useCallback((membership) => {
    if (!membership?.username || !membership?.organization_id) {
      return;
    }

    const sessionToken = pendingSelection?.session_token || null;
    const sessionExpiresAt = pendingSelection?.session_expires_at || null;
    const nextSession = {
      ...membership,
      available_memberships: pendingSelection?.memberships || [membership],
      ...(sessionToken ? { session_token: sessionToken } : {}),
      ...(sessionExpiresAt ? { session_expires_at: sessionExpiresAt } : {}),
      loggedInAt: new Date().toISOString(),
    };
    writeStoredAuthState({
      session: nextSession,
      pendingSelection: null,
    });
    setAuthState({
      session: nextSession,
      pendingSelection: null,
    });
  }, [pendingSelection]);

  const switchOrganization = useCallback((membership) => {
    if (!session || !membership?.username || !membership?.organization_id) {
      return false;
    }

    const availableMemberships = session.available_memberships || session.memberships || [session];
    const allowedMembership = availableMemberships.find((item) => (
      Number(item?.organization_id) === Number(membership.organization_id)
    ));
    if (!allowedMembership) {
      return false;
    }

    const nextSession = {
      ...allowedMembership,
      available_memberships: availableMemberships,
      ...(session.session_token ? { session_token: session.session_token } : {}),
      ...(session.session_expires_at ? { session_expires_at: session.session_expires_at } : {}),
      loggedInAt: session.loggedInAt || new Date().toISOString(),
    };
    writeStoredAuthState({ session: nextSession, pendingSelection: null });
    setAuthState({ session: nextSession, pendingSelection: null });
    return true;
  }, [session]);

  const cancelOrganizationSelection = useCallback(() => {
    writeStoredAuthState({
      session: null,
      pendingSelection: null,
    });
    setAuthState({
      session: null,
      pendingSelection: null,
    });
  }, []);

  const logout = useCallback(() => {
    const token = session?.session_token || pendingSelection?.session_token || null;
    if (token) {
      logoutRequest(token).catch(() => {});
    }

    writeStoredAuthState({
      session: null,
      pendingSelection: null,
    });
    setAuthState({
      session: null,
      pendingSelection: null,
    });
  }, [pendingSelection, session]);

  const contextValue = useMemo(
    () => ({
      isAuthenticated: Boolean(session),
      session,
      pendingSelection,
      requiresOrganizationSelection: Boolean(pendingSelection),
      loading,
      setSession: (nextSession) => setAuthState({ session: nextSession, pendingSelection: null }),
      login,
      selectOrganization,
      switchOrganization,
      cancelOrganizationSelection,
      logout,
    }),
    [loading, login, logout, pendingSelection, selectOrganization, switchOrganization, cancelOrganizationSelection, session],
  );

  return <AuthContext.Provider value={contextValue}>{children}</AuthContext.Provider>;
}
