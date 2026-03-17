from flask import Blueprint, render_template, request, redirect, url_for, abort
from models.models import SQGAMESPLAY # Import the model
from extensions import dbSQLite # Import the database instance

game_bp = Blueprint('game', __name__)

@game_bp.route('/new-game', methods=['GET', 'POST'])
def new_game():
    if request.method == 'POST':
        player1_name = request.form.get('player1_name')
        player2_name = request.form.get('player2_name')
        player1_country = request.form.get('player1_country')
        player2_country = request.form.get('player2_country')
        score_type = request.form.get('score_type')
        referee_name = request.form.get('referee_name')
        if not player1_name or not player2_name or not score_type or not referee_name:
            abort(400, "Missing required form fields")
        game = SQGAMESPLAY(
            PLAYER1_NAME=player1_name,
            PLAYER2_NAME=player2_name,
            PLAYER1_country=player1_country,
            PLAYER2_COUNTRY=player2_country,
            SCORE_TYPE=score_type,
            REFEREE_NAME=referee_name
        )
        dbSQLite.session.add(game)
        dbSQLite.session.commit()
        return redirect(url_for('game.scoreboard'))
    return render_template('new-game.html')

@game_bp.route('/scoreboard')
def scoreboard():
    return render_template('scoreboard.html')

@game_bp.route('/scoreboard/<int:game_id>/')
def scoreboardID(game_id):
    scoreboardID = SQGAMESPLAY.query.get_or_404(game_id)
    return render_template('scoreboardnew.html', scoreboardID=scoreboardID)

@game_bp.route('/read-games')
def read_games():
    activegames = SQGAMESPLAY.query.all()
    return render_template('read-games.html', activegames=activegames)