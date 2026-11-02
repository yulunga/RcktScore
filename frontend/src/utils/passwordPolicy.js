export const PASSWORD_MIN_LENGTH = 8;

const COMMON_PASSWORD_TERMS = [
  "password",
  "passw0rd",
  "qwerty",
  "welcome",
  "letmein",
  "changeme",
  "admin",
  "login",
  "secret",
  "abc123",
  "hitnscore",
];

export function passwordPolicyError(password) {
  const value = String(password || "");
  if (value.length < PASSWORD_MIN_LENGTH) return `Password must be at least ${PASSWORD_MIN_LENGTH} characters.`;
  if (!/[A-Z]/.test(value)) return "Password must include at least one uppercase letter.";
  if (!/\d/.test(value)) return "Password must include at least one number.";
  if (!/[^A-Za-z0-9\s]/.test(value)) return "Password must include at least one symbol.";

  const normalized = value.toLowerCase().replace(/[^a-z0-9]/g, "");
  if (COMMON_PASSWORD_TERMS.some((term) => normalized.includes(term))) {
    return "Password must not contain a common or easily guessed word.";
  }
  return "";
}

export function passwordRequirements(password) {
  const value = String(password || "");
  const normalized = value.toLowerCase().replace(/[^a-z0-9]/g, "");
  return [
    { label: "At least 8 characters", met: value.length >= PASSWORD_MIN_LENGTH },
    { label: "One uppercase letter", met: /[A-Z]/.test(value) },
    { label: "One number", met: /\d/.test(value) },
    { label: "One symbol", met: /[^A-Za-z0-9\s]/.test(value) },
    { label: "No common or easily guessed words", met: Boolean(value) && !COMMON_PASSWORD_TERMS.some((term) => normalized.includes(term)) },
  ];
}
