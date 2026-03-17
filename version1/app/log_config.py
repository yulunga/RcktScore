# log_config.py
import os
import logging
from logging.handlers import RotatingFileHandler

def setup_logging(app=None, log_filename='debug.log'):
    """
    Set up centralized logging for the app or standalone modules.

    Args:
        app: Flask app instance (optional). If provided, hooks into app.logger.
        log_filename: Target log file inside 'logs/' folder.
    """
    log_dir = os.path.join(os.path.dirname(__file__), 'logs')
    os.makedirs(log_dir, exist_ok=True)

    log_path = os.path.join(log_dir, log_filename)

    formatter = logging.Formatter(
        '[%(asctime)s] %(levelname)s in %(module)s: %(message)s'
    )

    file_handler = RotatingFileHandler(log_path, maxBytes=10240, backupCount=3)
    file_handler.setFormatter(formatter)
    file_handler.setLevel(logging.DEBUG)

    if app:
        app.logger.addHandler(file_handler)
        app.logger.setLevel(logging.DEBUG)
    else:
        # For modules that use logging.getLogger(__name__)
        root_logger = logging.getLogger()
        root_logger.setLevel(logging.DEBUG)
        if not root_logger.handlers:
            root_logger.addHandler(file_handler)
