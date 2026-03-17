#!/usr/bin/python3.7

import os
import sqlite3

# check if the database exists
db_path = '../dbSpace/SqPointManDB.db'
print (db_path)
if os.path.exists(db_path):
    print("Database already exists.")
else:
    # create a new database and connect to it
    conn = sqlite3.connect(db_path)
    print("Database created successfully.")
    conn.close()
