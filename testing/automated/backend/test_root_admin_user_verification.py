from datetime import datetime, timezone

from common import root_admin_logic
from common.root_admin_logic import _serialize_root_admin_user_summary
from common.root_admin_logic import verify_root_admin_user_email


def membership_row(**overrides):
    row = {
        "membership_id": 1,
        "clubusername": "player@example.com",
        "first_name": "Test",
        "surname": "Player",
        "created_at": datetime(2026, 1, 1, tzinfo=timezone.utc),
        "approval_status": "approved",
        "org_type": "personal",
        "plan": "personal_free",
        "interest_request_id": 10,
        "email_validated": True,
    }
    row.update(overrides)
    return row


def test_personal_user_is_unverified_until_email_validation_completes():
    user = _serialize_root_admin_user_summary(
        "player@example.com",
        [membership_row(approval_status="pending", email_validated=False)],
    )

    assert user["email_verified"] is False
    assert user["unverified_membership_count"] == 1


def test_personal_user_is_verified_after_password_link_completion():
    verified_at = datetime(2026, 1, 2, tzinfo=timezone.utc)
    user = _serialize_root_admin_user_summary(
        "player@example.com",
        [membership_row(email_validated_at=verified_at)],
    )

    assert user["email_verified"] is True
    assert user["email_verified_at"] == verified_at.isoformat()
    assert user["unverified_membership_count"] == 0


def test_approved_club_user_without_personal_registration_is_verified():
    user = _serialize_root_admin_user_summary(
        "club-player@example.com",
        [
            membership_row(
                org_type="club",
                plan="club_essentials",
                interest_request_id=None,
                email_validated=None,
            )
        ],
    )

    assert user["email_verified"] is True


def test_user_summary_reports_last_login_and_inactivity_bands(monkeypatch):
    monkeypatch.setattr(
        root_admin_logic,
        "_utcnow",
        lambda: datetime(2026, 11, 6, tzinfo=timezone.utc),
    )
    last_login = datetime(2025, 10, 1, tzinfo=timezone.utc)

    user = _serialize_root_admin_user_summary(
        "club-player@example.com",
        [membership_row(last_login_at=last_login)],
    )

    assert user["last_login_at"] == last_login.isoformat()
    assert user["inactive_12_months"] is True
    assert user["inactive_24_months"] is False


def test_never_logged_in_user_uses_registration_date_for_inactivity(monkeypatch):
    monkeypatch.setattr(
        root_admin_logic,
        "_utcnow",
        lambda: datetime(2026, 11, 6, tzinfo=timezone.utc),
    )

    user = _serialize_root_admin_user_summary(
        "never-logged-in@example.com",
        [membership_row(created_at=datetime(2024, 1, 1, tzinfo=timezone.utc), last_login_at=None)],
    )

    assert user["last_login_at"] is None
    assert user["inactive_12_months"] is True
    assert user["inactive_24_months"] is True


def test_user_summary_exposes_delete_pending_dates():
    requested_at = datetime(2026, 11, 8, tzinfo=timezone.utc)
    purge_after = datetime(2027, 11, 8, tzinfo=timezone.utc)

    user = _serialize_root_admin_user_summary(
        "pending-delete@example.com",
        [membership_row(deletion_requested_at=requested_at, deletion_purge_after=purge_after)],
    )

    assert user["account_status"] == "delete_pending"
    assert user["deletion_requested_at"] == requested_at.isoformat()
    assert user["deletion_purge_after"] == purge_after.isoformat()


class DirectoryCursor:
    def __init__(self, rows):
        self.rows = rows

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, traceback):
        return False

    def execute(self, _statement, _params=None):
        return None

    def fetchall(self):
        return self.rows


class DirectoryConnection:
    def __init__(self, rows):
        self.rows = rows

    def cursor(self):
        return DirectoryCursor(self.rows)


def test_user_directory_counts_and_filters_inactive_users(monkeypatch):
    monkeypatch.setattr(
        root_admin_logic,
        "_utcnow",
        lambda: datetime(2026, 11, 6, tzinfo=timezone.utc),
    )
    old_row = membership_row(
        membership_id=1,
        clubusername="old@example.com",
        created_at=datetime(2023, 1, 1, tzinfo=timezone.utc),
        last_login_at=datetime(2024, 1, 1, tzinfo=timezone.utc),
    )
    recent_row = membership_row(
        membership_id=2,
        clubusername="recent@example.com",
        created_at=datetime(2026, 1, 1, tzinfo=timezone.utc),
        last_login_at=datetime(2026, 10, 1, tzinfo=timezone.utc),
    )

    directory = root_admin_logic.get_root_admin_users(
        DirectoryConnection([old_row, recent_row]),
        account_type="inactive_24_months",
    )

    assert directory["summary"]["inactive_12_month_count"] == 1
    assert directory["summary"]["inactive_24_month_count"] == 1
    assert [user["username"] for user in directory["users"]] == ["old@example.com"]


def test_user_directory_counts_and_filters_delete_pending_users():
    pending_row = membership_row(
        membership_id=3,
        clubusername="pending-delete@example.com",
        deletion_requested_at=datetime(2026, 11, 8, tzinfo=timezone.utc),
        deletion_purge_after=datetime(2027, 11, 8, tzinfo=timezone.utc),
    )
    active_row = membership_row(membership_id=4, clubusername="active@example.com")

    directory = root_admin_logic.get_root_admin_users(
        DirectoryConnection([pending_row, active_row]),
        account_type="delete_pending",
    )

    assert directory["summary"]["delete_pending_count"] == 1
    assert [user["username"] for user in directory["users"]] == ["pending-delete@example.com"]


class VerificationCursor:
    def __init__(self, connection):
        self.connection = connection
        self.rowcount = 0
        self.row = None

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, traceback):
        return False

    def execute(self, statement, params=None):
        self.connection.statements.append((statement, params or {}))
        if "SELECT clubusername" in statement:
            self.row = {"clubusername": "player@example.com"}
            self.rowcount = 1
        elif 'UPDATE "SkwshOrgUsers"' in statement:
            self.row = None
            self.rowcount = 2
        elif 'UPDATE "HitnScoreInterestRequests"' in statement:
            self.row = None
            self.rowcount = 1

    def fetchone(self):
        return self.row


class VerificationConnection:
    def __init__(self):
        self.statements = []
        self.commit_count = 0

    def cursor(self):
        return VerificationCursor(self)

    def commit(self):
        self.commit_count += 1


def test_root_admin_can_manually_verify_email_and_pending_memberships():
    connection = VerificationConnection()

    result = verify_root_admin_user_email(connection, 42, "root@example.com")

    membership_update = next(
        call for call in connection.statements if 'UPDATE "SkwshOrgUsers"' in call[0]
    )
    registration_update = next(
        call for call in connection.statements if 'UPDATE "HitnScoreInterestRequests"' in call[0]
    )
    assert membership_update[1]["username"] == "player@example.com"
    assert registration_update[1]["verified_by"] == "root@example.com"
    assert "use_type = 'personal'" in registration_update[0]
    assert result["verified"] is True
    assert result["approved_memberships"] == 2
    assert result["validated_registrations"] == 1
    assert connection.commit_count == 1
