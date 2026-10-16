# HitnScore web client — manual testing checklist

Prepared 15 October 2026. This is a test plan, not a record of completed testing. Scope: the responsive web client, including Safari on iPhone/iPad; not the native iOS app.

## 1. Devices and resolutions

| Device ID | Baseline | Physical display pixels (portrait) | Browser test viewport (CSS px) | Browser |
|---|---|---|---|---|
| PH | iPhone 16 (standard model) | 1179 × 2556 | 393 × 852 portrait; 852 × 393 landscape | Safari |
| TB | iPad 11-inch A16 (assumed model) | 1640 × 2360 | 820 × 1180 portrait; 1180 × 820 landscape | Safari |
| DT | Desktop baseline | Record actual monitor resolution | 1440 × 900; spot-check 1920 × 1080 | Chrome; Safari smoke check on Mac |

Physical resolutions: [Apple iPhone 16 specifications](https://www.apple.com/uk/iphone-16/specs/) and [Apple iPad A16 specifications](https://www.apple.com/uk/ipad-11/specs/). CSS sizes are baseline emulation targets derived at 3×/2× pixel density. Real Safari browser chrome, zoom and display settings change available content space: record the actual viewport. Desktop values refer to browser content, not the entire monitor. Replace the iPad baseline if using a different model. Use real devices for final touch/keyboard checks.

## 2. Accounts and test data

| Account ID | Account / role | Specific expectation |
|---|---|---|
| PF | Personal Free (“personal”) | Latest three completed matches plus redacted teaser; basic analytics; scheduling upgrade gate |
| PP | Personal Plus (“personal+”) | Latest 100 completed matches; deeper performance reporting; scheduling |
| CE | Club Essentials, regular member | Club-scoped data; no admin-only controls |
| CP | Club Pro, regular member | Club-scoped data; no admin-only controls |
| CA | Club admin | Admin controls and Club Analytics; record whether Essentials or Pro |
| MC | User with two approved club memberships | Test Club A and Club B separately, including each membership’s role and sport access |

Plan, role and memberships are separate dimensions. Add a second CA run if both Essentials-admin and Pro-admin behaviour need validation. Do not infer permissions from a plan name alone.

Before starting:

- [ ] Record URL/environment, build or commit, tester, date, browser/OS versions and actual viewport.
- [ ] Prepare disposable accounts and a mailbox for registration, reset and email-change checks. Do not store passwords in this file.
- [ ] Record each club’s plan, member/admin roles, enabled sports and available sport-specific or legacy unassigned courts.
- [ ] Enable all four sports for the positive-path runs; separately verify one disabled sport and a club with no matching court. Expected gating is a pass, not a failed game-start test.
- [ ] Seed each account/club with an active match, scheduled matches where permitted and completed matches across all four sports, dates, opponents and outcomes; use matching profile names for Player Analytics.
- [ ] Include at least four completed matches for Free, 25 for dashboard pagination, 21 accessible for History pagination and dated fixtures across the analytics periods. Reuse data where possible.
- [ ] Seed unread/read notifications and a plan-targeted message; retain known match IDs and expected analytics totals.

## 3. How to work through it

Run the checklist below for every device/account row in the coverage grid. For MC, repeat club-specific cases in each club. Registration creates a fresh personal account or club enquiry; it does not directly create every paid tier. Reuse that device’s registration result for unrelated account rows and explicitly mark it N/A there with a reason.

Record each case as **Not run / Pass / Fail / Blocked / N/A**. A group passes only after all applicable cases pass. Use Blocked when missing test data, email delivery or configuration prevents a check; reserve N/A for genuinely inapplicable cases. For every sport, actually create, score and finish a match on each applicable device/account combination. Use separate matches for mutually exclusive rule options.

## 4. Test cases

### Registration

| ID | Action | Expected result |
|---|---|---|
| REG-01 | Open Want In; submit valid personal registration; receive email, set password and sign in. | Account is created once with correct details; email link works and confirmation explains the next step. |
| REG-02 | Try blank/invalid fields, existing email, mismatched passwords and a reused/expired email link. | Clear validation; no duplicate account; recovery route is available. |
| REG-03 | Submit a club enquiry, then separately accept a prepared club-member invitation. | Enquiry acknowledges interest rather than granting immediate club access; invitation/approval grants only the intended membership. |

### Login

| ID | Action | Expected result |
|---|---|---|
| AUTH-01 | Sign in with valid credentials; then try wrong password and unapproved membership. | Valid approved user reaches the correct account; failures are clear and grant no access. |
| AUTH-02 | Use password reset from login and sign in with the new password. | Email/reset flow succeeds; old password no longer authenticates. |
| AUTH-03 | Refresh while signed in; log out; use Back and open a protected URL. | Valid session restores; logged-out protected content requires authentication. |
| AUTH-04 | Sign in as the two-club user; select Club A; log out, sign in and select Club B. | Both memberships are offered; each choice loads that club’s role, matches, courts, sports and analytics without Club A data leaking into Club B. |

### Dashboard

| ID | Action | Expected result |
|---|---|---|
| DASH-01 | Open Home; review active, scheduled and recent matches and empty states. | Correct account data and available actions; no stale data from the previous login. |
| DASH-02 | Open Start New Match and header +; close each sport chooser. | Both open the same chooser; only enabled implemented sports appear; closing returns to dashboard. |
| DASH-03 | Use header navigation and scroll the page. | Correct active item; sticky header compacts; phone navigation remains usable; Settings goes to Settings. |
| DASH-04 | Review scheduling, club controls and Tournament navigation where enabled. | Free scheduling shows upgrade gate; admin controls follow role; Tournament is visible only for a club with the feature enabled. |

### Messages

| ID | Action | Expected result |
|---|---|---|
| MSG-01 | Open Messages with unread and read seeded notifications; mark one read; refresh and inspect on another device. | Messages open correctly; unread state clears explicitly and read state persists across devices. |
| MSG-02 | Review inbox for an account with no messages and accounts with plan-targeted messages. | Useful empty state; only intended recipients see targeted notifications. |

### Profile

| ID | Action | Expected result |
|---|---|---|
| PROF-01 | Open profile icon; check and update name, surname, telephone, location and country; refresh. | Own details persist; no other user’s details appear; labels and save feedback are usable. |
| PROF-02 | On a disposable account, change email to an unused valid address and sign in again. | Prior sessions are revoked; login uses the new address; invalid/duplicate email is rejected clearly. |

### Squash

| ID | Action | Expected result |
|---|---|---|
| SQ-01 | Create squash from dashboard; select players, shirts, format and a club court where applicable. | Setup saves correct players/rules/court; disabled or unavailable sports cannot be created. |
| SQ-02 | Score both players; change service side; use stroke/let and Undo; refresh. | Scores, server and point rail are correct; side change replaces the current marker; undo/refresh retain consistent state. |
| SQ-03 | Exercise Golden Point, handicap and optional timing; complete a match and separately test early-end confirmation. | Handicap works across all tiers; timer-off opens scoring directly; enabled warm-up/break works; completion records correct winner; cancelling early-end preserves play. |

### Racketball

| ID | Action | Expected result |
|---|---|---|
| RB-01 | Create racketball with player shirts, format, rules and applicable court. | Correct sport, participants and court; independent sport/court gates explain any blocked creation. |
| RB-02 | Score both players, change service side, use stroke/let and Undo; refresh. | Sport-appropriate scoring and service markers remain correct without duplicate current-score markers. |
| RB-03 | Exercise handicap, Golden Point, optional warm-up/game break; complete and test early-end cancellation. | Rules and timing match setup; completion appears in history; cancelling early-end does not finish the match. |

### Tennis

| ID | Action | Expected result |
|---|---|---|
| TEN-01 | Create singles, then doubles, including all shirt colours and opening order. | Singles derives receiver from opening server; doubles accepts explicit serve/receive order and four participants. |
| TEN-02 | Play through 0/15/30/40, deuce, advantage, a game, a set and a 6–6 tiebreak; use Undo. | Points/games/sets, server/receiver and Right/Left labels follow the rules; undo restores prior state. |
| TEN-03 | Test Golden Point, final-set 10-point match tiebreak and timed breaks in separate suitable matches. | Golden Point uses Right court; final-set option uses match tiebreak; enabled odd-game/set breaks show 90/120 seconds. |
| TEN-04 | Complete match; open result and point timeline. | Correct winner, set scores, game/set boundaries and saved history after refresh. |

### Padel

| ID | Action | Expected result |
|---|---|---|
| PAD-01 | With Padel enabled, create a match with four participants, shirts and opening order. | Setup is doubles only; platform/account visibility gates are respected. |
| PAD-02 | Play advantage and a separate Golden Point game; select Right/Left receiving partner at Golden Point. | Receiving team chooses partner; scoring, service rotation and named receiver remain correct. |
| PAD-03 | Reach 6–6 tiebreak; exercise Undo, enabled breaks and match completion. | Tiebreak, restored state, timing and final result agree with selected rules and persist after refresh. |

### Recent matches

| ID | Action | Expected result |
|---|---|---|
| REC-01 | Review Recent Matches and pagination with sufficient data. | Newest accessible completed matches appear; maximum 24 dashboard entries, six cards per page; desktop shows up to three two-card rows. |
| REC-02 | Open a recent card for each sport; refresh detail and return. | Correct read-only result, participants, start/duration, game/set timing and grouped timeline; tennis/Padel use tennis labels. |
| REC-03 | For Free, open the latest three completed matches then attempt a known older match URL. | Latest three are accessible; older history is redacted/gated and direct authenticated access is denied; teaser exposes no restricted details. |
| REC-04 | For Plus, review expanded history and attempt older entries beyond the allowance if seeded. | Latest 100 completed matches are accessible within entitlement; dashboard still caps at 24. |

### Matches and search

| ID | Action | Expected result |
|---|---|---|
| MAT-01 | Click Recent Matches heading; also click Active and Scheduled headings. | Recent opens Matches History; other headings open corresponding Current/Scheduled tabs. |
| MAT-02 | Review Current, Scheduled and History tabs, including empty states. | Correct status grouping; completed matches cannot be scored; active matches reopen correctly. |
| MAT-03 | Test scheduling and activation for each account. | Free receives upgrade gate; Plus can schedule during an active personal match but cannot activate until it ends; club scheduling uses authorised club courts. |
| MAT-04 | Filter History by squash, racketball, tennis and Padel in turn. | Only the selected sport remains; clearing restores the accessible results. |
| MAT-05 | Search by player name, surname, winner and sport; try mixed case and no-match text. | Matching results are correct and case-insensitive; useful no-results state; clear restores results. |
| MAT-06 | Combine text, sport, single date and date range; clear filters; paginate. | All filters apply together; boundaries include expected matches; no duplicates/skipped entries; History has up to 20 cards per page (ten desktop rows). |

### Analytics

| ID | Action | Expected result |
|---|---|---|
| ANA-01 | Open Analytics and inspect App/Player tabs; inspect Club as admin and regular member. | App and Player are available across tiers; Club is restricted to club admins; direct navigation cannot expose another club’s data. |
| ANA-02 | On App, choose 30 days, 90 days, 12 months and All time using known dated matches. | Match volume, sport splits, completion/abandonment, durations and activity charts reconcile with fixtures in each selected period. |
| ANA-03 | Check App heatmaps, rule/format usage, competitiveness, points and participant reuse. | Charts remain readable; totals/labels agree with seeded data; historically untracked attribution is labelled rather than invented. |
| ANA-04 | Open Player using a profile whose full name appears in known matches; compare an unmatched profile. | Basic results, court time, sports and opponents reflect the profile-name match rule; no-data state is clear. |
| ANA-05 | Compare Free and Plus Player reporting. | Both have basic player stats; Plus adds deeper results, game/point and serve percentages, streaks, close games/sets and progress; Free cannot access restricted detail. |
| ANA-06 | As club admin, inspect Club courts, demand, simultaneous activity, scheduled demand, sport trends and digest where available. | Values agree with club fixtures and plan configuration; do not assume every Club Pro-labelled metric is available to Essentials. |
| ANA-07 | Complete one known match, refresh Analytics, then repeat after choosing the other club. | Relevant figures update without double counting; account context and reporting periods remain correct. |

### Layout and usability

| ID | Action | Expected result |
|---|---|---|
| UI-01 | Repeat all groups in portrait and spot-check landscape; rotate during setup and scoring. | No hidden primary action, overlapping text or accidental page-wide horizontal scroll; intended tab strips scroll. |
| UI-02 | Use phone/tablet keyboard, long names, dropdowns, dialogs, date inputs and score controls; test desktop keyboard and 200% zoom. | Inputs and close/save controls remain reachable; focus is visible; no lost form state or clipped scores. |
| UI-03 | On a safe test account, interrupt connectivity during a read/save and reconnect. | No false success or duplicate match/action; clear failure/recovery; web is not assumed to support native offline scoring. |

## 5. Coverage grid

Enter P/F/B/N/A only after checking the individual cases; blank means Not run. Keep case-level results in the run record below.

| Run | Registration | Login | Dashboard | Messages | Profile | Squash | Racketball | Tennis | Padel | Recent | Matches/search | Analytics | Layout |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| PH-PF | | | | | | | | | | | | | |
| PH-PP | | | | | | | | | | | | | |
| PH-CE | | | | | | | | | | | | | |
| PH-CP | | | | | | | | | | | | | |
| PH-CA | | | | | | | | | | | | | |
| PH-MC | | | | | | | | | | | | | |
| TB-PF | | | | | | | | | | | | | |
| TB-PP | | | | | | | | | | | | | |
| TB-CE | | | | | | | | | | | | | |
| TB-CP | | | | | | | | | | | | | |
| TB-CA | | | | | | | | | | | | | |
| TB-MC | | | | | | | | | | | | | |
| DT-PF | | | | | | | | | | | | | |
| DT-PP | | | | | | | | | | | | | |
| DT-CE | | | | | | | | | | | | | |
| DT-CP | | | | | | | | | | | | | |
| DT-CA | | | | | | | | | | | | | |
| DT-MC | | | | | | | | | | | | | |

## 6. Run record — copy for each device/account

- Run ID / club context:
- Tester / date / environment / build:
- Device / OS / browser version / actual CSS viewport / orientation:
- Account ID / plan / role / enabled sports (no passwords):

| Case ID | Status | Actual result / evidence / issue ID |
|---|---|---|
| Example: TEN-02 | Not run | |

## 7. Issue log

| Issue ID | Run / case | Severity | Steps to reproduce | Expected | Actual | Screenshot / match ID | Retest result |
|---|---|---|---|---|---|---|---|
| HNS-001 | | | | | | | |

Severity: Critical = account/data exposure or core journey unavailable; High = incorrect score, lost data or blocked journey; Medium = impaired function with workaround; Low = cosmetic/copy. Include URL and orientation where relevant, but redact tokens, passwords and personal data from evidence.

Finish each run by logging out. Retest fixes on the failing device/account and one other screen size; for scoring or permission changes repeat the affected sport/role cases. Keep unresolved issues and blocked cases visible rather than marking the run passed.
