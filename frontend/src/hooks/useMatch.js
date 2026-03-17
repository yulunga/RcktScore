import { useContext } from "react";

import { MatchContext } from "../context/MatchContext";

export function useMatch() {
  return useContext(MatchContext);
}
