export const MATCH_SPORT_OPTIONS = [
  {
    value: "squash",
    label: "Squash",
    note: "Use the standard squash match setup flow.",
    implemented: true,
  },
  {
    value: "racketball",
    label: "Racketball",
    note: "Use the shared squash and racketball setup flow.",
    implemented: true,
  },
  {
    value: "tennis",
    label: "Tennis",
    note: "Use the tennis setup and live scoring flow.",
    implemented: true,
  },
  {
    value: "padel",
    label: "Padel",
    note: "Sport engine scaffolded but scoring is not live yet.",
    implemented: false,
  },
  {
    value: "table_tennis",
    label: "Table Tennis",
    note: "Sport engine scaffolded but scoring is not live yet.",
    implemented: false,
  },
  {
    value: "badminton",
    label: "Badminton",
    note: "Sport engine scaffolded but scoring is not live yet.",
    implemented: false,
  },
  {
    value: "pickleball",
    label: "Pickleball",
    note: "Sport engine scaffolded but scoring is not live yet.",
    implemented: false,
  },
];

export const DEFAULT_ENABLED_SPORTS = ["squash", "racketball", "tennis"];

export function normalizeMatchSport(value) {
  const normalizedValue = String(value || "").trim().toLowerCase();
  return MATCH_SPORT_OPTIONS.find((sport) => sport.value === normalizedValue)?.value || "";
}

export function normalizeEnabledSports(values, fallback = DEFAULT_ENABLED_SPORTS) {
  if (values == null) {
    return [...fallback];
  }

  const candidates = Array.isArray(values) ? values : fallback;
  const normalizedSet = new Set(
    candidates
      .map((value) => normalizeMatchSport(value))
      .filter(Boolean),
  );

  const normalized = MATCH_SPORT_OPTIONS
    .map((sport) => sport.value)
    .filter((value) => normalizedSet.has(value));

  return normalized;
}

export function getMatchSportOption(value) {
  const normalizedValue = normalizeMatchSport(value);
  return MATCH_SPORT_OPTIONS.find((sport) => sport.value === normalizedValue) || null;
}

export function getPlayableMatchSports(enabledSports) {
  const enabledSet = new Set(normalizeEnabledSports(enabledSports));
  return MATCH_SPORT_OPTIONS.filter((sport) => sport.implemented && enabledSet.has(sport.value));
}
