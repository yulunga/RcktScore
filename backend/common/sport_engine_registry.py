from importlib import import_module


DEFAULT_SPORT = "squash"

SPORT_ENGINE_MODULES = {
    "squash": "common.squash_match_logic",
    "racketball": "common.squash_match_logic",
    "tennis": "common.tennis_match_logic",
    "padel": "common.padel_match_logic",
    "table_tennis": "common.table_tennis_match_logic",
    "badminton": "common.badminton_match_logic",
    "pickleball": "common.pickleball_match_logic",
}


def normalize_sport(value):
    parsed = str(value or DEFAULT_SPORT).strip().lower()
    return parsed if parsed in SPORT_ENGINE_MODULES else DEFAULT_SPORT


def resolve_engine_module(sport):
    return import_module(SPORT_ENGINE_MODULES[normalize_sport(sport)])
