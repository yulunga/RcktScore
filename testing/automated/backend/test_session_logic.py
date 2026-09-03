from common.session_logic import (
    login_source_label,
    normalize_login_source,
    session_token_from_event,
)


def test_normalize_login_source_defaults_to_web_app():
    assert normalize_login_source("") == "web_app"
    assert normalize_login_source(None) == "web_app"
    assert normalize_login_source("browser") == "web_app"


def test_normalize_login_source_recognizes_mobile_aliases():
    assert normalize_login_source("mobile") == "mobile_app"
    assert normalize_login_source("ios") == "mobile_app"
    assert normalize_login_source("mobile_app") == "mobile_app"


def test_login_source_label_is_human_readable():
    assert login_source_label("mobile") == "mobile app"
    assert login_source_label("web") == "web app"


def test_session_token_prefers_bearer_authorization_header():
    event = {
        "headers": {
            "Authorization": "Bearer abc123",
            "x-session-token": "fallback-token",
        }
    }

    assert session_token_from_event(event) == "abc123"


def test_session_token_falls_back_to_custom_header():
    event = {
        "headers": {
            "x-session-token": "custom-token",
        }
    }

    assert session_token_from_event(event) == "custom-token"
