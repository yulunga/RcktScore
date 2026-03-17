#!/usr/bin/python3.7

import sqlite3

# connect to the database
conn = sqlite3.connect('/home/cantarauk/mysite/dbSpace/SqPointManDB.db')

# create a cursor object
cur = conn.cursor()

# execute the ALTER TABLE statement to modify a column
# cur.execute("ALTER TABLE MATCHGAMES MODIFY COLUMN PLAYER1_NAME VARCHAR(50)")

# execute the ALTER TABLE statement to rename the column
#cur.execute("ALTER TABLE MATCHGAMES RENAME COLUMN MATCHSESSISON TO MATCHSESSION")

# execute the ALTER TABLE statement to add a new column
cur.execute("ALTER TABLE MATCHGAMES ADD COLUMN SCORE_TYPE TEXT")


# commit the changes
conn.commit()

# close the cursor and database connections
cur.close()
conn.close()