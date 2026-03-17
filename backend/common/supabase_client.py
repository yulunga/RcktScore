import os
from contextlib import contextmanager

import psycopg
from psycopg.rows import dict_row


def get_database_url():
    database_url = os.getenv("SUPABASE_DB_URL") or os.getenv("DATABASE_URL")
    if not database_url:
        raise RuntimeError("SUPABASE_DB_URL or DATABASE_URL must be configured.")
    return database_url


@contextmanager
def get_db_connection():
    connection = psycopg.connect(get_database_url(), row_factory=dict_row)
    try:
        yield connection
    finally:
        connection.close()
