# Import the Flask class from the flask module
from flask import Flask, render_template, redirect, url_for, request, session, flash
import git 
import os
import sqlite3
from functools import wraps
from datetime import datetime, timedelta
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy.sql import func
import logging

# Create the application object
app = Flask(__name__)

# Base Directory 
basedir = os.path.abspath(os.path.dirname(__file__))

# DB connection details
dbPathFile = 'dbSpace/SqPointManDB.db'

# /Users/glerowe/Documents/Scripts/SqScore/SqScore-1/dbSpace/SqPointManDB.db
# Session secret and lifespan 
app.secret_key = "my_precious"
app.permanent_session_lifetime = timedelta(minutes=90)
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///' + os.path.join(basedir, 'dbSpace/SqPointManDB.db')
app.config['SQLALCHEMY_TRACK_MODIFICAtioNS'] = False

dbSQLite = SQLAlchemy(app)

# Class to define the DB model for the games table 
class SQGAMESPLAY(dbSQLite.Model):
    __tablename__ = "SQGAMESPLAY"
    ID = dbSQLite.Column('ID', dbSQLite.Integer, primary_key = True)
    matchsession = dbSQLite.Column(dbSQLite.String(100))
    PLAYER1_NAME = dbSQLite.Column(dbSQLite.String(100))
    PLAYER1_SURNAME = dbSQLite.Column(dbSQLite.String(100))
    PLAYER1_country = dbSQLite.Column(dbSQLite.String(100))
    PLAYER1_HANDICAP = dbSQLite.Column(dbSQLite.Integer)
    PLAYER2_NAME = dbSQLite.Column(dbSQLite.String(100))
    PLAYER2_SURNAME = dbSQLite.Column(dbSQLite.String(100))
    PLAYER2_COUNTRY = dbSQLite.Column(dbSQLite.String(100))
    PLAYER2_HANDICAP = dbSQLite.Column(dbSQLite.Integer)
    COURT_NAME = dbSQLite.Column(dbSQLite.String(100))
    REFEREE_NAME = dbSQLite.Column(dbSQLite.String(100))
    SCORE_TYPE = dbSQLite.Column(dbSQLite.Integer)

    livegames = dbSQLite.relationship('SQGAMESSCORE', backref='sqgameplay', lazy=True)

    def __repr__(self):
        return f'<SQGAMESPLAY {self.ID}>'

class SQGAMESSCORE(dbSQLite.Model):
    ID = dbSQLite.Column('ID', dbSQLite.Integer, primary_key = True)
    GAMEID = dbSQLite.Column(dbSQLite.Integer, dbSQLite.ForeignKey('SQGAMESPLAY.ID'))
    PLAY1POINTS  = dbSQLite.Column(dbSQLite.Integer)
    PLAY1GAMES  = dbSQLite.Column(dbSQLite.Integer)
    PLAY1SRVSIDE  = dbSQLite.Column(dbSQLite.String)
    PLAY2POINTS = dbSQLite.Column(dbSQLite.Integer)
    PLAY2GAMES = dbSQLite.Column(dbSQLite.Integer)
    PLAY2SRVESIDE = dbSQLite.Column(dbSQLite.String)

    def __repr__(self):
        return f'<SQGAMESSCORE {self.ID}>'

# Login Object 
def login_required(f):
    @wraps(f)
    def wrap(*args, **kwargs):
        if 'logged_in' in session:
            return f(*args, **kwargs)
        else:
            flash('You need to login first')
            return redirect(url_for('login'))
        return wrap
    return wrap

def get_db_connection():
    conn = sqlite3.connect('database.db')
    conn.row_factory = sqlite3.Row
    return conn

# use decorators to link the function to a url
@app.route('/')
@login_required
def home():
    return render_template('index.html')  # render a template

@app.route('/dalanding')
#@login_required('welcome')
def dalanding():
    return render_template('dalanding.html')  # render a template

@app.route('/welcome')
#@login_required('welcome')
def welcome():
    return render_template('welcome.html')  # render a template

@app.route('/baselayout')
#@login_required('welcome')
def baselayout():
    return render_template('baselayout.html')  # render a template

# Route for handling the login page logic
@app.route('/login', methods=['GET', 'POST'])
#@login_required('welcome')
def login():
    error = None
    if request.method == 'POST':
        if request.form['username'] != 'admin' or request.form['password'] != 'admin':
            error = 'Invalid Credentials. Please try again.'
        else:
            session['logged_in'] = True
            flash('You were just logged in')
            return redirect(url_for('dalanding'))
    return render_template('login.html', error=error)


@app.route("/new-game", methods=["GET", "POST"])
def new_game1():
    if request.method == "POST":
        player1_name = request.form.get('player1_name')
        player2_name = request.form.get('player2_name')
        player1_country = request.form.get('player1_country')
        player2_country = request.form.get('player2_country')
        score_type = request.form.get('score_type')
        referee_name = request.form.get('referee_name')
        if not player1_name or not player2_name or not score_type or not referee_name:
            abort(400, "Missing required form fields")
        game = Game(player1_name, player2_name, player1_country, player2_country, score_type, referee_name)
        db.session.add(game)
        db.session.commit()
        return redirect(url_for('scoreboard'))
    else:
        return render_template("new-game.html")


# ACTIVE - Live scoreboard for selected game based on court
@app.route('/scoreboard')
#@login_required('welcome')
def scoreboard():
    return render_template('scoreboard.html')  # render a template


# ACTIVE - Live scoreboard for selected game based on court
@app.route('/scoreboard/<int:game_id>/')
#@login_required('welcome')
def scoreboardID(game_id):
    scoreboardID = SQGAMESPLAY.query.get_or_404(game_id)
#    scoreboardID = SQGAMESSCORE.query.get_or_404(game_id)
    return render_template('scoreboardnew.html', scoreboardID=scoreboardID)  # render a template


# ACTIVE - Route for reading all table details of all games created
@app.route('/read-games')
def read_games():
    activegames = SQGAMESPLAY.query.all()
    return render_template('read-games.html', activegames=activegames)

# ACTIVE - Route for reading all table details of all games created 
@app.route('/score-game')
def scoregames():
    activegames = SQGAMESPLAY.query.all()
    return render_template('read-games111.html', activegames=activegames)


# ACTIVE - Route for handling creation of a new game
@app.route('/new-game/create', methods=['POST'])
def create_game():
    # get the form data
    score_type = request.form['score_type']
    player1_name = request.form['player1_name']
    player1_surname = request.form['player1_surname']
    player1_country = request.form['player1_country']
    player2_name = request.form['player2_name']
    player2_surname = request.form['player2_surname']
    player2_country = request.form['player2_country']
    court_name = request.form['court_name']
    referee_name = request.form['referee_name']

    # connect to the database
    conn = sqlite3.connect('/home/cantarauk/mysite/dbSpace/SqPointManDB.db')
    cur = conn.cursor()

    # insert the data into the database table MATCHGAMES
    cur.execute("INSERT INTO SQGAMESPLAY ( score_type, player1_name, player1_surname, player1_country, player2_name, player2_surname, player2_country, court_name, referee_name) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
                (score_type, player1_name, player1_surname, player1_country, player2_name, player2_surname, player2_country, court_name, referee_name))

    # commit the changes and close the connections
    conn.commit()
    cur.close()
    conn.close()

    return redirect(url_for('scoring_app'))
    # old code --> return "Game created successfully!"

    # redirect to the scoring application template with the game ID
    # game_id = cur.lastrowid
    # return redirect(url_for('scoring_app', game_id=game_id))

@app.route('/scoring/<int:game_id>')
def scoring_app(game_id):
    # render the scoring application template with the game ID
    return render_template('scoringapp.html', game_id=game_id)


@app.route('/logout')
#@login_required
#@login_required('welcome')
def logout():
    session.pop('logged_in', None)
    flash('You were just logged out')
    return redirect(url_for('login'))


@app.route('/bracketstest')
#@login_required('welcome')
def bracketstest():
    return render_template('bracketstest.html')  # render a template

@app.route('/bracketstest2')
#@login_required('welcome')
def bracketstest2():
    return render_template('bracketstest2.html')  # render a template

@app.route('/slscore')
#@SL box league scores
def slscore():
    date_string = datetime.now().strftime("%Y-%m-%d")
    return render_template('slscores1.html', date_string=date_string) # render a template



@app.errorhandler(400)
def bad_request(e):
    return render_template('error.html', error_message=e), 400

@app.errorhandler(404)
def not_found(e):
    return render_template('error.html', error_message="Page not found"), 404

@app.errorhandler(500)
def internal_server_error(e):
    logging.error(f"Server Error: {e}")
    return render_template('error.html', error_message="An unexpected error occurred. Please try again later."), 500


@app.route('/update_server', methods=['POST'])
def webhook():
    if request.method == 'POST':
        repo = git.Repo('/home/cantarauk/mysite')
        origin = repo.remotes.origin
        origin.pull()
        return 'Updated PythonAnywhere successfully', 200
    else:
        return 'Wrong event type', 400
            
# start the server with the 'run()' method
if __name__ == '__main__':
    logging.basicConfig(filename='error.log', level=logging.ERROR)
    app.run()
