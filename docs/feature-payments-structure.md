# RcktScore Feature Packaging for Pricing Tiers

## Purpose

This document maps current, code-backed product capabilities into commercial tiers so pricing can be modelled and discussed with stakeholders.

It is intentionally split into:

1. **What exists now** (safe to price immediately)
2. **What is proposed but not yet implemented** (requires product/engineering work)

---

## Current Capability Snapshot (Code-Backed)

### Individual and Club Access Foundations

- The login flow supports organisation users, including users attached to multiple organisations with an organisation-selection step. This supports both personal-like and club-like account experiences from one auth flow.
- The app provides protected routes for dashboard, settings, match setup, and match scoring, plus a public display route.
- Match operations include start, score point, event actions (for example let/stroke/service side), undo, and manual end of match.
- Match history already exists in the data model (`matches`, `match_events`) and is surfaced on dashboard views (`active`, `scheduled`, `recent`).

### Club Administration Foundations

- Club administration currently supports:
  - organisation details maintenance
  - organisation user creation and role updates (`admin`, `user`)
  - court create/update/delete
- Root administration supports multi-club operations:
  - tenant club creation
  - club search/directory
  - cross-club user management

### Display / External Screen Foundation

- A standalone public display route (`/display?match=...`) exists with scoreboard-first rendering and optional event timeline.
- Frontend includes WebSocket client hooks, but realtime infrastructure is explicitly incomplete in deployment. Current reliable experience should be treated as fetch + partial realtime support.

---

## Recommended Commercial Tier Definition

## 1) Personal (Free)

### Suggested Included Features

- Create and score matches for personal use.
- View current scoreboards and completed match summaries.
- Personal historical retention: **last 3 completed matches**.

### Implementation Notes

- Retention is enforced server-side through the dashboard API.
- Personal accounts are represented as hidden single-user organisations so they can later be upgraded or attached to a club without changing the auth model.
- Personal organisation IDs are allocated from the 50000+ range.
- Current first release keeps all data in storage, but API returns only latest 3 for Personal users.
- Later hard-retention option: scheduled purge/archive job by account plan.

### Positioning

- Entry point for individuals and casual players.
- Designed to drive upgrade into Personal+.

---

## 2) Personal+

### Suggested Included Features

- Everything in Personal.
- Personal historical retention: **last 100 completed matches**.
- Candidate premium features (to decide in product discovery):
  - richer match stats/history filtering
  - export/download of match history
  - saved player profiles / favourites

### Implementation Notes

- Same pattern as Personal: historical-return limits are enforced by plan at API layer.
- Keep feature flags plan-based so additional premium features can be added without reworking core auth.
- Match filtering, saved players, exports, and lightweight stats remain planned implementation items.

### Positioning

- Serious individual players and coaches needing deeper history.

---

## 3) Club Essentials

### Suggested Included Features

- Multi-user club workspace.
- Court management.
- Club user and role management.
- Player management and match operations across club courts.
- External display capability for live scoreboards.

### Implementation Notes

- Court/user management is already present and should be explicitly bundled here.
- “Player management” should be defined more formally (currently player data is match-entry centric; not yet a dedicated player module).
- External display is already present as route capability; realtime reliability/latency expectations should be documented by tier while WebSocket infra remains partial.

### Positioning

- Small-to-mid clubs that need core operational tooling.

---

## 4) Club Pro

### Suggested Included Features

- Everything in Club Essentials.
- Designed for larger clubs with **more than 8 courts** and higher staff/operator volume.
- Priority capabilities to attach here:
  - higher usage and concurrency limits
  - advanced reporting and club analytics
  - optional priority support/SLA
  - future realtime-first display package (when infrastructure completes)

### Implementation Notes

- Define Pro primarily with measurable entitlements:
  - max courts
  - max users
  - max active/scheduled matches
  - data retention window
- Since dashboard and settings already expose court/user counts, usage guardrails can be added with low UX disruption.

### Positioning

- Multi-court venues and tournament-heavy operations requiring scale and governance.

---

## Proposed Tier Matrix (Draft)

| Capability | Personal | Personal+ | Club Essentials | Club Pro |
|---|---:|---:|---:|---:|
| Match scoring (core) | ✅ | ✅ | ✅ | ✅ |
| Historic matches retained | 3 | 100 | Club policy | Extended club policy |
| Court management | ❌ | ❌ | ✅ | ✅ |
| Multi-user organisation roles | ❌ | ❌ | ✅ | ✅ |
| Public display screen | Limited | Limited | ✅ | ✅ |
| Large club scale (>8 courts) | ❌ | ❌ | Limited | ✅ |
| Advanced analytics/reporting | ❌ | Candidate | Candidate | ✅ (target) |

> Note: “Limited” means feature exists technically but should be constrained by policy/plan limits.

---

## Gaps to Close Before Pricing Launch

1. **Plan/entitlement model**
   - Source of truth now exists on organisation records via `org_type` and `plan`.
2. **Server-side enforcement**
   - Personal match-history limits are enforced in the dashboard query/service layer.
   - Saved-player limits, export permissions, and advanced filtering limits still need dedicated endpoints.
3. **Personal vs Club identity model**
   - Personal users are modelled as hidden single-user organisations.
4. **Player management scope**
   - Define whether this is lightweight lookup/history reuse or a full CRUD player registry.
5. **Realtime promise by tier**
   - Avoid “live realtime guaranteed” language until WebSocket infra is production-complete.

---

## Suggested Next Steps (Commercial + Product)

1. Confirm entitlement boundaries for each tier:
   - history retention
   - courts
   - users
   - active matches
2. Decide one billing metric for clubs (for example by court-count band, user-count band, or blended).
3. Lock “Personal+ premium feature set v1” (1–2 meaningful value adds beyond retention).
4. Implement backend enforcement and plan-aware API responses.
5. Update marketing copy and in-app upgrade prompts using this matrix as source.

---

## Working Assumptions

- Current codebase already supports the operational core needed for all four tiers.
- Main remaining work is **commercial packaging + entitlement enforcement**, not greenfield feature construction.
