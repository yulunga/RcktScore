#!/usr/bin/python3

import sqlite3
import os

# Dynamic base directory
basedir = os.path.abspath(os.path.dirname(__file__))
db_path = os.path.abspath(os.path.join(basedir, '..', 'dbSpace', 'SqPointManDB.db'))

print("Script is running from:", basedir)
print("Resolved database path:", db_path)

# connect to the database and test connection
#conn = sqlite3.connect('/home/cantarauk/mysite/dbSpace/SqPointManDB.db')
# conn = sqlite3.connect(os.path.join(basedir, 'SqPointManDB.db'))

# Connect and read tables
with sqlite3.connect(db_path) as conn:

# create a cursor object
    cur = conn.cursor()

# execute a SELECT statement to get the names of all tables in the database
    cur.execute("SELECT name FROM sqlite_master WHERE type='table';")

# fetch all the results
    tables = cur.fetchall()

# print the names of all tables
if tables:
        print("Tables in database:")
        for table in tables:
            print(f" - {table[0]}")
else:
        print("No tables found in the database.")

# close the cursor and database connections
cur.close()
conn.close()