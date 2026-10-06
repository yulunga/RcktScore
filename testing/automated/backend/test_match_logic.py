from datetime import datetime, timezone
from itertools import product

from common.squash_match_logic import (
    _build_state,
    _best_of_value,
    _games_to_win,
    _is_game_complete,
    _can_choose_shirt_colors,
    _next_service_side_after_point,
    _prepare_scoring_transition,
    _score_type_value,
    _shirt_color_value,
)


def test_best_of_value_only_allows_supported_options():
    assert _best_of_value(1) == 1
    assert _best_of_value(3) == 3
    assert _best_of_value(5) == 5
    assert _best_of_value(7) == 1


def test_games_to_win_is_derived_from_best_of():
    assert _games_to_win(1) == 1
    assert _games_to_win(3) == 2
    assert _games_to_win(5) == 3


def test_score_type_value_defaults_to_par_15_for_invalid_values():
    assert _score_type_value(11) == 11
    assert _score_type_value(15) == 15
    assert _score_type_value(99) == 15


def test_shirt_color_value_falls_back_when_unknown():
    assert _shirt_color_value("blue", "navy") == "blue"
    assert _shirt_color_value("unknown", "navy") == "navy"


def test_shirt_colors_are_available_to_both_personal_plans_and_clubs():
    assert _can_choose_shirt_colors({"org_type": "personal", "plan": "personal_free"}, 50001) is True
    assert _can_choose_shirt_colors({"org_type": "personal", "plan": "personal_plus"}, 50002) is True
    assert _can_choose_shirt_colors({"org_type": "club", "plan": "club_essentials"}, 1) is True


def test_game_completion_requires_target_and_two_point_margin():
    assert _is_game_complete(15, 12, 15) is True
    assert _is_game_complete(15, 14, 15) is False
    assert _is_game_complete(17, 15, 15) is True


def test_golden_point_completes_on_the_next_point_at_target_all():
    assert _is_game_complete(11, 10, 11, golden_point=True) is True
    assert _is_game_complete(15, 14, 15, golden_point=True) is True
    assert _is_game_complete(10, 10, 11, golden_point=True) is False


def _active_match(**state_overrides):
    state = {
        "player1_score": 1,
        "player2_score": 1,
        "player1_games_won": 0,
        "player2_games_won": 0,
        "current_game_number": 1,
        "best_of": 3,
        "games_to_win": 2,
        "current_server": "Alex",
        "current_server_side": "player1",
        "service_side": "Right",
        "game_history": [],
        "match_complete": False,
    }
    state.update(state_overrides)
    return {
        "status": "active",
        "score_type": 11,
        "best_of": 3,
        "player1_name": "Alex",
        "player2_name": "Blair",
        "player1_handedness": "right",
        "player2_handedness": "right",
        "handicap_enabled": False,
        "player1_offset": 0,
        "player2_offset": 0,
        "state": state,
    }


def test_server_win_alternates_from_manually_selected_left_side():
    match = _active_match(service_side="Left")

    transition = _prepare_scoring_transition(match, "player1", "score_point", {"scorer": "player1"})

    assert transition["state"]["player1_score"] == 2
    assert transition["state"]["current_server_side"] == "player1"
    assert transition["state"]["service_side"] == "Right"
    assert transition["payload"]["service_side"] == "Right"


def test_racket_golden_point_ends_game_with_one_point_lead():
    match = _active_match(
        player1_score=10,
        player2_score=10,
        tennis_no_ad_scoring=True,
    )

    transition = _prepare_scoring_transition(match, "player1", "score_point", {"scorer": "player1"})

    assert transition["payload"]["game_completed"] is True
    assert transition["payload"]["game_result"]["player1_score"] == 11
    assert transition["payload"]["game_result"]["player2_score"] == 10


def test_service_transfer_uses_receivers_handedness_default():
    match = _active_match(
        current_server="Blair",
        current_server_side="player2",
        service_side="Left",
    )
    match["player2_handedness"] = "left"

    transition = _prepare_scoring_transition(match, "player1", "score_point", {"scorer": "player1"})

    assert transition["state"]["current_server_side"] == "player1"
    assert transition["state"]["service_side"] == "Left"


def test_legacy_event_replay_preserves_previous_server_for_service_transfer():
    match_row = {
        **_active_match(),
        "status": "active",
        "current_game_number": 1,
        "player1_games_won": 0,
        "player2_games_won": 0,
        "winner_side": None,
        "winner_name": None,
        "ended_early": False,
        "end_reason": None,
        "match_duration_seconds": 0,
    }
    match_row.pop("state")
    event_rows = [
        {
            "id": "start",
            "event_type": "match_started",
            "event_source": "api",
            "created_at": datetime.now(timezone.utc),
            "payload": {
                "current_server": "Blair",
                "current_server_side": "player2",
                "service_side": "Right",
                "player1_score": 0,
                "player2_score": 1,
            },
        },
        {
            "id": "legacy-point",
            "event_type": "score_point",
            "event_source": "api",
            "created_at": datetime.now(timezone.utc),
            "payload": {"scorer": "player1"},
        },
    ]

    state = _build_state(match_row, event_rows)

    assert state["current_server_side"] == "player1"
    assert state["service_side"] == "Right"


def test_service_side_helper_does_not_change_score_or_server():
    match = _active_match()

    assert _next_service_side_after_point(match, "player1", "Left", "player1") == "Right"
    assert _next_service_side_after_point(match, "player2", "Left", "player1") == "Right"


def test_exhaustive_six_point_sequences_keep_server_and_service_side_consistent():
    for player1_handedness, player2_handedness in product(("right", "left"), repeat=2):
        for scorers in product(("player1", "player2"), repeat=6):
            match = _active_match(player1_score=0, player2_score=0)
            match["player1_handedness"] = player1_handedness
            match["player2_handedness"] = player2_handedness
            expected_player1 = 0
            expected_player2 = 0

            for scorer in scorers:
                previous_server = match["state"]["current_server_side"]
                previous_side = match["state"]["service_side"]
                expected_side = (
                    "Left" if previous_side == "Right" else "Right"
                ) if scorer == previous_server else (
                    "Left"
                    if (
                        player2_handedness if scorer == "player1" else player1_handedness
                    ) == "left"
                    else "Right"
                )

                transition = _prepare_scoring_transition(
                    match,
                    scorer,
                    "score_point",
                    {"scorer": scorer},
                )
                match["state"] = transition["state"]
                expected_player1 += scorer == "player1"
                expected_player2 += scorer == "player2"

                assert transition["state"]["player1_score"] == expected_player1
                assert transition["state"]["player2_score"] == expected_player2
                assert transition["state"]["current_server_side"] == scorer
                assert transition["state"]["service_side"] == expected_side


def test_game_and_match_boundaries_reset_only_when_another_game_is_required():
    match = _active_match(player1_score=10, player2_score=4)

    game_transition = _prepare_scoring_transition(
        match,
        "player1",
        "score_point",
        {"scorer": "player1"},
    )

    assert game_transition["payload"]["game_result"]["player1_score"] == 11
    assert game_transition["state"]["current_game_number"] == 2
    assert game_transition["state"]["player1_games_won"] == 1
    assert game_transition["state"]["player1_score"] == 0
    assert game_transition["state"]["player2_score"] == 0
    assert game_transition["state"]["match_complete"] is False

    match["state"] = {
        **game_transition["state"],
        "player1_score": 10,
        "player2_score": 5,
    }
    match_transition = _prepare_scoring_transition(
        match,
        "player1",
        "score_point",
        {"scorer": "player1"},
    )

    assert match_transition["state"]["match_complete"] is True
    assert match_transition["state"]["player1_games_won"] == 2
    assert match_transition["state"]["player1_score"] == 11
    assert match_transition["state"]["winner_name"] == "Alex"
