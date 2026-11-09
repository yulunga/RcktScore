import React from "react";
import { NavLink } from "react-router-dom";

export default function RootAdminSettingsNav() {
  return (
    <nav className="panel root-admin-profile-tabs" aria-label="Ground Control settings">
      <NavLink className="root-admin-tab" to="/rckscoreAdmin/tournaments">Tournament Manager</NavLink>
      <NavLink className="root-admin-tab" to="/rckscoreAdmin/racket-sports">Sports Controls</NavLink>
    </nav>
  );
}
