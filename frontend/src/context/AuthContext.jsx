import React, { createContext, useCallback, useEffect, useMemo, useState } from "react";

import { login as loginRequest } from "../services/api";

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

export function AuthProvider({ children }) {
  const [authState, setAuthState] = useState(() => readStoredAuthState());
  const [loading, setLoading] = useState(false);
  const session = authState.session;
  const pendingSelection = authState.pendingSelection;

  useEffect(() => {
    if (typeof window === "undefined") {
      return;
    }

    if (!session && !pendingSelection) {
      window.sessionStorage.removeItem(SESSION_KEY);
      return;
    }

    window.sessionStorage.setItem(
      SESSION_KEY,
      JSON.stringify({
        session: session || null,
        pendingSelection: pendingSelection || null,
      }),
    );
  }, [pendingSelection, session]);

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
      if (response.session) {
        const nextSession = {
          ...response.session,
          loggedInAt: new Date().toISOString(),
        };
        setAuthState({
          session: nextSession,
          pendingSelection: null,
        });
        return { ok: true, session: nextSession };
      }

      if (response.organizationSelection?.memberships?.length) {
        setAuthState({
          session: null,
          pendingSelection: {
            username: response.organizationSelection.username || trimmedUsername,
            memberships: response.organizationSelection.memberships,
            loggedInAt: new Date().toISOString(),
          },
        });
        return { ok: true, requiresOrganizationSelection: true };
      }

      return {
        ok: false,
        message: "Login failed.",
      };
    } catch (requestError) {
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

    setAuthState({
      session: {
        ...membership,
        loggedInAt: new Date().toISOString(),
      },
      pendingSelection: null,
    });
  }, []);

  const cancelOrganizationSelection = useCallback(() => {
    setAuthState({
      session: null,
      pendingSelection: null,
    });
  }, []);

  const logout = useCallback(() => {
    setAuthState({
      session: null,
      pendingSelection: null,
    });
  }, []);

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
