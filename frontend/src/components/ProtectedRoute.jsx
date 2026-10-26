import React from "react";
import { Navigate, useLocation } from "react-router-dom";

import { useAuth } from "../hooks/useAuth";
import { canManageMatches } from "../utils/accessControl";

export default function ProtectedRoute({ children, requireMatchManagement = false }) {
  const { isAuthenticated, session } = useAuth();
  const location = useLocation();

  if (!isAuthenticated) {
    return <Navigate replace state={{ from: location }} to="/" />;
  }
  if (requireMatchManagement && !canManageMatches(session)) {
    return <Navigate replace to="/matches" />;
  }

  return children;
}
