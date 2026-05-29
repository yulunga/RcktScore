export const MATCH_SPORT_OPTIONS = [
  {
    value: "squash",
    label: "Squash",
    note: "Use the standard squash match setup flow.",
  },
  {
    value: "racketball",
    label: "Racketball",
    note: "Use the shared squash and racketball setup flow.",
  },
];

export function normalizeMatchSport(value) {
  const normalizedValue = String(value || "").trim().toLowerCase();
  return MATCH_SPORT_OPTIONS.find((sport) => sport.value === normalizedValue)?.value || "";
}

export function getMatchSportOption(value) {
  const normalizedValue = normalizeMatchSport(value);
  return MATCH_SPORT_OPTIONS.find((sport) => sport.value === normalizedValue) || null;
}
