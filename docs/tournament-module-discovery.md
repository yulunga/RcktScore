# Tournament Manager Discovery and Architecture

## Status

This document began as an architectural discovery note. The first web-only
foundation is now implemented: per-club feature access, draft tournament CRUD,
product-wide player identities, guest/member affiliations and singles entry capture.
Draw generation, fixtures, scheduling, live tournament views and iOS support are
not implemented yet.

The intended initial release posture is:

- club organisations only
- disabled for each organisation by default
- selectively enabled by a root administrator for development and beta clubs
- enabled for the seeded `Demo Club` test organisation
- no tournament entry point in the normal web or iOS navigation while disabled
- the existing HitNScore match-scoring experience remains the primary product

## Product Position

Tournament Manager should be a layer above HitNScore scoring, not a replacement
for it and not a new scoring engine.

The module owns entrants, draws, fixtures, scheduling, standings and progression.
When a fixture is ready to be played, it launches or links to an ordinary
HitNScore match. The current sport engine remains authoritative for point-by-point
scoring. The tournament module consumes a completed result and advances the draw
or recalculates standings.

This separation keeps normal club scoring fast and uncluttered. A club member who
only wants to score a match should not need to enter a tournament workflow.

## What the Existing Product Can Reuse

The current backend already provides useful foundations:

- organisation tenancy and expiring authenticated sessions
- club administrators, users and courts
- sport availability at platform, organisation and membership level
- active, scheduled and completed matches
- squash, racketball, tennis and Padel scoring engines
- event timelines, undo and idempotent mobile action receipts
- match duration and result summaries
- single-court public display sessions
- persisted notification inbox messages
- root-admin authentication and organisation management
- email delivery infrastructure

These capabilities reduce the work needed for scoring a tournament fixture, but
they do not yet form a tournament system.

## Important Current Gaps

### Participant identity

Players are currently recorded as names on each match. Tournament operations need
stable participant identities so the system can detect repeat pairings, retain a
seed or rating, form doubles pairs, process withdrawals and produce history.

A participant must not be assumed to be a HitNScore login. It should optionally
link to an organisation user while also supporting guests, juniors and imported
players. Public-facing names and personal/contact details should be separated.

### Tournament scheduling

The existing `scheduled` match status is a queue state. It has no planned start,
time slot, minimum rest rule, player conflict check, estimated duration or rolling
reschedule model. Tournament fixtures therefore need their own planning state and
should create or attach an ordinary scoring match only when appropriate.

### Roles and permissions

Organisation memberships currently use `admin` and `user`. Tournament permissions
need event-scoped assignments such as organiser, desk official, scorer and
referee/marker. An entrant is not automatically authorised to edit a result, and
a public spectator does not require a membership.

### Public live experience

The current public display is for a court or individual match. There is no public
tournament page, published draw, event QR token or tournament-level live feed.
WebSocket infrastructure is not yet production-complete, and notifications are
currently inbox-polled rather than APNs push notifications.

### Audit and corrections

Match events provide a scoring history, but draw generation, manual seeding,
withdrawals, result overrides and progression changes need a separate append-only
audit trail. Correcting a result after a dependent fixture has started cannot be
handled as an ordinary silent recalculation.

### Exports and imports

There is no current player registry, ranking import, draw export, print layout or
tournament history export.

## Implemented Feature Gating

A club-level `tournament_organization_features` record currently controls web
access. Missing records mean disabled. Root admin can enable or disable the
feature from the existing club administration screen. iOS remains unavailable.

A future platform rollout mode (`off`, `allowlist` or `all`) can be added before
broad commercial release if a second kill switch is required.

Effective access should require all of the following:

- the organisation is a club, never a personal account
- the platform rollout permits the organisation
- the organisation has the feature enabled
- its club plan is entitled once commercial packaging is decided
- the requesting membership has the required operation permission

Initial data creates no enabled records for existing clubs. Migration `031`
creates an enabled Demo Club. Disabling access hides the entry point and rejects
direct API access without deleting tournament data.

Feature checks must be enforced in the backend. Hiding a web or iOS menu item is
not an entitlement boundary.

## Recommended Domain Model

The initial tables below are implemented in migration `030`; later draw and
scheduling tables remain conceptual.

### Feature control

- `tournament_organization_features`: organisation, web-enabled state and audit
  timestamps

### People and entries

- `users`: canonical signed-up identity keyed by normalized email; the existing
  `SkwshOrgUsers` rows remain organisation memberships/credentials and are linked
  through `user_id` during the compatibility migration
- `players`: product-wide stable person record, optional linked
  membership, display identity, contact/privacy fields and external ranking IDs
- `tournament_entries`: an entry in an event, with status, seed,
  registration source and waitlist position
- `player_organization_affiliations`: non-authentication member/guest relationship
  between a reusable player and the host club
- participant and entry snapshots so a later profile edit does not rewrite a
  published historic draw

Partner changes should create a revised entry membership record and audit event.
They should not mutate completed fixture history.

The first slice links registered emails to `users` but does not yet attach player
IDs to ordinary `matches`. That scoring/history migration is a later identity
phase and must cover tennis/Padel doubles as well as singles.

### Event structure

- `tournaments`: club, name, venue/time zone, registration window, lifecycle
  state and public visibility
- `tournament_divisions`: sport, category, gender/open classification, grade,
  age/handicap rules and entry limits
- `tournament_stages`: ordered knockout, plate, Monrad or round-robin stage with a
  versioned format and scoring configuration
- `tournament_rounds`: stage round number, label and publication state
- `tournament_draw_versions`: deterministic random seed, input/config snapshot,
  generated structure, constraint warnings and publish/supersede metadata
- `tournament_fixtures`: stable fixture identity, round, status, planned time,
  court, sides, result and progression references
- `tournament_match_links`: one tournament fixture linked to the ordinary
  HitNScore scoring match used to play it

Keep bracket dependencies in the tournament model. A future slot should refer to
the winner or loser of another fixture rather than copying a player name before
that participant is known.

### Operations

- `tournament_role_assignments`: event-scoped organiser, scorer and official roles
- `tournament_official_assignments`: optional referee/marker assignment per fixture
- `tournament_availability`: participant and court availability constraints
- `tournament_audit_events`: append-only commands and before/after metadata
- `tournament_notifications`: scheduled and delivered tournament notices with
  channel status
- standings should be a reproducible projection from fixture results; persisted
  snapshots may be added for publication and performance, but must be rebuildable

All mutable resources should carry a revision or version number for optimistic
concurrency. Create/result commands should accept idempotency keys.

## Draw Formats

### Knockout

Supported design:

- calculate the next bracket size at or above the entry count
- represent byes explicitly and assign them according to seed policy
- place seeded entries into separated bracket regions
- randomise unseeded entries with a stored random seed so a draw is reproducible
- treat club/nation separation as a constraint with an explicit priority order
- optionally generate a third-place fixture from semifinal losers

Club/nation separation cannot always be satisfied simultaneously with seeding.
The generator must report relaxed constraints instead of silently presenting the
draw as fully compliant.

### Knockout with plate

The plate should be a separate stage linked to its parent stage. Its eligibility
policy should be snapshotted when the draw is published:

- first-round losers only, or
- losers from the first two rounds

The model must also define whether a first-round bye followed by a loss counts as
a first-match loser, when plate registration closes, and whether entry is
automatic or requires confirmation. Withdrawals before plate publication should
remove the entry; later withdrawals should produce an explicit walkover or bye
according to the stage state.

### Monrad

Monrad needs a pairing service rather than a static bracket generator:

- fixed round count declared before play
- seeded or random first round
- later score-group pairing based on current standings
- no repeat opponents where possible
- fair bye allocation, normally excluding anyone who already received a bye
- deterministic fallback order when a perfect no-rematch pairing is impossible
- recorded explanation of every relaxed pairing constraint

Recommended fallback sequence:

1. pair within score groups with no repeat
2. float the lowest/highest suitable entry to an adjacent score group
3. search alternative pairings across the affected groups
4. permit the least harmful repeat only when no valid arrangement exists

The exact ordering of floats and repeat penalties is a product rule and must be
confirmed before implementation.

### Round robin

The circle method is suitable for fixture generation. For an odd field, a dummy
slot produces one bye per round. Each pool has `N(N-1)/2` fixtures and `N-1`
rounds for even fields or `N` for odd fields.

In round robin, seeds cannot literally meet later because every entrant meets
every other entrant. Seeding has two useful meanings instead:

- distribute seeds across different pools, and
- order a pool's fixture list so the strongest projected match occurs later.

The design also needs a rule for progression from pools into a later knockout
stage, including qualifier count, cross-pool seed placement and ties at the
qualification boundary.

## Standings and Outcomes

Standings rules must be versioned per stage. A configurable sequence can include:

- league points
- head-to-head result
- matches won/lost
- games or sets difference
- points difference
- opponents' match/league points (strength of schedule)
- a documented final fallback such as seed, playoff or supervised draw

Head-to-head needs special handling for a multi-player tie; applying a two-player
rule to a three-way tie can produce contradictory results.

Fixture outcomes should distinguish at least:

- played result
- walkover
- retirement
- default/no-show
- conduct default
- cancelled/void
- bye

Each scoring profile must define how these outcomes affect progression,
league points and game/point statistics. A walkover should not be represented as
invented point scores.

## Sport-Specific Scoring

Tournament configuration should select a versioned scoring profile understood by
the relevant HitNScore sport engine. It should not expose options that the engine
cannot enforce.

The first implementation can reuse currently supported squash, racketball,
tennis and Padel settings. Broader requirements such as arbitrary rally versus
service scoring, additional tiebreak systems and new sports require explicit
engine work before Tournament Manager can offer them.

The generic tournament result model should store games/sets and points without
assuming that every sport uses `points per game`. Tennis and Padel require their
own set/game/tiebreak semantics.

## Result Propagation and Corrections

Recommended safety rules:

1. A completed linked HitNScore match submits a versioned fixture result.
2. The tournament service validates the result against the stage scoring profile.
3. It updates standings or resolves dependent winner/loser slots transactionally.
4. If a result is corrected before dependent fixtures start, affected future
   slots and schedules can update automatically and an audit event is recorded.
5. If a dependent fixture has started or completed, progression is frozen. The
   organiser receives an explicit conflict workflow with choices such as reject
   the correction, void/replay affected fixtures, or apply an authorised manual
   override.

Never silently replace participants in an in-progress downstream match.

## Scheduling Design

Scheduling should remain separate from draw generation. A fixture exists before
it has a court or time.

The scheduler needs:

- venue time zone and playable windows
- court availability and sport compatibility
- participant availability and no double-booking
- configurable minimum rest
- estimated duration by sport/scoring profile and optional division override
- fixed/manual assignments that automation cannot move
- referee/marker availability
- dependency readiness for knockout fixtures
- reschedule reasons and audit history

Start with a validation-assisted manual scheduler. Fully automatic rolling
optimisation is substantially more complex and should follow only after the
constraint model and real club workflows are proven. An overrun can initially
produce conflict warnings and suggested moves rather than automatically changing
many published fixtures.

## Requirements Not Yet Explicitly Decided

The supplied scope also needs decisions on:

- whether Tournament Manager belongs to Club Essentials, Club Pro, or an add-on
- maximum entries, divisions, courts and concurrent tournaments by plan
- multi-venue and multi-day events
- registration fees, refunds, waivers and consent; payments are best kept out of
  the first backend release
- junior entrants, guardian contact and public-name privacy
- check-in, late arrival and waitlist promotion cut-offs
- late entries and whether a published draw can be regenerated
- participant availability and self-withdrawal permissions
- rating providers, import format, duplicate matching and import provenance
- pool-to-knockout qualification rules
- Monrad bye points and exact fallback policy
- tie resolution when head-to-head cannot resolve a multi-way tie
- whether players may submit provisional results and who confirms them
- protest/appeal and result-lock windows
- notification channels and opt-out preferences
- data retention, deletion and public-result privacy
- printable formats, CSV/PDF exports and external federation reporting
- team competitions made of multiple rubbers; this is distinct from individual
  doubles and should be treated as a later module unless explicitly required

## Recommended Delivery Sequence

### Phase 0: contracts and disabled foundation — implemented baseline

- agree lifecycle states, permissions, scoring-profile contract and plan policy
- add club-level feature gating, defaulted off
- add a root-admin per-club web enable/disable control
- add reusable players, player affiliations, events, entries, tournament roles and
  audit tables
- add backend authorization helpers and CRUD for draft tournaments and entries
- expose the web entry point only in Settings for an enabled club; keep iOS hidden

The remaining structural tables for divisions, stages, rounds, fixtures, match
links and immutable draw versions move into Phase 1 with the draw engine.

This is the safest pre-launch backend/database target.

### Phase 1: first usable beta

- singles only
- one venue and one organisation
- knockout and single-pool round robin
- deterministic draw preview, validation and explicit publish step
- manual fixture court/time assignment with conflict warnings
- launch/link an existing HitNScore match and ingest its completed result
- safe pre-start result correction and full tournament audit trail

### Phase 2: operational depth

- pools of three to six and pool-to-knockout progression
- plate stages and withdrawal handling
- registration, check-in and waitlists
- event roles and scorer/referee permissions
- public read-only tournament page and QR code
- email/inbox notices; APNs only when platform push support exists
- basic CSV and print/PDF output

### Phase 3: advanced competition

- Monrad pairings and standings-strength tiebreakers
- doubles and mixed pairs, controlled partner replacement
- assisted rolling rescheduling and referee allocation
- ranking imports and richer player history
- advanced correction/protest workflows

## Suggested First Backend API Shape

Keep tournament endpoints under a distinct namespace, for example:

- `GET/POST /organizations/{organization_id}/tournaments`
- `GET/PUT /tournaments/{tournament_id}`
- `POST /tournaments/{tournament_id}/divisions`
- `POST /tournament_divisions/{division_id}/entries`
- `POST /tournament_stages/{stage_id}/draw/preview`
- `POST /tournament_stages/{stage_id}/draw/publish`
- `GET /tournament_stages/{stage_id}/fixtures`
- `PUT /tournament_fixtures/{fixture_id}/schedule`
- `POST /tournament_fixtures/{fixture_id}/scoring-match`
- `POST /tournament_fixtures/{fixture_id}/result-override`

Preview endpoints should have no side effects. Publishing should require the
latest revision and create an immutable draw version. Every mutation should be
tenant-authorised, role-authorised and audited.

## Validation Strategy

Draw logic should be implemented as deterministic pure functions outside Lambda
handlers. Tests should cover examples and invariants, including:

- every eligible entry appears exactly once in a knockout round
- byes and seeds are placed according to the selected policy
- no fixture contains the same entry on both sides
- round-robin pair counts and bye counts are exact for odd/even fields
- no pair repeats in a round-robin stage
- Monrad never repeats or duplicates a participant unless the recorded fallback
  explicitly permits it
- nobody receives a second Monrad bye while an eligible zero-bye entrant exists
- rebuilding standings from the same results produces the same ordering
- result correction either updates only safe downstream fixtures or raises a
  dependency conflict
- cross-tenant access is rejected
- disabled feature access is rejected even when an endpoint is called directly

Property-based tests are particularly valuable for arbitrary field sizes and
non-power-of-two draws.

## Current Recommendation

Do not try to deliver the complete supplied feature list before the imminent web
and iOS launch. Implement the disabled data and entitlement foundation first,
then prove a singles knockout/round-robin beta with selected clubs. This protects
the scoring launch, keeps Tournament Manager secondary in the UI and prevents
early schema shortcuts from making Monrad, doubles and safe result correction
unnecessarily difficult later.
