# AGENTS.md

## Purpose

This file is the working operating guide for the `RcktScore` repository.
It should describe the codebase as it exists now, not as it is planned to be.

When the app changes materially, this file should be updated in the same workstream.

---

## Current Product State

`RcktScore` v2 is a cloud-hosted squash scoring application with:

- a React frontend in `frontend/`
- a Python AWS Lambda backend in `backend/`
- Supabase Postgres as the primary datastore
- AWS Amplify hosting for the frontend
- AWS SAM for backend deployment

The old Flask application remains in `version1/` as reference only. It is not the active app.

---

## Current Deployment State

### Frontend

- Hosted with AWS Amplify
- Amplify build config is at [amplify.yml](/Users/glennrowe/Development/Projects/RcktScore/amplify.yml)
- Amplify app has been deployed in `eu-north-1`
- The frontend calls the backend through `VITE_API_BASE_URL`

### Backend

- Deployed with AWS SAM from [template.yaml](/Users/glennrowe/Development/Projects/RcktScore/backend/template.yaml)
- Active stack name: `rcktscore-backend`
- Active backend region: `eu-west-2`
- Current deployed HTTP API base URL:
  `https://st3nn5zsm6.execute-api.eu-west-2.amazonaws.com/prod`

### Supabase

- Supabase Postgres is the system of record
- Lambda connections must use the Supabase pooler connection string, not the direct IPv6 database host
- The backend connection helper in [supabase_client.py](/Users/glennrowe/Development/Projects/RcktScore/backend/common/supabase_client.py) disables prepared statements for Supabase pooler compatibility

---

## Repository Layout

### Root

- `frontend/` React + Vite client
- `backend/` Lambda handlers, shared backend logic, SAM config
- `infrastructure/` reference deployment notes and older config support files
- `version1/` legacy Flask code kept for migration/reference

### Frontend

- `src/App.jsx` route definitions
- `src/context/AuthContext.jsx` frontend auth/session state
- `src/context/MatchContext.jsx` match state and API mutations
- `src/services/api.js` HTTP API client
- `src/services/websocket.js` browser WebSocket client

### Backend

- `functions/create_match/handler.py`
- `functions/login/handler.py`
- `functions/get_match/handler.py`
- `functions/score_point/handler.py`
- `functions/event_action/handler.py`
- `functions/undo_action/handler.py`
- `functions/websocket_broadcast/handler.py`
- `common/match_logic.py`
- `common/auth_logic.py`
- `common/supabase_client.py`
- `common/utils.py`
- `common/organization_logic.py`
- `docs/backend-api.md` backend/API developer reference
- `docs/technical-walkthrough.md` end-to-end lifecycle walkthroughs

---

## Request Lifecycle

The v2 request lifecycle is now documented explicitly in:

- [backend-api.md](/Users/glennrowe/Development/Projects/RcktScore/docs/backend-api.md)
- [technical-walkthrough.md](/Users/glennrowe/Development/Projects/RcktScore/docs/technical-walkthrough.md)

Current architecture layers:

- frontend state owner
  - [AuthContext.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/context/AuthContext.jsx)
  - [MatchContext.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/context/MatchContext.jsx)
- API client layer
  - [api.js](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/services/api.js)
- Lambda handler layer
  - `backend/functions/*/handler.py`
- shared domain logic layer
  - `backend/common/auth_logic.py`
  - `backend/common/organization_logic.py`
  - `backend/common/dashboard_logic.py`
  - `backend/common/match_logic.py`
- persistence layer
  - [supabase_client.py](/Users/glennrowe/Development/Projects/RcktScore/backend/common/supabase_client.py)
  - Supabase Postgres tables:
    - `SkwshOrgSettings`
    - `SkwshOrgUsers`
    - `SkwshCourts`
    - `matches`
    - `match_events`

Current runtime flow is:

1. React page/component triggers an action through [api.js](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/services/api.js)
2. The request is sent to the deployed HTTP API in API Gateway
3. API Gateway invokes the matching Lambda from [template.yaml](/Users/glennrowe/Development/Projects/RcktScore/backend/template.yaml)
4. The Lambda handler parses input using [utils.py](/Users/glennrowe/Development/Projects/RcktScore/backend/common/utils.py)
5. Shared domain logic runs in `backend/common/*.py`
6. Shared DB access is created through [supabase_client.py](/Users/glennrowe/Development/Projects/RcktScore/backend/common/supabase_client.py)
7. Supabase/Postgres is read/written
8. The handler returns JSON to the frontend
9. Frontend context updates local state and the relevant page rerenders

This flow is consistent across login, dashboard, organisation settings, match creation, scoring, undo, and match completion.

---

## Current Frontend Routes

Defined in [App.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/App.jsx):

- `/` -> login page
- `/login` -> login page
- `/dashboard` -> protected organisation dashboard
- `/settings` -> protected organisation settings page
- `/match/new` -> protected route
- `/match/:matchId` -> protected route
- `/display` -> public spectator display route

Auth protection is currently implemented in the frontend with `AuthContext` and `ProtectedRoute`.

---

## Current Backend HTTP API

Defined in [template.yaml](/Users/glennrowe/Development/Projects/RcktScore/backend/template.yaml):

- `POST /login`
- `GET /dashboard/{organization_id}`
- `GET /organization_settings/{organization_id}`
- `PUT /organization_details/{organization_id}`
- `POST /organization_users`
- `PUT /organization_users/{user_id}`
- `POST /organization_courts`
- `PUT /organization_courts/{court_id}`
- `DELETE /organization_courts/{court_id}`
- `POST /start_match`
- `GET /get_score/{match_id}`
- `POST /score_point`
- `POST /event_action`
- `POST /undo_action`
- `POST /end_match`

Important: these are the real v2 endpoints. Do not document or build against `/matches`, `/matches/{id}/score`, or other REST shapes unless the code has actually been changed to support them.

Current API contract status:

- response handling is centralized through [utils.py](/Users/glennrowe/Development/Projects/RcktScore/backend/common/utils.py)
- status codes are mostly consistent (`200`, `201`, `400`, `404`, `500`)
- error payloads generally use `{"message": "..."}`
- success payloads are not yet fully standardized across all endpoints

Do not claim that a final unified API envelope already exists. It is still a backlog item.

---

## Authentication

### Current State

Login is now backed by Supabase/Postgres via the `SkwshOrgUsers` table.

The active login flow:

1. Frontend posts username/password to `POST /login`
2. Lambda queries `SkwshOrgUsers`
3. Password is verified against the stored `password_hash`
4. The API returns:
   - `id`
   - `username`
   - `role`
   - `organization_id`
   - `organization_name`
5. Frontend stores that session in `sessionStorage`

Relevant files:

- [AuthContext.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/context/AuthContext.jsx)
- [api.js](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/services/api.js)
- [auth_logic.py](/Users/glennrowe/Development/Projects/RcktScore/backend/common/auth_logic.py)
- [handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/login/handler.py)

### Source of Truth

Organisation users are stored in:

- `SkwshOrgUsers`

Current expected columns:

- `id`
- `clubusername`
- `password_hash`
- `organization_id`
- `role`

Organisation metadata is joined from:

- `SkwshOrgSettings`

### Important Constraint

Backend login is real, but backend authorization for match-management routes is not yet enforced.

Current status:

- login is validated against the database
- route blocking in the browser exists
- organisation users now land on a protected dashboard after login
- scoring/match APIs are still callable without server-side token verification

Any work on auth should preserve the existing `SkwshOrgUsers` table model unless there is an explicit migration plan.

---

## Match Creation and Organisation Association

When an operator logs in, the frontend uses the authenticated user's `organization_id` as `tenant_id` when creating a match.

This is implemented in [NewMatch.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/pages/NewMatch.jsx).

Current match setup behavior:

- the operator does not manually type the tenant or organisation id
- the court selector is populated from organisation settings
- the selector displays `court_name` values from `SkwshCourts`
- `court_alias` is shown as the read-only paired field once a court is selected
- player country fields are intentionally hidden for now pending a later maturity pass
- the setup form supports `PAR-11` and `PAR-15`
- the setup form supports `best_of` values `1`, `3`, and `5`
- after successful match creation the operator is routed directly to `/match/:matchId`
- handicap matches use the predefined 2024 matrix bands (`A` through `M`) to calculate opening offsets
- handicap mode forces PAR-15 scoring in the current implementation
- the setup page includes an in-page handicap matrix table and summary helper for the selected player bands

Do not reintroduce free-text manual entry of the tenant/organisation ID in the operator UI unless there is a clear reason.

The dashboard is now the primary post-login landing page and currently includes:

- quick actions
- active matches
- recent completed matches
- organisation summary information
- a direct route into organisation settings management

The organisation settings page currently provides:

- organisation detail editing for club name, address, contact, telephone, email, and website
- a Google Maps embed driven from the saved address
- organisation user creation and role updates (`admin` / `user`)
- court create, update, and delete operations
- a game settings section with an organisation-level handicap scoring toggle scaffold
- a visible racket-sports launch matrix where only squash is currently active and the other sports are intentionally greyed out

Important: social profile inputs and organisation-level game settings are scaffolded in the UI only right now. They are not yet persisted because the current documented organisation table does not yet include dedicated columns for them.

---

## Match and Scoring Logic

Current match and event processing lives in [match_logic.py](/Users/glennrowe/Development/Projects/RcktScore/backend/common/match_logic.py).

Current behavior:

- match records are created in `matches`
- events are stored in `match_events`
- schema bootstrap for these tables now lives in [001_match_storage.sql](/Users/glennrowe/Development/Projects/RcktScore/backend/schema/001_match_storage.sql)
- match state is reconstructed from event history
- squash scoring is now match-aware, not just single-score aware
- `score_type` is the game target, so `PAR-11` wins at 11 and `PAR-15` wins at 15
- both PAR formats use win-by-2 logic once tied at game ball
- matches support `best_of` values `1`, `3`, and `5`
- first player to the required number of game wins completes the match automatically
- the backend tracks:
  - current game number
  - games required to win
  - games won by each player
  - current server
  - current server side
  - current service side
  - completed game history
- undo deletes the last non-`match_started` event and rebuilds state
- service side and current server are derived from events
- ending a match sets `matches.status` to `completed`, stamps `completed_at`, and stores `player1_final_score`, `player2_final_score`, `winner_side`, and `winner_name`
- operators can also end a match early through `POST /end_match`, which records `ended_early` and `end_reason`
- new matches should be created as `sport = "squash"` for the current launch scope unless the app has been explicitly extended for another racket sport

The scoring timeline is now the persistence source for historic views:

- every scoring action is written to `match_events`
- scoring payloads carry game-aware snapshot data
- completed matches persist enough summary data in `matches` for dashboard/history queries without replaying every event first

Current summary columns expected on `matches` include:

- `best_of`
- `games_to_win`
- `current_game_number`
- `player1_games_won`
- `player2_games_won`
- `player1_final_score`
- `player2_final_score`
- `winner_side`
- `winner_name`
- `ended_early`
- `end_reason`
- `completed_at`

Important: rerun [001_match_storage.sql](/Users/glennrowe/Development/Projects/RcktScore/backend/schema/001_match_storage.sql) in Supabase whenever these match-tracking columns are added or changed. The deployed backend now expects them.

Relevant operator-facing frontend files:

- [MatchScreen.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/pages/MatchScreen.jsx)
- [Scoreboard.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/components/Scoreboard.jsx)
- [MatchControls.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/components/MatchControls.jsx)
- [EventTimeline.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/components/EventTimeline.jsx)

Current scoring screen behavior:

- the scoreboard shows games won as well as the current game score
- the active server is shown next to the player name with the current service side
- the event timeline is scrollable inside a fixed-height panel
- the spectator display section appears below the event timeline
- operators can end a match early
- operators can navigate back to the dashboard from the scoring controls

---

## Realtime / WebSocket Status

Realtime support is only partially implemented at present.

Current state:

- the frontend has a WebSocket client in [websocket.js](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/services/websocket.js)
- there is a broadcast Lambda in [handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/websocket_broadcast/handler.py)
- the active SAM template does not currently provision a WebSocket API
- therefore WebSocket-based live updates should be treated as incomplete infrastructure, not as fully deployed behavior

Do not describe realtime as production-complete unless the WebSocket API, connection management, and broadcast flow are fully wired and deployed.

---

## Environment Variables

### Frontend

Used by Vite/Amplify:

- `VITE_API_BASE_URL`
- `VITE_WEBSOCKET_URL`
- `VITE_API_KEY`
- `VITE_BUILD_ID`

Notes:

- `VITE_*` values are public build-time values
- `VITE_BUILD_ID` is displayed in the footer and should be sourced from CI metadata when available
- do not put database credentials or private secrets in frontend env vars

### Backend

Used by Lambda:

- `SUPABASE_DB_URL`

This should be provided as the Supabase pooler connection string during deployment, not committed into repo files.

---

## Deployment Workflow

### Frontend

- Build with `npm ci` then `npm run build`
- Deploy via Amplify using [amplify.yml](/Users/glennrowe/Development/Projects/RcktScore/amplify.yml)
- Amplify app must expose the correct `VITE_API_BASE_URL`

### Backend

- Build with `sam build`
- Deploy with `sam deploy`
- Default SAM deploy config is in [samconfig.toml](/Users/glennrowe/Development/Projects/RcktScore/backend/samconfig.toml)

Current SAM config intentionally does not store the real Supabase password in the repo.

---

## Security Rules

- Never commit live Supabase passwords or pooler URLs containing real passwords
- Never place backend secrets in Amplify `VITE_*` variables
- Treat `samconfig.toml` as sensitive if credentials are temporarily added locally
- Prefer deploy-time parameter injection or AWS Secrets Manager / Parameter Store for backend secrets

---

## Coding Rules For Agents

### Do

- keep documentation aligned to deployed behavior
- reuse backend shared modules in `backend/common/`
- preserve compatibility with existing `SkwshOrgUsers` and `SkwshOrgSettings` tables
- keep frontend API access centralized in `frontend/src/services/api.js`
- keep auth/session access centralized in `frontend/src/context/AuthContext.jsx`
- update this file when routes, deployment targets, auth model, or architecture changes

### Do Not

- document unimplemented endpoints as if they already exist
- describe WebSocket live updates as complete when infrastructure is still partial
- introduce a second unrelated auth model without an explicit migration decision
- hardcode secrets into repo-tracked files
- move scoring logic into the frontend

---

## Current Known Gaps

- backend token-based authorization is not yet enforced on protected scoring endpoints
- WebSocket infrastructure is incomplete in the deployed backend
- historic match list/detail UX is still basic compared with the richer scoring data now stored
- AGENTS.md, README, and deployment notes should continue to be kept in sync as v2 expands

---

## Maintenance Rule

When version 2 progresses, update this file for:

- new deployed stacks or regions
- route changes
- auth/authorization changes
- database model changes
- environment variable changes
- realtime infrastructure changes
- completed features that are currently listed as gaps

This file should remain the short operational truth for the repository.



## 📝 TODO — Architecture & Platform Enhancements (Backlog)

The following items are intentionally deferred while frontend UI structure is prioritised. These must be implemented before production maturity.

---

### 🔄 Core Architecture Improvements

* [x] Define and document full request lifecycle (frontend → API → Lambda → Supabase → response)
  Completed in:
  - [AGENTS.md](/Users/glennrowe/Development/Projects/RcktScore/AGENTS.md)
  - [backend-api.md](/Users/glennrowe/Development/Projects/RcktScore/docs/backend-api.md)
  - [technical-walkthrough.md](/Users/glennrowe/Development/Projects/RcktScore/docs/technical-walkthrough.md)
* [ ] Standardise API response contract (success/error format)
  Remaining work:
  - create shared success/error helpers in `backend/common/utils.py`
  - define one stable envelope for success payloads
  - define one stable envelope for error payloads
  - migrate all handlers and frontend API consumers to the same contract
* [ ] Define and enforce match event schema in `match_events`
  Current state:
  - the event model is described in docs and implemented in `match_logic.py`
  Remaining work:
  - formally document the payload shape for each event type
  - validate payload structure consistently before insert
  - reject malformed event payloads at the backend boundary
* [ ] Document and implement WebSocket target architecture
* [ ] Introduce versioning and API change management rules

---

### ⚡ Realtime (Option A)

Goal: Enable live scoreboard updates without polling

* [ ] Create API Gateway WebSocket API (SAM template)
* [ ] Implement connection management (store connection IDs)
* [ ] Implement match subscription model (connection → match_id)
* [ ] Build broadcast Lambda for match updates
* [ ] Integrate WebSocket client fully in frontend
* [ ] Remove polling fallback once stable

---

### 🔐 Backend Authentication Enforcement (Option B)

Goal: Secure all match and scoring operations

* [ ] Introduce token/session validation in Lambda
* [ ] Ensure all scoring endpoints require authenticated user
* [ ] Enforce organisation-level access control (tenant isolation)
* [ ] Prevent cross-organisation match access
* [ ] Align backend auth with existing `SkwshOrgUsers` model
* [ ] Add middleware/shared auth validation module

---

### 🧪 Reference Endpoint Refactor (Option C)

Goal: Establish a gold-standard implementation pattern

* [ ] Refactor `score_point` Lambda:

  * [ ] Input validation
  * [ ] Shared logic usage (`match_logic.py`)
  * [ ] Supabase write consistency
  * [ ] Structured logging
  * [ ] WebSocket broadcast hook
* [ ] Use this endpoint as template for all others
* [ ] Ensure consistent error handling and response format

---

### 📊 Observability & Logging

* [ ] Add structured logging across all Lambdas
* [ ] Include match_id, user_id, action in logs
* [ ] Improve CloudWatch traceability

---

### 📌 Notes

These items are deferred while focusing on:

* frontend UX structure
* operator workflows
* dashboard experience

Recently completed from this backlog:

* request lifecycle is now documented explicitly
* architecture layers are now documented explicitly

They must be revisited before declaring v2 production-ready.
