from common.organization_logic import normalize_association_competitions, normalize_timed_break_defaults


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


def test_association_competitions_are_normalized_and_deduplicated():
    assert normalize_association_competitions([
        {
            "name": " County League ",
            "type": "league",
            "match_setup_enabled": True,
            "fixtures": [
                {"date": "2027-02-12", "opposition": " North Club "},
                {"date": "2027-01-08", "opposition": "South Club"},
                {"date": "not-a-date", "opposition": "Ignored Club"},
                {"date": "2027-01-08", "opposition": "south club"},
                {"date": "2027-03-04", "opposition": ""},
            ],
        },
        {"name": "county league", "type": "interclub"},
        {"name": "Club Cup", "type": "INTERCLUB"},
        {"name": "Ignored", "type": "unsupported"},
        {"name": "", "type": "league"},
        "not-an-object",
    ]) == [
        {
            "name": "County League",
            "type": "league",
            "match_setup_enabled": True,
            "divisions": [{
                "name": "General",
                "url": "",
                "fixtures": [
                    {"date": "2027-01-08", "opposition": "South Club", "venue": "home"},
                    {"date": "2027-02-12", "opposition": "North Club", "venue": "home"},
                ],
            }],
        },
        {"name": "Club Cup", "type": "interclub", "match_setup_enabled": False, "divisions": []},
    ]


def test_association_competitions_reject_non_lists():
    assert normalize_association_competitions(None) == []
    assert normalize_association_competitions({"name": "County League"}) == []
