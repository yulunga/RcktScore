from common.organization_logic import approve_organization_user_membership
from common.supabase_client import get_db_connection
from common.utils import html_response
import os


def _render_page(*, title, heading, message, redirect_url=None, redirect_delay_ms=3000):
    escaped_redirect_url = (redirect_url or "").replace("&", "&amp;").replace("\"", "&quot;")
    redirect_meta = (
        f'<meta http-equiv="refresh" content="{max(1, int(redirect_delay_ms / 1000))};url={escaped_redirect_url}" />'
        if redirect_url
        else ""
    )
    redirect_script = (
        f"""
      <script>
        window.setTimeout(function () {{
          window.location.replace("{escaped_redirect_url}");
        }}, {int(redirect_delay_ms)});
      </script>
"""
        if redirect_url
        else ""
    )
    redirect_hint = (
        f'<p class="redirect-note">Redirecting to sign in in 3 seconds. <a href="{escaped_redirect_url}">Continue now</a>.</p>'
        if redirect_url
        else ""
    )
    return f"""<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    {redirect_meta}
    <title>{title}</title>
    <style>
      body {{
        margin: 0;
        min-height: 100vh;
        font-family: "Avenir Next", "Segoe UI", sans-serif;
        background: linear-gradient(180deg, #f7fafc 0%, #edf2f7 100%);
        color: #102a43;
        display: grid;
        place-items: center;
        padding: 24px;
      }}
      .card {{
        width: min(100%, 520px);
        background: rgba(255, 255, 255, 0.96);
        border: 1px solid rgba(16, 42, 67, 0.08);
        border-radius: 24px;
        box-shadow: 0 20px 50px rgba(16, 42, 67, 0.08);
        padding: 28px;
      }}
      h1 {{
        margin: 0 0 12px;
        font-size: 2rem;
      }}
      p {{
        margin: 0;
        font-size: 1rem;
        line-height: 1.5;
        color: #486581;
      }}
      .redirect-note {{
        margin-top: 14px;
        font-size: 0.95rem;
      }}
      .redirect-note a {{
        color: #1f7ae0;
        text-decoration: none;
        font-weight: 600;
      }}
    </style>
    {redirect_script}
  </head>
  <body>
    <section class="card">
      <h1>{heading}</h1>
      <p>{message}</p>
      {redirect_hint}
    </section>
  </body>
</html>
"""


def _login_redirect_url():
    return (os.getenv("USER_APPROVAL_LOGIN_URL") or "").strip() or None


def lambda_handler(event, context):
    token = ((event.get("queryStringParameters") or {}).get("token") or "").strip()
    if not token:
        return html_response(
            400,
            _render_page(
                title="Hit n Score",
                heading="Approval link invalid",
                message="This approval link is missing a token. Please use the full link from your email.",
            ),
        )

    with get_db_connection() as connection:
        approval_result = approve_organization_user_membership(connection, token)

    if not approval_result:
        return html_response(
            404,
            _render_page(
                title="Hit n Score",
                heading="Approval link invalid",
                message="This organisation approval link is no longer valid.",
            ),
        )

    if approval_result["result"] == "already_approved":
        return html_response(
            200,
            _render_page(
                title="Hit n Score",
                heading="Already approved",
                message=(
                    f"{approval_result['username']} already has approved access to "
                    f"{approval_result['organization_name']}."
                ),
            ),
        )

    return html_response(
        200,
        _render_page(
            title="Hit n Score",
            heading="Access approved",
            message=(
                f"{approval_result['username']} is now approved for "
                f"{approval_result['organization_name']}. You can now sign in."
            ),
            redirect_url=_login_redirect_url(),
        ),
    )
