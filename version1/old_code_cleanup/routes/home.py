from flask import Blueprint, render_template

# Import authentication model
from auth import login_required  

home_bp = Blueprint('home', __name__)

@home_bp.route('/', strict_slashes = False, methods=['GET'])
@login_required
def home():
    return render_template('index.html')

@home_bp.route('/landing')
def dalanding():
    return render_template('landing.html')

@home_bp.route('/welcome')
def welcome():
    return render_template('welcome.html')

@home_bp.route('/baselayout')
def baselayout():
    return render_template('baselayout.html')