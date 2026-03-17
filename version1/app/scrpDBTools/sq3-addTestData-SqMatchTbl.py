#!/usr/bin/python3.7
#!
import sqlite3

# connect to the database
conn = sqlite3.connect('dbSpace/SqPointManDB.db')

# create a cursor object
cur = conn.cursor()

# define the data to be inserted
data = (1, '2022 Summer', 'John', 'Doe', 'USA', 3, 'Jane', 'Smith', 'Canada', 2, 'Court 1', 'Referee 1')

# execute the INSERT statement
cur.execute("INSERT INTO MATCHGAMES (ID, MATCHSESSION, PLAYER1_NAME, PLAYER1_SURNAME, PLAYER1_COUNTRY, PLAYER1_HANDICAP, PLAYER2_NAME, PLAYER2_SURNAME, PLAYER2_COUNTRY, PLAYER2_HANDICAP, COURT_NAME, REFEREE_NAME) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", data)

# commit the changes
conn.commit()

# close the cursor and database connections
cur.close()
conn.close()