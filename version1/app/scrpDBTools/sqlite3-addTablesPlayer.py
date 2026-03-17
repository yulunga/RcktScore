#!/usr/bin/python3.7

import sqlite3

conn = sqlite3.connect('SqPointManDB.db')
print "Opened database successfully";

conn.execute('''CREATE TABLE PLAYERS
         (ID INT PRIMARY KEY    NOT NULL,
         NAME           TEXT    NOT NULL,
         SURNAME	TEXT	NOT NULL,
         COUNTRY        TEXT    NOT NULL,
         HANDICAP	INT     NOT NULL,;''')
print "Table created successfully";

conn.close()
