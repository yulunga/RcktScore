from flask import Blueprint, render_template
import logging

error_bp = Blueprint('error', __name__)

@error_bp.app_errorhandler(400)
def bad_request(e):
    return render_template('error.html', error_message=e), 400

@error_bp.app_errorhandler(404)
def not_found(e):
    return render_template('error.html', error_message="Page not found"), 404

@error_bp.app_errorhandler(500)
def internal_server_error(e):
    logging.error(f"Server Error: {e}")
    return render_template('error.html', error_message="An unexpected error occurred. Please try again later."), 500