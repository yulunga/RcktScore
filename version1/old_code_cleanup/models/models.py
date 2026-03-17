# models/models.py
# from app import dbSQLite

from extensions import dbSQLite 

class SQGAMESPLAY(dbSQLite.Model):
    __tablename__ = "SQGAMESPLAY"
    ID = dbSQLite.Column('ID', dbSQLite.Integer, primary_key=True)
    matchsession = dbSQLite.Column(dbSQLite.String(100))
    PLAYER1_NAME = dbSQLite.Column(dbSQLite.String(100))
    PLAYER1_SURNAME = dbSQLite.Column(dbSQLite.String(100))
    PLAYER1_country = dbSQLite.Column(dbSQLite.String(100))
    PLAYER1_HANDICAP = dbSQLite.Column(dbSQLite.Integer)
    PLAYER2_NAME = dbSQLite.Column(dbSQLite.String(100))
    PLAYER2_SURNAME = dbSQLite.Column(dbSQLite.String(100))
    PLAYER2_COUNTRY = dbSQLite.Column(dbSQLite.String(100))
    PLAYER2_HANDICAP = dbSQLite.Column(dbSQLite.Integer)
    COURT_NAME = dbSQLite.Column(dbSQLite.String(100))
    REFEREE_NAME = dbSQLite.Column(dbSQLite.String(100))
    SCORE_TYPE = dbSQLite.Column(dbSQLite.Integer)

    def __repr__(self):
        return f'<SQGAMESPLAY {self.ID}>'