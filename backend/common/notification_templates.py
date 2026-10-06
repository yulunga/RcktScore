import html
import os
from pathlib import Path
from string import Template


TEMPLATE_DIRECTORY = Path(__file__).resolve().parent.parent / "notifications" / "templates"
DEFAULT_EMAIL_LOGO_URL = "https://www.hitnscore.com/assets/images/brand-logo.png"


def render_notification_template(template_name, context):
    template_path = TEMPLATE_DIRECTORY / template_name
    template = Template(template_path.read_text(encoding="utf-8"))
    return template.safe_substitute(context)


def _escape(value):
    return html.escape(str(value or ""), quote=True)


def render_branded_email(
    *,
    title,
    greeting="Hi there,",
    paragraphs=None,
    action_label=None,
    action_url=None,
    detail_rows=None,
    notice=None,
    message=None,
):
    """Render the shared, email-client-safe HitnScore HTML presentation."""
    logo_url = (os.getenv("EMAIL_LOGO_URL") or DEFAULT_EMAIL_LOGO_URL).strip()
    paragraph_html = "".join(
        f'<p style="margin:0 0 18px;color:#475569;font-size:17px;line-height:1.65;">{_escape(paragraph)}</p>'
        for paragraph in (paragraphs or [])
        if paragraph
    )

    action_html = ""
    if action_label and action_url:
        action_html = f"""
          <table role="presentation" cellspacing="0" cellpadding="0" style="margin:10px auto 23px;">
            <tr>
              <td align="center" bgcolor="#1274d0" style="border-radius:999px;">
                <a href="{_escape(action_url)}" style="display:inline-block;padding:15px 30px;border-radius:999px;color:#ffffff;text-decoration:none;font-size:16px;font-weight:700;">{_escape(action_label)}</a>
              </td>
            </tr>
          </table>
        """

    details_html = ""
    if detail_rows:
        rows = "".join(
            f"""
              <tr>
                <td valign="top" style="padding:8px 10px;color:#64748b;font-size:14px;font-weight:700;white-space:nowrap;">{_escape(label)}</td>
                <td valign="top" style="padding:8px 10px;color:#1e293b;font-size:14px;word-break:break-word;">{_escape(value)}</td>
              </tr>
            """
            for label, value in detail_rows
        )
        details_html = f"""
          <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="margin:8px 0 24px;background:#f8fafc;border:1px solid #e2e8f0;border-radius:14px;text-align:left;">
            {rows}
          </table>
        """

    message_html = ""
    if message:
        message_html = f"""
          <div style="margin:8px 0 24px;padding:18px 20px;background:#f8fafc;border:1px solid #e2e8f0;border-radius:14px;color:#1e293b;font-size:15px;line-height:1.6;text-align:left;white-space:pre-wrap;word-break:break-word;">{_escape(message)}</div>
        """

    notice_html = ""
    if notice:
        notice_html = f"""
          <table role="presentation" width="100%" cellspacing="0" cellpadding="0">
            <tr><td style="padding-top:25px;border-top:1px solid #e8edf4;color:#64748b;font-size:14px;line-height:1.6;text-align:center;">{_escape(notice)}</td></tr>
          </table>
        """

    return f"""<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <title>{_escape(title)}</title>
  </head>
  <body style="margin:0;padding:0;background:#f5f7fb;font-family:Arial,Helvetica,sans-serif;color:#111827;">
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="width:100%;background:#f5f7fb;">
      <tr>
        <td align="center" style="padding:32px 16px;">
          <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="width:100%;max-width:640px;background:#ffffff;border:1px solid #e5e7eb;border-radius:16px;">
            <tr>
              <td align="center" style="padding:52px 38px 44px;text-align:center;">
                <img src="{_escape(logo_url)}" width="86" height="86" alt="HitnScore" style="display:block;width:86px;height:86px;margin:0 auto;object-fit:contain;border:0;">
                <div style="margin-top:8px;color:#1274d0;font-size:28px;font-weight:800;letter-spacing:-0.8px;">Hit<span style="color:#ec5ea8;">n</span>Score</div>
                <h1 style="margin:34px 0 20px;color:#111827;font-size:31px;line-height:1.2;letter-spacing:-0.6px;">{_escape(title)}</h1>
                <p style="margin:0 0 18px;color:#475569;font-size:17px;line-height:1.65;">{_escape(greeting)}</p>
                {paragraph_html}
                {action_html}
                {details_html}
                {message_html}
                {notice_html}
                <div style="margin-top:30px;color:#94a3b8;font-size:13px;line-height:1.6;">The HitnScore Team<br><a href="https://www.hitnscore.com" style="color:#1274d0;text-decoration:none;">www.hitnscore.com</a></div>
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>"""
