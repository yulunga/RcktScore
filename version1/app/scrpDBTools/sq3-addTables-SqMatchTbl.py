#!/usr/bin/python3.7

import sqlite3

conn = sqlite3.connect('../dbSpace/SqPointManDB.db')
print ("Opened database successfully")

conn.execute('''CREATE TABLE MATCHGAMES
         (ID INT PRIMARY         KEY     NOT NULL,
         MATCHSESSION           TEXT    NULL,
         PLAYER1_NAME            TEXT    NOT NULL,
         PLAYER1_SURNAME	     TEXT	 NOT NULL,
         PLAYER1_COUNTRY         TEXT    NOT NULL,
         PLAYER1_HANDICAP	     INT     NOT NULL,
         PLAYER2_NAME            TEXT    NOT NULL,
         PLAYER2_SURNAME	     TEXT	 NOT NULL,
         PLAYER2_COUNTRY         TEXT    NOT NULL,
         PLAYER2_HANDICAP	     INT     NOT NULL,
         COURT_NAME              TEXT    NOT NULL,
         REFEREE_NAME             TEXT    NOT NULL
         )''')
print ("Table created successfully")

conn.close()
