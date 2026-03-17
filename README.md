# SqScore

https://www.cisco.com/c/en/us/products/collateral/security/secure-firewall/guide-c07-737902.html

https://www.simplilearn.com/tutorials/sql-tutorial/what-is-sqlite#why_use_sqlite


There is a requirements file which needs to be impoted to support the application. 

# pip3 install - r requirements.text



✅ .env holds all DB URLs
✅ config.py manages env-specific configs
✅ create_app() selects config based on env
✅ models.py stays clean, no DB logic
✅ Use FLASK_ENV to switch environments



Multiple databases connected using bind

Database structure - use sql.toad.cz - import XML


Need to add a .env file with the following details - 

TEST_DATABASE_URL=postgresql://test_user:test_pass@localhost/test_db
PROD_DATABASE_URL=postgresql://prod_user:prod_pass@prod_host/prod_db
    

JWT_SECRET_KEY=super-secret-key
FLASK_ENV=development




# models.py Overview

This module supports dual database connectivity:

- **SQLite** for internal app data (e.g., games, courts)
- **Supabase/Postgres** for multi-tenant user/org data and root admin control

## 🔧 Technologies Used

- SQLAlchemy ORM (for SQLite)
- SQLAlchemy Core (for Supabase/Postgres via raw SQL)
- Flask-Login (`UserMixin` for Root Admin)
- Python `os.getenv()` for secure environment variable loading
- Engine caching for performance

## 🔑 Key Patterns

### 1. Supabase Engine Connection

```python
engine = get_engine()
# RcktScore
