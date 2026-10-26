export function normalizedClubRole(session) {
  const role = String(session?.role || "scorer").trim().toLowerCase();
  return role === "user" ? "scorer" : role;
}

export function isPersonalSession(session) {
  return session?.organization_type === "personal" || Number(session?.organization_id) >= 50000;
}

export function canManageMatches(session) {
  return isPersonalSession(session) || ["admin", "scorer"].includes(normalizedClubRole(session));
}

export function canAdministerClub(session) {
  return isPersonalSession(session) || normalizedClubRole(session) === "admin";
}

export function clubRoleLabel(role) {
  const normalized = role === "user" ? "scorer" : role;
  if (normalized === "admin") return "Administrator";
  if (normalized === "read_only") return "Read only";
  return "Scorer";
}
