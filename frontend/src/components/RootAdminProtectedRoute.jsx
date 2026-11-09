import React from "react";
import { Navigate, useLocation } from "react-router-dom";

import SessionLoadingScreen from "./SessionLoadingScreen";
import { useRootAdmin } from "../hooks/useRootAdmin";

export default function RootAdminProtectedRoute({ children }) {
  const { isAuthenticated, restoringSession } = useRootAdmin();
  const location = useLocation();

  if (restoringSession) {
    return <SessionLoadingScreen />;
  }

  if (!isAuthenticated) {
    return <Navigate replace state={{ from: location }} to="/rckscoreAdmin" />;
  }

  return children;
}
