from flask import Blueprint, render_template, request, redirect, url_for

score_bp = Blueprint('score', __name__)

@score_bp.route('/update', methods=['POST'])
def update_score():
    # Handle score update logic
    # Example: get data from form
    player = request.form.get('player')
    action = request.form.get('action')
    print(f"Player: {player}, Action: {action}")  # Placeholder
    return redirect(url_for('main.home'))