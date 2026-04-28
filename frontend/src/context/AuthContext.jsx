import React, { createContext, useCallback, useEffect, useMemo, useState } from "react";

import { login as loginRequest, logout as logoutRequest } from "../services/api";

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

    const handleSessionInvalidated = () => {
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
    const nextSession = {
      ...membership,
      ...(sessionToken ? { session_token: sessionToken } : {}),
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
      cancelOrganizationSelection,
      logout,
    }),
    [loading, login, logout, pendingSelection, selectOrganization, cancelOrganizationSelection, session],
  );

  return <AuthContext.Provider value={contextValue}>{children}</AuthContext.Provider>;
}
