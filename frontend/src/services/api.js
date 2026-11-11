const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || "";
const API_KEY = import.meta.env.VITE_API_KEY;
let webCsrfToken = "";
let rootAdminCsrfToken = "";
const SESSION_INVALIDATION_CODES = new Set(["SESSION_REQUIRED", "SESSION_INVALID", "SESSION_REPLACED", "SESSION_EXPIRED"]);
const ROOT_ADMIN_SESSION_INVALIDATION_CODES = new Set([
  "ROOT_ADMIN_SESSION_REQUIRED",
  "ROOT_ADMIN_SESSION_INVALID",
  "ROOT_ADMIN_SESSION_REPLACED",
  "ROOT_ADMIN_SESSION_EXPIRED",
]);

export function setWebCsrfToken(value) {
  webCsrfToken = String(value || "");
}

export function setRootAdminCsrfToken(value) {
  rootAdminCsrfToken = String(value || "");
}

function notifySessionInvalidated(code, rootAdmin = false) {
  if (typeof window === "undefined") {
    return;
  }

  window.dispatchEvent(
    new CustomEvent(rootAdmin ? "rcktscore:root-admin-session-invalidated" : "rcktscore:session-invalidated", {
      detail: {
        code,
      },
    }),
  );
}

async function apiRequest(path, options = {}) {
  const rootAdminRequest = Boolean(options.rootAdminRequest);
  const rootAdminPath = path.startsWith("/root_admin/") && path !== "/root_admin/login";
  const usesRootAdminSession = rootAdminRequest || rootAdminPath;
  const method = String(options.method || "GET").toUpperCase();
  const csrfToken = usesRootAdminSession ? rootAdminCsrfToken : webCsrfToken;
  const bearerToken = options.bearerToken;
  const stateChanging = ["POST", "PUT", "PATCH", "DELETE"].includes(method);
  const headers = {
    "Content-Type": "application/json",
    ...(API_KEY ? { "x-api-key": API_KEY } : {}),
    ...(bearerToken ? { Authorization: `Bearer ${bearerToken}` } : {}),
    ...(stateChanging && csrfToken ? { "X-CSRF-Token": csrfToken } : {}),
    ...(usesRootAdminSession ? { "X-HitnScore-Session": "root_admin" } : {}),
    ...(options.headers || {}),
  };

  const requestOptions = { ...options };
  delete requestOptions.rootAdminRequest;
  delete requestOptions.bearerToken;
  delete requestOptions.sessionToken;

  let response;
  try {
    response = await fetch(`${API_BASE_URL}${path}`, {
      ...requestOptions,
      headers,
      credentials: "include",
    });
  } catch (requestError) {
    const error = new Error(
      "Unable to reach the API endpoint. Please check the backend deployment and API base URL.",
    );
    error.cause = requestError;
    throw error;
  }

  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    const error = new Error(payload?.error?.message || payload.message || "API request failed");
    error.code = payload?.error?.code;
    error.details = payload?.error?.details;
    if (SESSION_INVALIDATION_CODES.has(error.code)) {
      notifySessionInvalidated(error.code);
    }
    if (ROOT_ADMIN_SESSION_INVALIDATION_CODES.has(error.code)) {
      notifySessionInvalidated(error.code, true);
    }
    throw error;
  }

  if (typeof payload?.success === "boolean") {
    return payload.data;
  }

  return payload;
}

export function startMatch(payload) {
  return apiRequest("/start_match", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export function startScheduledMatch(payload) {
  return apiRequest("/start_scheduled_match", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export function login(payload) {
  return apiRequest("/login", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export function logout() {
  return apiRequest("/logout", {
    method: "POST",
  });
}

export function getSessionStatus() {
  return apiRequest("/session/status");
}

export function rootAdminLogin(payload) {
  return apiRequest("/root_admin/login", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export function rootAdminLogout() {
  return apiRequest("/root_admin/logout", {
    method: "POST",
  });
}

export function getRootAdminSessionStatus() {
  return apiRequest("/root_admin/session/status", { rootAdminRequest: true });
}

export function registerInterest(payload) {
  return apiRequest("/register_interest", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export function submitFeedback(payload) {
  return apiRequest("/feedback", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export function requestPasswordReset(payload) {
  return apiRequest("/password_reset/request", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export function confirmPasswordReset(payload) {
  return apiRequest("/password_reset/confirm", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export function validatePasswordResetToken(payload) {
  return apiRequest("/password_reset/validate", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export function getDashboard(organizationId, options = {}) {
  const params = new URLSearchParams();
  if (options.activeLimit !== undefined) {
    params.set("active_limit", String(options.activeLimit));
  }
  if (options.recentLimit !== undefined) {
    params.set("recent_limit", String(options.recentLimit));
  }
  if (options.analyticsPeriodDays !== undefined) {
    params.set("analytics_period_days", String(options.analyticsPeriodDays));
  }
  const suffix = params.toString() ? `?${params.toString()}` : "";
  return apiRequest(`/dashboard/${organizationId}${suffix}`);
}

export function beginMatchSetupAnalytics(organizationId, sport) {
  return apiRequest(`/analytics/setup/${organizationId}`, {
    method: "POST",
    body: JSON.stringify({ sport }),
  });
}

export function finishMatchSetupAnalytics(organizationId, setupId, outcome, matchId, options = {}) {
  return apiRequest(`/analytics/setup/${organizationId}/${setupId}`, {
    method: "PUT",
    body: JSON.stringify({ outcome, match_id: matchId || null }),
    keepalive: Boolean(options.keepalive),
  });
}

export function exportAnalytics(organizationId, periodDays = 30) {
  return apiRequest(`/analytics/export/${organizationId}?period_days=${encodeURIComponent(periodDays)}`);
}

export function getProfileImage(organizationId) {
  return apiRequest(`/profile_image/${organizationId}`);
}

export function beginProfileImageUpload(organizationId) {
  return apiRequest(`/profile_image/${organizationId}/upload`, {
    method: "POST",
    body: JSON.stringify({}),
  });
}

export function completeProfileImageUpload(organizationId, objectKey) {
  return apiRequest(`/profile_image/${organizationId}/complete`, {
    method: "POST",
    body: JSON.stringify({ object_key: objectKey }),
  });
}

export function deleteProfileImage(organizationId) {
  return apiRequest(`/profile_image/${organizationId}`, { method: "DELETE" });
}

export function getNotifications(organizationId) {
  return apiRequest(`/notifications/${organizationId}`);
}

export function markNotificationRead(notificationId, organizationId) {
  return apiRequest(`/notifications/${notificationId}/read`, {
    method: "POST",
    body: JSON.stringify({ organization_id: organizationId }),
  });
}

export function getRootAdminOnlineUsers() {
  return apiRequest("/root_admin/online_users");
}

export function getRootAdminDashboard() {
  return apiRequest("/root_admin/dashboard");
}

export function deleteRootAdminAssociationCompetition(name) {
  return apiRequest(`/root_admin/association-competitions/${encodeURIComponent(name)}`, { method: "DELETE" });
}

export function getRootAdminNotifications() {
  return apiRequest("/root_admin/notifications");
}

export function getRootAdminSubscriptions(organizationId) {
  const suffix = organizationId ? `?organization_id=${encodeURIComponent(organizationId)}` : "";
  return apiRequest(`/root_admin/subscriptions${suffix}`);
}

export function createRootAdminNotification(payload) {
  return apiRequest("/root_admin/notifications", { method: "POST", body: JSON.stringify(payload) });
}

export function getRootAdminPlatformSports() {
  return apiRequest("/root_admin/platform_sports");
}

export function updateRootAdminPlatformSports(payload) {
  return apiRequest("/root_admin/platform_sports", {
    method: "PUT",
    body: JSON.stringify(payload),
  });
}

export function previewRootAdminPlatformSports(payload) {
  return apiRequest("/root_admin/platform_sports/preview", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export function getRootAdminMatches(filters = {}) {
  const params = new URLSearchParams();
  if (filters.sport) {
    params.set("sport", filters.sport);
  }
  if (filters.organizationId) {
    params.set("organization_id", String(filters.organizationId));
  }
  const suffix = params.toString() ? `?${params.toString()}` : "";
  return apiRequest(`/root_admin/matches${suffix}`);
}

export function archiveRootAdminMatch(matchId) {
  return apiRequest(`/root_admin/matches/${matchId}/archive`, {
    method: "PUT",
  });
}

export function getRootAdminMatch(matchId) {
  return apiRequest(`/root_admin/matches/${matchId}`);
}

export function deleteRootAdminMatch(matchId, confirmation) {
  return apiRequest(`/root_admin/matches/${matchId}`, {
    method: "DELETE",
    body: JSON.stringify({ confirmation }),
  });
}

export function getRootAdminInterestRequests(status = "") {
  const params = status ? new URLSearchParams({ status }) : null;
  const suffix = params ? `?${params.toString()}` : "";
  return apiRequest(`/root_admin/interest_requests${suffix}`);
}

export function updateRootAdminInterestRequestStatus(requestId, payload) {
  return apiRequest(`/root_admin/interest_requests/${requestId}`, {
    method: "PUT",
    body: JSON.stringify(payload),
  });
}

export function getRootAdminPersonalAccounts(plan = "") {
  const params = plan ? new URLSearchParams({ plan }) : null;
  const suffix = params ? `?${params.toString()}` : "";
  return apiRequest(`/root_admin/personal_accounts${suffix}`);
}

export function updateRootAdminPersonalAccount(requestId, payload) {
  return apiRequest(`/root_admin/personal_accounts/${requestId}`, {
    method: "PUT",
    body: JSON.stringify(payload),
  });
}

export function getRootAdminUsers(filters = {}) {
  const params = new URLSearchParams();
  if (filters.accountType) {
    params.set("account_type", filters.accountType);
  }
  if (filters.query) {
    params.set("q", filters.query);
  }
  const suffix = params.toString() ? `?${params.toString()}` : "";
  return apiRequest(`/root_admin/users${suffix}`);
}

export function getRootAdminUserProfile(userId) {
  return apiRequest(`/root_admin/users/${userId}`);
}

export function deleteRootAdminUser(userId, payload) {
  return apiRequest(`/root_admin/users/${userId}`, {
    method: "DELETE",
    body: JSON.stringify(payload),
  });
}

export function addRootAdminUserMembership(userId, payload) {
  return apiRequest(`/root_admin/users/${userId}/memberships`, {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export function deleteRootAdminUserMembership(userId, membershipId) {
  return apiRequest(`/root_admin/users/${userId}/memberships/${membershipId}`, {
    method: "DELETE",
  });
}

export function updateRootAdminUserSportAccess(userId, membershipId, payload) {
  return apiRequest(`/root_admin/users/${userId}/memberships/${membershipId}/sport-access`, {
    method: "PUT",
    body: JSON.stringify(payload),
  });
}

export function updateRootAdminUserPassword(userId, payload) {
  return apiRequest(`/root_admin/users/${userId}/password`, {
    method: "PUT",
    body: JSON.stringify(payload),
  });
}

export function verifyRootAdminUserEmail(userId) {
  return apiRequest(`/root_admin/users/${userId}/verify-email`, {
    method: "PUT",
  });
}

export function createRootAdminOrganization(payload) {
  return apiRequest("/root_admin/organizations", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export function updateRootAdminTournamentFeature(organizationId, webEnabled) {
  return apiRequest(`/root_admin/organizations/${organizationId}/tournament-feature`, {
    method: "PUT",
    body: JSON.stringify({ web_enabled: Boolean(webEnabled) }),
  });
}

export function searchRootAdminOrganizations(query) {
  const params = new URLSearchParams({ q: query });
  return apiRequest(`/root_admin/organizations/search?${params.toString()}`);
}

export function createRootAdminOrganizationUser(payload) {
  return apiRequest("/root_admin/organization_users", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export function updateRootAdminOrganizationUserRole(userId, payload) {
  return apiRequest(`/root_admin/organization_users/${userId}`, {
    method: "PUT",
    body: JSON.stringify(payload),
  });
}

export function approveRootAdminOrganizationUser(userId, payload) {
  return apiRequest(`/root_admin/organization_users/${userId}/approve`, {
    method: "PUT",
    body: JSON.stringify(payload),
  });
}

export function getOrganizationSettings(organizationId, options = {}) {
  return apiRequest(`/organization_settings/${organizationId}`, options);
}

export function getTournaments(organizationId) {
  return apiRequest(`/organizations/${organizationId}/tournaments`);
}

export function createTournament(organizationId, payload) {
  return apiRequest(`/organizations/${organizationId}/tournaments`, {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export function searchTournamentPlayers(organizationId, query) {
  const params = new URLSearchParams({ q: query });
  return apiRequest(`/organizations/${organizationId}/tournament-players?${params.toString()}`);
}

export function getTournament(tournamentId, organizationId) {
  const params = new URLSearchParams({ organization_id: String(organizationId) });
  return apiRequest(`/tournaments/${tournamentId}?${params.toString()}`);
}

export function createTournamentEntry(tournamentId, payload) {
  return apiRequest(`/tournaments/${tournamentId}/entries`, {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export function updateTournamentEntry(tournamentId, entryId, payload) {
  return apiRequest(`/tournaments/${tournamentId}/entries/${entryId}`, {
    method: "PUT",
    body: JSON.stringify(payload),
  });
}

export function generateTournamentDraw(tournamentId, payload) {
  return apiRequest(`/tournaments/${tournamentId}/draw`, {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export function publishTournamentDraw(tournamentId, payload) {
  return apiRequest(`/tournaments/${tournamentId}/draw/publish`, {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export function setTournamentPublicAccess(tournamentId, payload) {
  return apiRequest(`/tournaments/${tournamentId}/draw/public-access`, {
    method: "PUT",
    body: JSON.stringify(payload),
  });
}

export function returnTournamentDrawToDraft(tournamentId, payload) {
  return apiRequest(`/tournaments/${tournamentId}/draw/draft`, {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export function updateTournamentDrawSlot(tournamentId, matchId, payload) {
  return apiRequest(`/tournaments/${tournamentId}/draw/matches/${matchId}`, {
    method: "PUT",
    body: JSON.stringify(payload),
  });
}

export function scheduleTournamentMatch(tournamentId, matchId, payload) {
  return apiRequest(`/tournaments/${tournamentId}/draw/matches/${matchId}/schedule`, {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export function recordTournamentMatchResult(tournamentId, matchId, payload) {
  return apiRequest(`/tournaments/${tournamentId}/draw/matches/${matchId}/result`, {
    method: "PUT",
    body: JSON.stringify(payload),
  });
}

export function getPublicTournamentDraw(accessKey) {
  return apiRequest(`/public/tournament-draws/${encodeURIComponent(accessKey)}`);
}

export function searchMatchSetupLookup(organizationId, query) {
  const params = new URLSearchParams({ q: query });
  return apiRequest(`/match_setup_lookup/${organizationId}?${params.toString()}`);
}

export function updateOrganizationDetails(organizationId, payload, options = {}) {
  return apiRequest(`/organization_details/${organizationId}`, {
    ...options,
    method: "PUT",
    body: JSON.stringify(payload),
  });
}

export function updatePersonalProfile(organizationId, payload) {
  return apiRequest(`/personal_profile/${organizationId}`, {
    method: "PUT",
    body: JSON.stringify(payload),
  });
}

export function deletePersonalAccount(organizationId) {
  return apiRequest(`/personal_account/${organizationId}`, {
    method: "DELETE",
    body: JSON.stringify({ confirmation: "DELETE MY ACCOUNT" }),
  });
}

export function createOrganizationUser(payload) {
  return apiRequest("/organization_users", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export function updateOrganizationUser(userId, payload) {
  return apiRequest(`/organization_users/${userId}`, {
    method: "PUT",
    body: JSON.stringify(payload),
  });
}

export function updateOrganizationUserRole(userId, payload) {
  return updateOrganizationUser(userId, payload);
}

export function deleteOrganizationUser(userId, payload) {
  return apiRequest(`/organization_users/${userId}`, {
    method: "DELETE",
    body: JSON.stringify(payload),
  });
}

export function createOrganizationCourt(payload, options = {}) {
  return apiRequest("/organization_courts", {
    ...options,
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export function createOrganizationCourtDisplayCode(courtId, payload, options = {}) {
  return apiRequest(`/organization_courts/${courtId}/display-code`, {
    ...options,
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export function updateOrganizationCourt(courtId, payload, options = {}) {
  return apiRequest(`/organization_courts/${courtId}`, {
    ...options,
    method: "PUT",
    body: JSON.stringify(payload),
  });
}

export function deleteOrganizationCourt(courtId, payload, options = {}) {
  return apiRequest(`/organization_courts/${courtId}`, {
    ...options,
    method: "DELETE",
    body: JSON.stringify(payload),
  });
}

export function scorePoint(payload) {
  return apiRequest("/score_point", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export function sendEventAction(payload) {
  return apiRequest("/event_action", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export function undoAction(payload) {
  return apiRequest("/undo_action", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export function endMatch(payload) {
  return apiRequest("/end_match", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export function getScore(matchId) {
  return apiRequest(`/get_score/${matchId}`);
}

export function getMatchDisplayAccess(matchId) {
  return apiRequest(`/match_display_access/${matchId}`);
}

export function getWatchedMatch(payload) {
  return apiRequest("/match_watch/lookup", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export function saveWatchedMatch(payload) {
  return apiRequest("/match_watch/save", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export function createScoreboardDisplaySession(payload) {
  return apiRequest("/scoreboard_display/session", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export function createScoreboardPairing() {
  return apiRequest("/scoreboard_display/pairing", {
    method: "POST",
    body: "{}",
  });
}

export function exchangeScoreboardPairing(token) {
  return apiRequest("/scoreboard_display/session/qr", {
    method: "POST",
    body: JSON.stringify({ token }),
  });
}

export function getScoreboardDisplayCurrent(displaySessionToken) {
  return apiRequest("/scoreboard_display/current", {
    method: "GET",
    bearerToken: displaySessionToken,
  });
}
