#!/usr/bin/python3

import sqlite3
import os 

# Dynamic base directory
basedir = os.path.abspath(os.path.dirname(__file__))
db_path = os.path.abspath(os.path.join(basedir, '..', 'dbSpace', 'SqPointManDB.db'))

print("Script is running from:", basedir)
print("Resolved database path:", db_path)

# connect to the database

with sqlite3.connect(db_path) as conn:

# create a cursor object
    cur = conn.cursor()

# get the name of the table you want to see the structure of
    table_name = input("Enter the name of the table: ")

# execute a SELECT statement to get the structure of the table
    cur.execute(f"PRAGMA table_info({table_name})")

# fetch all the results
    table_info = cur.fetchall()

# print the structure of the table
print(f"Structure of table {table_name}:")
for column in table_info:
    print(f"{column[1]} ({column[2]}) {column[3]} {column[4]} {column[5]} ")

# close the cursor and database connections
cur.close()
conn.close()
