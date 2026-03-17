# /app/models/match_logger

import os
import json
import logging
from datetime import datetime

# Setup logging
BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
LOG_DIR = os.path.join(BASE_DIR, 'logs')
os.makedirs(LOG_DIR, exist_ok=True)

LOG_FILE = os.path.join(LOG_DIR, 'debug.log')
logging.basicConfig(
    filename=LOG_FILE,
    level=logging.DEBUG,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

MATCH_LOG_DIR = os.path.join(BASE_DIR, 'app', 'temp_matches')
os.makedirs(MATCH_LOG_DIR, exist_ok=True)

def log_match_event(match_id, event_type, data=None):
    try:
        filepath = os.path.join(MATCH_LOG_DIR, f'match_{match_id}.json')
        logging.debug(f"[MATCH_LOGGER] Event type: {event_type}, Data: {data}")
        logging.debug(f"[MATCH_LOGGER] Log file path: {filepath}")

        # Create file if it doesn't exist
        if not os.path.exists(filepath):
            logging.info(f"[MATCH_LOGGER] Creating new log file for match {match_id}")
            content = {
                "match_id": match_id,
                "player1_name": data.get("player1", "") if data else "",
                "player2_name": data.get("player2", "") if data else "",
                "events": [],
                "scores": {
                    "player1": 0,
                    "player2": 0
                }
            }
        
        else:
            with open(filepath, 'r') as file:
                content = json.load(file)

            updated = False
                
            if "scores" not in content:
                content["scores"] = {"player1": 0, "player2": 0}
                updated = True

                logging.debug(f"[MATCH_LOGGER] Loaded match content: {json.dumps(content, indent=2)}")

            # Only set names if they're missing
            if data:
                if 'player1' in data and not content.get('player1_name'):
                    content['player1_name'] = data['player1']
                    updated = True
                if 'player2' in data and not content.get('player2_name'):
                    content['player2_name'] = data['player2']
                    updated = True

                if updated:
                    with open(filepath, 'w') as file:
                        json.dump(content, file, indent=2)
                    logging.warning(f"[MATCH_LOGGER] META data updated saved for match  {match_id}")    

        # Determine who scored
        if event_type == 'score' and data and 'player' in data:
            player_name = data['player']
            logging.debug(f"[MATCH_LOGGER] Checking if player '{player_name}' matches player1: '{content.get('player1_name')}' or player2: '{content.get('player2_name')}'")
            if player_name == content.get('player1_name'):
                content['scores']['player1'] += 1
            elif player_name == content.get('player2_name'):
                content['scores']['player2'] += 1
            else:
                logging.warning(f"[MATCH_LOGGER] Score received for unknown player: {player_name}")

        # Append new event
        event = {
            "timestamp": datetime.utcnow().isoformat(),
            "event_type": event_type,
            "data": data or {}
        }
        content['events'].append(event)

        # Write back to file
        with open(filepath, 'w') as file:
            json.dump(content, file, indent=2)

        logging.info(f"[MATCH_LOGGER] Event logged: {event_type} for match {match_id}")
        logging.debug(f"[MATCH_LOGGER] File content: {json.dumps(content, indent=2)}")

    except Exception as e:
        logging.error(f"[MATCH_LOGGER] Failed to log event for match {match_id}: {e}")
        import traceback
        traceback.print_exc()
