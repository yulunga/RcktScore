# AGENTS.md

## Purpose

This file is the short operating guide for the `RcktScore` repository.
It should describe the codebase as it exists now, not as it is planned to be.

When the product, API surface, security posture, or troubleshooting path changes,
update this file together with:

- [docs/backend-api.md](/Users/glennrowe/Development/Projects/RcktScore/docs/backend-api.md)
- [docs/technical-walkthrough.md](/Users/glennrowe/Development/Projects/RcktScore/docs/technical-walkthrough.md)
- [docs/troubleshooting.md](/Users/glennrowe/Development/Projects/RcktScore/docs/troubleshooting.md)

## Current Product State

`RcktScore` v2 is the active app in this repository.

Current stack:

- React + Vite frontend in `frontend/`
- Python AWS Lambda backend in `backend/`
- Supabase Postgres as the primary datastore
- AWS SAM for backend deployment
- native iOS client in `mobile/ios/`

The old Flask code in `version1/` is reference-only and should not be treated as the active product.

## Current Release Posture

The repository is still pre-launch. Web and backend flows are in late beta, and
the native iOS app is in active device hardening rather than production release
readiness.

What is real and implemented:

- org-user login with backend session tokens
- multi-organisation membership selection
- dashboard, history, and match lists
- personal-plan entitlements: Personal Free exposes the latest three completed matches plus a redacted upgrade teaser, while Personal Plus exposes expanded cross-device history and server-derived performance reporting
- the Personal Free completed-history limit is enforced on both dashboard lists and direct authenticated match reads
- organisation settings, user creation with first-name/surname fields, organisation-user detail editing and delete, user role updates, and court CRUD
- root-admin club management, including club-user invite email approval links and root-admin manual approval for pending organisation users
- match create, schedule, start, score, event actions, undo, and end
- sport-specific match engine dispatch with live squash/racketball and expanded tennis scoring, including native tennis doubles setup with per-participant shirt colours, automatic singles receiver selection from the opening server, explicit doubles serve/receive selection, optional Golden Point played automatically from the 40-40/Right service side, an optional final-set 10-point match tiebreak, and optional timed 90-second odd-game changeovers plus 120-second set breaks
- padel uses an explicit doubles-only adapter over the mature tennis-style set engine, including advantage or Golden Point where the receiving team selects which partner receives, 6-6 tiebreaks, serve/receive rotation, offline replay, undo and match completion; table tennis, badminton, and pickleball remain fail-safe placeholders
- native iOS client for org-user login, dashboard/matches/history/settings/help, native match setup, historic-match viewing, and live scoring
- web and native Personal Plus performance views covering results, game/point and serve-point percentages, court time, close games/sets, streaks, opponents, scorelines, sport splits, and weekly/monthly progress
- native iOS login now handles backend `organizationSelection` responses and lets users choose between multiple club/account memberships
- native iOS login now includes a show/hide password toggle and can restore an unexpired, device-bound Keychain session with Face ID or Touch ID when enabled from settings, including from the login screen after local sign-out
- native iOS match setup exposes the implemented and enabled sports only: squash, racketball, tennis, and doubles Padel; Padel remains hidden until it is enabled through the platform and account sport controls
- native iOS sport selection uses clean brand-blue court diagrams with photo-style, transparent ball artwork for squash, racketball, tennis, and Padel, with adaptive light/dark card surfaces; the Settings Racket Sports rows reuse compact versions of the same ball artwork without changing their menu layout
- native iOS gives Personal Free and Personal Plus the same Home, Matches, Analytics, Settings and Need Help navigation; Matches is split into Current, Scheduled and History, with Personal Free seeing an upgrade gate for scheduling, while Analytics exposes basic scored-match stats to both tiers and adds personal performance reporting for Personal Plus
- native historic tennis and Padel timelines use tennis point labels, set terminology and separate game/set completion cards, include match start time, and omit squash-style service-side markers
- organisation and root-admin controls for enabling which racket sports are visible to a club or personal account
- native settings now use a plan-aware menu layout with About first, followed by Profile and Subscription, dedicated per-section pages, self-profile editing, password-reset access, optional local biometric session unlock, personal-account deletion with two destructive confirmations, association switching between available memberships, sign-out access, and club-admin access to organisation, user, court, and racket-sport visibility controls
- native match setup now respects dark mode styling, uses compact sport-specific headings and dropdown shirt selection for both personal tiers, and supports personal-tier squash/racketball handicap setup
- native match setup uses live player-name headings with compact colour-dot menus, disambiguates matching first names in score cards with surname initials, offers squash/racketball Golden Point and optional timed game breaks, and asks for confirmation before ending a live match early
- native iOS bottom navigation and scoring controls now compact themselves under large Dynamic Type settings to better fit smaller iPhone screens
- native squash/racketball scoring also selects its compact presentation by available width, keeps point rails and warm-up actions within phone bounds, and presents a dedicated completed-match summary when the final point is scored
- native squash/racketball point rails reconcile a manual service-box change into the existing current-score marker, so changing `R2` to `L2` replaces the marker rather than appending a duplicate; automated mobile and backend scenarios cover service transfers, successive server points, undo-style rollback, handedness defaults, game boundaries and exhaustive six-point sequences, a saved credential-free XCUITest verifies the visible `R2` to `L2` to `R3` flow in an Apple Simulator, and an opt-in credential-backed journey creates, completes and logs out from a real Personal Plus test match
- an opt-in credential-backed tennis XCUITest logs in, creates a real singles Best of 3 match, exercises deuce and advantage, reaches 6-6 in set one, completes an extended 8-6 tiebreak, closes the match in straight sets, and logs out; its sport-specific runner keeps credentials out of source control and retains an Xcode result bundle
- native scoring keeps light shirt colours readable with adaptive dark score text, distinguishes a running timer with a light-green control, and uses a pink-accented in-place action sheet with explicit player names for stroke and let choices
- native iOS can reopen a previously loaded active match without connectivity, score squash/racketball or tennis locally, retain queued actions across app restarts, and replay them in order when connectivity returns
- native offline replay preserves actions added while an earlier request is still synchronising and reports the underlying API or network error when an online replay cannot complete
- native tennis scoring is isolated in `TennisScoringReducer.swift` and `TennisScoringPresentation.swift`; shared match code retains loading, timers, networking, and offline queue plumbing
- native tennis scoring includes a point timeline with centred score markers and blue score-only game dividers; new backend/offline tennis point events preserve the point-time server, receiver, Deuce/Ad court, score and game/set boundary for accurate future serve/return statistics
- mobile scoring actions use client-generated UUIDs and backend `match_action_receipts` so reconnect retries cannot apply the same action twice
- organisation-user sessions now carry a server expiry timestamp; the native app discards expired cached sessions and supports Face ID or Touch ID for an unexpired session saved on that device
- the native dashboard replaces its notification bell with an offline indicator while disconnected; online, the bell opens the persisted notification inbox and highlights unread messages in yellow until explicitly marked read
- system notifications are persisted in Postgres, can be published by root admin to all users or a specific plan, and share cross-device read state across web and iOS
- native Help & Feedback includes an in-app privacy and data page, and the iOS target includes a privacy manifest for its required-reason UserDefaults access
- immediate self-service personal-account registration with emailed password setup, controlled club-interest registration, password reset, and feedback email flows
- the public web login and `Want In` registration states omit internal package-version/build details
- the responsive app `/help` route is the single public Help Centre and knowledge base, with web and iPhone registration/sign-in guides, password reset, legal pages, and a footer matching the public website; public landing-page help, privacy, and cookie links route into it rather than maintaining a duplicate landing Help page
- the app client and public landing homepage share the `HitNScore | Every Point. Every Court.` browser title and the same public description metadata
- shared responsive HitnScore HTML branding across password reset, account setup, club invitations and enquiries, and feedback notifications, with plain-text fallbacks
- one authoritative personal entitlement contract is enforced server-side: Personal Free can read its latest three completed matches, while Personal Plus can read its latest 100 and receives performance analytics
- native iOS StoreKit 2 purchasing offers new Personal Plus upgrades through the yearly product only, passes the stable account UUID into StoreKit, submits Apple-signed transaction and app-transaction JWS values to the backend, and finishes server-enabled transactions only after backend acceptance; monthly transactions remain recognized for restore and lifecycle safety, and local Xcode StoreKit testing remains non-authoritative
- authenticated Apple purchase context/verification, App Store Server Notifications V2, renewal/cancellation/grace/refund/expiry processing, hourly App Store Server API reconciliation, automatic plan changes, root-admin subscription activity and append-only entitlement audit are implemented; elapsed subscriptions are reconciled with Apple before a bounded local-expiry fallback so delayed renewal notifications cannot cause temporary entitlement churn; migrations `025`–`027` provide their persistence model
- native Subscription links for logged-in Club Essentials and Club Pro enquiries, capturing full club contact details in the root-admin queue and sending requester/admin acknowledgement emails
- the native login help chooser is vertically centred with a 44-point circular close target; successful personal registration and Ping Us submissions replace their forms with confirmation and next-step screens; Ping Us maps SES delivery failures to a structured API error and uses the verified `hello@hitnscore.com` feedback identity by default
- root-admin UI and supporting backend functions, including system-wide match listing plus root-admin archive/delete controls
- root-admin User Accounts directory across personal and club memberships, with account-type and unverified-user summary filters, user search, visible email-verification warnings, and tabbed user profiles for registered details/last activity, password changes, subscriptions, club associations, scoring activity, and enabled sports
- root-admin user profiles show email-verification state and allow an authenticated root admin to manually verify an account and approve pending memberships for that email without changing its password
- personal accounts are created immediately through self-service registration; only club account enquiries and club membership invitations remain approval-controlled
- root-admin RacketSports controls for separate web and iOS availability lists; the default save changes only platform availability, while a separate affected-user preview and confirmation-protected apply-to-all action remains available, and individual access is assigned from User Accounts or club settings
- expiring backend root-admin session tokens, enforced across all root-admin routes and reused organisation-management routes
- a public database-backed `/health` readiness endpoint, a five-minute scheduled health invocation, and CloudWatch/SNS alarms for API availability/latency and the Apple subscription lifecycle

What is still partial or risky:

- WebSocket broadcast infrastructure is scaffolded but not fully wired
- the current iPhone scoring layout is much improved but still needs final UX hardening before release
- some native settings sections are still UI scaffolds only, including federation-style association links beyond simple membership switching, account-level game-settings presets, and reporting views
- notifications currently use inbox polling; APNs push delivery and background notification badges are not implemented yet
- Apple migration `027`, the Secrets Manager In-App Purchase key, Sandbox and Production V2 URLs, the three-day paid-to-paid grace policy, and `Sandbox,Production` backend routing are deployed; Sandbox V2 delivery is verified, while the Production App Store Server API smoke test remains a mandatory post-release check because Apple rejects it before the first live app release
- Release StoreKit purchasing stays disabled until the verification endpoint has passed Sandbox/TestFlight testing; a local Xcode StoreKit transaction intentionally does not update `personal_plan`
- the production Apple subscription architecture and release gates are documented in `docs/apple-subscription-production.md`; the implementation remains incomplete until its endpoint, notification, reconciliation, admin and audit checklists pass
- native profile photos are still device-local only and are not stored centrally or shared across users/devices yet
- offline behavior remains intentionally scoped: new match creation, scheduled-match activation, historic data, settings changes, and matches not previously opened on that device still require connectivity
- there is no documented iOS CI/archive/release pipeline in the repo yet
- lightweight automated baselines are checked in for backend pytest logic tests,
  Playwright public-route smoke tests, and native iOS UI smoke tests; coverage is
  still a first pass and there is no documented CI pipeline running them

## Repository Layout

- `frontend/`
  - route definitions in `src/App.jsx`
  - auth state in `src/context/AuthContext.jsx`
  - root-admin state in `src/context/RootAdminContext.jsx`
  - match state in `src/context/MatchContext.jsx`
  - HTTP client in `src/services/api.js`
  - browser WebSocket client in `src/services/websocket.js`
- `backend/`
  - Lambda handlers in `functions/*/handler.py`
  - shared backend logic in `common/*.py`
  - sport engines currently split across `common/match_logic.py`, `common/squash_match_logic.py`, `common/tennis_match_logic.py`, a Padel adapter in `common/padel_match_logic.py`, plus placeholder engine files for `table_tennis`, `badminton`, and `pickleball`
  - schema migrations in `schema/*.sql`
  - SAM template in `template.yaml`
- `mobile/`
  - iOS project in `ios/RcktScoreMobile/`
  - mobile-facing shared references in `shared/`
  - offline active-match state and action queue in `ios/RcktScoreMobile/RcktScoreMobile/State/OfflineMatchStore.swift`
  - native tennis rules and score UI in `ios/RcktScoreMobile/RcktScoreMobile/State/TennisScoringReducer.swift` and `ios/RcktScoreMobile/RcktScoreMobile/Views/TennisScoringPresentation.swift`
- `docs/`
  - backend/API reference
  - lifecycle walkthrough
  - troubleshooting
  - mobile notes
  - pricing and packaging notes

## Current Frontend Routes

Defined in [frontend/src/App.jsx](/Users/glennrowe/Development/Projects/RcktScore/frontend/src/App.jsx):

- `/` and `/login`
- `/help`
- `/dashboard`
- `/matches`
- `/history`
- `/notifications`
- `/performance`
- `/settings`
- `/settings/users/:userId`
- `/ping`
- `/match/new`
- `/match/new/setup`
- `/match/:matchId`
- `/scoreboard`
- `/display`
- `/rckscoreAdmin`
- `/rckscoreAdmin/dashboard`
- `/rckscoreAdmin/clubs/:organizationId`
- `/rckscoreAdmin/matches`
- `/rckscoreAdmin/notifications`
- `/rckscoreAdmin/subscriptions`
- `/rckscoreAdmin/racket-sports`
- `/rckscoreAdmin/interests`
- `/rckscoreAdmin/personal-accounts` (legacy alias for User Accounts)
- `/rckscoreAdmin/users`
- `/rckscoreAdmin/users/:userId`

## Current Backend API Groups

Defined in [backend/template.yaml](/Users/glennrowe/Development/Projects/RcktScore/backend/template.yaml):

- authentication and session
- password reset and membership approval
- root-admin operations
- dashboard and organisation settings
- personal profile
- user and court administration
- match setup lookup
- match lifecycle and scoring

See the backend/API reference for the exact route list.

## Security Notes

- org-user session enforcement is real in `backend/common/session_logic.py`
- org-user sessions expire after 30 days by default, configurable from one to 90 days, and cached native sessions cannot be reopened after their server-provided expiry
- reconnect-safe scoring action UUIDs are recorded in `match_action_receipts`; duplicate retries return current match state without repeating the mutation
- scoring and organisation endpoints are tenant-aware through backend authorization checks
- sport visibility is enforced before match creation as the intersection of platform client access, organisation `enabled_sports`, and per-membership web/iOS access
- root-admin login issues an expiring opaque session token whose hash is stored in `root_admin_sessions`; all privileged root-admin routes validate it server-side
- the former `x-root-admin-request` trust-header bypass has been removed
- root-admin authorization is implemented, but public-route rate limiting, broader audit logging, and other launch hardening still remain
- do not describe WebSocket live display as production-complete

## Troubleshooting Entry Points

Use these first:

- [docs/troubleshooting.md](/Users/glennrowe/Development/Projects/RcktScore/docs/troubleshooting.md)
- [docs/backend-api.md](/Users/glennrowe/Development/Projects/RcktScore/docs/backend-api.md)
- [docs/technical-walkthrough.md](/Users/glennrowe/Development/Projects/RcktScore/docs/technical-walkthrough.md)

Fast local verification commands:

```bash
PYTHONPYCACHEPREFIX=/tmp/rcktscore-pyc python3 -m py_compile $(find backend/common backend/functions -name '*.py' | sort)
cd frontend && npm run build -- --outDir /tmp/rcktscore-frontend-dist
```

Additional checked-in test commands:

```bash
pytest -c testing/automated/backend/pytest.ini testing/automated/backend
cd frontend && npm run test:e2e:smoke
testing/automated/mobile/run-tennis-scenarios.sh
testing/automated/mobile/run-racket-point-rail-scenarios.sh
testing/automated/mobile/run-racket-service-side-ui-test.sh
testing/automated/mobile/run-live-racket-match-ui-test.sh
```
