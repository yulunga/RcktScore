# Config.py
# InitConfig file for Flask Application 
# Seperates appllication setting from the rest of the App

import os
from datetime import timedelta
from dotenv import load_dotenv
import logging

# Load environment variables from .env if available
load_dotenv()


basedir = os.path.abspath(os.path.dirname(__file__))

class Config:
    """
    Main application config:
    - Sets up DB URIs
    - Loads secret key and other environment variables
    """

    SECRET_KEY = os.environ.get('my_precious', 'super_secret_default_key_123')
    # Use environment variable if set, otherwise fallback to local SQLite DB
    #SQLALCHEMY_DATABASE_URI = os.environ.get(
    #'DATABASE_URI',
    #    'sqlite:///' + os.path.join(basedir, 'app/dbSpace/SqPointManDB.db')
    #)

    default_sqlite_path = os.path.join(basedir, 'app', 'dbSpace', 'SqPointManDB.db')
    SQLALCHEMY_DATABASE_URI = os.environ.get('DATABASE_URI', f"sqlite:///{default_sqlite_path}")

    # External Supabase/Postgres DB (for tenant system)
    SUPABASE_DB_URL = os.getenv('SUPABASE_DB_URL')

    SQLALCHEMY_BINDS = {}
    if SUPABASE_DB_URL:
        # Use 'supabase' as the bind key (cleaner naming)
        SQLALCHEMY_BINDS['supabase'] = SUPABASE_DB_URL
        

    SQLALCHEMY_TRACK_MODIFICATIONS = False
    PERMANENT_SESSION_LIFETIME = timedelta(minutes=90)

print(f"[Config] Using database URI: {Config.SQLALCHEMY_DATABASE_URI}")
print(f"[Config] DB file exists: {os.path.exists(Config.default_sqlite_path)}")

# Debug logging to confirm config loaded
logger = logging.getLogger(__name__)
logger.info(f"[Config] Using database URI: {Config.SQLALCHEMY_DATABASE_URI}")
logger.info(f"[Config] DB file exists: {os.path.exists(Config.default_sqlite_path)}")


