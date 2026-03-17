# /routes/game_routes.py
#
import logging
from flask import Blueprint, render_template, request, redirect, url_for, abort, flash, jsonify, current_app
from app.models.models import SQGAMESPLAY # Import the model
from extensions import dbSQLite # Import the database instance
from flask_login import login_required, current_user
from app.routes.auth import role_required
from app.models.models import User, Court, get_users_by_organization, get_organization_settings, update_organization_settings, get_engine
from app.models.models import add_court, delete_court, get_court_by_id, update_court, get_courts_by_organization, update_court_field
from app.models.match_logger import log_match_event
from werkzeug.security import generate_password_hash
from sqlalchemy import text

logger = logging.getLogger(__name__)
settings_bp = Blueprint('settings', __name__)

@settings_bp.route('/', methods=['GET'])
@login_required
@role_required('admin')  # or 'root' depending on your intention
def settings_home():
    users = get_users_by_organization(current_user.organization_id)
    return render_template('settings.html', users=users)



# --- User Management ---

"""
@settings_bp.route('/users')
@login_required
@role_required(['admin', 'root'])
def settings_user_manager():
    users = get_users_by_organization(current_user.organization_id)
    return render_template('settings_club_users.html', users=users)
"""

@settings_bp.route('/users', methods=['GET'])
@login_required
@role_required(['admin', 'root'])
def settings_user_manager():
    org_id = current_user.organization_id
    users = get_users_by_organization(org_id)
    return render_template('settings_club_users.html', users=users)

"""
@settings_bp.route('/settings/add-user', methods=['POST'])
def add_user():
    username = request.form.get('username')
    role = request.form.get('role', 'user')
    if username:
        new_user = User(username=username, role=role)
        dbSQLite.session.add(new_user)
        dbSQLite.session.commit()
        flash(f"User '{username}' added successfully.")
    return redirect(url_for('settings.settings_home'))
"""

@settings_bp.route('/settings/users/add', methods=['POST'])
@login_required
@role_required(['admin', 'root'])
def add_user():
    username = request.form.get('username')
    password = request.form.get('password')
    role = request.form.get('role')
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
            "org_id": current_user.organization_id
        })

    flash(f"✅ User '{username}' added.")
    return redirect(url_for('settings.settings_club_users'))


@settings_bp.route('/settings/users/<int:user_id>/delete')
@login_required
@role_required(['admin', 'root'])
def delete_user(user_id):
    query = text("DELETE FROM \"SkwshOrgUsers\" WHERE id = :user_id AND organization_id = :org_id")
    with get_engine().connect() as conn:
        conn.execute(query, {
            "user_id": user_id,
            "org_id": current_user.organization_id
        })

    flash("🗑️ User deleted.")
    return redirect(url_for('settings.settings_club_users'))


@settings_bp.route('/edit-user/<int:user_id>', methods=['GET', 'POST'])
@login_required
@role_required(['admin', 'root'])
def edit_user(user_id):
    if request.method == 'POST':
        new_role = request.form.get('role')
        query = text("UPDATE \"SkwshOrgUsers\" SET role = :role WHERE id = :user_id")
        with get_engine().connect() as conn:
            conn.execute(query, {"role": new_role, "user_id": user_id})
        flash("✅ User role updated.")
        return redirect(url_for('settings.settings_user_manager'))

    # Fetch user data
    query = text("SELECT id, clubusername, role FROM \"SkwshOrgUsers\" WHERE id = :user_id")
    with get_engine().connect() as conn:
        user = conn.execute(query, {"user_id": user_id}).mappings().first()
    if not user:
        flash("❌ User not found.")
        return redirect(url_for('settings.settings_user_manager'))

    return render_template('settings_club_users_edit.html', user=user)


@settings_bp.route('/update-role/<int:user_id>', methods=['POST'])
@login_required
@role_required(['admin', 'root'])
def update_user_role(user_id):
    new_role = request.form.get('role')
    if not new_role:
        flash("❌ Role is required.")
        return redirect(url_for('settings.settings_user_manager'))

    query = text("""
        UPDATE "SkwshOrgUsers"
        SET role = :role
        WHERE id = :user_id AND organization_id = :org_id
    """)
    try:
        with get_engine().connect() as conn:
            conn.execute(query, {
                "role": new_role,
                "user_id": user_id,
                "org_id": current_user.organization_id
            })
        flash("✅ User role updated.")
    except Exception as e:
        current_app.logger.exception("Error updating user role")
        flash("❌ Failed to update role.")

    return redirect(url_for('settings.settings_club_users'))


@settings_bp.route('/settings/users/<int:user_id>/reset', methods=['GET', 'POST'])
@login_required
@role_required(['admin', 'root'])
def reset_password(user_id):
    if request.method == 'POST':
        new_password = request.form.get('new_password')
        password_hash = generate_password_hash(new_password)
        query = text("UPDATE \"SkwshOrgUsers\" SET password_hash = :password WHERE id = :user_id")
        with get_engine().connect() as conn:
            conn.execute(query, {"password": password_hash, "user_id": user_id})

        flash("🔐 Password reset.")
        return redirect(url_for('settings.settings_club_users'))

    return render_template('settings_user_reset_password.html', user_id=user_id)

# --- Court Management ---

@settings_bp.route('/courts', methods=['GET'])
@login_required
@role_required(['admin', 'root'])
def settings_courts():
    courts = get_courts_by_organization(current_user.organization_id)
    return render_template('settings_club_courts.html', courts=courts)

@settings_bp.route('/courts/add', methods=['GET', 'POST'])
@login_required
@role_required(['admin', 'root'])
def add_court_route():
    if request.method == 'POST':
        court_name = request.form.get('court_name')
        court_alias = request.form.get('court_alias')
        if add_court(current_user.organization_id, court_name, court_alias):
            flash("✅ Court added successfully")
        else:
            flash("❌ Failed to add court")
        return redirect(url_for('settings.settings_courts'))
    return render_template('settings_club_courts_add.html')


@settings_bp.route('/courts/edit/<int:court_id>', methods=['GET', 'POST'])
@login_required
@role_required(['admin', 'root'])
def edit_court(court_id):
    court = get_court_by_id(court_id)
    if not court:
        flash("❌ Court not found")
        return redirect(url_for('settings.settings_courts'))

    if request.method == 'POST':
        name = request.form.get('court_name')
        alias = request.form.get('court_alias')
        if update_court(court_id, name, alias):
            flash("✅ Court updated")
        else:
            flash("❌ Update failed")
        return redirect(url_for('settings.settings_courts'))

    return render_template('settings_club_courts_edit.html', court=court)


@settings_bp.route('/courts/update/<int:court_id>', methods=['POST'])
@login_required
@role_required(['admin', 'root'])
def update_court(court_id):
    logger.debug(f"[COURT UPDATE] Incoming request for court ID: {court_id}")
    if request.is_json:
        data = request.get_json()
        logger.debug(f"[COURT UPDATE] Received JSON payload: {data}")
        field = data.get("field")
        value = data.get("value")

        if field not in ['court_name', 'court_alias']:
            logger.warning(f"[COURT UPDATE] Invalid field '{field}' received")
            return jsonify(success=False), 400

        logger.info(f"[COURT UPDATE] Updating field '{field}' to '{value}' for court ID {court_id}")
        success = update_court_field(current_user.organization_id, court_id, field, value)

        if success:
            logger.info(f"[COURT UPDATE] Update successful for court ID {court_id}")
        else:
            logger.error(f"[COURT UPDATE] Update failed for court ID {court_id}")
        
        logger.debug(f"[COURT UPDATE] Success value returned: {success}")
        return jsonify(success=success)
    logger.error("[COURT UPDATE] Invalid request type (non-JSON)")

    flash("❌ Invalid request type.")
    return jsonify(success=False), 400

""""
@settings_bp.route('/courts/delete/<int:court_id>', methods=['POST'])
@login_required
@role_required(['admin', 'root'])
def delete_court_record(court_id):
    if delete_court(court_id):
        flash("🗑️ Court deleted")
    else:
        flash("❌ Deletion failed")
    return redirect(url_for('settings.settings_courts'))
"""

@settings_bp.route('/courts/delete/<int:court_id>', methods=['POST'])
@login_required
@role_required(['admin', 'root'])
def delete_court_record(court_id):
    success = delete_court(court_id)
    if request.headers.get('X-Requested-With') == 'XMLHttpRequest':
        return jsonify(success=success)
    flash("✅ Court deleted." if success else "❌ Failed to delete court.")
    return redirect(url_for('settings.settings_courts'))









@settings_bp.route('/club', methods=['GET', 'POST'])
@login_required
@role_required(['admin', 'root'])
def settings_club_details():
    org_id = current_user.organization_id

    if request.method == 'POST':
        data = {
            'organization_name': request.form.get('organization_name'),
            'org_address': request.form.get('org_address'),
            'org_contact': request.form.get('org_contact'),
            'org_telephone': request.form.get('org_telephone'),
            'org_email': request.form.get('org_email'),
            'org_webaddress': request.form.get('org_webaddress')
        }
        update_organization_settings(org_id, data)
        flash("✅ Club details updated successfully")

    # Fetch latest org settings (after possible update)
    org_settings = get_organization_settings(org_id)
    return render_template('settings_club.html', settings=org_settings)
