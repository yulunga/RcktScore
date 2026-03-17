# cli_users.py

import typer
from werkzeug.security import generate_password_hash
from sqlalchemy import text
from app import create_app
from app.models.models import get_engine
from dotenv import load_dotenv
import os

load_dotenv()
create_app()
app = typer.Typer()

@app.command()
def create_user(username: str, password: str, role: str, org_id: int):
    """Create a new user in an organization."""
    password_hash = generate_password_hash(password)
    query = text("""
        INSERT INTO "SkwshOrgUsers" (clubusername, password_hash, role, organization_id)
        VALUES (:username, :password_hash, :role, :org_id)
    """)
    with get_engine().connect() as conn:
        conn.execute(query, {
            "username": username,
            "password_hash": password_hash,
            "role": role,
            "org_id": org_id
        })
    typer.echo(f"✅ Created user '{username}' in org {org_id}")

@app.command()
def list_users(org_id: int):
    """List users in an organization."""
    query = text("SELECT id, clubusername, role FROM \"SkwshOrgUsers\" WHERE organization_id = :org_id")
    with get_engine().connect() as conn:
        results = conn.execute(query, {"org_id": org_id}).fetchall()
        for row in results:
            typer.echo(f"{row.id}: {row.clubusername} ({row.role})")

@app.command()
def update_user(user_id: int, role: str):
    """Update a user's role."""
    query = text("UPDATE \"SkwshOrgUsers\" SET role = :role WHERE id = :user_id")
    with get_engine().connect() as conn:
        result = conn.execute(query, {"role": role, "user_id": user_id})
        if result.rowcount == 0:
            typer.echo("❌ No user found.")
        else:
            typer.echo(f"✅ Updated user {user_id} role to {role}")

@app.command()
def reset_password(user_id: int, password: str):
    """Reset a user's password."""
    password_hash = generate_password_hash(password)
    query = text("UPDATE \"SkwshOrgUsers\" SET password_hash = :password_hash WHERE id = :user_id")
    with get_engine().connect() as conn:
        result = conn.execute(query, {"password_hash": password_hash, "user_id": user_id})
        if result.rowcount == 0:
            typer.echo("❌ No user found.")
        else:
            typer.echo(f"🔐 Password reset for user {user_id}")

@app.command()
def delete_user(user_id: int):
    """Delete a user."""
    query = text("DELETE FROM \"SkwshOrgUsers\" WHERE id = :user_id")
    with get_engine().connect() as conn:
        result = conn.execute(query, {"user_id": user_id})
        if result.rowcount == 0:
            typer.echo("❌ No user found.")
        else:
            typer.echo(f"🗑️ Deleted user {user_id}")

if __name__ == "__main__":
    app()
