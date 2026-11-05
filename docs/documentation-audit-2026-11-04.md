# HitnScore Documentation Audit

**Naming:** HitnScore is the customer-facing application. `RcktScore` is the internal project and repository code name.

Audit date: 4 November 2026

## Outcome

The repository contains a strong set of current engineering references, but 31
documents need content updates and three dated reports need clearer historical
labelling. The largest drift is caused by Android progressing to M4, the move to
identity-first account context and one retained session per identity, the new
club least-privilege roles, expanded Tournament Manager behavior, Padel and
tennis parity, notification inbox work, Personal Plus match watching, and the
implemented Apple subscription lifecycle.

No existing manual was changed during this audit. The proposed changes below
require approval before implementation.

## Approval Register

### Batch A Authoritative Repository Documents

| Document | Why it is out of date | Proposed change |
| --- | --- | --- |
| `AGENTS.md` | Its stack and repository-layout sections still call Android a foundation with no product features, while the code contains authentication, dashboard, match setup, squash/racketball/tennis/Padel scoring, notifications, analytics, settings, tests, signing, and CI scaffolding. | Replace the Android foundation wording with the implemented M4 boundary and remaining M5/M6/billing gaps. |
| `README.md` | It omits Android, current sport engines, analytics, notifications, subscriptions, Tournament Manager, least-privilege roles, and the expanded test baseline. | Refresh the product summary, gaps, document map, and verification commands. |
| `docs/backend-api.md` | It describes web and iOS as API clients but does not document the implemented Android client or its current online scoring boundary. | Add Android to runtime/client notes and identify its implemented and deferred API use without changing route contracts. |
| `docs/technical-walkthrough.md` | It has no native Android lifecycle section. | Add Android login, context switching, dashboard, setup, online scoring, notifications, analytics, and current offline limitations. |
| `docs/troubleshooting.md` | It lacks native Android build, session, API, and scoring troubleshooting despite a substantial Android app. | Add Android verification and failure-mode sections linked to the Gradle project and current M4 scope. |
| `docs/service-relationships.md` | Its service inventory says Android has no implemented product flows. | Split Apple/iOS and Android rows and describe the Android HTTPS/API boundary accurately. Preserve the file as user-owned until approval. |

### Batch B Mobile Manuals

| Document | Why it is out of date | Proposed change |
| --- | --- | --- |
| `docs/mobile/README.md` | Android is described as a shell with no authentication, backend, scoring, settings, or analytics. | Replace the Android section with the M4 feature boundary and explicit M5/M6/billing gaps. |
| `docs/mobile/android-parity-plan.md` | The introduction and stages say product work remains to be implemented, although stages 2-6 are substantially complete. | Turn it into a progress plan: mark completed milestones, map current code to parity, and retain offline/settings/help/billing/release work as remaining. |
| `docs/mobile/setup.md` | It treats current native scope mainly as iOS and lists deep notification flows as out of scope even though inbox/read state exists on iOS and Android. | Separate iOS and Android scope, clarify push versus inbox notifications, and add Android environment/build references. |
| `docs/mobile/ios-v1-plan.md` | It uses older navigation names, understates Padel, Personal Plus match watching, StoreKit lifecycle, notifications, and the latest native scoring/test work. | Rebaseline the implemented iOS state and narrow the plan to device hardening, release evidence, APNs, placeholders, and remaining offline limits. |
| `docs/mobile/release-notes.md` | It omits Padel from one implemented-sports list, uses older navigation wording, and says StoreKit/server verification remain release work even though the lifecycle is implemented and awaiting final production gates. | Correct feature lists and distinguish implemented subscription infrastructure from outstanding production evidence/configuration. |
| `docs/mobile/signing.md` | It says signing ownership must be finalised before TestFlight even though TestFlight builds and Sandbox purchase tests already exist. | Record the proven TestFlight state and document only the remaining archive, ownership, build-number, App Store Connect, and release steps. |
| `mobile/README.md` | Android is called foundation-only and notifications are called device-local, conflicting with Android M4 and the backend inbox. | Refresh both platform summaries and separate inbox delivery from unimplemented APNs push. |
| `mobile/shared/README.md` | Offline/sync notes are described as future even though offline iOS scoring and idempotent action replay exist. | Convert the folder description into a live reference index and link authoritative implementations. |
| `mobile/shared/api-contracts/README.md` | It lists only recommended future fixture files and omits session status, membership context, analytics, notifications, match watching, subscriptions, and action receipts. | Replace the placeholder list with the current mobile contract map and links to API/client models. |
| `mobile/shared/match-states/README.md` | It is still a placeholder despite multiple sport reducers, offline projection, timers, and compensation-aware replay. | Document the authoritative state sources and supported state families, or explicitly retire the empty reference area. |

### Batch C User Onboarding And Help

| Document | Why it is out of date | Proposed change |
| --- | --- | --- |
| `docs/new-user-onboarding-walkthrough.md` | The diagram still requires an organisation chooser after login, says web/mobile sessions are separate, omits Android, and lists only Squash/Racketball/Tennis. | Update to identity-first login, the retained membership switcher, single retained identity session, Android, and enabled doubles Padel. |
| `docs/knowledge-base/register-and-sign-in-ios.md` | It says multiple memberships always produce Choose Organisation and that web/mobile sessions remain separate. | Explain the default preferred-context login, header/settings switching, legacy chooser fallback, and cross-device session replacement. |
| `docs/knowledge-base/register-and-sign-in-web.md` | It has the same legacy chooser/session model and only mentions an eight-character password minimum. | Update identity-first context behavior, one retained session, current switcher location, and the full password-strength rules. |

### Batch D Testing Manuals

| Document | Why it is out of date | Proposed change |
| --- | --- | --- |
| `docs/Testing-automated-testing-plan.md` | It says Playwright is not declared and presents implemented suites as future Week 1-4 work. It omits the substantial Android tests and newer web/native journeys. | Replace the bootstrap timeline with the checked-in suite inventory, actual commands, coverage gaps, and proposed CI gates. |
| `docs/Testing-web-test-script.md` | It contains legacy `user` terminology, hard-coded test identities, identity-first login assumptions that no longer hold, and overlaps the newer checklist/workbook. | Archive it or consolidate unique scenarios into `testing/manual/web-client-checklist.md`; remove credentials from the canonical manual. |
| `testing/README.md` | It describes only web/backend automation and starter-scale targets. | Add native iOS and Android automation, current suite locations, and the real verification entry points. |
| `testing/automated/README.md` | It lists only web and backend responsibilities. | Add mobile reducer/UI and Android unit/Compose coverage. |
| `testing/automated/backend/README.md` | It still reads as a first-test bootstrap guide despite a broad checked-in backend suite. | Add current suite scope, migration/authorization/scoring emphasis, and maintenance guidance. |
| `testing/manual/ui-ux-checklist.md` | It is too generic for the current product and omits role variants, Analytics, notifications, Tournament Manager, all four implemented sports, account switching, historic views, and constrained landscape scorer shells. | Expand it into a short current smoke checklist while keeping the detailed web checklist separate. |
| `testing/manual/HitnScore-Web-Testing-Workbook.docx` | Prepared 15 October, it still expects a login-time organisation chooser and a separate profile icon; later identity-first, role, header, Tournament, and session changes are missing. | Produce a revised workbook after the Markdown source checklist is approved, preserving its result-sheet format and re-rendering every page. |

### Batch E Product And Implementation References

| Document | Why it is out of date | Proposed change |
| --- | --- | --- |
| `docs/app-store-subscription-production.md` | Its production path still says to add reconciliation although hourly reconciliation and lifecycle processing are implemented. | Reword implemented steps as current controls and leave only configuration/evidence gates as future work. |
| `docs/feature-payments-structure.md` | It predates least-privilege roles, expanded Tournament Manager, Personal Plus match watching, newer analytics, Android M4, and the implemented Apple lifecycle. | Re-audit the packaging matrix against `plan_entitlements.py`, role capabilities, and current platform surfaces. |
| `docs/hitnscore-capability-and-access-inventory-2026-10-23.md` | It explicitly records the old `user/admin` model as current and proposes a read-only role that migration 045 has since implemented. It also predates Android M4 and later tournament/session/header changes. | Preserve it as a dated snapshot and create a superseding current inventory, or revise it with a new review date and change log. |
| `docs/tournament-module-discovery.md` | Large portions are still written as conceptual gaps or future phases even though draw publication, knockout/plate/Monrad progression, scheduling, outcomes, public access, permissions, and corrections are implemented. | Keep the architectural rationale, add an implemented-state map, and move genuinely undecided/unfinished items into a remaining-work section. |
| `docs/scoreboard-v1-implementation.md` | It still ends with a post-V1 testing next step although the court-display flow is now an established product path. | Convert the spec into a current operations/contract reference and verify limitations against today’s display implementation. |

### Batch F Historical Labelling

These documents should not be rewritten to match today because they are dated
evidence. Approval would add a short archive banner and links to current sources:

- `docs/production-readiness-and-personal-plus-review-2026-09-08.md`
- `docs/public-website-review-2026-09-10.md`
- `testing/reports/HitnScore-Production-Release-Readiness-and-Four-Day-Plan-2026-09-11.docx`

The Apple Sandbox report should remain unchanged as test evidence:

- `testing/reports/RcktScore-Apple-Subscription-Sandbox-Test-Report-2026-09-11.docx`

## Documents Assessed As Current

No content update is proposed for these files in this pass:

- `docs/apple-subscription-production.md`
- `docs/mobile/build.md`
- `docs/promotion-runbook.md`
- `docs/weblanding-aws-godaddy-deployment.md`
- `mobile/android/README.md`
- `mobile/ios/README.md`
- `mobile/ios/RcktScoreMobile/RcktScoreMobileUITests/README.md`
- `testing/automated/mobile/README.md`
- `testing/automated/web/README.md`
- `testing/fixtures/README.md`
- `testing/manual/README.md`
- `testing/manual/web-client-checklist.md`
- `weblanding/README.md`

## Review Method And Limits

The audit compared repository documents with the current operating guide,
backend route/template structure, migration set, web package scripts, native iOS
and Android source trees, and checked-in test runners. The three Word documents
were rendered and visually inspected; their layouts are readable, and the stale
finding for the workbook is about content rather than formatting.

This was a static repository review. It did not verify deployed AWS, Supabase,
App Store Connect, Google Play Console, GoDaddy, or live production settings.
