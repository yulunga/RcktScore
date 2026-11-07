def mask_email_for_log(value):
    """Return a useful but non-identifying label for an email-like value."""
    normalized = str(value or "").strip().lower()
    if not normalized:
        return "unknown"

    if "@" not in normalized:
        return f"{normalized[0]}***"

    local_part, domain = normalized.rsplit("@", 1)
    masked_local = f"{local_part[0]}***" if local_part else "***"
    return f"{masked_local}@{domain or 'unknown'}"
