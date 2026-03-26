const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || "";
const API_KEY = import.meta.env.VITE_API_KEY;

async function apiRequest(path, options = {}) {
  const headers = {
    "Content-Type": "application/json",
    ...(API_KEY ? { "x-api-key": API_KEY } : {}),
    ...(options.headers || {}),
  };

  const response = await fetch(`${API_BASE_URL}${path}`, {
    ...options,
    headers,
  });

  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    const error = new Error(payload?.error?.message || payload.message || "API request failed");
    error.code = payload?.error?.code;
    error.details = payload?.error?.details;
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

export function login(payload) {
  return apiRequest("/login", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export function rootAdminLogin(payload) {
  return apiRequest("/root_admin/login", {
    method: "POST",
    body: JSON.stringify(payload),
  });
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

export function getDashboard(organizationId) {
  return apiRequest(`/dashboard/${organizationId}`);
}

export function getRootAdminDashboard() {
  return apiRequest("/root_admin/dashboard");
}

export function createRootAdminOrganization(payload) {
  return apiRequest("/root_admin/organizations", {
    method: "POST",
    body: JSON.stringify(payload),
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

export function getOrganizationSettings(organizationId) {
  return apiRequest(`/organization_settings/${organizationId}`);
}

export function updateOrganizationDetails(organizationId, payload) {
  return apiRequest(`/organization_details/${organizationId}`, {
    method: "PUT",
    body: JSON.stringify(payload),
  });
}

export function createOrganizationUser(payload) {
  return apiRequest("/organization_users", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export function updateOrganizationUserRole(userId, payload) {
  return apiRequest(`/organization_users/${userId}`, {
    method: "PUT",
    body: JSON.stringify(payload),
  });
}

export function createOrganizationCourt(payload) {
  return apiRequest("/organization_courts", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export function updateOrganizationCourt(courtId, payload) {
  return apiRequest(`/organization_courts/${courtId}`, {
    method: "PUT",
    body: JSON.stringify(payload),
  });
}

export function deleteOrganizationCourt(courtId, payload) {
  return apiRequest(`/organization_courts/${courtId}`, {
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
