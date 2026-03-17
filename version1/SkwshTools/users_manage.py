# manage_users.py

import click
from app import create_app
from app.models.models import get_engine
from sqlalchemy import text
import os
from dotenv import load_dotenv
from werkzeug.security import generate_password_hash


load_dotenv()
app = create_app()

@click.group()
def cli():
    """Org User Management CLI"""
    pass

@cli.command()
@click.argument('username')
@click.argument('password_hash')
@click.argument('role')
@click.argument('organization_id')
def create_user(username, password_hash, role, organization_id):
    """Create a new user"""
    query = text("""
        INSERT INTO "SkwshOrgUsers" (clubusername, password_hash, role, organization_id)
        VALUES (:username, :password_hash, :role, :org_id)
    """)
    with get_engine().connect() as conn:
        conn.execute(query, {
            "username": username,
            "password_hash": password_hash,
            "role": role,
            "org_id": organization_id
        })
    click.echo(f"✅ User '{username}' created in org {organization_id}")

@cli.command()
@click.argument('organization_id')
def list_users(organization_id):
    """List users by org"""
    query = text("SELECT id, clubusername, role FROM \"SkwshOrgUsers\" WHERE organization_id = :org_id")
    with get_engine().connect() as conn:
        results = conn.execute(query, {"org_id": organization_id}).fetchall()
        for row in results:
            click.echo(f"{row.id}: {row.clubusername} ({row.role})")

@cli.command()
@click.argument('user_id')
@click.option('--role', help='New role')
def update_user(user_id, role):
    """Update a user's role"""
    query = text("UPDATE \"SkwshOrgUsers\" SET role = :role WHERE id = :user_id")
    with get_engine().connect() as conn:
        result = conn.execute(query, {"role": role, "user_id": user_id})
        if result.rowcount == 0:
            click.echo("❌ No user found.")
        else:
            click.echo(f"✅ User {user_id} role updated to {role}")

@cli.command()
@click.argument('user_id')
def delete_user(user_id):
    """Delete a user"""
    query = text("DELETE FROM \"SkwshOrgUsers\" WHERE id = :user_id")
    with get_engine().connect() as conn:
        result = conn.execute(query, {"user_id": user_id})
        if result.rowcount == 0:
            click.echo("❌ No user found.")
        else:
            click.echo(f"🗑️ User {user_id} deleted.")


@cli.command()
@click.argument('user_id')
@click.option('--password', prompt=True, hide_input=True, confirmation_prompt=True, help='New password')
def reset_password(user_id, password):
    """Reset a user's password securely."""
    password_hash = generate_password_hash(password)
    query = text("UPDATE \"SkwshOrgUsers\" SET password_hash = :password_hash WHERE id = :user_id")
    
    with get_engine().connect() as conn:
        result = conn.execute(query, {"password_hash": password_hash, "user_id": user_id})
        if result.rowcount == 0:
            click.echo("❌ No user found.")
        else:
            click.echo(f"🔐 Password updated for user ID {user_id}")



if __name__ == '__main__':
    cli()


