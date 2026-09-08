# RcktScore production readiness, web parity and Personal Plus review

**Review date:** 8 September 2026  
**Scope:** current local repository, delivery documentation, web responsiveness,
native iPhone/iPad posture, backend/root administration and current premium
racket-sport market patterns.

## Executive decision

RcktScore has moved beyond prototype stage and is a credible **late-beta
product**. The main journeys exist: registration and verification, secure user
and root-admin sessions, personal and club accounts, user/club/court controls,
match creation and scoring, history, native offline continuation, and an active
TestFlight path.

It is **not yet production-ready as a complete web + iPhone + iPad service**.
Feature implementation is approximately **75–80% of a deliberately narrow v1**,
but production readiness is closer to **55–60%** because automated release
gates, operational monitoring, billing lifecycle, broad device regression and
several important web/native inconsistencies are unfinished. Overall, use
**about 65% complete** as the planning headline—not as a code-volume metric.

With one focused developer, a realistic planning range is:

- **6–10 focused development weeks** for a controlled production v1 limited to
  squash, racketball and tennis, with existing offline scope and no promise of
  realtime push notifications.
- **12–20+ weeks** if “production” also includes fully live WebSockets, backend
  push notifications, strong iPad-specific layouts, mature subscription billing,
  richer Plus analytics and complete automated cross-client regression.

These are scope-based estimates, not delivery commitments; App Review and
defect discovery can extend them.

## Readiness scorecard

| Area | Current position | Readiness | Main reason it is not 100% |
|---|---|---:|---|
| Backend scoring and core API | Strong late beta | 75% | Narrow integration/load coverage; realtime incomplete |
| Root/system administration | Functional | 72% | No billing operations, limited audit trail and coarse root role |
| Web client | Functional beta | 65% | Tennis and subscription parity gaps; authenticated responsive QA is thin |
| Native iPhone | Advanced beta/TestFlight | 75% | Final scoring, lifecycle, offline and accessibility regression remains |
| Native iPad | Compatible, not hardened | 55% | Targeted by the project but lacks an iPad-specific QA/layout sign-off |
| Security and privacy | Material controls present | 62% | Rate limiting, restrictive CORS, security testing and operational audit gaps |
| Reliability/operations | Early | 42% | No monitored CI/CD gate, alarms/tracing/runbooks, restore or rollback drill |
| Subscriptions/revenue | Entitlement shell only | 25% | No StoreKit purchase, server verification, renewal/refund/grace handling |

## What is already production-shaped

- Server-side tenant-aware organisation sessions and expiring, opaque root-admin
  sessions are implemented; the former trust-header bypass is gone.
- Personal registration, email verification/password setup, help feedback and
  controlled club enquiry flows exist.
- Root administration covers clubs, users, unverified users, associations,
  personal plans, enabled sports and match oversight.
- Squash/racketball are established and tennis now has a separate backend and
  native reducer/presentation, including deuce, no-ad, tiebreak and doubles work.
- Native iOS can reopen a previously loaded active match, queue UUID-labelled
  actions offline and replay them without duplicating points.
- Native biometric session unlock, expiry enforcement, account deletion and an
  in-app privacy surface are present.
- The current Vite production build, Python syntax compile, native tennis
  scenarios and iOS simulator build all pass.

## Release blockers and recommended order

### P0 — required before taking paying production users

1. **Create a repeatable release gate.** Add CI that installs pinned dependencies
   and runs backend tests, web unit/integration tests, Playwright at phone/tablet/
   desktop widths, the native scenario harness, and an Xcode build/test. Today the
   documented Pytest and Playwright commands require manual setup and Amplify only
   builds the frontend.
2. **Implement subscription lifecycle end to end.** StoreKit 2 purchase and
   restore, App Store product configuration, backend transaction verification,
   App Store Server Notifications, entitlement expiry/refund/grace handling,
   and an admin-visible audit trail are all still required. Apple requires IAP
   for consumer digital feature unlocks and requires subscribed features to work
   across the user’s devices ([Apple guidelines](https://developer.apple.com/app-store/review/guidelines/)).
3. **Make entitlements accurate everywhere.** Remove the web claim of 100 matches,
   saved players, filters, stats and export until implemented. The code currently
   grants 3 completed matches to Free and 12 to Plus. Decide one product contract,
   enforce it server-side, and make web/iOS/admin copy derive from it.
4. **Close tennis cross-client parity.** Web match setup and scoring must support
   the same singles/doubles metadata, no-ad option, final-set 10-point tiebreak,
   service/receiver rotation and completion behaviour as backend/native. Add
   shared scenario fixtures run against both implementations.
5. **Operational protection.** Restrict production CORS to owned origins; add
   rate limits/WAF controls to public auth, registration, reset and feedback;
   central structured logs, request correlation, alarms for errors/latency/email
   failures, and a documented incident/rollback path. AWS recommends alarms and
   structured logging for Lambda workloads ([AWS Lambda guidance](https://docs.aws.amazon.com/lambda/latest/dg/best-practices.html)).
6. **Data resilience.** Document migration promotion, Supabase backup retention,
   point-in-time recovery availability, restore testing, data export/deletion,
   and what happens to match/audit records when an account is deleted.
7. **Device and accessibility sign-off.** Run the real app on supported small and
   large iPhones and representative iPads, both orientations, light/dark mode,
   Dynamic Type, VoiceOver, lock/background transitions, Airplane Mode, restart,
   session expiry and reconnect after a long action queue.
8. **App Store completeness.** Final public privacy policy URL and disclosures,
   support/marketing URLs, screenshots for every required device class,
   subscription terms, restore purchases, review account/instructions and an
   archive/sign/upload/release runbook.

### P1 — complete immediately after the controlled v1 boundary

- Wire WebSocket live updates fully or explicitly label display refresh as
  polling/beta; do not promise realtime until reconnect and ordering are proven.
- Replace the local-only welcome notification with backend notifications, push
  delivery and cross-device read state if notifications are part of launch copy.
- Add root-admin audit events for plan, password, verification, membership,
  deletion and sport-setting changes, with actor, target, timestamp and request ID.
- Split root access into least-privilege support, club-operations and billing
  roles before adding more administrators.
- Add dependency/security scanning, API authorization matrix tests, load tests
  around database connections and scoring bursts, and an independent security
  review.
- Add product analytics and consent-aware funnel events before selling Plus; a
  subscription cannot be improved if exposure, trial, conversion and churn are
  invisible.

## Web versus native iOS parity

| Capability | Native iOS today | Web today | Required decision/action |
|---|---|---|---|
| Login/session | Password, membership selection, biometric restore, cached unexpired device session | Online password/session | Biometrics are native-only by design; ensure refresh/session-expiry tests on web |
| Offline scoring | Cached previously opened active match, durable UUID queue, replay | No offline match/action queue | Keep native-only for v1 or deliberately fund a PWA queue; do not imply web offline support |
| Sports | Squash, racketball and richer dedicated tennis | Same sport entry points, but generic tennis setup/scorer | P0 parity for all server-supported tennis rules |
| Tennis doubles/serve | Dedicated native metadata, reducer and presentation | No matching doubles/no-ad/final-match-tiebreak controls found | Port setup and presentation; share scenario fixtures |
| Shirt colours | Available to Personal Free and Plus | Personal Free is blocked in setup and live settings | Fix web entitlement to match the agreed product |
| Club subscription enquiry | Structured club name/address/postcode/email/site/phone request | Generic Ping Us message with a preset category | Reuse the structured backend enquiry and fields on web |
| Notifications | Local welcome notice, unread yellow bell; offline icon | Bell is rendered but has no action/state | Implement a web notification page/state or remove the inactive control |
| Profile | Edit profile, password reset, biometric setting, delete account | Name/location edit and password reset; email read-only, no phone/delete surface | Add telephone and compliant account deletion; document email-change policy |
| Personal subscription | Plan page and club enquiry; no payment yet | Stale advertised benefits; no payment | Replace with one server-driven catalogue and StoreKit/web billing policy |
| Club administration | Native settings expose organisation, users, courts and sports controls | Broader, more mature administration | Keep web as primary admin surface; test native subset against role permissions |
| Root administration | Not offered, appropriately | Clubs, users, matches, sports, enquiries | Keep web-only, add audit/billing/least-privilege operations |
| Public display | Opens external/web display | Native web scoreboard/display layouts | Web remains the correct display client; finish realtime contract |
| Privacy/help | Native privacy page and feedback | Fuller public help/terms/privacy content | Use one canonical legal copy and revision date across clients |
| Version/brand | iOS 1.0.2 build 41, Hit n Score | web package 0.2.2; several RcktScore labels remain | Establish coordinated release versions and finish naming cleanup |

## Responsive web findings

I rendered the public login, help, display-code and root-admin login routes at
390×844, 768×1024, 1024×768 and 1440×900. They showed **no horizontal document
overflow**, so the responsive foundation is workable. The help tabs wrap on a
phone and the public display entry remains functional.

However, this is not yet a full responsive sign-off:

- The web login still shows `Need help?`, a local version/build footer and a small
  content-width Sign In button, unlike the latest native design.
- Authenticated dashboard, setup, scoring, user/club administration and root
  tables have not been exercised end to end with seeded data at all sizes.
- Most mobile rules pivot around 640/740/840px, with a separate portrait rule up
  to 1024px. Tablet landscape therefore needs explicit testing instead of being
  assumed from portrait behaviour.
- Horizontally scrollable data matrices are acceptable when the two-dimensional
  layout is essential, but all other content should reflow down to 320 CSS pixels
  for WCAG 2.2 AA ([W3C reflow criterion](https://www.w3.org/TR/WCAG22/#reflow)).
- There is no visual-regression baseline, keyboard/focus suite, screen-reader
  check or automated touch-target/contrast audit.

### Web hardening work package

1. Build a seeded Playwright matrix covering 320, 390, 768 portrait, 1024
   landscape and 1440 widths for every role and primary journey.
2. Add screenshot comparisons for login, dashboard, match setup, active scoring,
   history, settings, root users, user profile, clubs and public scoreboard.
3. Consolidate spacing, typography, control height, focus rings and breakpoint
   tokens instead of adding page-specific media-query patches.
4. Convert dense mobile tables to labelled cards where comparison is not
   essential; retain deliberate horizontal scrolling for true matrices.
5. Test real interaction: soft keyboard, 200/400% zoom, long names/emails,
   validation errors, slow network, session expiry and dark mode.
6. Resolve the parity table above before describing web and native as the same
   product offer.

## Personal Plus: the recommended promise

Position Personal Plus as:

> **Your complete racket-sport record—understand how you are improving, prepare
> for opponents and share every match professionally.**

The market pattern is clear. Playtomic sells advanced statistics and full level
graphs ([official plan](https://playerhelp.playtomic.com/hc/en-gb/articles/19831696399633-Premium-Plan-Unlimited));
SquashLevels sells full history, comparison, prediction and career statistics
([official features](https://squashlevels.com/features/)); SwingVision separates
free from paid using deeper analysis, exports and long-term cloud retention
([official product](https://swing.vision/)); and TennisKeeper establishes demand
for head-to-head, time trends, Watch/Health data, equipment alerts and sharing
([official product](https://www.tenniskeeperapp.com/)). These are evidence of
category expectations, not proof of RcktScore conversion, so the rollout must be
measured.

### Keep these in Personal Free

- Correct standard scoring for every released sport.
- Saving and safely completing the current match, including offline continuation
  for a previously opened match. Reliability is a trust feature, not an upsell.
- Three recent completed-match summaries, with older data retained securely so
  upgrading can reveal history rather than discovering it was deleted.
- Basic player names, country, handedness and shirt colours.
- Registration/security/privacy, undo and match recovery.

### Wave 1 — strongest, achievable Plus bundle

- **Complete cloud history and powerful search.** Unlock every retained match,
  filters by sport/opponent/date/result/format and season views. This is recurring
  cloud value, immediately understandable, and builds on data already captured.
- **Personal performance dashboard.** Show wins/losses, game and point percentage,
  match duration, streaks, close-game performance, improvement by month and
  sport-specific trends. Always explain calculations and minimum sample sizes.
- **Opponent book and head-to-head.** Save regular opponents, reuse their details
  in setup, compare meetings, surfaces/formats and recent results. This removes
  repetitive setup and turns isolated scores into a useful rivalry record.
- **Professional match reports and sharing.** Generate a private-by-default
  match page and branded result card, with optional PDF/CSV export. Let the owner
  revoke links. Existing event data and the web display make this a strong,
  visible premium benefit without requiring video.
- **Advanced formats and saved presets.** Save favourite match setups and unlock
  convenience formats/presets such as short sets, Fast4-style presets, custom
  tiebreak targets and reusable handicap settings. Standard official formats
  remain free; Plus pays for breadth and speed.
- **Cross-device continuity and backup.** Make full history, presets, saved
  opponents and reports available on web, iPhone and iPad with a clear last-sync
  indicator. Apple requires subscription benefits to work across supported user
  devices ([subscription rules](https://developer.apple.com/app-store/review/guidelines/#subscriptions)).
- **Weekly/monthly progress digest.** A concise in-app and optional email summary
  of matches, court time, record, best streak and one useful insight. This creates
  ongoing subscription value rather than a one-off unlock.

### Wave 2 — differentiation after Wave 1 proves demand

- **Richer point tagging.** Optional tracking levels: score only; serve + point;
  winner/error; and detailed shot outcomes. Smashpoint uses progressively richer
  tracking modes and turns them into match/career analysis
  ([App Store listing](https://apps.apple.com/us/app/smashpoint-tennis-tracker/id1098174650)).
- **Momentum and key-moment analysis.** Visualise scoring runs, lead changes,
  game/set/match points saved or converted, and where a match turned. This uses
  the action log and is relevant across all racket sports.
- **Personal level and what-if tools.** An Elo-style private rating, opponent
  comparison and outcome simulator can create a compelling progress loop.
  Clearly label self-entered data as unverified and require opponent/club
  confirmation before any public ranking.
- **Apple Watch scoring and Health integration.** One-tap wrist scoring, haptics,
  heart rate, active time and calories are strong on-court convenience. Treat it
  as a separate high-cost project with privacy, battery and WatchConnectivity
  testing—not a small add-on.
- **Goals, milestones and equipment care.** Season targets, match-frequency
  goals, personal records and optional racket/string/shoe usage reminders improve
  retention, though they are less likely to drive the first purchase than stats,
  history and H2H.
- **Coach/player sharing.** Allow a user to grant a coach read-only access to
  selected reports and notes. Consent, revocation and youth safeguarding must be
  designed before release.

### Later, only after validation

- Video attachments, automated highlights, stroke recognition and line calling
  have high perceived value—SwingVision demonstrates the category—but introduce
  major storage, compute, camera placement, consent, child-safety and accuracy
  costs. They should not be promised in the first Plus release.
- Public matchmaking, leagues and rankings can create network effects, but need
  moderation, identity trust, location/privacy controls and enough local users.
  They are a new product surface rather than a subscription checkbox.

## How to turn the bundle into revenue

- Launch Plus only when **at least three benefits are real**: full history,
  performance dashboard and H2H/saved opponents. Avoid selling a future-feature
  list.
- Use one App Store subscription group with monthly and annual Personal Plus
  products, plus Restore Purchases. Keep the backend as the entitlement source of
  truth and process renewals, cancellations, refunds, billing retry and grace
  periods from App Store Server Notifications
  ([Apple subscription setup](https://developer.apple.com/app-store/subscriptions/)).
- Consider a 14-day annual-plan trial so an active player can score more than one
  match and experience trends. Show the exact renewal date and price; Apple says
  benefits and terms must be clear before subscribing.
- Present upgrades contextually: after the third completed match, when opening an
  older result, when selecting Stats/H2H/Export, and after a satisfying completed
  match—not repeatedly during live scoring.
- Show benefits, not implementation labels: “See every match,” “Know where you’re
  improving,” “Prepare for this opponent,” and “Share a professional report.”
- Instrument `paywall_viewed`, benefit source, trial started, purchase, restore,
  renewal, cancellation/refund, history limit reached, report shared and premium
  feature activation. Segment by sport and match frequency.
- Track conversion, trial-to-paid, 30/90-day renewal, refund rate and the share of
  subscribers who use each promised benefit. Remove or improve benefits that do
  not drive retained use. Freemium guidance supports proving real value first and
  prompting at meaningful limits ([RevenueCat](https://www.revenuecat.com/blog/growth/how-to-turn-freemium-users-into-loyal-subscribers)).

## Recommended next delivery sequence

1. Fix the current entitlement/copy contradictions and web shirt-colour rule.
2. Port native tennis setup/presentation parity to web and share scenario tests.
3. Establish CI, staging seed data and the responsive/auth/role test matrix.
4. Add monitoring, rate limiting, CORS restriction, audit events and recovery
   runbooks.
5. Build Wave 1 Plus data features before payment so the paid promise is genuine.
6. Add StoreKit/backend subscription lifecycle and admin billing visibility.
7. Complete iPhone/iPad device, accessibility, offline and App Store sign-off.
8. Release to a controlled cohort, measure, then decide whether Watch, advanced
   tagging or realtime notifications is the next retention investment.

## Review limitations

Authenticated web pages were reviewed from source and existing tests, while
public routes were rendered interactively across four viewport sizes. A seeded
end-to-end production-like environment is still needed for definitive visual and
workflow sign-off. Competitor research identifies proven category patterns but
must be validated with RcktScore users and product analytics.
