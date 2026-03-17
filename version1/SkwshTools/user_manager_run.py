# run_manage_users.py

import sys
import os
# Add the parent directory (project root) to sys.path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from werkzeug.security import generate_password_hash
from app import create_app
from app.models.models import get_engine
from sqlalchemy import text
from dotenv import load_dotenv

load_dotenv()
create_app()

def create_user():
    username = input("Enter username: ").strip()
    password = input("Enter password: ").strip()
    role = input("Enter role (admin/scorer/read-only): ").strip()
    org_id = input("Enter organization ID: ").strip()
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
    print(f"✅ User '{username}' created.")

def list_users():
    org_id = input("Enter organization ID: ").strip()
    query = text("SELECT id, clubusername, role FROM \"SkwshOrgUsers\" WHERE organization_id = :org_id")
    with get_engine().connect() as conn:
        results = conn.execute(query, {"org_id": org_id}).fetchall()
        for row in results:
            print(f"{row.id}: {row.clubusername} ({row.role})")

def update_user():
    user_id = input("Enter user ID: ").strip()
    new_role = input("Enter new role: ").strip()
    query = text("UPDATE \"SkwshOrgUsers\" SET role = :role WHERE id = :user_id")
    with get_engine().connect() as conn:
        result = conn.execute(query, {"role": new_role, "user_id": user_id})
        if result.rowcount == 0:
            print("❌ No user found.")
        else:
            print(f"✅ User {user_id} role updated to {new_role}")

def reset_password():
    user_id = input("Enter user ID: ").strip()
    password = input("Enter new password: ").strip()
    confirm = input("Confirm password: ").strip()
    if password != confirm:
        print("❌ Passwords do not match.")
        return
    password_hash = generate_password_hash(password)
    query = text("UPDATE \"SkwshOrgUsers\" SET password_hash = :password_hash WHERE id = :user_id")
    with get_engine().connect() as conn:
        result = conn.execute(query, {"password_hash": password_hash, "user_id": user_id})
        if result.rowcount == 0:
            print("❌ No user found.")
        else:
            print(f"🔐 Password updated for user {user_id}")

def delete_user():
    user_id = input("Enter user ID to delete: ").strip()
    confirm = input(f"Type YES to confirm deletion of user ID {user_id}: ").strip()
    if confirm != "YES":
        print("❌ Deletion aborted.")
        return
    query = text("DELETE FROM \"SkwshOrgUsers\" WHERE id = :user_id")
    with get_engine().connect() as conn:
        result = conn.execute(query, {"user_id": user_id})
        if result.rowcount == 0:
            print("❌ No user found.")
        else:
            print(f"🗑️ User {user_id} deleted.")

def menu():
    while True:
        print("\n===== Org User Management Menu =====")
        print("1. Create User")
        print("2. List Users")
        print("3. Update User Role")
        print("4. Reset Password")
        print("5. Delete User")
        print("6. Exit")

        choice = input("Select an option: ").strip()

        if choice == "1":
            create_user()
        elif choice == "2":
            list_users()
        elif choice == "3":
            update_user()
        elif choice == "4":
            reset_password()
        elif choice == "5":
            delete_user()
        elif choice == "6":
            print("Goodbye 👋")
            break
        else:
            print("❌ Invalid option. Try again.")

if __name__ == "__main__":
    menu()
