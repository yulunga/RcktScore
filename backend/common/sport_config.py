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
IMPLEMENTED_RACKET_SPORTS = ("squash", "racketball", "tennis", "padel")
DEFAULT_ENABLED_SPORTS = ("squash", "racketball", "tennis")
PLATFORM_SETTINGS_KEY = "default"
CLIENT_TYPE_WEB = "web_app"
CLIENT_TYPE_IOS = "mobile_app"


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


def normalize_sport_client(value):
    mobile_aliases = {"mobile", "mobile_app", "ios", "ios_app"}
    return CLIENT_TYPE_IOS if str(value or "").strip().lower() in mobile_aliases else CLIENT_TYPE_WEB


def client_sport_field(client_type):
    return "enabled_sports_ios" if normalize_sport_client(client_type) == CLIENT_TYPE_IOS else "enabled_sports_web"


def effective_enabled_sports(platform_values, organization_values, membership_values=None):
    platform = normalize_enabled_sports(platform_values)
    organization = set(normalize_enabled_sports(organization_values))
    membership = set(
        normalize_enabled_sports(membership_values)
        if membership_values is not None
        else organization
    )
    return [sport for sport in platform if sport in organization and sport in membership]


def fetch_platform_enabled_sports(connection):
    try:
        # A nested transaction becomes a savepoint when the caller already has
        # pending writes. A missing optional table can then be handled without
        # rolling back an in-progress registration or settings update.
        with connection.transaction():
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
        row = None

    return normalize_enabled_sports((row or {}).get("enabled_sports"))


def fetch_platform_client_enabled_sports(connection, client_type):
    field = client_sport_field(client_type)
    with connection.cursor() as cursor:
        cursor.execute(
            f"""
            SELECT enabled_sports, {field} AS client_enabled_sports
            FROM platform_settings
            WHERE id = %(settings_id)s
            LIMIT 1
            """,
            {"settings_id": PLATFORM_SETTINGS_KEY},
        )
        row = cursor.fetchone() or {}

    return normalize_enabled_sports(row.get("client_enabled_sports"), default=row.get("enabled_sports"))


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


def constrain_user_enabled_sports(connection, organization_id, values, client_type):
    requested = set(normalize_enabled_sports(values))
    organization_enabled = set(fetch_enabled_sports(connection, organization_id))
    platform_client_enabled = fetch_platform_client_enabled_sports(connection, client_type)
    return [
        sport
        for sport in platform_client_enabled
        if sport in organization_enabled and sport in requested
    ]
