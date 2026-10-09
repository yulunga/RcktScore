import React from "react";
import { Route, Routes } from "react-router-dom";

import AnalyticsRouteTracker from "./components/AnalyticsRouteTracker";
import CookieConsent from "./components/CookieConsent";
import ProtectedRoute from "./components/ProtectedRoute";
import RootAdminProtectedRoute from "./components/RootAdminProtectedRoute";
import DisplayScreen from "./pages/DisplayScreen";
import DashboardPage from "./pages/DashboardPage";
import HelpPage from "./pages/HelpPage";
import HistoricMatchPage from "./pages/HistoricMatchPage";
import LoginPage from "./pages/LoginPage";
import MatchSportSelectionPage from "./pages/MatchSportSelectionPage";
import MatchScreen from "./pages/MatchScreen";
import NewMatch from "./pages/NewMatch";
import NotificationsPage from "./pages/NotificationsPage";
import OrganisationSettingsPage from "./pages/OrganisationSettingsPage";
import OrganisationUserPage from "./pages/OrganisationUserPage";
import PerformancePage from "./pages/PerformancePage";
import PingUsPage from "./pages/PingUsPage";
import ProfilePage from "./pages/ProfilePage";
import RootAdminClubPage from "./pages/RootAdminClubPage";
import RootAdminDashboardPage from "./pages/RootAdminDashboardPage";
import RootAdminInterestRequestsPage from "./pages/RootAdminInterestRequestsPage";
import RootAdminLoginPage from "./pages/RootAdminLoginPage";
import RootAdminMatchesPage from "./pages/RootAdminMatchesPage";
import RootAdminNotificationsPage from "./pages/RootAdminNotificationsPage";
import RootAdminPlatformSportsPage from "./pages/RootAdminPlatformSportsPage";
import RootAdminSubscriptionsPage from "./pages/RootAdminSubscriptionsPage";
import RootAdminUserAccountsPage from "./pages/RootAdminUserAccountsPage";
import RootAdminUserProfilePage from "./pages/RootAdminUserProfilePage";
import TournamentDetailPage from "./features/tournaments/pages/TournamentDetailPage";
import TournamentListPage from "./features/tournaments/pages/TournamentListPage";
import PublicTournamentDrawPage from "./features/tournaments/pages/PublicTournamentDrawPage";

export default function App() {
  return (
    <>
      <AnalyticsRouteTracker />
      <Routes>
      <Route path="/" element={<LoginPage />} />
      <Route path="/login" element={<LoginPage />} />
      <Route path="/help" element={<HelpPage />} />
      <Route path="/tournament-draw" element={<PublicTournamentDrawPage />} />
      <Route path="/tournament-draw/:accessKey" element={<PublicTournamentDrawPage />} />
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
        path="/rckscoreAdmin/matches"
        element={(
          <RootAdminProtectedRoute>
            <RootAdminMatchesPage />
          </RootAdminProtectedRoute>
        )}
      />
      <Route
        path="/rckscoreAdmin/notifications"
        element={(<RootAdminProtectedRoute><RootAdminNotificationsPage /></RootAdminProtectedRoute>)}
      />
      <Route
        path="/rckscoreAdmin/subscriptions"
        element={(<RootAdminProtectedRoute><RootAdminSubscriptionsPage /></RootAdminProtectedRoute>)}
      />
      <Route
        path="/rckscoreAdmin/racket-sports"
        element={(
          <RootAdminProtectedRoute>
            <RootAdminPlatformSportsPage />
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
            <RootAdminUserAccountsPage />
          </RootAdminProtectedRoute>
        )}
      />
      <Route
        path="/rckscoreAdmin/users"
        element={(
          <RootAdminProtectedRoute>
            <RootAdminUserAccountsPage />
          </RootAdminProtectedRoute>
        )}
      />
      <Route
        path="/rckscoreAdmin/users/:userId"
        element={(
          <RootAdminProtectedRoute>
            <RootAdminUserProfilePage />
          </RootAdminProtectedRoute>
        )}
      />
      <Route
        path="/dashboard"
        element={(
          <ProtectedRoute>
            <DashboardPage screenMode="dashboard" />
          </ProtectedRoute>
        )}
      />
      <Route
        path="/matches"
        element={(
          <ProtectedRoute>
            <DashboardPage screenMode="matches" />
          </ProtectedRoute>
        )}
      />
      <Route
        path="/history"
        element={(
          <ProtectedRoute>
            <DashboardPage screenMode="history" />
          </ProtectedRoute>
        )}
      />
      <Route
        path="/performance"
        element={(
          <ProtectedRoute>
            <PerformancePage />
          </ProtectedRoute>
        )}
      />
      <Route
        path="/notifications"
        element={(
          <ProtectedRoute>
            <NotificationsPage />
          </ProtectedRoute>
        )}
      />
      <Route
        path="/profile"
        element={(
          <ProtectedRoute>
            <ProfilePage />
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
        path="/settings/users/:userId"
        element={(
          <ProtectedRoute>
            <OrganisationUserPage />
          </ProtectedRoute>
        )}
      />
      <Route
        path="/tournaments"
        element={(
          <ProtectedRoute>
            <TournamentListPage />
          </ProtectedRoute>
        )}
      />
      <Route
        path="/tournaments/:tournamentId"
        element={(
          <ProtectedRoute>
            <TournamentDetailPage />
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
            <MatchSportSelectionPage />
          </ProtectedRoute>
        )}
      />
      <Route
        path="/match/new/setup"
        element={(
          <ProtectedRoute>
            <NewMatch />
          </ProtectedRoute>
        )}
      />
      <Route
        path="/match/:matchId/history"
        element={(
          <ProtectedRoute>
            <HistoricMatchPage />
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
      <Route path="/scoreboard" element={<DisplayScreen />} />
      <Route path="/display" element={<DisplayScreen />} />
      </Routes>
      <CookieConsent />
    </>
  );
}
