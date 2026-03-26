import React from "react";
import { Route, Routes } from "react-router-dom";

import ProtectedRoute from "./components/ProtectedRoute";
import RootAdminProtectedRoute from "./components/RootAdminProtectedRoute";
import DisplayScreen from "./pages/DisplayScreen";
import DashboardPage from "./pages/DashboardPage";
import LoginPage from "./pages/LoginPage";
import MatchScreen from "./pages/MatchScreen";
import NewMatch from "./pages/NewMatch";
import OrganisationSettingsPage from "./pages/OrganisationSettingsPage";
import PingUsPage from "./pages/PingUsPage";
import RootAdminClubPage from "./pages/RootAdminClubPage";
import RootAdminDashboardPage from "./pages/RootAdminDashboardPage";
import RootAdminLoginPage from "./pages/RootAdminLoginPage";

export default function App() {
  return (
    <Routes>
      <Route path="/" element={<LoginPage />} />
      <Route path="/login" element={<LoginPage />} />
      <Route path="/rckscoreAdmin" element={<RootAdminLoginPage />} />
      <Route
        path="/rckscoreAdmin/dashboard"
        element={(
          <RootAdminProtectedRoute>
            <RootAdminDashboardPage />
          </RootAdminProtectedRoute>
        )}
      />
      <Route
        path="/rckscoreAdmin/clubs/:organizationId"
        element={(
          <RootAdminProtectedRoute>
            <RootAdminClubPage />
          </RootAdminProtectedRoute>
        )}
      />
      <Route
        path="/dashboard"
        element={(
          <ProtectedRoute>
            <DashboardPage />
          </ProtectedRoute>
        )}
      />
      <Route
        path="/settings"
        element={(
          <ProtectedRoute>
            <OrganisationSettingsPage />
          </ProtectedRoute>
        )}
      />
      <Route
        path="/ping"
        element={(
          <ProtectedRoute>
            <PingUsPage />
          </ProtectedRoute>
        )}
      />
      <Route
        path="/match/new"
        element={(
          <ProtectedRoute>
            <NewMatch />
          </ProtectedRoute>
        )}
      />
      <Route
        path="/match/:matchId"
        element={(
          <ProtectedRoute>
            <MatchScreen />
          </ProtectedRoute>
        )}
      />
      <Route path="/display" element={<DisplayScreen />} />
    </Routes>
  );
}
