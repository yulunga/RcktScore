# app/routes/main_routes.py file
from flask import Blueprint, render_template, session, redirect, url_for
from flask_login import login_required, current_user
from app.routes.auth import role_required

# Import authentication model
#from app.routes.auth import login_required  

main_bp = Blueprint('main', __name__)

@main_bp.route('/')
@login_required
def index():
    if current_user.is_root:
        return redirect(url_for('toplevel.root_dashboard'))
    
    # Continue to org user homepage
    return render_template('index.html')

@main_bp.route("/whoami")
@login_required
def whoami():
    return f"Logged in as {current_user.username}, role: {current_user.role}, is_root: {current_user.is_root}"

