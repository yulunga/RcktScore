import pytest

from common.tournament import access, tournament_logic


class SingleRowCursor:
    def __init__(self, connection):
        self.connection = connection
        self.rowcount = 1

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, traceback):
        return False

    def execute(self, query, params=None):
        self.connection.statements.append((" ".join(query.split()), params or {}))

    def fetchone(self):
        return self.connection.rows.pop(0) if self.connection.rows else None


class SingleRowConnection:
    def __init__(self, rows):
        self.rows = list(rows)
        self.statements = []
        self.committed = False

    def cursor(self):
        return SingleRowCursor(self)

    def commit(self):
        self.committed = True


def test_missing_tournament_feature_row_defaults_to_disabled():
    connection = SingleRowConnection([{
        "organization_id": 12,
        "organization_type": "club",
        "web_enabled": False,
        "enabled_by": None,
        "enabled_at": None,
        "updated_at": None,
    }])

    feature = access.get_tournament_feature(connection, 12)

    assert feature["web_enabled"] is False
    with pytest.raises(access.TournamentAccessError):
        access.require_tournament_feature(SingleRowConnection([{
            "organization_id": 12,
            "organization_type": "club",
            "web_enabled": False,
            "enabled_by": None,
            "enabled_at": None,
            "updated_at": None,
        }]), 12)


def test_personal_accounts_cannot_use_tournament_manager():
    connection = SingleRowConnection([{
        "organization_id": 50001,
        "organization_type": "personal",
        "web_enabled": True,
        "enabled_by": "root",
        "enabled_at": None,
        "updated_at": None,
    }])

    with pytest.raises(access.TournamentAccessError):
        access.require_tournament_feature(connection, 50001)


def test_root_admin_feature_update_is_committed(monkeypatch):
    connection = SingleRowConnection([])
    returned_features = iter([
        {"organization_id": 7, "organization_type": "club", "web_enabled": False},
        {"organization_id": 7, "organization_type": "club", "web_enabled": True},
    ])
    monkeypatch.setattr(access, "get_tournament_feature", lambda *_args: next(returned_features))

    feature = access.set_tournament_feature(connection, 7, True, "root@example.com")

    assert feature["web_enabled"] is True
    assert connection.committed is True
    assert any("INSERT INTO tournament_organization_features" in query for query, _ in connection.statements)


@pytest.mark.parametrize("sport", ["badminton", "pickleball", ""])
def test_tournament_creation_rejects_unsupported_sports_before_database_write(sport):
    with pytest.raises(ValueError):
        tournament_logic.create_tournament(
            None,
            1,
            {"name": "Club Open", "sport": sport, "draw_format": "knockout"},
            "admin@example.com",
        )


def test_tournament_creation_rejects_end_before_start():
    with pytest.raises(ValueError, match="ends_on cannot be before starts_on"):
        tournament_logic.create_tournament(
            None,
            1,
            {
                "name": "Club Open",
                "sport": "squash",
                "draw_format": "round_robin",
                "starts_on": "2026-10-10",
                "ends_on": "2026-10-09",
            },
            "admin@example.com",
        )


def test_player_normalization_is_case_and_whitespace_insensitive():
    assert tournament_logic._normalize_name("  Alex ", " Mc Kay  ") == "alex mc kay"


def test_new_player_requires_first_name_and_surname_before_database_access():
    with pytest.raises(ValueError, match="surname is required"):
        tournament_logic._find_or_create_player(None, 1, {"first_name": "Demo", "surname": ""})


def test_tournament_creation_rejects_invalid_audience_before_database_write():
    with pytest.raises(ValueError, match="audience must be internal or open"):
        tournament_logic.create_tournament(
            None,
            1,
            {"name": "Club Open", "sport": "squash", "draw_format": "knockout", "audience": "public"},
            "admin@example.com",
        )


def test_tournament_creation_rejects_draw_limit_below_two_before_database_write():
    with pytest.raises(ValueError, match="draw_size_limit must be at least 2"):
        tournament_logic.create_tournament(
            None,
            1,
            {"name": "Club Open", "sport": "squash", "draw_format": "knockout", "draw_size_limit": 1},
            "admin@example.com",
        )


@pytest.mark.parametrize(("ability_level", "grade"), [(1, "A"), (2, "B"), (3, "C"), (4, "D")])
def test_entry_serializer_maps_ability_level_to_grade(ability_level, grade):
    entry = tournament_logic._serialize_entry({
        "id": "07fd1fc6-4133-4872-b469-112841c49384",
        "player_id": "e1cbcc2a-d9bd-48b4-96c9-5643140d23ef",
        "first_name_snapshot": "Sam",
        "surname_snapshot": "Player",
        "ability_level": ability_level,
    })

    assert entry["ability_grade"] == grade


def test_knockout_pairings_put_top_entries_into_non_power_of_two_byes():
    entries = [{"id": str(index)} for index in range(1, 7)]
    pairings = tournament_logic._knockout_pairings(entries)
    assert len(pairings) == 4
    assert pairings[0] == (entries[0], None)
    assert pairings[1] == (entries[1], None)
    assert pairings[2:] == [(entries[2], entries[3]), (entries[4], entries[5])]


def test_knockout_pairings_allow_single_entry_grade_as_bye():
    entry = {"id": "1"}
    assert tournament_logic._knockout_pairings([entry]) == [(entry, None)]


def test_seeded_knockout_separates_top_seeds_and_gives_them_byes():
    import random

    entries = [{"id": str(index), "seed": index} for index in range(1, 7)]
    pairings = tournament_logic._seeded_knockout_pairings(entries, random.Random(1))

    seed_pairs = [
        (player1.get("seed") if player1 else None, player2.get("seed") if player2 else None)
        for player1, player2 in pairings
    ]
    assert seed_pairs == [(1, None), (4, 5), (2, None), (3, 6)]
    assert next(index for index, pair in enumerate(seed_pairs) if 1 in pair) // 2 != next(
        index for index, pair in enumerate(seed_pairs) if 2 in pair
    ) // 2


@pytest.mark.parametrize(("entrant_count", "round_count", "matches_per_round"), [(6, 5, 3), (5, 5, 2)])
def test_round_robin_circle_method(entrant_count, round_count, matches_per_round):
    entries = [{"id": str(index)} for index in range(entrant_count)]
    rounds = tournament_logic._round_robin_pairings(entries)
    assert len(rounds) == round_count
    assert all(len(matches) == matches_per_round for matches in rounds)
    pairings = {
        frozenset((player1["id"], player2["id"]))
        for matches in rounds
        for player1, player2 in matches
    }
    assert len(pairings) == entrant_count * (entrant_count - 1) // 2


def test_missing_draw_table_falls_back_to_expected_draw_groups():
    assert [draw["name"] for draw in tournament_logic._default_draw_groups({"graded_enabled": True})] == [
        "Grade A", "Grade B", "Grade C", "Grade D",
    ]
    assert tournament_logic._default_draw_groups({"graded_enabled": False})[0]["name"] == "Open Draw"


def test_short_player_search_returns_without_database_access():
    assert tournament_logic.search_tournament_players(None, 1, "x") == []


def test_graded_tournament_creation_creates_four_draw_groups():
    event_id = "07fd1fc6-4133-4872-b469-112841c49384"
    connection = SingleRowConnection([{
        "id": event_id,
        "organization_id": 1,
        "name": "Club Graded",
        "sport": "squash",
        "draw_format": "knockout",
        "audience": "open",
        "graded_enabled": True,
        "status": "draft",
    }])

    tournament_logic.create_tournament(
        connection,
        1,
        {
            "name": "Club Graded",
            "sport": "squash",
            "draw_format": "knockout",
            "audience": "open",
            "graded_enabled": True,
        },
        "admin@example.com",
    )

    draw_params = [
        params for query, params in connection.statements
        if "INSERT INTO tournament_draws" in query
    ]
    assert [params["grade"] for params in draw_params] == ["A", "B", "C", "D"]
    assert connection.committed is True
