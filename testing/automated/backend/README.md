# Backend Automation

This area is for fast Python tests using Pytest.

These tests should focus on pure logic first because they are:

- fast to write
- fast to run
- easy to trust
- less likely to become flaky than browser tests

## First run

Create and activate a virtual environment if needed:

```bash
python3 -m venv .venv
source .venv/bin/activate
```

Install the backend test dependencies:

```bash
pip install -r testing/automated/backend/requirements-test.txt
```

Run the backend test suite:

```bash
pytest -c testing/automated/backend/pytest.ini testing/automated/backend
```

## Good first test targets in this repo

- `backend/common/session_logic.py`
- `backend/common/match_logic.py`
- `backend/common/auth_logic.py`
- `backend/common/organization_logic.py`

## Growth path

Start with pure helper functions, then move into:

- handler-level request validation
- tenant and role restrictions
- match lifecycle rules
- password reset rules

