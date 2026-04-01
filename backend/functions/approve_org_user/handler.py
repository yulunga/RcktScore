from common.organization_logic import approve_organization_user_membership
from common.supabase_client import get_db_connection
from common.utils import html_response


def _render_page(*, title, heading, message):
    return f"""<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
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
    </style>
  </head>
  <body>
    <section class="card">
      <h1>{heading}</h1>
      <p>{message}</p>
    </section>
  </body>
</html>
"""


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
        ),
    )
