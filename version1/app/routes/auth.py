# app/routes/auth.py file

import logging
from flask import Blueprint, render_template, redirect, url_for, request, session, flash, abort
from flask_login import current_user, login_user, logout_user
from functools import wraps
from app.models.models import get_root_admin, RootUser, AppUser, get_org_user
from werkzeug.security import check_password_hash

logger = logging.getLogger(__name__)
auth_bp = Blueprint('auth', __name__)

# Define login_required decorator
""" def login_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if not session.get('logged_in'):
            flash('You need to be logged in to access this page.')
            return redirect(url_for('auth.login'))
        return f(*args, **kwargs)
    return decorated_function
"""

# Top-Level required decorator
def root_required(f):
    @wraps(f)
    def wrapper(*args, **kwargs):
        if not getattr(current_user, 'is_root', False):
            logger.warning(f"❌ Unauthorized access attempt by {current_user.username}")
            abort(403)
        return f(*args, **kwargs)
    return wrapper
    """
def role_required(required_role):
    def decorator(f):
        @wraps(f)
        def wrapper(*args, **kwargs):
            if not current_user.is_authenticated:
                logger.warning("403 blocked: unauthenticated access to %s", f.__name__)
                abort(403)
            if required_role == 'root' and not current_user.is_root:
                logger.warning("403 blocked: user %s is not root", current_user.username)
                abort(403)
            if required_role != 'root' and current_user.role != required_role:
                logger.warning("403 blocked: user %s does not have role %s (has %s)", current_user.username, required_role, current_user.role)
                abort(403)
            return f(*args, **kwargs)
        return wrapper
    return decorator
    """
def role_required(required_roles):
    """
    A decorator to enforce role-based access control on a Flask route.

    This decorator checks if the current user is authenticated and has the
    required role(s) to access the decorated route. If the user is not
    authenticated or does not have the required role(s), a 403 Forbidden
    error is raised.

    Args:
        required_roles (str or list): The role(s) required to access the route.
            This can be a single role as a string or a list of roles.

    Returns:
        function: The decorated function with role-based access control applied.

    Usage:
        @role_required('admin')
        def admin_dashboard():
            ...

        @role_required(['editor', 'moderator'])
        def edit_content():
            ...
    """
    def decorator(f):
        @wraps(f)
        def wrapper(*args, **kwargs):
            if not current_user.is_authenticated:
                logger.warning("403 blocked: unauthenticated access to %s", f.__name__)
                abort(403)

            user_role = current_user.role
            is_root = getattr(current_user, 'is_root', False)

            # Handle both single role string or list of roles
            if isinstance(required_roles, str):
                allowed_roles = [required_roles]
            else:
                allowed_roles = required_roles

            if 'root' in allowed_roles and is_root:
                return f(*args, **kwargs)  # Allow root access

            if user_role not in allowed_roles:
                logger.warning("403 blocked: user %s does not have role %s (has %s)",
                            current_user.username, allowed_roles, user_role)
                abort(403)

            return f(*args, **kwargs)
        return wrapper
    return decorator


@auth_bp.route('/sulogin', methods=['GET', 'POST'])
def sulogin():
    """
    Special login route for the super-user/root admin.
    This is TEMPORARY for testing purposes.
    """
    error = None
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']

        logger.info(f"Root login attempt for user: {username}")

        # Replace this with your actual root user check logic
        user_data = get_root_admin(username)
        
        if not user_data:
            error = 'Root admin not found.'
            logger.warning(f"Login failed: no root admin '{username}' found.")
        elif not check_password_hash(user_data['password_hash'], password):
            error = 'Invalid password.'
            logger.warning(f"Login failed: invalid password for root admin '{username}'.")
        else:
            root_user = RootUser(id=user_data['id'], username=user_data['rtusername'])
            login_user(root_user)
            logger.info(f"Root admin '{username}' logged in successfully.")
            flash('Root admin logged in successfully.')
            return redirect(url_for('toplevel.root_dashboard'))

        flash(error)
    return render_template('sulogin.html', error=error)


# Your login and logout routes below

@auth_bp.route('/login', methods=['GET', 'POST'])
def login():
    error = None
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']

        logger.info(f"Login attempt for: {username}")

        # 1. Try root admin
        user_data = get_root_admin(username)
        if user_data and check_password_hash(user_data['password_hash'], password):
            logger.debug(f"Matched ROOT user: {user_data['rtusername']}")
            user = AppUser(
                id=user_data['id'], 
                username=user_data['rtusername'], 
                role='root', 
                is_root=True)
            login_user(user)
            session.permanent = True  # ✅ Make session respect PERMANENT_SESSION_LIFETIME
            flash('Logged in as root admin')
            return redirect(url_for('toplevel.root_dashboard'))

        # 2. Try org user
        user_data = get_org_user(username)
        if user_data and check_password_hash(user_data['password_hash'], password):
            logger.debug(f"Matched ORG user: {user_data['clubusername']}")
            user = AppUser(
                id=user_data['id'],
                username=user_data['clubusername'],
                role=user_data['role'],  # 'admin', 'scorer', etc.
                is_root=False,
                organization_id=user_data['organization_id']
            )
            login_user(user)
            session.permanent = True  # ✅ Make session respect PERMANENT_SESSION_LIFETIME
            flash('Logged in as organization user')
            return redirect(url_for('main.index'))  # Or redirect based on role

        error = 'Invalid credentials'
        flash(error)

    return render_template('login.html', error=error)











@auth_bp.route('/logout')
def logout():
    logout_user()
    flash('You were logged out.')
    return redirect(url_for('auth.login'))