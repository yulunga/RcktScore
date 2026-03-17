from flask import Flask
from flask_sqlalchemy import SQLAlchemy
from datetime import timedelta
from config import Config
import os

# Initialize SQLAlchemy through an extension file
from extensions import dbSQLite 

print(f"Current working directory: {os.getcwd()}")

def create_app():
    """Create a Flask application."""
    app = Flask(__name__)
    
    # Base Directory 
    basedir = os.path.abspath(os.path.dirname(__file__))
    
    # DB connection details
    app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///' + os.path.join(basedir, 'dbSpace/SqPointManDB.db')
    app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
    
    # Session secret and lifespan 
    app.secret_key = "my_precious"
    app.permanent_session_lifetime = timedelta(minutes=90)
    
    # Initialize SQLAlchemy with the app
    dbSQLite.init_app(app)
    
    # Import and register blueprints
    from app.routes.home import home_bp
    #from models.auth import auth_bp
    #from routes.error import error_bp
    #from routes.game import game_bp
    #from routes.updateServer import updateServer_bp

    app.register_blueprint(home_bp)
    #app.register_blueprint(auth_bp, url_prefix='/auth')
    #app.register_blueprint(game_bp, url_prefix='/game')
    #app.register_blueprint(error_bp)
    #app.register_blueprint(updateServer_bp)

    return app

application = create_app()

# Only run the app if this script is executed directly
if __name__ == '__main__':
    application.run(debug=True)