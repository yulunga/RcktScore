import { Navigate, Route, Routes } from "react-router-dom";

import DisplayScreen from "./pages/DisplayScreen";
import MatchScreen from "./pages/MatchScreen";
import NewMatch from "./pages/NewMatch";

export default function App() {
  return (
    <Routes>
      <Route path="/" element={<Navigate to="/match/new" replace />} />
      <Route path="/match/new" element={<NewMatch />} />
      <Route path="/match/:matchId" element={<MatchScreen />} />
      <Route path="/display" element={<DisplayScreen />} />
    </Routes>
  );
}
