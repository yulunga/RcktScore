import React, { lazy, Suspense } from "react";
import { Route, Routes } from "react-router-dom";

import AnalyticsRouteTracker from "./components/AnalyticsRouteTracker";
import CookieConsent from "./components/CookieConsent";
import ProtectedRoute from "./components/ProtectedRoute";
import RootAdminProtectedRoute from "./components/RootAdminProtectedRoute";
import LoginPage from "./pages/LoginPage";

const DisplayScreen = lazy(() => import("./pages/DisplayScreen"));
const DashboardPage = lazy(() => import("./pages/DashboardPage"));
const HelpPage = lazy(() => import("./pages/HelpPage"));
const HistoricMatchPage = lazy(() => import("./pages/HistoricMatchPage"));
const MatchSportSelectionPage = lazy(() => import("./pages/MatchSportSelectionPage"));
const MatchScreen = lazy(() => import("./pages/MatchScreen"));
const NewMatch = lazy(() => import("./pages/NewMatch"));
const NotificationsPage = lazy(() => import("./pages/NotificationsPage"));
const SettingsHubPage = lazy(() => import("./pages/SettingsHubPage"));
const OrganisationUserPage = lazy(() => import("./pages/OrganisationUserPage"));
const PerformancePage = lazy(() => import("./pages/PerformancePage"));
const PingUsPage = lazy(() => import("./pages/PingUsPage"));
const ProfilePage = lazy(() => import("./pages/ProfilePage"));
const RootAdminClubPage = lazy(() => import("./pages/RootAdminClubPage"));
const RootAdminDashboardPage = lazy(() => import("./pages/RootAdminDashboardPage"));
const RootAdminInterestRequestsPage = lazy(() => import("./pages/RootAdminInterestRequestsPage"));
const RootAdminLoginPage = lazy(() => import("./pages/RootAdminLoginPage"));
const RootAdminMatchesPage = lazy(() => import("./pages/RootAdminMatchesPage"));
const RootAdminNotificationsPage = lazy(() => import("./pages/RootAdminNotificationsPage"));
const RootAdminPlatformSportsPage = lazy(() => import("./pages/RootAdminPlatformSportsPage"));
const RootAdminSubscriptionsPage = lazy(() => import("./pages/RootAdminSubscriptionsPage"));
const RootAdminUserAccountsPage = lazy(() => import("./pages/RootAdminUserAccountsPage"));
const RootAdminUserProfilePage = lazy(() => import("./pages/RootAdminUserProfilePage"));
const RemoteMatchPage = lazy(() => import("./pages/RemoteMatchPage"));
const TournamentDetailPage = lazy(() => import("./features/tournaments/pages/TournamentDetailPage"));
const TournamentListPage = lazy(() => import("./features/tournaments/pages/TournamentListPage"));
const PublicTournamentDrawPage = lazy(() => import("./features/tournaments/pages/PublicTournamentDrawPage"));

export default function App() {
  return (
    <>
      <AnalyticsRouteTracker />
      <Suspense fallback={<main className="page-shell"><div className="notice">Loading…</div></main>}>
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
        path="/matches/watch/:watchCode"
        element={(
          <ProtectedRoute>
            <RemoteMatchPage />
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
            <SettingsHubPage />
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
          <ProtectedRoute requireMatchManagement>
            <MatchSportSelectionPage />
          </ProtectedRoute>
        )}
      />
      <Route
        path="/match/new/setup"
        element={(
          <ProtectedRoute requireMatchManagement>
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
      </Suspense>
      <CookieConsent />
    </>
  );
}
