# /app/routes/updateServer.py file 

from flask import Blueprint, request  # Import request
import os
import git

updateServer_bp = Blueprint('updateServer', __name__)

@updateServer_bp.route('/update_server', methods=['POST'])
def webhook():
    try:
        # Ensure the repository path is valid
        repo = git.Repo('/home/cantarauk/mysite')
        origin = repo.remotes.origin

        # Perform a git pull
        origin.pull()

        # Reload the app
        os.system('touch /var/www/cantarauk_pythonanywhere_com_wsgi.py')
        return 'Updated and reloaded PythonAnywhere successfully', 200
    except git.exc.InvalidGitRepositoryError:
        return 'Error: Invalid Git repository', 500
    except git.exc.GitCommandError as e:
        return f'Error: Git command failed - {str(e)}', 500
    except Exception as e:
        return f'Error: {str(e)}', 500