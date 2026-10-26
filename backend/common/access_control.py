"""Central club membership role and capability policy.

Personal accounts are single-owner workspaces and retain their existing access.
Club access is deliberately capability based so handlers do not grow their own
slightly different role checks.
"""

ROLE_ADMIN = "admin"
ROLE_SCORER = "scorer"
ROLE_READ_ONLY = "read_only"
LEGACY_ROLE_USER = "user"

VALID_MEMBERSHIP_ROLES = {ROLE_ADMIN, ROLE_SCORER, ROLE_READ_ONLY}

CAPABILITY_MATCH_READ = "match.read"
CAPABILITY_MATCH_MANAGE = "match.manage"
CAPABILITY_ANALYTICS_READ = "analytics.read"
CAPABILITY_CLUB_SETTINGS_READ = "club.settings.read"
CAPABILITY_CLUB_SETTINGS_WRITE = "club.settings.write"
CAPABILITY_CLUB_MEMBERS_READ = "club.members.read"
CAPABILITY_CLUB_MEMBERS_WRITE = "club.members.write"
CAPABILITY_TOURNAMENT_READ = "tournament.read"
CAPABILITY_TOURNAMENT_MATCH_MANAGE = "tournament.match.manage"
CAPABILITY_TOURNAMENT_ADMIN = "tournament.admin"

ROLE_CAPABILITIES = {
    ROLE_ADMIN: {
        CAPABILITY_MATCH_READ,
        CAPABILITY_MATCH_MANAGE,
        CAPABILITY_ANALYTICS_READ,
        CAPABILITY_CLUB_SETTINGS_READ,
        CAPABILITY_CLUB_SETTINGS_WRITE,
        CAPABILITY_CLUB_MEMBERS_READ,
        CAPABILITY_CLUB_MEMBERS_WRITE,
        CAPABILITY_TOURNAMENT_READ,
        CAPABILITY_TOURNAMENT_MATCH_MANAGE,
        CAPABILITY_TOURNAMENT_ADMIN,
    },
    ROLE_SCORER: {
        CAPABILITY_MATCH_READ,
        CAPABILITY_MATCH_MANAGE,
        CAPABILITY_ANALYTICS_READ,
        CAPABILITY_CLUB_SETTINGS_READ,
        CAPABILITY_TOURNAMENT_READ,
        CAPABILITY_TOURNAMENT_MATCH_MANAGE,
    },
    ROLE_READ_ONLY: {
        CAPABILITY_MATCH_READ,
        CAPABILITY_ANALYTICS_READ,
        CAPABILITY_CLUB_SETTINGS_READ,
        CAPABILITY_TOURNAMENT_READ,
    },
}


def normalize_membership_role(role):
    normalized = (role or ROLE_SCORER).strip().lower()
    if normalized == LEGACY_ROLE_USER:
        return ROLE_SCORER
    return normalized


def membership_has_capability(membership, capability):
    if not capability:
        return True
    if (membership or {}).get("organization_type") == "personal":
        return True
    role = normalize_membership_role((membership or {}).get("role"))
    return capability in ROLE_CAPABILITIES.get(role, set())
