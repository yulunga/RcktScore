# RcktScore Feature Packaging and Current Entitlements

## Purpose

This document maps the current code-backed product capabilities to pricing and packaging conversations.

It is intentionally split into:

1. what is implemented now
2. what is proposed but not implemented yet

This document should not promise features that only exist as UI scaffolds or roadmap ideas.

## Current Code-Backed Product Capabilities

### Shared foundations

Current code supports:

- org-user login with backend session tokens
- multiple organisation memberships for one email address
- protected dashboard, matches, history, settings, match setup, and match scoring routes
- public single-match display route
- event-sourced match history through `matches` and `match_events`

### Match operations

Current match/scoring capabilities include:

- create active match
- create scheduled match when a court already has an active match
- activate scheduled match
- score point
- event actions:
  - let
  - stroke
  - server
  - serve_side
  - match_settings
  - timer
- undo last action
- manual match end

### Administration

Club administration currently supports:

- organisation detail maintenance
- organisation-user invite/create
- organisation-user role update
- court create/update/delete
- player/referee lookup based on prior match data and org-user usernames

Root-admin functionality currently supports:

- root-admin login
- root-admin dashboard
- club creation
- club search
- root-admin organisation-user creation/update
- interest-request review
- personal-account review

Important qualification:

- root-admin security is not fully production-ready yet

### Display and realtime

Current display capability:

- public `/display?match=...` route
- scoreboard rendering
- optional timeline rendering

Current limitation:

- WebSocket client code exists, but the infrastructure is still partial
- do not commercially promise production-grade realtime display yet

## Current Entitlement Behavior In Code

### Personal free

Currently enforced in code:

- one active personal match at a time
- dashboard/history returns the last `3` completed matches
- no shirt-colour selection entitlement

### Personal plus

Currently enforced in code:

- same personal-account model as personal free
- dashboard/history returns the last `12` completed matches
- shirt-colour selection is enabled

Important:

- earlier drafts that described `100` retained matches do not match the current code

### Club plans

Currently represented in code:

- club organisations default to `club_essentials`
- clubs can create and manage courts and users
- clubs can use shirt colours
- clubs can use active and scheduled matches

Currently not enforced as hard limits:

- max courts
- max users
- max active matches
- max scheduled matches
- pro-tier concurrency or SLA behavior

## Current Pricing-Safe Claims

These are safe to describe as implemented today:

- Personal accounts exist as hidden single-user organisations
- Personal free has reduced match-history access
- Personal plus unlocks deeper history than personal free and shirt colours
- Clubs have multi-user workspace, court management, and club match operations
- Public display route exists

## Not Yet Safe To Promise As Fully Implemented

- enterprise-grade root-admin security
- guaranteed realtime display
- persisted organisation-level game settings
- persisted social profiles
- dedicated player registry/CRM
- advanced analytics and reporting
- exports/downloadable reports
- hard plan guardrails for club scale

## Suggested Tier Framing Based On Current Code

### Personal free

- one active match
- limited match history
- core scoring

### Personal plus

- everything in personal free
- more retained history than personal free
- shirt-colour selection

### Club essentials

- multi-user club workspace
- court management
- club scoring operations
- scheduled matches
- public display route

### Club pro

This is still mostly a commercial shell rather than a code-enforced tier.
The repo does not yet contain strong club-pro enforcement logic.

## Recommended Commercial Cautions

- talk about the display route, but avoid a hard realtime promise
- talk about root-admin tooling carefully until backend auth is completed
- do not market scaffold-only settings as launch-ready features
- if pricing copy references personal-plus history depth, use the current code-backed limit, not older planning numbers

## Next Product and Commercial Work

1. Decide the true plan limits for:
   - history retention
   - courts
   - users
   - active matches
   - scheduled matches
2. Implement those limits server-side.
3. Decide whether player management remains lookup/history-based or becomes a real CRUD module.
4. Complete root-admin backend auth before positioning the admin surface as production-grade.
5. Complete WebSocket infrastructure before selling realtime display as a premium reliability feature.
