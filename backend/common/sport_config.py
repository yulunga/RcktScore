from psycopg.errors import UndefinedTable


SPORT_LABELS = {
    "squash": "Squash",
    "racketball": "Racketball",
    "tennis": "Tennis",
    "padel": "Padel",
    "table_tennis": "Table Tennis",
    "badminton": "Badminton",
    "pickleball": "Pickleball",
}

ALL_RACKET_SPORTS = tuple(SPORT_LABELS.keys())
IMPLEMENTED_RACKET_SPORTS = ("squash", "racketball", "tennis")
DEFAULT_ENABLED_SPORTS = ("squash", "racketball", "tennis")
PLATFORM_SETTINGS_KEY = "default"


def normalize_sport_id(value, default="squash"):
    parsed = str(value or default).strip().lower()
    return parsed if parsed in SPORT_LABELS else default


def normalize_enabled_sports(values, default=None):
    fallback = tuple(default or DEFAULT_ENABLED_SPORTS)
    if values is None:
        return list(fallback)

    if isinstance(values, str):
        candidates = [part.strip().lower() for part in values.split(",")]
    elif isinstance(values, (list, tuple, set)):
        candidates = [str(part or "").strip().lower() for part in values]
    else:
        return list(fallback)

    requested = {
        normalize_sport_id(candidate, default="")
        for candidate in candidates
        if str(candidate or "").strip()
    }

    return [sport for sport in ALL_RACKET_SPORTS if sport in requested]


def fetch_platform_enabled_sports(connection):
    try:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                SELECT enabled_sports
                FROM platform_settings
                WHERE id = %(settings_id)s
                LIMIT 1
                """,
                {"settings_id": PLATFORM_SETTINGS_KEY},
            )
            row = cursor.fetchone()
    except UndefinedTable:
        connection.rollback()
        row = None

    return normalize_enabled_sports((row or {}).get("enabled_sports"))


def constrain_enabled_sports(connection, values):
    requested = normalize_enabled_sports(values)
    platform_enabled = fetch_platform_enabled_sports(connection)
    platform_enabled_set = set(platform_enabled)
    return [sport for sport in requested if sport in platform_enabled_set]


def fetch_enabled_sports(connection, organization_id):
    platform_enabled = fetch_platform_enabled_sports(connection)
    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT enabled_sports
            FROM "SkwshOrgSettings"
            WHERE id = %(organization_id)s
            LIMIT 1
            """,
            {"organization_id": int(organization_id)},
        )
        row = cursor.fetchone()

    organization_enabled = normalize_enabled_sports((row or {}).get("enabled_sports"))
    platform_enabled_set = set(platform_enabled)
    return [sport for sport in organization_enabled if sport in platform_enabled_set]
