from werkzeug.security import generate_password_hash

from common import organization_logic


class InsertCursor:
    def __init__(self, statements):
        self.statements = statements

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, traceback):
        return False

    def execute(self, statement, params=None):
        self.statements.append((" ".join(statement.split()), params or {}))

    def fetchone(self):
        return {
            "id": 44,
            "clubusername": "player@example.com",
            "role": "scorer",
            "approval_status": "pending",
            "first_name": "Pat",
            "surname": "Player",
            "created_at": None,
            "invitation_sent_at": None,
            "approved_at": None,
        }


class InsertConnection:
    def __init__(self):
        self.statements = []
        self.commits = 0

    def cursor(self):
        return InsertCursor(self.statements)

    def commit(self):
        self.commits += 1


def test_new_club_user_also_gets_personal_free_setup_membership(monkeypatch):
    connection = InsertConnection()
    ensured = []
    monkeypatch.setattr(organization_logic, "get_existing_org_users_by_username", lambda *_args: [])
    monkeypatch.setattr(organization_logic, "_get_organization_name", lambda *_args: "Example Club")
    monkeypatch.setattr(
        organization_logic,
        "ensure_personal_account_for_identity",
        lambda *args, **kwargs: ensured.append((args, kwargs)),
    )
    monkeypatch.setattr(
        organization_logic,
        "get_organization_user",
        lambda _connection, organization_id, user_id: {"id": user_id, "organization_id": organization_id},
    )

    user = organization_logic.create_organization_user(
        connection,
        12,
        "player@example.com",
        None,
        "scorer",
        "Pat",
        "Player",
        approval_base_url="https://app.hitnscore.com",
    )

    assert user == {"id": 44, "organization_id": 12}
    assert len(ensured) == 1
    _args, ensure_kwargs = ensured[0]
    assert ensure_kwargs["approval_status"] == "pending"
    assert ensure_kwargs["password_reset_token"].startswith("setup_")
    club_insert_params = next(params for statement, params in connection.statements if 'INSERT INTO "SkwshOrgUsers"' in statement)
    assert club_insert_params["password_reset_token"] == ensure_kwargs["password_reset_token"]


def test_existing_club_identity_gets_approved_personal_free_membership(monkeypatch):
    connection = InsertConnection()
    password_hash = generate_password_hash("Copper!Falcon9")
    ensured = []
    monkeypatch.setattr(
        organization_logic,
        "get_existing_org_users_by_username",
        lambda *_args: [
            {"id": 8, "organization_id": 5, "password_hash": password_hash, "approval_status": "approved"}
        ],
    )
    monkeypatch.setattr(organization_logic, "_get_organization_name", lambda *_args: "Second Club")
    monkeypatch.setattr(
        organization_logic,
        "ensure_personal_account_for_identity",
        lambda *args, **kwargs: ensured.append(kwargs),
    )
    monkeypatch.setattr(
        organization_logic,
        "get_organization_user",
        lambda _connection, organization_id, user_id: {"id": user_id, "organization_id": organization_id},
    )

    organization_logic.create_organization_user(
        connection,
        12,
        "player@example.com",
        None,
        "read_only",
        approval_base_url="https://app.hitnscore.com",
    )

    assert ensured[0]["password_hash"] == password_hash
    assert ensured[0]["approval_status"] == "approved"
    assert ensured[0]["password_reset_token"] is None
