
# A very simple Flask Hello World app for you to get started with...

from flask import Flask, render_template, request

Sscore = Flask(__name__)

@Sscore.route("/")
def home():
    return render_template("index.html")

@Sscore.route("/score", methods=["POST"])
def score():
    try:
        player1_score = int(request.form["player1_score"])
        player2_score = int(request.form["player2_score"])
        serving_player = int(request.form["serving_player"])
        # Do something with the score and serving_player variables
        return "Score updated!"
    except Exception as e:
        return f"Error: {e}"

if __name__ == "__main__":
    Sscore.run(debug=True)
