from datetime import datetime, timezone

import pytest

from common import tennis_match_logic as tennis


def make_match(**state_overrides):
    row = {
        "id": "match-1",
        "tenant_id": 1,
        "court_id": 1,
        "court_name": "Centre Court",
        "court_alias": None,
        "court_display_code": "",
        "sport": "tennis",
        "player1_name": "Alex",
        "player2_name": "Blair",
        "best_of": 3,
        "games_to_win": 2,
        "score_type": 6,
        "status": "active",
        "created_at": datetime.now(timezone.utc),
        "updated_at": datetime.now(timezone.utc),
        "completed_at": None,
        "player1_games_won": 0,
        "player2_games_won": 0,
        "current_game_number": 1,
        "team_format": "singles",
    }
    state = tennis._initial_state(row)
    state.update(state_overrides)
    return {**row, "state": state}


def point(match, side):
    transition = tennis._prepare_scoring_transition(match, side, "score_point", {"scorer": side})
    return {**match, "state": transition["state"]}, transition


def test_advantage_deuce_requires_two_clear_points():
    match = make_match(player1_score=3, player2_score=3)
    match, _ = point(match, "player1")
    assert match["state"]["player1_score_label"] == "Ad"
    match, _ = point(match, "player2")
    assert match["state"]["player1_score_label"] == "40"
    assert match["state"]["player2_score_label"] == "40"


def test_no_ad_requires_receiver_choice_then_next_point_wins():
    match = make_match(
        player1_score=3,
        player2_score=3,
        tennis_no_ad_scoring=True,
        no_ad_deciding_side=None,
    )
    with pytest.raises(ValueError, match="receiver must choose"):
        point(match, "player1")

    payload, state = tennis._prepare_receiver_choice(match, {"side": "Left"})
    assert payload["side"] == "Left"
    match["state"] = state
    match, _ = point(match, "player2")
    assert match["state"]["player2_set_games"] == 1
    assert match["state"]["player1_score"] == 0
    assert match["state"]["no_ad_deciding_side"] is None


def test_six_all_starts_seven_point_tiebreak_and_long_tiebreak_continues():
    match = make_match(player1_score=3, player2_score=0, player1_set_games=5, player2_set_games=6)
    match, _ = point(match, "player1")
    assert match["state"]["is_tie_break"] is True
    assert match["state"]["player1_set_games"] == 6

    match["state"].update(player1_score=7, player2_score=7)
    match, _ = point(match, "player1")
    assert match["state"]["match_complete"] is False
    assert match["state"]["player1_score"] == 8


def test_final_set_is_replaced_by_ten_point_match_tiebreak():
    match = make_match(
        player1_games_won=0,
        player2_games_won=1,
        player1_score=3,
        player2_score=0,
        player1_set_games=5,
        player2_set_games=0,
        tennis_final_set_match_tiebreak=True,
    )
    match, _ = point(match, "player1")
    assert match["state"]["player1_games_won"] == 1
    assert match["state"]["player2_games_won"] == 1
    assert match["state"]["is_tie_break"] is True
    assert match["state"]["is_match_tiebreak"] is True

    match["state"].update(player1_score=9, player2_score=8)
    match, _ = point(match, "player1")
    assert match["state"]["match_complete"] is True
    assert match["state"]["winner_side"] == "player1"


def test_doubles_service_order_rotates_across_set_boundary():
    match = make_match()
    _, teams = tennis._build_tennis_teams({
        "team_format": "doubles",
        "player1_name": "Alex",
        "player2_name": "Blair",
        "team1_player2_name": "Casey",
        "team2_player2_name": "Drew",
    })
    order = ["team1_player1", "team2_player1", "team1_player2", "team2_player2"]
    match["state"].update(
        team_format="doubles",
        tennis_teams=teams,
        serve_order=order,
        current_server_participant_id="team2_player1",
        current_server_side="player2",
        player1_score=3,
        player2_score=0,
        player1_set_games=5,
        player2_set_games=0,
    )
    match, _ = point(match, "player1")
    assert match["state"]["current_server_participant_id"] == "team1_player2"
    assert match["state"]["serve_order"][0] == "team1_player2"


def test_best_of_one_match_completes_when_first_set_is_won():
    match = make_match(
        best_of=1,
        games_to_win=1,
        player1_score=3,
        player2_score=0,
        player1_set_games=5,
        player2_set_games=0,
    )
    match, _ = point(match, "player1")
    assert match["state"]["match_complete"] is True
    assert match["state"]["winner_name"] == "Alex"


def test_event_rebuild_without_last_point_restores_pre_point_state_for_undo():
    match = make_match()
    _, transition = point(match, "player1")
    started = {
        "id": "event-start",
        "event_type": "match_started",
        "payload": {"sport": "tennis", "score_type": 6, "best_of": 3, "games_to_win": 2},
        "event_source": "test",
        "created_at": datetime.now(timezone.utc),
    }
    scored = {
        "id": "event-score",
        "event_type": "score_point",
        "payload": transition["payload"],
        "event_source": "test",
        "created_at": datetime.now(timezone.utc),
    }
    with_point = tennis._build_state(match, [started, scored])
    after_undo = tennis._build_state(match, [started])
    assert with_point["player1_score"] == 1
    assert after_undo["player1_score"] == 0
