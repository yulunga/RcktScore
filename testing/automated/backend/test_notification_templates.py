from common import mailer
from common.notification_templates import render_branded_email


class RecordingSesClient:
    def __init__(self):
        self.calls = []

    def send_email(self, **kwargs):
        self.calls.append(kwargs)


def test_branded_email_renders_shared_brand_and_action(monkeypatch):
    monkeypatch.setenv("EMAIL_LOGO_URL", "https://static.example.com/logo.png")

    rendered = render_branded_email(
        title="Reset your password",
        paragraphs=["Use the secure link below."],
        action_label="Choose a new password",
        action_url="https://app.example.com/reset?token=abc",
        notice="This link expires in 2 hours.",
    )

    assert "https://static.example.com/logo.png" in rendered
    assert "Hit<span" in rendered
    assert "Reset your password" in rendered
    assert "Choose a new password" in rendered
    assert "https://app.example.com/reset?token=abc" in rendered
    assert "The HitnScore Team" in rendered


def test_branded_email_escapes_user_supplied_values():
    rendered = render_branded_email(
        title="New feedback submission",
        detail_rows=[("Name", '<script>alert("bad")</script>')],
        message='<img src=x onerror="alert(1)">',
    )

    assert "<script>" not in rendered
    assert "<img src=x" not in rendered
    assert "&lt;script&gt;" in rendered
    assert "&lt;img src=x" in rendered


def test_mailer_sends_friendly_source_and_multipart_body(monkeypatch):
    ses_client = RecordingSesClient()
    monkeypatch.setattr(mailer.boto3, "client", lambda *args, **kwargs: ses_client)

    mailer.send_email_message(
        destination_email="player@example.com",
        source_email="hello@hitnscore.com",
        subject="Test email",
        text_body="Plain text",
        html_body="<strong>HTML</strong>",
    )

    sent = ses_client.calls[0]
    assert sent["Source"] == "HitnScore <hello@hitnscore.com>"
    assert sent["Message"]["Body"]["Text"]["Data"] == "Plain text"
    assert sent["Message"]["Body"]["Html"]["Data"] == "<strong>HTML</strong>"
