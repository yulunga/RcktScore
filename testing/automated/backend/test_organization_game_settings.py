from common.organization_logic import normalize_timed_break_defaults


def test_timed_break_defaults_are_complete_and_false_by_default():
    assert normalize_timed_break_defaults(None) == {
        "squash": False,
        "racketball": False,
        "tennis": False,
        "padel": False,
    }


def test_timed_break_defaults_preserve_supported_per_sport_choices_only():
    assert normalize_timed_break_defaults({
        "squash": True,
        "racketball": False,
        "tennis": 1,
        "padel": "",
        "badminton": True,
    }) == {
        "squash": True,
        "racketball": False,
        "tennis": True,
        "padel": False,
    }
