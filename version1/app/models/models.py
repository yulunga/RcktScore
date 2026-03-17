# models/models.py
"""
models.py

- Defines SQLAlchemy models for local SQLite tables (e.g., SQGAMESPLAY)
- Provides helper functions to connect to Supabase/Postgres via SQLAlchemy
- Uses lazy-loaded `get_engine()` to avoid .env timing issues during WSGI startup

This module contains:

1. Local SQLAlchemy ORM models for SQLite (e.g., SQGAMESPLAY, User, Court).
2. A Flask-Login-compatible RootUser class for authenticating root admins.
3. Supabase/Postgres helper functions using raw SQL (via SQLAlchemy engine).
4. Lazy-initialized `get_engine()` function to safely connect to Supabase.

Key Features:
- Compatible with both SQLite (local) and Supabase (cloud Postgres).
- Works reliably under WSGI servers like PythonAnywhere by deferring engine creation until first use.
- Caches the engine in `_engine` for performance.
- Includes detailed logging for all DB operations.

Environment Variable:
- Requires `SUPABASE_DB_URL` to be set via .env or environment config.

"""


# from app import dbSQLite
from sqlalchemy import create_engine, text
from sqlalchemy.exc import OperationalError
from extensions import dbSQLite 
from flask_login import UserMixin
import os
import logging

logger = logging.getLogger(__name__)
_engine = None  # Cached engine instance


# Initialize SQLAlchemy engine for Supabase/Postgres
"""
    Lazily creates and caches the Supabase/Postgres SQLAlchemy engine.
    Ensures environment variable is loaded first.
"""
def get_engine():
    global _engine
    if _engine is None:
        SUPABASE_DB_URL = os.getenv('SUPABASE_DB_URL')  # e.g., 'postgresql://user:pass@host:port/dbname'
        if not SUPABASE_DB_URL:
            raise ValueError("SUPABASE_DB_URL is not set. Please check your .env file or environment variables.")
        logger.debug("Creating new SQLAlchemy engine for Supabase")
        _engine = create_engine(SUPABASE_DB_URL)
    return _engine
# Connects to Supabase/Postgres using environment variable SUPABASE_DB_URL.
# Make sure this is loaded early via load_dotenv() in app __init__.py.
#old - remove ----engine = create_engine(SUPABASE_DB_URL)


class SQGAMESPLAY(dbSQLite.Model):
    __tablename__ = "SQGAMESPLAY"
    ID = dbSQLite.Column('ID', dbSQLite.Integer, primary_key=True)
    matchsession = dbSQLite.Column(dbSQLite.String(100))
    PLAYER1_NAME = dbSQLite.Column(dbSQLite.String(100))
    PLAYER1_SURNAME = dbSQLite.Column(dbSQLite.String(100))
    PLAYER1_country = dbSQLite.Column(dbSQLite.String(100))
    PLAYER1_HANDICAP = dbSQLite.Column(dbSQLite.Integer)
    PLAYER2_NAME = dbSQLite.Column(dbSQLite.String(100))
    PLAYER2_SURNAME = dbSQLite.Column(dbSQLite.String(100))
    PLAYER2_COUNTRY = dbSQLite.Column(dbSQLite.String(100))
    PLAYER2_HANDICAP = dbSQLite.Column(dbSQLite.Integer)
    COURT_NAME = dbSQLite.Column(dbSQLite.String(100))
    REFEREE_NAME = dbSQLite.Column(dbSQLite.String(100))
    SCORE_TYPE = dbSQLite.Column(dbSQLite.Integer)

    def __repr__(self):
        return f'<SQGAMESPLAY {self.ID}>'
    

class User(dbSQLite.Model):
    id = dbSQLite.Column(dbSQLite.Integer, primary_key=True)
    username = dbSQLite.Column(dbSQLite.String(80), unique=True, nullable=False)
    role = dbSQLite.Column(dbSQLite.String(10), nullable=False)

class Court(dbSQLite.Model):
    id = dbSQLite.Column(dbSQLite.Integer, primary_key=True)
    name = dbSQLite.Column(dbSQLite.String(50), unique=True, nullable=False)

class RootUser(UserMixin):
    """
    Flask-Login compatible user class for Root Admin.
    """
    def __init__(self, id, username):
        self.id = id
        self.username = username
        self.is_root = True  # Always true for root admin

    def get_id(self):
        return str(self.id)


class AppUser(UserMixin):
    def __init__(self, id, username, role, is_root=False, organization_id=None):
        self.id = id
        self.username = username
        self.role = role
        self.is_root = is_root
        self.organization_id = organization_id

    def get_id(self):
        return f"root:{self.id}" if self.is_root else f"org:{self.id}"
    

# Supabase (Postgres) helper functions using raw SQL

def get_organization_settings(organization_id):
    """
    Fetch organization settings by ID.
    """
    query = text("SELECT * FROM \"SkwshOrgSettings\" WHERE id = :org_id LIMIT 1;")
    try:
        with get_engine().connect() as conn:
            result = conn.execute(query, {"org_id": organization_id}).mappings().first()
            return dict(result) if result else None
    except OperationalError as e:
        logger.exception(f"Database error fetching organization settings for {organization_id}: {e}")
        return None

def get_users_by_organization(organization_id):
    """
    Fetch all users for a specific organization.
    """
    query = text("SELECT * FROM \"SkwshOrgUsers\" WHERE organization_id = :org_id;")
    try:
        with get_engine().connect() as conn:
            result = conn.execute(query, {"org_id": organization_id}).mappings().all()
            return [dict(row) for row in result]
    except OperationalError as e:
        logger.exception(f"Database error fetching users for organization {organization_id}: {e}")
        return []

def get_all_organizations():
    """
    Fetch all organizations.
    """
    query = text("SELECT * FROM \"SkwshOrgSettings\";")
    try:
        with get_engine().connect() as conn:
            result = conn.execute(query).mappings().all()
            return [dict(row) for row in result]
    except OperationalError as e:
        logger.exception("Database error fetching all organizations: %s", e)
        return []

def get_all_users():
    """
    Fetch all users.
    """
    query = text("SELECT * FROM \"SkwshOrgUsers\";")
    try:
        with get_engine().connect() as conn:
            result = conn.execute(query).mappings().all()
            return [dict(row) for row in result]
    except OperationalError as e:
        logger.exception("Database error fetching all users: %s", e)
        return []

def get_org_user_by_id(user_id):
    """
    Fetch organization user by ID.
    """
    query = text("SELECT * FROM \"SkwshOrgUsers\" WHERE id = :id LIMIT 1;")
    logger.debug(f"Fetching ORG user by ID: {user_id}") 
    try:
        with get_engine().connect() as conn:
            result = conn.execute(query, {"id": user_id}).mappings().first()
            return dict(result) if result else None
    except OperationalError as e:
        logger.exception(f"Error fetching org user by ID {user_id}: {e}")
        return None
    
def get_root_admin(username):
    """
    Fetch root admin by username.
    """
    query = text("SELECT * FROM \"SkRootAdmin\" WHERE rtusername = :username LIMIT 1;")
    try:
        with get_engine().connect() as conn:
            result = conn.execute(query, {"username": username}).mappings().first()
            return dict(result) if result else None
    except OperationalError as e:
        logger.exception(f"Error fetching root admin {username}")
        return None

def get_root_admin_by_id(user_id):
    """
    Fetch root admin from SkRootAdmin by ID.
    """
    query = text("SELECT * FROM \"SkRootAdmin\" WHERE id = :id LIMIT 1;")
    logger.debug(f"Fetching ROOT admin by ID: {user_id}") 
    try:
        with get_engine().connect() as conn:
            result = conn.execute(query, {"id": user_id}).mappings().first()
            return dict(result) if result else None
    except OperationalError as e:
        logger.exception(f"Error fetching root admin by ID {user_id}: {e}")
        return None
    
def get_org_user(clubusername):
    query = text("SELECT * FROM \"SkwshOrgUsers\" WHERE clubusername = :username LIMIT 1;")
    try:
        with get_engine().connect() as conn:
            result = conn.execute(query, {"username": clubusername}).mappings().first()
            return dict(result) if result else None
    except OperationalError as e:
        logger.exception(f"Database error fetching org user {clubusername}: {e}")
        return None
    
def delete_organization(org_id):
    """
    Delete an organization and its users from the OrgSettings and OrgUsers tables.
    """
    delete_users_query = text("DELETE FROM \"SkwshOrgUsers\" WHERE organization_id = :org_id;")
    delete_org_query = text("DELETE FROM \"SkwshOrgSettings\" WHERE id = :org_id;")

    try:
        with get_engine().begin() as conn:  # begin() ensures a transaction
            conn.execute(delete_users_query, {"org_id": org_id})
            result = conn.execute(delete_org_query, {"org_id": org_id})
            if result.rowcount == 0:
                logger.warning(f"No organization found to delete with ID {org_id}")
                return False
            logger.info(f"Deleted organization {org_id} and its users.")
            return True
    except OperationalError as e:
        logger.exception(f"Database error deleting organization {org_id}: {e}")
        return False


def delete_user(user_id):
    """
    Delete a user from the OrgUsers table.
    """
    delete_query = text("DELETE FROM \"SkwshOrgUsers\" WHERE id = :user_id;")
    try:
        with get_engine().begin() as conn:
            result = conn.execute(delete_query, {"user_id": user_id})
            if result.rowcount == 0:
                logger.warning(f"No user found to delete with ID {user_id}")
                return False
            logger.info(f"Deleted user {user_id}.")
            return True
    except OperationalError as e:
        logger.exception(f"Database error deleting user {user_id}: {e}")
        return False
    
def get_organization_settings(org_id):
    query = text("SELECT * FROM \"SkwshOrgSettings\" WHERE id = :org_id LIMIT 1;")
    try:
        with get_engine().connect() as conn:
            result = conn.execute(query, {"org_id": org_id}).mappings().first()
            return dict(result) if result else None
    except OperationalError as e:
        logger.exception(f"Error fetching org settings for ID {org_id}: {e}")
        return None
    

def update_organization_settings(org_id, data):
    query = text("""
        UPDATE "SkwshOrgSettings"
        SET organization_name = :organization_name,
            org_address = :org_address,
            org_contact = :org_contact,
            org_telephone = :org_telephone,
            org_email = :org_email,
            org_webaddress = :org_webaddress
        WHERE id = :org_id
    """)
    try:
        with get_engine().connect() as conn:
            conn.execute(query, {**data, "org_id": org_id})
    except OperationalError as e:
        logger.exception(f"Error updating organization settings for ID {org_id}: {e}")


def get_courts_by_organization(org_id):
    query = text("SELECT * FROM \"SkwshCourts\" WHERE organization_name = :org_id ORDER BY court_name ASC")
    try:
        with get_engine().connect() as conn:
            result = conn.execute(query, {"org_id": org_id}).mappings().all()
            return [dict(row) for row in result]
    except OperationalError as e:
        logger.exception(f"Error fetching courts for org {org_id}")
        return []

def add_court(org_id, court_name, court_alias=None):
    query = text("""
        INSERT INTO "SkwshCourts" (court_name, court_alias, organization_name)
        VALUES (:court_name, :court_alias, :org_id)
    """)
    try:
        with get_engine().connect() as conn:
            conn.execute(query, {
                "court_name": court_name,
                "court_alias": court_alias,
                "org_id": org_id
            })
            return True
    except OperationalError as e:
        logger.exception(f"Error adding court '{court_name}' for org {org_id}")
        return False
    
def update_court(court_id, court_name, court_alias):
    query = text("""
        UPDATE "SkwshCourts"
        SET court_name = :court_name, court_alias = :court_alias
        WHERE id = :court_id
    """)
    try:
        with get_engine().connect() as conn:
            result = conn.execute(query, {
                "court_name": court_name,
                "court_alias": court_alias,
                "court_id": court_id
            })
            return result.rowcount > 0
    except OperationalError as e:
        logger.exception(f"Error updating court {court_id}")
        return False

def update_court_field(org_id, court_id, field, value):
    query = text(f'''
        UPDATE "SkwshCourts"
        SET {field} = :value
        WHERE id = :court_id AND organization_name = :org_id
    ''')
    try:
        with get_engine().connect() as conn:
            result = conn.execute(query, {"value": value, "court_id": court_id, "org_id": org_id})
            return result.rowcount > 0
    except Exception as e:
        logger.exception("Court field update failed")
        return False
    

def delete_court(court_id):
    query = text("DELETE FROM \"SkwshCourts\" WHERE id = :court_id")
    try:
        with get_engine().connect() as conn:
            result = conn.execute(query, {"court_id": court_id})
            return result.rowcount > 0
    except OperationalError as e:
        logger.exception(f"Error deleting court {court_id}")
        return False


def get_court_by_id(court_id):
    query = text("SELECT * FROM \"SkwshCourts\" WHERE id = :court_id LIMIT 1")
    try:
        with get_engine().connect() as conn:
            result = conn.execute(query, {"court_id": court_id}).mappings().first()
            return dict(result) if result else None
    except OperationalError as e:
        logger.exception(f"Error fetching court {court_id}")
        return None
