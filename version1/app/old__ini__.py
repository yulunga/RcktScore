# app/__init__.py 

# Import the Flask Class
from flask import Flask

# Import the Config from config.py
from config import Config

# Import the extensions from extensions.py
from extensions import dbSQLite

from flask_sqlalchemy import SQLAlchemy
from datetime import timedelta

import os

# Initialize SQLAlchemy through an extension file
from extensions import dbSQLite 


"""def create_app():
    ""Create a Flask application.""
    app = Flask(__name__)
    
    # Base Directory 
    basedir = os.path.abspath(os.path.dirname(__file__))
"""
    

def create_app(config_class=Config):
    app = Flask(__name__)
    app.config.from_object(config_class)

    dbSQLite.init_app(app)

    # Register all blueprints
    from app.routes import register_blueprints
    register_blueprints(app)

    return app