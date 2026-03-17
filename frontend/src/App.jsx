import { Navigate, Route, Routes } from "react-router-dom";

import ProtectedRoute from "./components/ProtectedRoute";
import DisplayScreen from "./pages/DisplayScreen";
import LoginPage from "./pages/LoginPage";
import MatchScreen from "./pages/MatchScreen";
import NewMatch from "./pages/NewMatch";

export default function App() {
  return (
    <Routes>
      <Route path="/" element={<Navigate to="/login" replace />} />
      <Route path="/login" element={<LoginPage />} />
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
