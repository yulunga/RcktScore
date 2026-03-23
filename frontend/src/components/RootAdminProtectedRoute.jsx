import React from "react";
import { Navigate, useLocation } from "react-router-dom";

import { useRootAdmin } from "../hooks/useRootAdmin";

export default function RootAdminProtectedRoute({ children }) {
  const { isAuthenticated } = useRootAdmin();
  const location = useLocation();

  if (!isAuthenticated) {
    return <Navigate replace state={{ from: location }} to="/rckscoreAdmin" />;
  }

  return children;
}
