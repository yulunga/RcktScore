import hashlib
import hmac
import secrets
import time


def get_registration_settings(connection, *, lock=False):
    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT public_registration_enabled AS enabled,
                   public_registration_message AS message,
                   registration_challenge_key AS challenge_key
            FROM public_registration_settings
            WHERE id = 'default'
            """ + (" FOR SHARE" if lock else "")
        )
        return cursor.fetchone()


def _signature(key, value):
    return hmac.new(str(key).encode(), value.encode(), hashlib.sha256).hexdigest()


def create_challenge(key):
    left, right = (secrets.randbelow(8) + 2 for _ in range(2))
    token = f"{int(time.time()) + 900}.{secrets.token_hex(16)}"
    return {
        "prompt": f"Human check: what is {left} + {right}?",
        "token": f"{token}.{_signature(key, f'{token}.{left + right}')}",
    }


def verify_challenge(key, token, answer):
    parts = token.split(".")
    if len(parts) != 3 or not parts[0].isascii() or not parts[0].isdigit() or len(parts[0]) > 12:
        return False
    expires, nonce, signature = parts
    if int(expires) < time.time() or not signature.isascii():
        return False
    return hmac.compare_digest(signature, _signature(key, f"{expires}.{nonce}.{answer}"))
