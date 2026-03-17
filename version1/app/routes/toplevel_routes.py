# app/routes/toplevel_routes.py file
# This route is for administoring the system from the top level - Super-Admin
#
from flask import Blueprint, render_template, session, request, redirect, url_for, flash, abort
# Import authentication model
from flask_login import login_required
from app.routes.auth import root_required, role_required

# Import the Database elements from the model.py 
from app.models.models import get_all_users, get_all_organizations, delete_organization, delete_user
from functools import wraps
import logging


# Import authentication model - old model see above
#from app.routes.auth import login_required 

toplevel_bp = Blueprint('toplevel', __name__)

# Initialize a logger for error/debugging
logger = logging.getLogger(__name__)

@toplevel_bp.route('/root-dashboard')
@login_required
@root_required
#@role_required('root')

def root_dashboard():
    #
    #Root Admin Dashboard:
    #Displays all organizations and users for super-admin management.
    #

    try:
        orgs = get_all_organizations()
        users = get_all_users()
        if orgs is None or users is None:
            flash("Failed to fetch data from Supabase.")
            logger.error("Supabase fetch returned None for organizations or users.")
    except Exception as e:
        logger.exception("Error loading root dashboard data.")
        flash(f"Error loading dashboard: {str(e)}")
        abort(500)
    return render_template('root-dashboard.html', orgs=orgs, users=users)


@toplevel_bp.route('/delete-org/<uuid:org_id>', methods=['POST'])
@login_required
@root_required
def delete_org(org_id):
    try:
        # Add your deletion logic here
        success = delete_organization(str(org_id))
        if success:
            flash('Organization deleted successfully.')
        else:
            flash('Failed to delete organization.')
    except Exception as e:
        logger.exception(f"Error deleting organization {org_id}: {e}")
        flash(f"Error deleting organization: {str(e)}")
    return redirect(url_for('toplevel.root_dashboard'))


@toplevel_bp.route('/delete-user/<uuid:user_id>', methods=['POST'])
@login_required
@root_required
def delete_user_route(user_id):
    try:
        # Add your deletion logic here
        success = delete_user(str(user_id))
        if success:
            flash('User deleted successfully.')
        else:
            flash('Failed to delete user.')
    except Exception as e:
        logger.exception(f"Error deleting user {user_id}: {e}")
        flash(f"Error deleting user: {str(e)}")
    return redirect(url_for('toplevel.root_dashboard'))
