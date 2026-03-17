# app/__init__.py file
#
import os
import logging
from app.log_config import setup_logging
from flask import Flask, request, session
from extensions import dbSQLite  # Import your db instance
from dotenv import load_dotenv
from flask_login import LoginManager, current_user
from datetime import timedelta
from app.models.models import AppUser, RootUser, get_root_admin, get_root_admin_by_id, get_org_user_by_id

# Explicitly point to the .env path
basedir = os.path.abspath(os.path.dirname(__file__))  # /path/to/app/
env_path = os.path.join(basedir, '..', '.env')        # goes one level up to find .env
load_dotenv(env_path)

login_manager = LoginManager()
login_manager.login_view = 'auth.login'
logger = logging.getLogger(__name__)



def create_app():
    app = Flask(__name__)
    app.config.from_object('config.Config')
    os.makedirs('app/temp_matches', exist_ok=True)

    # Logging function from log_config.py for standardisation
    setup_logging(app)
    
    # Initialize database with app
    dbSQLite.init_app(app)

    app.config['PERMANENT_SESSION_LIFETIME'] = timedelta(minutes=5)
    app.config['SESSION_PERMANENT'] = True

    login_manager = LoginManager()
    login_manager.login_view = 'auth.login'  # Replace with your actual login route
    login_manager.init_app(app)

    @app.before_request
    def extend_session():
        if current_user.is_authenticated:
            session.modified = True  # Resets session timer on activity

    @login_manager.user_loader
    def load_user(user_key):
        logger.debug(f"Flask-Login loading user from session: {user_key}")
        try:
            prefix, user_id = user_key.split(":")        
            if prefix == "root":
                user_data = get_root_admin_by_id(user_id)
                if user_data:
                    logger.debug(f"[LOAD ROOT] {user_data['rtusername']}")
                    return AppUser(
                        id=user_data['id'],
                        username=user_data['rtusername'],
                        role='root',
                        is_root=True
                    )
            elif prefix == "org":
                user_data = get_org_user_by_id(user_id)
                if user_data:
                    logger.debug(f"[LOAD ORG] {user_data['clubusername']}")
                    return AppUser(
                        id=user_data['id'],
                        username=user_data['clubusername'],
                        role=user_data['role'],
                        is_root=False,
                        organization_id=user_data['organization_id']
                    )

            logger.warning(f"[LoginManager] No user found for {user_key}")
            return None

        except Exception as e:
            logger.exception(f"[LoginManager] Failed to load user: {user_key}")
            return None

    login_manager.init_app(app)
    
    # Import Blueprints
    from app.routes import main_bp, toplevel_bp, score_bp, auth_bp, game_bp, settings_bp
    from app.routes.updateServer import updateServer_bp

    # Register blueprints
    app.register_blueprint(toplevel_bp)
    app.register_blueprint(main_bp)
    app.register_blueprint(auth_bp)
    app.register_blueprint(score_bp, url_prefix='/score')
    app.register_blueprint(game_bp, url_prefix='/game')
    app.register_blueprint(updateServer_bp)
    app.register_blueprint(settings_bp, url_prefix='/settings')

    return app