# Technical Walkthrough

## Purpose

This document walks through the current end-to-end request lifecycles in `RcktScore` v2.
It is intended for developers working on the live app.

For the route list and backend module reference, see [backend-api.md](/Users/glennrowe/Development/Projects/RcktScore/docs/backend-api.md).

---

## Shared Request Pattern

Almost every request follows the same path:

1. A React page or component triggers an action.
2. The action goes through [api.js](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/services/api.js).
3. API Gateway routes the request to a Lambda from [template.yaml](/Users/glennrowe/Development/Projects/RcktScore/backend/template.yaml).
4. The Lambda handler parses and validates input using [utils.py](/Users/glennrowe/Development/Projects/RcktScore/backend/common/utils.py).
5. Shared logic in `backend/common/` performs the real business work.
6. A DB connection from [supabase_client.py](/Users/glennrowe/Development/Projects/RcktScore/backend/common/supabase_client.py) reads/writes Supabase Postgres.
7. The Lambda returns JSON.
8. Frontend context updates state and the screen rerenders.

The sections below describe each major flow explicitly.

---

## 1. Login Flow

### Frontend Entry

- [LoginPage.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/pages/LoginPage.jsx)
- [AuthContext.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/context/AuthContext.jsx)
- [api.js](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/services/api.js)

### Request Path

1. User submits username/password on the login page.
2. `AuthContext.login(...)` calls `api.js -> POST /login`.
3. API Gateway invokes [login/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/login/handler.py).
4. Handler parses body and validates required fields.
5. Handler opens DB connection.
6. Handler calls [authenticate_org_user(...)](/Users/glennrowe/Development/Projects/RcktScore/backend/common/auth_logic.py).
7. `auth_logic.py`:
   - loads the user from `SkwshOrgUsers`
   - joins `SkwshOrgSettings`
   - verifies `password_hash`
   - returns serialized session data
8. Handler returns `{"session": ...}`.
9. Frontend stores the session in `sessionStorage`.
10. User is redirected to `/dashboard`.

---

## 2. Dashboard Load

### Frontend Entry

- [DashboardPage.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/pages/DashboardPage.jsx)
- [api.js](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/services/api.js)

### Request Path

1. Dashboard loads after login.
2. Frontend calls `GET /dashboard/{organization_id}`.
3. API Gateway invokes [get_dashboard/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/get_dashboard/handler.py).
4. Handler opens DB connection and calls [get_dashboard_data(...)](/Users/glennrowe/Development/Projects/RcktScore/backend/common/dashboard_logic.py).
5. `dashboard_logic.py`:
   - loads active matches from `matches`
   - loads recent completed matches from `matches`
   - loads organisation summary from `SkwshOrgSettings`
   - loads user/court counts from `SkwshOrgUsers` and `SkwshCourts`
6. Handler returns a dashboard object.
7. Dashboard page renders quick actions, active matches, recent matches, and organisation summary.

Important:
- dashboard logic safely handles missing `matches` tables by returning empty match lists

---

## 3. Organisation Settings Load

### Frontend Entry

- [OrganisationSettingsPage.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/pages/OrganisationSettingsPage.jsx)

### Request Path

1. Frontend calls `GET /organization_settings/{organization_id}`.
2. API Gateway invokes [get_organization_settings/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/get_organization_settings/handler.py).
3. Handler opens DB connection and calls [get_organization_settings(...)](/Users/glennrowe/Development/Projects/RcktScore/backend/common/organization_logic.py).
4. Shared logic loads:
   - organisation details from `SkwshOrgSettings`
   - users from `SkwshOrgUsers`
   - courts from `SkwshCourts`
5. Handler returns:
   - `organization`
   - `users`
   - `courts`
6. Frontend renders organisation forms, users, courts, game settings scaffold, and map.

---

## 4. Organisation Detail Update

### Frontend Entry

- [OrganisationSettingsPage.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/pages/OrganisationSettingsPage.jsx)

### Request Path

1. User edits organisation fields.
2. Frontend calls `PUT /organization_details/{organization_id}`.
3. API Gateway invokes [update_organization_details/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/update_organization_details/handler.py).
4. Handler calls [update_organization_details(...)](/Users/glennrowe/Development/Projects/RcktScore/backend/common/organization_logic.py).
5. Shared logic updates `SkwshOrgSettings`.
6. Updated organisation settings payload is returned.
7. Frontend refreshes the settings screen state.

---

## 5. Organisation User Create / Update

### Create User

1. Frontend calls `POST /organization_users`.
2. API Gateway invokes [create_org_user/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/create_org_user/handler.py).
3. Handler calls [create_organization_user(...)](/Users/glennrowe/Development/Projects/RcktScore/backend/common/organization_logic.py).
4. Shared logic:
   - validates username, password, and role
   - hashes the password
   - inserts into `SkwshOrgUsers`
5. Serialized user object is returned.

### Update User Role

1. Frontend calls `PUT /organization_users/{user_id}`.
2. API Gateway invokes [update_org_user/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/update_org_user/handler.py).
3. Handler calls [update_organization_user_role(...)](/Users/glennrowe/Development/Projects/RcktScore/backend/common/organization_logic.py).
4. Shared logic updates `SkwshOrgUsers.role`.
5. Updated user object is returned.

---

## 6. Court Create / Update / Delete

### Create Court

1. Frontend calls `POST /organization_courts`.
2. API Gateway invokes [create_court/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/create_court/handler.py).
3. Handler calls [create_court(...)](/Users/glennrowe/Development/Projects/RcktScore/backend/common/organization_logic.py).
4. Shared logic inserts into `SkwshCourts`.
5. Court object is returned.

### Update Court

1. Frontend calls `PUT /organization_courts/{court_id}`.
2. API Gateway invokes [update_court/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/update_court/handler.py).
3. Handler calls [update_court(...)](/Users/glennrowe/Development/Projects/RcktScore/backend/common/organization_logic.py).
4. Shared logic updates `SkwshCourts`.
5. Updated court object is returned.

### Delete Court

1. Frontend calls `DELETE /organization_courts/{court_id}`.
2. API Gateway invokes [delete_court/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/delete_court/handler.py).
3. Handler calls [delete_court(...)](/Users/glennrowe/Development/Projects/RcktScore/backend/common/organization_logic.py).
4. Shared logic deletes the row from `SkwshCourts`.
5. Boolean success is returned.

---

## 7. New Match Creation

### Frontend Entry

- [NewMatch.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/pages/NewMatch.jsx)
- [MatchContext.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/context/MatchContext.jsx)

### Request Path

1. Operator chooses:
   - court
   - players
   - referee
   - `PAR-11` or `PAR-15`
   - `best_of` `1`, `3`, or `5`
   - optional handicap bands
2. Frontend calls `POST /start_match`.
3. API Gateway invokes [create_match/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/create_match/handler.py).
4. Handler validates required fields and calls [create_match(...)](/Users/glennrowe/Development/Projects/RcktScore/backend/common/match_logic.py).
5. `match_logic.py`:
   - inserts a `matches` row
   - inserts a `match_started` event into `match_events`
   - initializes best-of, games-to-win, and handicap offsets
6. Handler returns `{"match": ..., "broadcast": ...}`.
7. Frontend stores the match in `MatchContext`.
8. Operator is routed to `/match/:matchId`.

---

## 8. Load Match / Scoreboard Screen

### Frontend Entry

- [MatchScreen.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/pages/MatchScreen.jsx)
- [MatchContext.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/context/MatchContext.jsx)

### Request Path

1. Match screen loads with a `matchId`.
2. `MatchContext.loadMatch(...)` calls `GET /get_score/{match_id}`.
3. API Gateway invokes [get_match/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/get_match/handler.py).
4. Handler calls [get_match(...)](/Users/glennrowe/Development/Projects/RcktScore/backend/common/match_logic.py).
5. Shared logic:
   - loads the `matches` row
   - loads `match_events`
   - rebuilds match state from the event stream
6. Handler returns the match object.
7. Frontend renders:
   - current game score
   - games won
   - serving player and side
   - timeline
   - spectator link

---

## 9. Score Point

### Frontend Entry

- [MatchControls.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/components/MatchControls.jsx)

### Request Path

1. Operator taps `+1 Player 1` or `+1 Player 2`.
2. Frontend calls `POST /score_point`.
3. API Gateway invokes [score_point/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/score_point/handler.py).
4. Handler calls [score_point(...)](/Users/glennrowe/Development/Projects/RcktScore/backend/common/match_logic.py).
5. Shared logic:
   - loads the current match
   - applies squash scoring rules
   - advances service marker
   - detects game completion
   - detects match completion
   - writes a `score_point` event to `match_events`
   - updates summary columns in `matches`
6. Handler returns the updated `match`.
7. Frontend updates the scoreboard immediately.

Current scoring rules:

- `PAR-11` target = 11
- `PAR-15` target = 15
- both require a two-point margin after tied game ball
- best-of logic completes the match when enough games are won

---

## 10. Event Actions

### Supported Actions

- `let`
- `stroke`
- `serve_side`
- `timer`

### Request Path

1. Frontend calls `POST /event_action`.
2. API Gateway invokes [event_action/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/event_action/handler.py).
3. Handler validates action type.
4. Shared logic:
   - `stroke` is scoring-aware and can complete a game/match
   - other actions append event entries without changing score summaries
5. Updated `match` is returned.

---

## 11. Undo Last Action

### Request Path

1. Frontend calls `POST /undo_action`.
2. API Gateway invokes [undo_action/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/undo_action/handler.py).
3. Shared logic deletes the last non-`match_started` event.
4. Match state is rebuilt from the remaining event stream.
5. `matches` summary columns are updated to the rebuilt state.
6. Updated `match` is returned.

---

## 12. End Match

### Request Path

1. Frontend calls `POST /end_match`.
2. API Gateway invokes [end_match/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/end_match/handler.py).
3. Shared logic:
   - determines the current match leader
   - records `ended_early` when used by operator flow
   - stores `end_reason`
   - appends `match_ended` to `match_events`
   - updates final summary fields in `matches`
4. Updated `match` is returned.
5. Frontend can route the operator back to the dashboard after completion.

---

## 13. Display Screen

### Frontend Entry

- [DisplayScreen.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/pages/DisplayScreen.jsx)

### Current Path

1. Display screen receives `match` as a query parameter.
2. It loads match state using the same match fetch path as the operator interface.
3. It renders a read-only view of score and event/timeline state.

Important:
- the WebSocket architecture is not fully completed in AWS yet
- treat display updates as HTTP-driven behavior unless the WebSocket infrastructure is explicitly completed

---

## 14. Current Response Shape Notes

The backend response contract is only partially standardized today.

Current conventions:

- success:
  - `{"session": ...}`
  - `{"match": ..., "broadcast": ...}`
  - direct dashboard/organisation payloads
- error:
  - `{"message": "..."}`
  - optional `{"fields": [...]}` for validation failures

This is good enough for current implementation work, but it is not yet the finished contract.

---

## 15. Current Gaps Relevant To The Lifecycle

- backend authorization is not yet enforced on scoring endpoints
- WebSocket infrastructure is still incomplete at the API Gateway level
- response payloads are not yet fully standardized into one shared envelope
- historical reporting pages are still lighter than the scoring data now stored in the database

---

## Maintenance Rule

When any of these flows change:

- update this document
- update [backend-api.md](/Users/glennrowe/Development/Projects/RcktScore/docs/backend-api.md)
- update [AGENTS.md](/Users/glennrowe/Development/Projects/RcktScore/AGENTS.md)

These three documents should stay aligned.
