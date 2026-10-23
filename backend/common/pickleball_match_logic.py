from common._unsupported_sport_logic import (
    activate_scheduled_match,
    serialize_match,
    unsupported_sport_error,
)


SPORT = "pickleball"


def create_match(connection, payload, source="api"):
    unsupported_sport_error("Pickleball")


def score_point(connection, match_id, scorer, source="api", commit=True):
    unsupported_sport_error("Pickleball")


def event_action(connection, match_id, action_type, payload, source="api", commit=True):
    unsupported_sport_error("Pickleball")


def undo_last_action(connection, match_id, commit=True):
    unsupported_sport_error("Pickleball")


def end_match(
    connection,
    match_id,
    source="api",
    reason=None,
    ended_early=None,
    match_duration_seconds=None,
    commit=True,
):
    unsupported_sport_error("Pickleball")
