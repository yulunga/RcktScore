import ast
from pathlib import Path


BACKEND_DIR = Path(__file__).resolve().parents[3] / "backend"
PUBLIC_ROOT_ADMIN_HANDLERS = {"root_admin_login", "root_admin_logout"}


def test_every_privileged_root_admin_handler_requires_a_session():
    unprotected_handlers = []

    for handler_path in sorted((BACKEND_DIR / "functions").glob("*root_admin*/handler.py")):
        if handler_path.parent.name in PUBLIC_ROOT_ADMIN_HANDLERS:
            continue

        syntax_tree = ast.parse(handler_path.read_text())
        called_functions = {
            node.func.id
            for node in ast.walk(syntax_tree)
            if isinstance(node, ast.Call) and isinstance(node.func, ast.Name)
        }
        if "require_root_admin_session" not in called_functions:
            unprotected_handlers.append(handler_path.parent.name)

    assert unprotected_handlers == []


def test_removed_root_admin_trust_header_is_not_used_by_active_code():
    active_files = [
        *BACKEND_DIR.glob("common/*.py"),
        *BACKEND_DIR.glob("functions/*/handler.py"),
        BACKEND_DIR / "template.yaml",
        BACKEND_DIR.parent / "frontend/src/services/api.js",
    ]

    offenders = [
        str(path.relative_to(BACKEND_DIR.parent))
        for path in active_files
        if "x-root-admin-request" in path.read_text()
    ]

    assert offenders == []
