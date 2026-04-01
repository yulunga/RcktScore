from pathlib import Path
from string import Template


TEMPLATE_DIRECTORY = Path(__file__).resolve().parent.parent / "notifications" / "templates"


def render_notification_template(template_name, context):
    template_path = TEMPLATE_DIRECTORY / template_name
    template = Template(template_path.read_text(encoding="utf-8"))
    return template.safe_substitute(context)
