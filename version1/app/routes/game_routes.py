# /routes/game_routes.py
#
import logging
from flask import Blueprint, render_template, request, redirect, url_for, abort, flash, jsonify, current_app
from flask_login import login_required, current_user
from app.routes.auth import role_required
from app.models.models import SQGAMESPLAY, User, get_engine, get_courts_by_organization # Import the model
from extensions import dbSQLite # Import the database instance
from app.models.match_logger import log_match_event
from pathlib import Path
from sqlalchemy import text

import json
import os

logger = logging.getLogger(__name__)
settings_bp = Blueprint('settings', __name__)

game_bp = Blueprint('game', __name__)

"""
@game_bp.route('/new-game', methods=['GET', 'POST'])
def new_game():
    if request.method == 'POST':
        player1_name = request.form.get('player1_name')
        player2_name = request.form.get('player2_name')
        player1_country = request.form.get('player1_country')
        player2_country = request.form.get('player2_country')
        score_type = request.form.get('score_type')
        referee_name = request.form.get('referee_name')
        court_name = request.form.get('court_name')

        if not player1_name or not player2_name or not score_type or not referee_name:
            abort(400, "Missing required form fields")

        game = SQGAMESPLAY(
            PLAYER1_NAME=player1_name,
            PLAYER2_NAME=player2_name,
            PLAYER1_COUNTRY=player1_country,
            PLAYER2_COUNTRY=player2_country,
            SCORE_TYPE=score_type,
            REFEREE_NAME=referee_name,
            COURT_NAME=court_name
        )
        dbSQLite.session.add(game)
        dbSQLite.session.commit()

        log_match_event(game.ID, "game_created", {
            "player1": player1_name,
            "player2": player2_name,
            "court": court_name,
            "score_type": score_type,
            "referee": referee_name
        })

        flash('New game created successfully!')
        return redirect(url_for('game.matchscore', game_id=game.ID))
    return render_template('new-game.html')
"""


@game_bp.route('/new-game', methods=['GET', 'POST'])
@login_required
@role_required(['admin', 'root'])
def new_game():
    if request.method == 'POST':
        # Extract form data
        player1_name = request.form.get('player1_name')
        player1_surname = request.form.get('player1_surname')
        player2_name = request.form.get('player2_name')
        player2_surname = request.form.get('player2_surname')
        player1_country = request.form.get('player1_country')
        player2_country = request.form.get('player2_country')
        referee_name = request.form.get('referee_name')
        court_name = request.form.get('court_name')
        score_type = request.form.get('score_type', '15')  # Should be numeric
        organization_id = current_user.organization_id

        # SQL & params
        query = text("""
            INSERT INTO "SkwshAmigos"
                (player1_name, player1_surname, player2_name, player2_surname,
                player1_country, player2_country, referee_name, court_name,
                score_type, organization_name)
            VALUES (:player1_name, :player1_surname, :player2_name, :player2_surname,
                    :player1_country, :player2_country, :referee_name, :court_name,
                    :score_type, :organization_name)
            RETURNING id
        """)

        params = {
            "player1_name": player1_name,
            "player1_surname": player1_surname,
            "player2_name": player2_name,
            "player2_surname": player2_surname,
            "player1_country": player1_country,
            "player2_country": player2_country,
            "referee_name": referee_name,
            "court_name": court_name,
            "score_type": int(score_type),
            "organization_name": organization_id  # Match Supabase column name
        }

        # Log input data and SQL
        logger.debug(f"[NEW_GAME] Form data received: {params}")
        logger.debug(f"[NEW_GAME] SQL Query: {query.text}")

        try:
            with get_engine().connect() as conn:
                result = conn.execute(query, params)
                inserted_row = result.fetchone()
                logger.debug(f"[NEW_GAME] DB Result: {inserted_row}")
                if inserted_row and inserted_row['id']:
                    game_id = inserted_row['id']
                    log_match_event(game_id, "game_created", params)
                    logger.info(f"[NEW_GAME] Game {game_id} created successfully")
                    flash("✅ New game created successfully!")
                    return redirect(url_for('game.matchscore', game_id=game_id))
                else:
                    logger.warning("[NEW_GAME] No ID returned from INSERT")
                    flash("❌ Failed to create game", "danger")
        except Exception as e:
            logger.exception(f"[NEW_GAME] Error inserting game: {e}")
            flash(f"❌ Error saving game to database: {e}", "danger")

        return redirect(url_for('game.new_game'))

    # GET request – fetch courts from database
    org_id = current_user.organization_id
    courts = get_courts_by_organization(org_id)
    logger.debug(f"[NEW_GAME] Loaded {len(courts)} courts for org {org_id}")

    return render_template("new-game.html", courts=courts)



#
# /read-games - Get game list to edit games or score games
#
@game_bp.route('/read-games')
def read_games():
    activegames = SQGAMESPLAY.query.all()
    return render_template('read-games.html', activegames=activegames)





@game_bp.route('/matchscore/<int:game_id>/', methods=['GET', 'POST'])
def matchscore(game_id):
    game = SQGAMESPLAY.query.get_or_404(game_id)
    
    filepath = Path(current_app.root_path) / "temp_matches" / f"match_{game_id}.json"
    player1_score = None
    player2_score = None
    point_history = []

    # Always load existing score log first
    if os.path.exists(filepath):
        with open(filepath, 'r') as file:
            data = json.load(file)

            # 1) If the JSON has a "scores" object, trust it:
            scores = data.get('scores', {})
            if 'player1' in scores and 'player2' in scores:
                player1_score = scores.get('player1', 0)
                player2_score = scores.get('player2', 0)

            # 2) Fallback: if scores is still None (or you want history), recompute from events
            if player1_score is None or player2_score is None:
                player1_score = 0
                player2_score = 0
                for ev in data.get('events', []):
                    if ev['event_type'] == 'score':
                        who = ev['data'].get('player')
                        if who == game.PLAYER1_NAME:
                            player1_score += 1
                        elif who == game.PLAYER2_NAME:
                            player2_score += 1
                        point_history.append(f"{who} scored")
                    elif ev['event_type'] in ('let','stroke','undo','serve_side'):
                        detail = ev['data'].get('player') or ev['data'].get('side')
                        point_history.append(f"{ev['event_type'].capitalize()}: {detail}")

#            for event in data.get('events', []):
#                if event['event_type'] == 'score':
#                    scorer = event['data'].get('player')
#                    if scorer == game.PLAYER1_NAME:
#                        player1_score += 1
#                    elif scorer == game.PLAYER2_NAME:
#                        player2_score += 1
#                    point_history.append(f"{scorer} scored")
#                elif event['event_type'] in ['let', 'stroke', 'undo', 'serve_side']:
#                    detail = event.get('data', {}).get('player', '') or event.get('data', {}).get('side', '')
#                    point_history.append(f"{event['event_type'].capitalize()}: {detail}")

    if request.method == 'POST':
        action = request.form.get('action')
        side = request.form.get('side')
        player = request.form.get('player')

        event_data = {
            "player": player,
            "player1": game.PLAYER1_NAME,
            "player2": game.PLAYER2_NAME
        }
        if side:
            event_data["side"] = side

        if action == 'score':
            flash(f"{player} scored a point!")
            current_app.logger.debug(f"[SCORE] Player: {player}")
            log_match_event(game_id, 'score', event_data)

        elif action == 'let':
            flash(f"Let awarded to {player}")
            print(f"[DEBUG] Logging event: {action} for {player or side}")
            log_match_event(game_id, 'let', event_data)

        elif action == 'stroke':
            flash(f"Stroke awarded to {player}")
            log_match_event(game_id, 'stroke', event_data)

        elif action == 'undo':
            flash("Last point undone.")
            log_match_event(game_id, 'undo', event_data)

        elif action == 'serve_side':
            flash(f"Serve side switched to {side}")
            log_match_event(game_id, 'serve_side', {"side": side})

        elif action == 'toggle_timer':
            flash("Timer toggled.")
            log_match_event(game_id, 'toggle_timer')
            
        return redirect(url_for('game.matchscore', game_id=game_id))

    return render_template(
            'matchscore.html',
            game_id=game_id,
            player1_name=game.PLAYER1_NAME,
            player2_name=game.PLAYER2_NAME,
            court_name=game.COURT_NAME,
            player1_score=player1_score,
            player2_score=player2_score,
            serving_player=1,
            serving_side="Right",
            point_history=point_history
)

#
# /matchscore/logs - Logging game play to JSON file based on game_ID
#
@game_bp.route('/matchscore/logs/<int:game_id>')
def get_match_logs(game_id):
    filepath = Path(current_app.root_path) / "temp_matches" / f"match_{game_id}.json"
    current_app.logger.info(f"[LOGS] Looking for logfile in {filepath}")
    try:
        with open(filepath, 'r') as file:
            data = json.load(file)
        current_app.logger.info(f"[LOGS] Successfully loaded match log for game {game_id}")
        return jsonify(data)
    except FileNotFoundError:
        current_app.logger.warning(f"[LOGS] File not found for game {game_id}")
        return jsonify({"match_id": game_id, "events": []})
    except Exception as e:
        current_app.logger.error(f"[LOGS] Unexpected error reading log for game {game_id}: {str(e)}")
        return jsonify({"match_id": game_id, "events": []})
    
    #filepath = f'app/temp_matches/match_{game_id}.json'
    try:
        with open(filepath, 'r') as file:
            data = json.load(file)
        return jsonify(data)
    except FileNotFoundError:
        return jsonify({"match_id": game_id, "events": []})
    
#
# JavaScrip logging for debugging
#
@game_bp.route('/log-js-error', methods=['POST'])
def log_js_error():
    try:
        error_data = request.get_json()
        if error_data:
            current_app.logger.warning(
                "[JS ERROR] {message} | URL: {url} | Stack: {stack}".format(
                    message=error_data.get('message'),
                    url=error_data.get('url'),
                    stack=error_data.get('stack')
                )
            )
            return jsonify({"status": "logged"}), 200
    except Exception as e:
        current_app.logger.error(f"[JS ERROR HANDLER FAILED] {str(e)}")
    return jsonify({"status": "error"}), 500


#
# Used for the scoreboard calls
#
@game_bp.route('/scoreboard/live/<int:game_id>/')
def scoreboardID(game_id):
    # Construct the file path
    filepath = os.path.join('app', 'temp_matches', f'match_{game_id}.json')

    # Initialize default values
    player1_name = "Player 1"
    player2_name = "Player 2"
    player1_score = 0
    player2_score = 0
    serving_player = None
    serving_side = "Right"
    point_history = []

    # Check if the file exists
    if os.path.exists(filepath):
        try:
            with open(filepath, 'r') as file:
                data = json.load(file)

                # Extract player names
                player1_name = data.get('player1_name', player1_name)
                player2_name = data.get('player2_name', player2_name)

                # Extract scores
                scores = data.get('scores', {})
                player1_score = scores.get('player1', player1_score)
                player2_score = scores.get('player2', player2_score)

                # Determine serving player and side if available
                # Assuming the latest 'serve_side' event determines the current serving side
                events = data.get('events', [])
                for event in reversed(events):
                    if event.get('event_type') == 'serve_side':
                        serving_side = event.get('data', {}).get('side', serving_side)
                        break
                for event in reversed(events):
                    if event.get('event_type') == 'score':
                        last_scorer = event.get('data', {}).get('player')
                        if last_scorer == player1_name:
                            serving_player = 1
                        elif last_scorer == player2_name:
                            serving_player = 2
                        break

                # Build point history
                for event in events:
                    event_type = event.get('event_type')
                    data_field = event.get('data', {})
                    if event_type == 'score':
                        scorer = data_field.get('player')
                        point_history.append(f"{scorer} scored")
                    elif event_type in ['let', 'stroke', 'undo', 'serve_side']:
                        detail = data_field.get('player') or data_field.get('side', '')
                        point_history.append(f"{event_type.capitalize()}: {detail}")
        except Exception as e:
            current_app.logger.error(f"Error reading match file for game {game_id}: {e}")
    else:
        current_app.logger.warning(f"Match file not found for game {game_id}")

    return render_template(
        'scoreboard.html',
        game_id=game_id,
        player1_name=player1_name,
        player2_name=player2_name,
        player1_score=player1_score,
        player2_score=player2_score,
        serving_player=serving_player,
        serving_side=serving_side,
        point_history=point_history
    )


#
# Need to check as not been used I think
#
@game_bp.route('/scoreboard')
def scoreboard():
    return render_template('scoreboard1.html')

@game_bp.route('/scoreboardv1/<int:game_id>/')
def scoreboardv1(game_id):
    # Construct the file path
    filepath = os.path.join('app', 'temp_matches', f'match_{game_id}.json')

    # Initialize default values
    player1_name = "Player 1"
    player2_name = "Player 2"
    player1_score = 0
    player2_score = 0
    serving_player = None
    serving_side = "Right"
    point_history = []

    # Check if the file exists
    if os.path.exists(filepath):
        try:
            with open(filepath, 'r') as file:
                data = json.load(file)

                # Extract player names
                player1_name = data.get('player1_name', player1_name)
                player2_name = data.get('player2_name', player2_name)

                # Extract scores
                scores = data.get('scores', {})
                player1_score = scores.get('player1', player1_score)
                player2_score = scores.get('player2', player2_score)

                # Determine serving player and side if available
                # Assuming the latest 'serve_side' event determines the current serving side
                events = data.get('events', [])
                for event in reversed(events):
                    if event.get('event_type') == 'serve_side':
                        serving_side = event.get('data', {}).get('side', serving_side)
                        break
                for event in reversed(events):
                    if event.get('event_type') == 'score':
                        last_scorer = event.get('data', {}).get('player')
                        if last_scorer == player1_name:
                            serving_player = 1
                        elif last_scorer == player2_name:
                            serving_player = 2
                        break

                # Build point history
                for event in events:
                    event_type = event.get('event_type')
                    data_field = event.get('data', {})
                    if event_type == 'score':
                        scorer = data_field.get('player')
                        point_history.append(f"{scorer} scored")
                    elif event_type in ['let', 'stroke', 'undo', 'serve_side']:
                        detail = data_field.get('player') or data_field.get('side', '')
                        point_history.append(f"{event_type.capitalize()}: {detail}")
        except Exception as e:
            current_app.logger.error(f"Error reading match file for game {game_id}: {e}")
    else:
        current_app.logger.warning(f"Match file not found for game {game_id}")

    return render_template(
        'scoreboardv1.html',
        game_id=game_id,
        player1_name=player1_name,
        player2_name=player2_name,
        player1_score=player1_score,
        player2_score=player2_score,
        serving_player=serving_player,
        serving_side=serving_side,
        point_history=point_history
    )






