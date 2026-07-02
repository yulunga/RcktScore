from common import squash_match_logic as squash_logic


def serialize_match(match_row, event_rows):
    # Read models still share the current match schema until each sport gets its own state builder.
    return squash_logic._serialize_match(match_row, event_rows)


def activate_scheduled_match(connection, match_id):
    return squash_logic.activate_scheduled_match(connection, match_id)


def unsupported_sport_error(display_name):
    raise ValueError(
        f"{display_name} scoring logic is not implemented yet. "
        "The sport engine file exists and is wired into the dispatcher, "
        "but scoring actions are not enabled yet."
    )
