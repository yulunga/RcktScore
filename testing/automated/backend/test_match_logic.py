from common.match_logic import (
    _best_of_value,
    _games_to_win,
    _is_game_complete,
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


def test_game_completion_requires_target_and_two_point_margin():
    assert _is_game_complete(15, 12, 15) is True
    assert _is_game_complete(15, 14, 15) is False
    assert _is_game_complete(17, 15, 15) is True

