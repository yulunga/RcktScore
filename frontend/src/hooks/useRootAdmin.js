import { useContext } from "react";

import { RootAdminContext } from "../context/RootAdminContext";

export function useRootAdmin() {
  return useContext(RootAdminContext);
}
