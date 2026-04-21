import React from "react";
import { Route, Routes } from "react-router-dom";

import ProtectedRoute from "./components/ProtectedRoute";
import RootAdminProtectedRoute from "./components/RootAdminProtectedRoute";
import DisplayScreen from "./pages/DisplayScreen";
import DashboardPage from "./pages/DashboardPage";
import HelpPage from "./pages/HelpPage";
import LoginPage from "./pages/LoginPage";
import MatchScreen from "./pages/MatchScreen";
import NewMatch from "./pages/NewMatch";
import OrganisationSettingsPage from "./pages/OrganisationSettingsPage";
import PingUsPage from "./pages/PingUsPage";
import RootAdminClubPage from "./pages/RootAdminClubPage";
import RootAdminDashboardPage from "./pages/RootAdminDashboardPage";
import RootAdminInterestRequestsPage from "./pages/RootAdminInterestRequestsPage";
import RootAdminLoginPage from "./pages/RootAdminLoginPage";
import RootAdminPersonalAccountsPage from "./pages/RootAdminPersonalAccountsPage";

export default function App() {
  return (
    <Routes>
      <Route path="/" element={<LoginPage />} />
      <Route path="/login" element={<LoginPage />} />
      <Route path="/help" element={<HelpPage />} />
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
        path="/rckscoreAdmin/interests"
        element={(
          <RootAdminProtectedRoute>
            <RootAdminInterestRequestsPage />
          </RootAdminProtectedRoute>
        )}
      />
      <Route
        path="/rckscoreAdmin/personal-accounts"
        element={(
          <RootAdminProtectedRoute>
            <RootAdminPersonalAccountsPage />
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
