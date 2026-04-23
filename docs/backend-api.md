# Backend API Reference

## Purpose

This document is the developer-facing backend and API reference for `RcktScore` v2.
It describes the backend as it exists now.

For end-to-end request walkthroughs, see [technical-walkthrough.md](/Users/glennrowe/Development/Projects/RcktScore/docs/technical-walkthrough.md).

---

## Runtime Architecture

Current runtime path:

1. React UI triggers a request through [api.js](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/services/api.js), or the native iOS app triggers a request through [APIClient.swift](/Users/glennrowe/Development/Projects/RcktScore/mobile/ios/RcktScoreMobile/RcktScoreMobile/Services/APIClient.swift)
2. The browser calls `VITE_API_BASE_URL`, or the iOS client calls `APIBaseURL` from app configuration
3. AWS API Gateway HTTP API receives the request
4. API Gateway invokes a Lambda function defined in [template.yaml](/Users/glennrowe/Development/Projects/RcktScore/backend/template.yaml)
5. The Lambda handler:
   - parses the request body with [utils.py](/Users/glennrowe/Development/Projects/RcktScore/backend/common/utils.py)
   - validates required fields
   - opens a database connection with [supabase_client.py](/Users/glennrowe/Development/Projects/RcktScore/backend/common/supabase_client.py)
   - delegates business logic to shared modules in `backend/common/`
6. Shared logic reads/writes Supabase Postgres
7. The handler returns a JSON response
8. Web context or native view state updates local UI state

## Architecture Layers

### Frontend State Owner

Frontend state is owned in React context modules:

- [AuthContext.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/context/AuthContext.jsx)
  - login state
  - persisted browser session
  - logout flow
- [MatchContext.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/context/MatchContext.jsx)
  - current match state
  - match mutations
  - load/start/score/undo/end operations

### API Client Layer

HTTP access is centralized in:

- [api.js](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/services/api.js)
- [APIClient.swift](/Users/glennrowe/Development/Projects/RcktScore/mobile/ios/RcktScoreMobile/RcktScoreMobile/Services/APIClient.swift)

These client layers are responsible for:

- constructing requests
- attaching `Content-Type`
- attaching `x-api-key` when configured
- parsing JSON responses
- raising frontend-visible errors when the API returns non-2xx responses

### Lambda Handler Layer

API Gateway routes terminate in Lambda handlers under:

- `backend/functions/*/handler.py`

This layer is responsible for:

- parsing the AWS event
- validating required request fields
- choosing the correct domain function
- translating results into HTTP JSON responses

Examples:

- [login/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/login/handler.py)
- [root_admin_login/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/root_admin_login/handler.py)
- [register_interest/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/register_interest/handler.py)
- [create_match/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/create_match/handler.py)
- [score_point/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/score_point/handler.py)
- [end_match/handler.py](/Users/glennrowe/Development/Projects/RcktScore/backend/functions/end_match/handler.py)

### Shared Domain Logic Layer

Reusable backend business logic lives in:

- [auth_logic.py](/Users/glennrowe/Development/Projects/RcktScore/backend/common/auth_logic.py)
- [organization_logic.py](/Users/glennrowe/Development/Projects/RcktScore/backend/common/organization_logic.py)
- [dashboard_logic.py](/Users/glennrowe/Development/Projects/RcktScore/backend/common/dashboard_logic.py)
- [match_logic.py](/Users/glennrowe/Development/Projects/RcktScore/backend/common/match_logic.py)

This layer owns:

- authentication checks against `SkwshOrgUsers`
- root admin authentication checks against `SkRootAdmin`
- organisation and court CRUD logic
- root admin tenant-management aggregation
- dashboard aggregation
- squash scoring rules
- event sourcing and match reconstruction
- undo behavior
- match completion behavior

### Persistence Layer

Persistence is handled through:

- [supabase_client.py](/Users/glennrowe/Development/Projects/RcktScore/backend/common/supabase_client.py)
- Supabase Postgres

Current persistence tables include:

- `SkwshOrgSettings`
- `SkwshOrgUsers`
- `SkRootAdmin`
- `SkwshCourts`
- `matches`
- `match_events`

Schema bootstrap for match persistence is in:

- [001_match_storage.sql](/Users/glennrowe/Development/Projects/RcktScore/backend/schema/001_match_storage.sql)
- [010_match_shirt_colors.sql](/Users/glennrowe/Development/Projects/RcktScore/backend/schema/010_match_shirt_colors.sql)

---

## Deployment Context

- Frontend hosting: AWS Amplify in `eu-north-1`
- Backend stack: `rcktscore-backend`
- Backend region: `eu-west-2`
- Active API base URL:
  `https://st3nn5zsm6.execute-api.eu-west-2.amazonaws.com/prod`

Additional backend email parameters:

- `InterestToEmail`
  - current default: `rcktinterest@ucingo.com`
- `InterestFromEmail`
  - sender address used by AWS SES
  - must be verified in SES for delivery to succeed

---

## Backend Modules

### Shared Utilities

- [utils.py](/Users/glennrowe/Development/Projects/RcktScore/backend/common/utils.py)
  - `success_response(status_code, data=None, meta=None)`
  - `error_response(status_code, code, message, details=None)`
  - `json_response(status_code, body)` compatibility wrapper for older callers
  - `parse_body(event)`
  - `path_parameter(event, name)`
  - `require_fields(payload, fields)`

### Database Connection

- [supabase_client.py](/Users/glennrowe/Development/Projects/RcktScore/backend/common/supabase_client.py)
  - connects to Supabase Postgres
  - should use the Supabase pooler connection string
  - prepared statements are disabled for pooler compatibility

### Shared Domain Logic

- [auth_logic.py](/Users/glennrowe/Development/Projects/RcktScore/backend/common/auth_logic.py)
  - organisation user lookup and password verification
- [organization_logic.py](/Users/glennrowe/Development/Projects/RcktScore/backend/common/organization_logic.py)
  - organisation details, users, and courts CRUD
- [dashboard_logic.py](/Users/glennrowe/Development/Projects/RcktScore/backend/common/dashboard_logic.py)
  - dashboard aggregation for organisation summary, active matches, recent matches
- [match_logic.py](/Users/glennrowe/Development/Projects/RcktScore/backend/common/match_logic.py)
  - match creation
  - live squash scoring rules
  - event storage
  - undo
  - early/manual end
  - match serialization

---

## API Routes

Routes are defined in [template.yaml](/Users/glennrowe/Development/Projects/RcktScore/backend/template.yaml).

### Authentication

- `POST /login`
- `POST /root_admin/login`
- `POST /register_interest`
- `POST /feedback`

`POST /root_admin/login` authenticates against the `SkRootAdmin` table and returns a separate root-admin session payload.

`POST /register_interest` is an unauthenticated prospect-access route. It validates an email address, supports a honeypot field for basic bot filtering, and sends an AWS SES email notification to the configured interest inbox.

`POST /feedback` is the in-app support route used by the protected `Ping Us` page. It validates:

- `name`
- `email`
- `category`
- `message`

and accepts additional context such as:

- `username`
- `organization_name`
- `version`
- `build`
- `page_url`
- `user_agent`

It sends an SES email to the configured feedback inbox and returns the shared success envelope.

### Root Administration

- `GET /root_admin/dashboard`
- `POST /root_admin/organizations`
- `GET /root_admin/organizations/search?q=...`
- `POST /root_admin/organization_users`
- `PUT /root_admin/organization_users/{user_id}`

### Dashboard / Organisation

- `GET /dashboard/{organization_id}`
- `GET /organization_settings/{organization_id}`
- `PUT /organization_details/{organization_id}`
- `POST /organization_users`
- `PUT /organization_users/{user_id}`
- `POST /organization_courts`
- `PUT /organization_courts/{court_id}`
- `DELETE /organization_courts/{court_id}`

### Match / Scoring

- `POST /start_match`
- `POST /start_scheduled_match`
- `GET /get_score/{match_id}`
- `POST /score_point`
- `POST /event_action`
- `POST /undo_action`
- `POST /end_match`

### Match Setup Lookup

- `GET /match_setup_lookup/{organization_id}?q=...`

This endpoint supports the match setup player/referee lookup UI. It is backed by
[match_setup_logic.py](/Users/glennrowe/Development/Projects/RcktScore/backend/common/match_setup_logic.py).

---

## Data Layer

### Existing Organisation Tables

- `SkwshOrgSettings`
- `SkwshOrgUsers`
- `SkwshCourts`

These remain the source of truth for organisation metadata, users, and courts.

### Match Tables

Schema bootstrap is in [001_match_storage.sql](/Users/glennrowe/Development/Projects/RcktScore/backend/schema/001_match_storage.sql).

Current match persistence uses:

- `matches`
- `match_events`

Important current `matches` fields:

- `id`
- `tenant_id`
- `court_id`
- `court_name`
- `court_alias`
- `sport`
- `player1_name`
- `player1_surname`
- `player1_handedness`
- `player1_shirt_color`
- `player2_name`
- `player2_surname`
- `player2_handedness`
- `player2_shirt_color`
- `referee_name`
- `score_type`
- `best_of`
- `games_to_win`
- `current_game_number`
- `player1_games_won`
- `player2_games_won`
- `handicap_enabled`
- `player1_band`
- `player2_band`
- `player1_offset`
- `player2_offset`
- `player1_final_score`
- `player2_final_score`
- `winner_side`
- `winner_name`
- `ended_early`
- `end_reason`
- `status`
- `created_at`
- `updated_at`
- `completed_at`

Current `match_events` responsibility:

- every operator scoring action is written as an event
- event payloads carry enough snapshot data to reconstruct live state
- undo works by deleting the last non-`match_started` event and rebuilding state
- non-scoring operator actions such as `let`, `serve_side`, `server`, and `timer` are also recorded as events

---

## Current Response Contract

The API now uses one shared envelope for both success and error responses.

### Success Envelope

Every successful response returns:

```json
{
  "success": true,
  "data": {},
  "error": null,
  "meta": {}
}
```

Current resource payloads are nested inside `data`, for example:

- `{"success": true, "data": {"session": {...}}, "error": null, "meta": {}}`
- `{"success": true, "data": {"match": {...}, "broadcast": {...}}, "error": null, "meta": {}}`
- `{"success": true, "data": {"dashboard": {...}}, "error": null, "meta": {}}`
- `{"success": true, "data": {"organizationSettings": {...}}, "error": null, "meta": {}}`
- `{"success": true, "data": {"user": {...}}, "error": null, "meta": {}}`
- `{"success": true, "data": {"court": {...}}, "error": null, "meta": {}}`

### Error Envelope

Every error response returns:

```json
{
  "success": false,
  "data": null,
  "error": {
    "code": "ERROR_CODE",
    "message": "Human readable message"
  },
  "meta": {}
}
```

Validation errors may also include `error.details`, for example:

```json
{
  "success": false,
  "data": null,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Missing required fields",
    "details": {
      "fields": ["match_id"]
    }
  },
  "meta": {}
}
```

### Current Status Codes

- `200` successful read/update
- `201` successful create
- `400` invalid request or missing fields
- `401` authentication failure
- `404` resource not found
- `500` unhandled backend error

---

## Current Squash Scoring Rules

Implemented in [match_logic.py](/Users/glennrowe/Development/Projects/RcktScore/backend/common/match_logic.py):

- `PAR-11` uses target score `11`
- `PAR-15` uses target score `15`
- both use win-by-2 after the game reaches the target score on both sides
- matches support `best_of` `1`, `3`, and `5`
- first player to the required number of game wins completes the match
- manual early match end is supported
- Personal account match creation is blocked when the tenant already has an active match.
- Player shirt colours are stored on `matches`; choosing colours is available to Personal+ and club plans.

Tracked live state includes:

- current game score
- current game number
- games won by each player
- current server
- current server side
- service side
- player shirt colours
- completed game history
- winner state when the match completes

Supported non-point event actions include:

- `let`
- `serve_side`
- `server`
- `match_settings`
- `timer`

`stroke` is also sent through `POST /event_action`, but it is scoring-aware and
can complete a game or match.

---

## Frontend Integration Points

### HTTP Client

- [api.js](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/services/api.js)

### Session State

- [AuthContext.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/context/AuthContext.jsx)

### Match State

- [MatchContext.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/context/MatchContext.jsx)

### Operator Screens

- [LoginPage.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/pages/LoginPage.jsx)
- [DashboardPage.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/pages/DashboardPage.jsx)
- [OrganisationSettingsPage.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/pages/OrganisationSettingsPage.jsx)
- [NewMatch.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/pages/NewMatch.jsx)
- [MatchScreen.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/pages/MatchScreen.jsx)

---

## Current Security Position

- login is real and backed by `SkwshOrgUsers`
- frontend route protection exists
- backend token/session enforcement is not yet implemented for protected scoring routes

Do not describe the current backend as fully authenticated or tenant-isolated at the API layer.

---

## Developer Notes

- rerun [001_match_storage.sql](/Users/glennrowe/Development/Projects/RcktScore/backend/schema/001_match_storage.sql) whenever the backend adds expected `matches` columns
- do not use the direct Supabase IPv6 host in Lambda
- do not commit real Supabase credentials into repo-tracked files
- keep new backend behavior documented in this file and in [AGENTS.md](/Users/glennrowe/Development/Projects/RcktScore/AGENTS.md)
