import re


EMAIL_PATTERN = re.compile(r"[^@\s]+@[^@\s]+\.[^@\s]+")


def normalize_exception_emails(value):
    source = value.splitlines() if isinstance(value, str) else value
    normalized = []
    seen = set()
    for item in source if isinstance(source, list) else []:
        email = str(item or "").strip().lower()
        if not EMAIL_PATTERN.fullmatch(email) or len(email) > 254 or email in seen:
            continue
        seen.add(email)
        normalized.append(email)
    return sorted(normalized)[:250]


def subscription_access_enabled(user_row):
    return bool(user_row.get("subscription_access_enabled", True))
