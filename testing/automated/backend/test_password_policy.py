import pytest

from common.password_policy import validate_password


def test_password_policy_accepts_a_strong_password():
    assert validate_password("CourtSide7!") == "CourtSide7!"


@pytest.mark.parametrize(
    ("password", "message"),
    [
        ("Short1!", "at least 8"),
        ("lowercase7!", "uppercase"),
        ("NoNumber!", "number"),
        ("NoSymbol7", "symbol"),
        ("Password7!", "common or easily guessed"),
        ("HitnScore7!", "common or easily guessed"),
    ],
)
def test_password_policy_rejects_weak_passwords(password, message):
    with pytest.raises(ValueError, match=message):
        validate_password(password)
