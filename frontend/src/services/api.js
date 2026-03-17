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
    throw new Error(payload.message || "API request failed");
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

export function getScore(matchId) {
  return apiRequest(`/get_score/${matchId}`);
}
