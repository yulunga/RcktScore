import re


MIN_PASSWORD_LENGTH = 8
COMMON_PASSWORD_TERMS = (
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
)


def validate_password(password):
    value = str(password or "")
    if len(value) < MIN_PASSWORD_LENGTH:
        raise ValueError(f"Password must be at least {MIN_PASSWORD_LENGTH} characters")
    if not re.search(r"[A-Z]", value):
        raise ValueError("Password must include at least one uppercase letter")
    if not re.search(r"\d", value):
        raise ValueError("Password must include at least one number")
    if not re.search(r"[^A-Za-z0-9\s]", value):
        raise ValueError("Password must include at least one symbol")

    normalized = re.sub(r"[^a-z0-9]", "", value.lower())
    if any(term in normalized for term in COMMON_PASSWORD_TERMS):
        raise ValueError("Password must not contain a common or easily guessed word")

    return value
