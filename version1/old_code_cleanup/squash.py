# A very simple Flask Hello World app for you to get started with...

from flask import Flask, render_template, request, abort, redirect, url_for, jsonify
from flask_wtf.csrf import CSRFProtect
from flask_wtf import FlaskForm, RecaptchaField
from wtforms import StringField, PasswordField, SubmitField
from wtforms.validators import DataRequired, InputRequired
from configparser import ConfigParser
import configparser

app = Flask(__name__)

# Load the settings from the setting.ini file
config = configparser.ConfigParser()
config.read('/home/cantarauk/mysite/settings.ini')

# Get the current title from the INI file
title = config.get('Settings', 'Title')


# initialize players and scores
player_serving = 1
scoring_system = "First to 11"
player1_name = "Player 1"
player2_name = "Player 2"
'''score = {player1_name: 0, player2_name: 0}'''
score = {player1_name: {}, player2_name: {}}


app = Flask(__name__)

app.config['SECRET_KEY'] = 'mysecretkey'
csrf = CSRFProtect(app)

class LoginForm(FlaskForm):
    username = StringField('Username', validators=[InputRequired()])
    password = PasswordField('Password', validators=[DataRequired()])
    recaptcha = RecaptchaField()
    submit = SubmitField('Login')




@app.route('/', methods=['GET', 'POST'])
def login():
    form = LoginForm()
    if request.method == 'POST' and form.validate():
        parser = ConfigParser()
        parser.read('/home/cantarauk/mysite/settings.ini')
        username = form.username.data
        password = form.password.data
        if username == parser.get('login', 'username') and password == parser.get('login', 'password'):
            session['username'] = username
            return redirect('/landing')
        else:
            error = 'Invalid credentials. Please try again.'
            return render_template('getin.html', form=form, error=error)
    else:
        return render_template('getin.html', form=form)

@app.route('/landing')
def landing():
    username = session.get('username')
    if username:
        return render_template('landing.html', username=username)
    else:
        return redirect('/')


'''
@app.route("/")
def index():
    global player1_name, player2_name, score
    #return render_template('index.html', player1=player1_name, player2=player2_name, score=score)
    return render_template('index.html', player1=player1_name or 'Player 1', player2=player2_name or 'Player 2', score=score or {player1_name or 'Player 1': {'points': 0, 'games': 0}, player2_name or 'Player 2': {'points': 0, 'games': 0}})


@app.route('/')
def index():
    global player1_name, player2_name, score
    if not player1_name:
        player1_name = request.args.get('player1', 'Player 1')
    if not player2_name:
        player2_name = request.args.get('player2', 'Player 2')
    if not score:
        score = {player1_name: {'points': 0, 'games': 0}, player2_name: {'points': 0, 'games': 0}}
    return render_template('index.html', player1=player1_name, player2=player2_name, score=score)
'''


'''
@app.route('/')
def index():
    player1_name = "Player 1"
    player2_name = "Player 2"
    score = {"serve": player1_name, "side": "right", player1_name: {"points": 0}, player2_name: {"points": 0}}
    return render_template('index.html', title=title, player1=player1_name, player2=player2_name, score=score)
'''

# Define the route to the settings page
@app.route('/settings', methods=['GET', 'POST'])
def settings():
    if request.method == 'POST':
        # Update the settings with the form data
        config.set('Settings', 'title', request.form['title'])
        config.set('Settings', 'setting1', request.form['setting1'])
        config.set('Settings', 'setting2', request.form['setting2'])
        # Save the updated settings to the setting.ini file
        with open('setting.ini', 'w') as configfile:
            config.write(configfile)
    # Render the settings.html template with the values of the settings
    return render_template('settings.html', title=config.get('Settings', 'title'), setting1=config.get('Settings', 'setting1'), setting2=config.get('Settings', 'setting2'))

@app.route('/update_settings', methods=['POST'])
def update_settings():
    try:
        # Get data from AJAX request
        setting_key = request.form['setting_key']
        setting_value = request.form['setting_value']

        # Update settings.ini file
        config = configparser.ConfigParser()
        config.read('/home/cantarauk/mysite/settings.ini')
        config.set('Settings', setting_key, setting_value)
        with open('/home/cantarauk/mysite/settings.ini', 'w') as config_file:
            config.write(config_file)

        # Prepare response
        response = {'status': 'success', 'message': 'Setting updated successfully'}
    except Exception as e:
        # Prepare error response
        response = {'status': 'error', 'message': str(e)}

    return jsonify(response)


'''
@app.route('/new-game', methods=['GET', 'POST'])
def new_game():
    global player1_name
    global player2_name
    global scoring_system
    player1_name = request.form.get('player1_name')
    player2_name = request.form.get('player2_name')
    scoring_system = request.form.get('scoring_system')
    if not player1_name or not player2_name or not scoring_system:
        abort(400, "Missing required form fields")
    reset_game()
    return redirect(url_for('scoreboard'))
'''

@app.route("/new-game", methods=["GET", "POST"])
def new_game():
    global player1_name, player2_name, score

    if request.method == "POST":
        player1_name = request.form.get('player1_name')
        player2_name = request.form.get('player2_name')
        scoring_system = request.form.get('scoring_system')
        if not player1_name or not player2_name or not scoring_system:
            abort(400, "Missing required form fields")
        reset_game()
        return redirect(url_for('scoreboard'))
    else:
        return render_template("new-game.html")


@app.route("/new-game1", methods=["GET", "POST"])
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
        return render_template("new-game1.html")



@app.route('/scoreboard')
def scoreboard():
    return render_template('scoreboard.html', player1_name=player1_name, player2_name=player2_name, scoring_system=scoring_system, player1_score=player1_score, player2_score=player2_score, player_serving=player_serving)

@app.route('/add_point/<player>')
def add_point(player):
    global player1_score
    global player2_score
    global player_serving

    # convert player to integer
    try:
        player = int(player)
    except ValueError:
        abort(400, "Invalid player number")

    # increment score for the correct player
    if player == 1:
        player1_score += 1
    elif player == 2:
        player2_score += 1
    else:
        abort(400, "Invalid player number")

    # check for game-winning score
    winning_score = 11 if scoring_system == "First to 11" else 15
    if player1_score >= winning_score and player1_score > player2_score + 1:
        return redirect(url_for('game_over', winner=player1_name))
    elif player2_score >= winning_score and player2_score > player1_score + 1:
        return redirect(url_for('game_over', winner=player2_name))

    # switch server after every 2 points
    if (player1_score + player2_score) % 4 == 0:
        player_serving = 1 if player_serving == 2 else 2

    return redirect(url_for('scoreboard'))

@app.route('/toggle_serve', methods=['POST'])
def toggle_serve():
    global player_serving
    player_serving = 1 if player_serving == 2 else 2
    return redirect(url_for('scoreboard'))

@app.route('/toggle_side', methods=['POST'])
def toggle_side():
    score["side"] = "left" if score["side"] == "right" else "right"
    return "", 204


@app.route('/game_over/<string:winner>')
def game_over(winner):
    global player1_score
    global player2_score
    global player_serving
    reset_game()
    return render_template('game_over.html', winner=winner)

def reset_game():
    global player1_score
    global player2_score
    global player_serving
    player1_score = 0
    player2_score = 0
    player_serving = 1

@app.errorhandler(400)
def bad_request(e):
    return render_template('error.html', error_message=e), 400

@app.errorhandler(404)
def not_found(e):
    return render_template('error.html', error_message="Page not found"), 404

@app.errorhandler(500)
def internal_server_error(e):
    return render_template('error.html', error_message="Internal server error"), 500

if __name__ == '__main__':
    app.run(debug=True)

