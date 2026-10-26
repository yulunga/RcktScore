# HitnScore capability and access inventory

Reviewed: 23 October 2026. Scope: current checked-out v2 web, Python backend and native iOS code. This is a code review for packaging discussions, not confirmation of deployed configuration or a runtime security test. Existing unrelated working-tree changes were left untouched.

## How to use this document

The four access columns describe the **active workspace**: Personal Free, Personal Plus, Club Member and Club Admin. Club columns apply to the same person regardless of their separate personal subscription. “Yes” means the capability exists under normal prerequisites; it does not assert every client presents the same UI. “Enabled” means platform/account/feature availability must permit it. “—” means not applicable in that context. Partial, preview, untracked and not built must not be sold as complete capabilities.

Member is the user-facing name used here for the backend `user` role. Admin includes ordinary club access. There is no evidence of a complete code-enforced Club Essentials versus Club Pro capability split; those proposed packages should be mapped separately from member/admin roles.

For commercial workshops, add columns alongside each row: **Proposed Free; Proposed Plus; Essentials Member; Essentials Admin; Pro Member; Pro Admin; Data scope; Decision; Priority**. Leave proposals undecided until agreed. This inventory preserves actual behavior instead of silently replacing it with recommendations.

## Findings that change the permissions conversation

1. **Hiding the Club analytics tab does not hide club analytics generally.** Ordinary members receive extensive club-wide App analytics, including trends and heatmaps. The admin-only Club payload adds court/demand reporting but overlaps the member-visible metrics.
2. **Club membership currently grants basic player analytics.** The backend generates profile-name-linked player statistics for club users and admins without requiring a separate Personal Plus plan. Your proposed “Free user sees club stats only” would change this behavior if it also excludes these basic player reports.
3. **Club scoring permissions are broad.** Match reads, points, event actions, undo, ending and scheduled activation authorize approved membership and sport access, not ownership/assigned scorer or admin role. A read-only member role requires a new rule.
4. **View-only Settings still returns directory information.** Members cannot mutate club settings, but the settings API serializes member email and contact/location fields. Decide what members should receive as data, not only what buttons they see.
5. **Display access has distinct routes.** General Settings omits court codes for non-admins, while authorized match display access can return the linked court code. Decide whether scorers need this or whether display-code sharing should be restricted separately.
6. **Personal history and basic analytics have different scopes.** Free completed-match reads are limited to three, but web App analytics can aggregate activity over longer periods. Native basic duration/sport stats use available loaded history. Avoid claiming all Free statistics use the same three-match dataset.
7. **Personal Plus is not yet a cross-club reporting product.** Current advanced personal reporting uses the personal tenant, not a combined record of every club the person belongs to.
8. **Club Pro remains a packaging decision.** A “Premium Club Digest” label is not proof of a Pro entitlement check. Club subscription preview does not perform billing.

## Identity, membership and account context

| ID | Capability | Personal Free | Personal Plus | Club Member | Club Admin | Surface/status | Current behavior / qualification |
|---|---|---|---|---|---|---|---|
| CAP-001 | Sign in with email and password | Yes | Yes | Yes | Yes | Web/iOS | Approved membership and valid session required. |
| CAP-002 | Select between memberships at login | Yes | Yes | Yes | Yes | Web/iOS | Same email can have different roles in different organisations. |
| CAP-003 | Switch membership from Association settings | Yes | Yes | Yes | Yes | iOS | Implemented native switch; equivalent persistent web switcher is not established by this review. |
| CAP-004 | Personal workspace separate from club workspace | Yes | Yes | Yes | Yes | Backend | Personal accounts are stored as single-user personal organisations; club rights come from club membership. |
| CAP-005 | Different role in each club | — | — | Member | Admin | Backend | Roles are user and admin; no custom permission designer. |
| CAP-006 | Read another club without membership | No | No | No | No | Backend | Club authorization is tenant scoped. |
| CAP-007 | Use unapproved club membership | — | — | No | No | Backend | Approval is checked before access. |
| CAP-008 | Self-service personal registration | Yes | Yes | — | — | Web/iOS | Personal account is created immediately; password setup is emailed. |
| CAP-009 | Submit club-interest enquiry | Yes | Yes | Yes | Yes | Web/iOS | Enquiry process, not instant club provisioning or checkout. |
| CAP-010 | Reset own password | Yes | Yes | Yes | Yes | Web/iOS | Email reset flow. |
| CAP-011 | Edit own profile | Yes | Yes | Yes | Yes | Web/iOS | Name, surname, email and supported contact/location fields; email change ends previous sessions. |
| CAP-012 | Unlock saved session with biometrics | Yes | Yes | Yes | Yes | iOS | Device-local opt-in; saved session must remain unexpired. |
| CAP-013 | Sign out | Yes | Yes | Yes | Yes | Web/iOS | Session-backed sign-out. |
| CAP-014 | Delete own personal account | Yes | Yes | — | — | iOS/API | Personal owner only; native flow has two destructive confirmations. |
| CAP-015 | Profile photo | Local | Local | Local | Local | iOS | Device-local only, not a central shared profile image. |

## Dashboard, match discovery and history

| ID | Capability | Personal Free | Personal Plus | Club Member | Club Admin | Surface/status | Current behavior / qualification |
|---|---|---|---|---|---|---|---|
| CAP-016 | View active matches in selected workspace | Yes | Yes | Yes | Yes | Web/iOS | Club lists are club scoped, not limited to matches involving the signed-in player. |
| CAP-017 | View scheduled matches | Gate | Yes | Yes | Yes | Web/iOS | Personal Free sees upgrade presentation. |
| CAP-018 | View completed match history | Latest 3 | Latest 100 | Yes | Yes | Web/iOS/API | Club list request/page sizes are not established subscription retention limits. |
| CAP-019 | Open completed match by direct URL/API | Latest 3 | Latest 100 | Yes | Yes | Backend | Personal history limits also apply to direct authenticated reads. |
| CAP-020 | See redacted older-history teaser | Yes | — | — | — | Web/iOS | Older records remain stored; Free reads are restricted. |
| CAP-021 | Cross-device accessible history | Latest 3 | Latest 100 | Yes | Yes | Web/iOS | Within the account or selected club, not an aggregate of every membership. |
| CAP-022 | Search completed history by text | Yes | Yes | Yes | Yes | Web | Only accessible records are exposed by history entitlement. |
| CAP-023 | Filter history by sport | Yes | Yes | Yes | Yes | Web | Sport availability also applies. |
| CAP-024 | Filter history by date or date range | Yes | Yes | Yes | Yes | Web | Filters do not upgrade history entitlement. |
| CAP-025 | Paginate match history | Yes | Yes | Yes | Yes | Web | 20 cards per Matches History page; dashboard has a separate 24-entry display cap. |
| CAP-026 | Read final result and game/set scores | Yes | Yes | Yes | Yes | Web/iOS | Subject to match access/history limits. |
| CAP-027 | Read point-by-point historical timeline | Yes | Yes | Yes | Yes | Web/iOS | Sport-specific event presentation. |
| CAP-028 | Read match metadata and time breakdown | Yes | Yes | Yes | Yes | Web/iOS | Collapsed match information and timing disclosures. |
| CAP-029 | View live tournaments from dashboard | — | — | Enabled | Enabled | Web | Explicit per-club tournament feature required. |

## Match creation, scheduling and scoring permissions

| ID | Capability | Personal Free | Personal Plus | Club Member | Club Admin | Surface/status | Current behavior / qualification |
|---|---|---|---|---|---|---|---|
| CAP-030 | Create an immediate match | Yes | Yes | Yes | Yes | Web/iOS | Enabled implemented sport required; club court must support sport or be unassigned. |
| CAP-031 | Have more than one active personal match | No | No | — | — | Backend | Both personal plans retain one active match at a time. |
| CAP-032 | Schedule a match for later | No | Yes | Yes | Yes | Web/iOS | Personal Free requests do not gain scheduled status. |
| CAP-033 | Schedule while personal match is active | No | Yes | — | — | Web/iOS | Activation still waits for current personal match to end. |
| CAP-034 | Activate scheduled match | — | Yes | Yes | Yes | Web/iOS | Backend enforces active personal-match restriction. |
| CAP-035 | Choose club court | — | — | Yes | Yes | Web/iOS | Club court availability and sport compatibility apply. |
| CAP-036 | Lookup existing player/referee names | Yes | Yes | Yes | Yes | Web/iOS/API | Setup lookup is available to approved members; not a full player CRM. |
| CAP-037 | Enter participant names manually | Yes | Yes | Yes | Yes | Web/iOS | Recorded names are not always linked account identities. |
| CAP-038 | Set club referee / Me option | — | — | Yes | Yes | Web | Me option uses profile and is disabled when user is a named participant. |
| CAP-039 | Choose participant shirt colours | Yes | Yes | Yes | Yes | Web/iOS | Not a Plus-only feature. |
| CAP-040 | Score points | Yes | Yes | Yes | Yes | Web/iOS/API | Club authorization is membership based, not scorer assignment based. |
| CAP-041 | Use sport-specific scoring event actions | Yes | Yes | Yes | Yes | Web/iOS/API | Includes applicable let, stroke, server and service-side actions. |
| CAP-042 | Undo scoring action | Yes | Yes | Yes | Yes | Web/iOS/API | No separate club-admin requirement in handler. |
| CAP-043 | End live match early | Yes | Yes | Yes | Yes | Web/iOS/API | No separate club-admin requirement in handler. |
| CAP-044 | Change supported live match settings | Yes | Yes | Yes | Yes | Web/iOS | Subject to scoring-state rules; no separate delegated scorer role. |
| CAP-045 | Use warm-up / match / break timers | Yes | Yes | Yes | Yes | Web/iOS | Applicable controls depend on sport and match setup. |
| CAP-046 | Receive completed-match summary | Yes | Yes | Yes | Yes | Web/iOS | Read-only historic presentation also available afterward. |
| CAP-047 | Archive or delete arbitrary match as club admin | No | No | No | No | Root-admin tool | Root-admin archive/delete exists; ordinary club role does not imply it. |
| CAP-048 | Restrict scoring to assigned scorer | Not built | Not built | Not built | Not built | Roadmap | Requires a new match-level permission and assignment model. |

## Sports and rule configuration

| ID | Capability | Personal Free | Personal Plus | Club Member | Club Admin | Surface/status | Current behavior / qualification |
|---|---|---|---|---|---|---|---|
| CAP-049 | Squash scoring | Enabled | Enabled | Enabled | Enabled | Web/iOS | Platform, organisation and membership sport availability intersect. |
| CAP-050 | Racketball scoring | Enabled | Enabled | Enabled | Enabled | Web/iOS | Same availability rules. |
| CAP-051 | Tennis singles scoring | Enabled | Enabled | Enabled | Enabled | Web/iOS | Live set/game/point engine. |
| CAP-052 | Tennis doubles scoring | Enabled | Enabled | Enabled | Enabled | Web/iOS | Four participants and opening serve/receive order. |
| CAP-053 | Padel doubles scoring | Enabled | Enabled | Enabled | Enabled | Web/iOS | Explicitly enabled accounts only; doubles-only adapter. |
| CAP-054 | Table tennis scoring | Not built | Not built | Not built | Not built | Placeholder | Fail-safe placeholder, not a sellable scoring feature. |
| CAP-055 | Badminton scoring | Not built | Not built | Not built | Not built | Placeholder | Fail-safe placeholder. |
| CAP-056 | Pickleball scoring | Not built | Not built | Not built | Not built | Placeholder | Fail-safe placeholder. |
| CAP-057 | Configure best-of match format | Yes | Yes | Yes | Yes | Web/iOS | Available sport-specific supported formats. |
| CAP-058 | Squash/racketball handicap | Yes | Yes | Yes | Yes | Web/iOS | Sport capability, not plan entitlement or club toggle. |
| CAP-059 | Squash/racketball Golden Point | Yes | Yes | Yes | Yes | Web/iOS | Per-match rule option. |
| CAP-060 | Squash/racketball timed warm-up and game breaks | Yes | Yes | Yes | Yes | Web/iOS | Optional timing; game breaks are 90 seconds. |
| CAP-061 | Tennis advantage scoring | Yes | Yes | Yes | Yes | Web/iOS | Backend-authored score presentation. |
| CAP-062 | Tennis Golden Point | Yes | Yes | Yes | Yes | Web/iOS | 40-40/Right service side. |
| CAP-063 | Tennis final-set 10-point match tiebreak | Yes | Yes | Yes | Yes | Web/iOS | Optional match rule. |
| CAP-064 | Tennis/Padel timed changeovers and set breaks | Yes | Yes | Yes | Yes | Web/iOS | 90-second odd-game and 120-second set breaks. |
| CAP-065 | Padel receiving-partner choice at Golden Point | Enabled | Enabled | Enabled | Enabled | Web/iOS | Receiving team chooses Right/Left partner. |
| CAP-066 | Save per-sport timer defaults | Yes | Yes | Read only | Edit | Web/iOS/API | Default preselects match option and can be overridden per match. |
| CAP-067 | Change club enabled sports | — | — | No | Yes | Web/iOS | Cannot override platform restrictions. |
| CAP-068 | Change personal sport rollout access | Root managed | Root managed | — | — | Root admin | Do not assume upgrading automatically enables every sport. |

## App analytics — current web access, selected workspace

| ID | Capability | Personal Free | Personal Plus | Club Member | Club Admin | Surface/status | Current behavior / qualification |
|---|---|---|---|---|---|---|---|
| CAP-069 | Choose 30 / 90 / 365 day or all-time period | Yes | Yes | Yes | Yes | Web | Extended analytics are requested by the analytics page. |
| CAP-070 | Match volume | Yes | Yes | Yes | Yes | Web/API | Workspace-wide; personal analytics totals can cover more than the readable history cards. |
| CAP-071 | Completed-match count and rate | Yes | Yes | Yes | Yes | Web/API | Derived from recorded statuses. |
| CAP-072 | Abandoned / uncompleted-started rate | Yes | Yes | Yes | Yes | Web/API | Active unfinished records are included; not a reliable explicit abandonment event. |
| CAP-073 | Match counts by sport | Yes | Yes | Yes | Yes | Web/API | Workspace-wide. |
| CAP-074 | Average match duration | Yes | Yes | Yes | Yes | Web/API | Valid duration records only. |
| CAP-075 | Longest match duration | Yes | Yes | Yes | Yes | Web/API | Selected period. |
| CAP-076 | Shortest completed match duration | Yes | Yes | Yes | Yes | Web/API | Zero durations excluded. |
| CAP-077 | Duration distribution bands | Yes | Yes | Yes | Yes | Web/API | Under 30, 30–60, 60–90, over 90 minutes. |
| CAP-078 | Active weeks / returning usage | Yes | Yes | Yes | Yes | Web/API | Activity weeks, not verified unique returning users. |
| CAP-079 | Average matches per active day/week | Yes | Yes | Yes | Yes | Web/API | Activity frequency. |
| CAP-080 | Day/hour activity heatmap | Yes | Yes | Yes | Yes | Web/API | Members currently see club-wide match timing patterns. |
| CAP-081 | Monthly scoring trend | Yes | Yes | Yes | Yes | Web/API | Workspace-wide. |
| CAP-082 | Web versus iOS scoring source | Partial | Partial | Partial | Partial | Web/API | New session-attributed events; older records remain unattributed. |
| CAP-083 | Most-used match format | Yes | Yes | Yes | Yes | Web/API | Derived from saved setup. |
| CAP-084 | Timed-break usage rate | Yes | Yes | Yes | Yes | Web/API | Saved match setting. |
| CAP-085 | Golden Point usage rate | Yes | Yes | Yes | Yes | Web/API | Saved match setting. |
| CAP-086 | Handicap usage rate | Yes | Yes | Yes | Yes | Web/API | Saved match setting. |
| CAP-087 | Final-set tiebreak usage rate | Yes | Yes | Yes | Yes | Web/API | Saved match setting. |
| CAP-088 | Close-match frequency | Yes | Yes | Yes | Yes | Web/API | Engine-derived definition, not a rating system. |
| CAP-089 | Extra-points frequency | Yes | Yes | Yes | Yes | Web/API | Recorded match structure. |
| CAP-090 | Comeback-match frequency | Yes | Yes | Yes | Yes | Web/API | Derived from recorded progression. |
| CAP-091 | Longest game/set duration | Yes | Yes | Yes | Yes | Web/API | Requires usable event timing. |
| CAP-092 | Average games/sets per match by sport | Yes | Yes | Yes | Yes | Web/API | Sport-specific units. |
| CAP-093 | Average points per match by sport | Yes | Yes | Yes | Yes | Web/API | Recorded points. |
| CAP-094 | Average points per game/set by sport | Yes | Yes | Yes | Yes | Web/API | Recorded points and units. |
| CAP-095 | Unique participant-name count | Yes | Yes | Yes | Yes | Web/API | Names, not guaranteed distinct account identities. |
| CAP-096 | Repeat-participant rate | Yes | Yes | Yes | Yes | Web/API | Name reuse, not a verified member-retention metric. |
| CAP-097 | New-match setup completion/abandonment funnel | Untracked | Untracked | Untracked | Untracked | Placeholder metric | Setup-start/exit attribution is missing. |
| CAP-098 | Basic native activity statistics | Yes | Yes | Yes | Yes | iOS | Completed count, average/longest duration, sport mix; duration calculations use loaded history. |
| CAP-099 | Full web App analytics parity on iOS | No | No | No | No | Platform gap | Do not treat basic native stats as the complete web reporting suite. |

## Player analytics and Personal Plus performance

| ID | Capability | Personal Free | Personal Plus | Club Member | Club Admin | Surface/status | Current behavior / qualification |
|---|---|---|---|---|---|---|---|
| CAP-100 | Basic profile-linked player statistics | No on web | Yes | Yes | Yes | Web/API | Club member/admin receive basic player stats regardless of separate personal subscription. |
| CAP-101 | Matches played / won / lost and win percentage | No on web | Yes | Yes | Yes | Web/API | Club basic player stats are scoped to selected club. |
| CAP-102 | Player points won | No on web | Yes | Yes | Yes | Web/API | Basic player statistics. |
| CAP-103 | Player playing time and average duration | No on web | Yes | Yes | Yes | Web/API | Basic player statistics. |
| CAP-104 | Player sport breakdown | No on web | Yes | Yes | Yes | Web/API | Basic player statistics. |
| CAP-105 | Most-played opponent list | No on web | Yes | Yes | Yes | Web/API | Club basic player stats list frequent opponents. |
| CAP-106 | Game win percentage | No | Yes | No | No | Web/iOS | Advanced personal performance is generated for personal_plus personal workspace. |
| CAP-107 | Point win percentage | No | Yes | No | No | Web/iOS | Same personal performance gate. |
| CAP-108 | Service-point win percentage | No | Yes | No | No | Web/iOS | Depends on recorded service events. |
| CAP-109 | Close-game/set win percentage | No | Yes | No | No | Web/iOS | Classified personal matches. |
| CAP-110 | Current and best winning streak | No | Yes | No | No | Web/iOS | Classified personal history. |
| CAP-111 | Weekly and monthly progress summary | No | Yes | No | No | Web/iOS | Personal performance report. |
| CAP-112 | Month-over-month sport improvement | No | Yes | No | No | Web/iOS | Needs consecutive-month data. |
| CAP-113 | Winning scoreline distribution | No | Yes | No | No | Web/iOS | Personal report. |
| CAP-114 | Per-sport personal win/loss reporting | No | Yes | Basic only | Basic only | Web/iOS | Advanced report remains personal Plus. |
| CAP-115 | Opponent head-to-head win/loss records | No | Yes | No | No | Web/iOS | More detailed than basic most-played-opponents list. |
| CAP-116 | Aggregate my performance across multiple clubs | Not built | Not built | Not built | Not built | Roadmap | Current reporting is tenant scoped; Plus alone does not aggregate memberships. |
| CAP-117 | Stable account-linked player attribution everywhere | Partial | Partial | Partial | Partial | Data gap | Current analytics match profile first name/surname; names can collide or change. |
| CAP-118 | Admin browse every member personal performance report | No | No | Not built | Not built | Roadmap | Admin operational reporting is not a personal performance directory. |

## Dedicated club analytics — current web access

| ID | Capability | Personal Free | Personal Plus | Club Member | Club Admin | Surface/status | Current behavior / qualification |
|---|---|---|---|---|---|---|---|
| CAP-119 | Club analytics tab / payload | — | — | No | Yes | Web/API | Backend includes club_analytics only for club admin. |
| CAP-120 | Club match volume summary | — | — | No | Yes | Web/API | Similar information is also visible to members in App analytics today. |
| CAP-121 | Club usage day/hour heatmap | — | — | No | Yes | Web/API | App heatmap overlaps this admin-only presentation. |
| CAP-122 | Peak hours / peak-time concentration | — | — | No | Yes | Web/API | Top three busiest hours derived from recorded activity. |
| CAP-123 | Off-peak match count | — | — | No | Yes | Web/API | Outside the three busiest hours; not a configured club tariff window. |
| CAP-124 | Court-level match counts | — | — | No | Yes | Web/API | Recorded matches, not booking inventory. |
| CAP-125 | Court-level recorded playing hours | — | — | No | Yes | Web/API | Does not calculate occupancy against opening/available court hours. |
| CAP-126 | Court sport-demand breakdown | — | — | No | Yes | Web/API | Recorded sport mix by court. |
| CAP-127 | Maximum simultaneous match activity | — | — | No | Yes | Web/API | Derived overlap; not a live capacity guarantee. |
| CAP-128 | Scheduled-match demand list | — | — | No | Yes | Web/API | Uses saved match records; not a full calendar booking forecast. |
| CAP-129 | Monthly sport popularity trend | — | — | No | Yes | Web/API | Selected club records. |
| CAP-130 | Premium Club Digest text | — | — | No | Yes | Web/API | Generated summary exists; name does not establish a Club Pro entitlement gate. |
| CAP-131 | Active member count from scored actions | — | — | Untracked | Untracked | Placeholder metric | Per-member action attribution missing. |
| CAP-132 | Member adoption rate | — | — | Untracked | Untracked | Placeholder metric | Do not sell as an implemented insight. |
| CAP-133 | New member activation | — | — | Untracked | Untracked | Placeholder metric | Same attribution gap. |
| CAP-134 | Court booking occupancy percentage | — | — | Not built | Not built | Roadmap | Needs opening hours, capacity and booking data. |
| CAP-135 | Download analytics / scheduled reports | Not built | Not built | Not built | Not built | Roadmap | No established reporting export feature in this review. |

## Club settings, member directory and administration

| ID | Capability | Personal Free | Personal Plus | Club Member | Club Admin | Surface/status | Current behavior / qualification |
|---|---|---|---|---|---|---|---|
| CAP-136 | Open club Settings | — | — | View only | Edit | Web/iOS | Web members are explicitly allowed to open Settings. |
| CAP-137 | View organisation name/address/contact details | — | — | Yes | Yes | Web/API | Read-only access is broader than just club name. |
| CAP-138 | Edit organisation name/address/contact details | — | — | No | Yes | Web/iOS/API | Admin authorization. |
| CAP-139 | Select club Primary Contact | — | — | No | Yes | Web | Approved-member lookup; primary contact is not a separate permission role. |
| CAP-140 | View club user directory | — | — | Yes | Yes | Web/API | Settings response returns users for ordinary members. |
| CAP-141 | View other users email/contact/location fields | — | — | API returns | API returns | API | Serialization includes email, telephone, city/location and country; decide field-level visibility. |
| CAP-142 | View roles and approval status | — | — | Yes | Yes | Web/API | Included in directory/settings data. |
| CAP-143 | Create/invite club user | — | — | No | Yes | Web/iOS/API | Invitation approval/password setup flow. |
| CAP-144 | Edit club-user details | — | — | No | Yes | Web/iOS/API | Membership-level administration. |
| CAP-145 | Promote/demote club role | — | — | No | Yes | Web/iOS/API | user/admin only. |
| CAP-146 | Delete club user membership | — | — | No | Yes | Web/iOS/API | Do not equate this with deleting every account association. |
| CAP-147 | Remove/demote last club admin | — | — | No | No | Backend | At least one admin is retained. |
| CAP-148 | Manually verify email / approve pending accounts | — | — | No | Root only | Root-admin tool | Do not package root-admin verification as a normal club capability. |
| CAP-149 | View court list and sport assignments | — | — | Yes | Yes | Web/iOS/API | Members may use courts without editing them. |
| CAP-150 | Create club court | — | — | No | Yes | Web/iOS/API | Admin mutation. |
| CAP-151 | Edit court name/alias/sport | — | — | No | Yes | Web/iOS/API | Admin mutation. |
| CAP-152 | Delete club court | — | — | No | Yes | Web/iOS/API | Admin mutation. |
| CAP-153 | Generate/regenerate court display code | — | — | No | Yes | Web/API | Code generation has explicit admin requirement. |
| CAP-154 | Read display codes from general Settings API | — | — | No | Yes | API | Codes omitted for ordinary club members on this endpoint. |
| CAP-155 | Read display access from authorized match | Yes | Yes | Yes | Yes | API | Match display-access endpoint can return linked court code; separate policy from Settings code visibility. |
| CAP-156 | View per-sport timer defaults | Yes | Yes | Yes | Yes | Web/iOS/API | Selected workspace. |
| CAP-157 | Edit club timer defaults | — | — | No | Yes | Web/iOS/API | Per-sport persisted defaults. |
| CAP-158 | View enabled racket sports | Yes | Yes | Yes | Yes | Web/iOS | Selected workspace/platform intersection. |
| CAP-159 | Edit social profile links | Not built | Not built | Not built | Not built | UI scaffold | Fields exist as disabled coming-soon placeholders. |
| CAP-160 | Manage federation associations | Not built | Not built | Not built | Not built | UI scaffold | Native Association membership switching exists; federation links do not. |
| CAP-161 | Configure detailed per-role permission switches | — | — | Not built | Not built | Roadmap | Current admin/user model is coarse. |

## Spectators, remote viewing and offline use

| ID | Capability | Personal Free | Personal Plus | Club Member | Club Admin | Surface/status | Current behavior / qualification |
|---|---|---|---|---|---|---|---|
| CAP-162 | Open match viewing code as remote viewer | No | Yes | No personal benefit | No personal benefit | Web/iOS | Remote viewer requires a Personal Plus personal membership context. |
| CAP-163 | Poll live read-only score and timeline | No | Yes | — | — | Web/iOS | Code-based remote watching, distinct from scoring access. |
| CAP-164 | View final result from watched match | No | Yes | — | — | Web/iOS | Read-only viewer flow. |
| CAP-165 | Save watched match to Viewed Matches | No | Yes | — | — | Web/iOS | Cross-device saved list in viewer personal workspace. |
| CAP-166 | Get match-specific viewing code as scorer | Yes | Yes | Yes | Yes | Web/iOS/API | Viewer entitlement differs from scorer code access. |
| CAP-167 | Public scoreboard/display entry | Public | Public | Public | Public | Web | Key/code/URL based access; read-only public surface. |
| CAP-168 | Club spectator display access from scoring | — | — | Yes | Yes | Web | Linked club court/display controls. |
| CAP-169 | Guaranteed WebSocket realtime delivery | Partial | Partial | Partial | Partial | Infrastructure | Scaffold exists; not production-complete broadcast. |
| CAP-170 | Reopen previously loaded active match offline | Yes | Yes | Yes | Yes | iOS | Device must already have loaded the match. |
| CAP-171 | Score supported loaded match offline | Yes | Yes | Yes | Yes | iOS | Native reducers/queue; squash, racketball, tennis and Padel adapter paths. |
| CAP-172 | Persist pending actions through restart | Yes | Yes | Yes | Yes | iOS | Offline action queue. |
| CAP-173 | Replay queued actions after reconnect | Yes | Yes | Yes | Yes | iOS/API | Client action UUIDs prevent duplicate mutations on retry. |
| CAP-174 | Create new match while offline | No | No | No | No | iOS limitation | Requires connectivity. |
| CAP-175 | Activate scheduled match while offline | No | No | No | No | iOS limitation | Requires connectivity. |
| CAP-176 | Browse uncached history/settings offline | No | No | No | No | iOS limitation | Not a general offline workspace. |
| CAP-177 | Web offline scoring equivalent to iOS | Not established | Not established | Not established | Not established | Platform gap | Do not assume native offline capability is shared by web. |

## Subscriptions, notifications and help

| ID | Capability | Personal Free | Personal Plus | Club Member | Club Admin | Surface/status | Current behavior / qualification |
|---|---|---|---|---|---|---|---|
| CAP-178 | View current personal plan and benefits | Yes | Yes | — | — | Web/iOS | Free/Plus history and performance contract is server derived. |
| CAP-179 | Upgrade personal plan with Apple purchase | Eligible | Current | — | — | iOS, release gated | New purchase offer is yearly; server verification and release gates apply. |
| CAP-180 | Restore Apple purchases | Eligible | Yes | — | — | iOS | Monthly legacy transactions still recognized for restore/lifecycle safety. |
| CAP-181 | Manage Apple subscription | Eligible | Yes | — | — | iOS | Apple subscription management flow. |
| CAP-182 | Web self-service paid checkout | Not built | Not built | — | — | Commercial gap | No established web payment checkout in current implementation. |
| CAP-183 | Club Essentials/Pro subscription comparison | — | — | Do not infer billing right | Preview | Web | Admin frontend preview; no payment or entitlement mutation. |
| CAP-184 | Paid club checkout / upgrade entitlement mutation | — | — | Not built | Not built | Commercial gap | No Stripe SDK/payment endpoint/persisted billing integration in preview. |
| CAP-185 | Enquire about Club Essentials/Pro | Yes | Yes | Yes | Yes | iOS/help | Enquiry captures contacts and emails requester/admin. |
| CAP-186 | Hard plan limit on club users | — | — | Not enforced | Not enforced | Packaging gap | Choose and implement any future cap explicitly. |
| CAP-187 | Hard plan limit on club courts | — | — | Not enforced | Not enforced | Packaging gap | No established Essentials/Pro court cap. |
| CAP-188 | Hard plan limit on club concurrency/schedules | — | — | Not enforced | Not enforced | Packaging gap | Operational court conflict handling is separate from tier limits. |
| CAP-189 | Read system notification inbox | Yes | Yes | Yes | Yes | Web/iOS | Persisted messages, polled inbox. |
| CAP-190 | Mark notifications read across devices | Yes | Yes | Yes | Yes | Web/iOS | Explicit read state. |
| CAP-191 | Publish system messages to users/plans | No | No | No | No | Root admin | Platform function, not club-admin messaging. |
| CAP-192 | Send club announcements to members | — | — | Not built | Not built | Roadmap | Do not infer from platform notification publisher. |
| CAP-193 | APNs push / background notification badges | Not built | Not built | Not built | Not built | Roadmap | Inbox polling exists. |
| CAP-194 | Use Help Centre and legal/privacy pages | Yes | Yes | Yes | Yes | Web/iOS | Public help plus native help/privacy access. |
| CAP-195 | Send feedback / Ping Us | Yes | Yes | Yes | Yes | Web/iOS | Email-backed flow, not a ticketing service or priority support SLA. |
| CAP-196 | Choose website analytics cookie consent | Yes | Yes | Yes | Yes | Web | GA4 loaded after explicit Allow all consent. |
| CAP-197 | Native accessibility / Dynamic Type / dark mode | Yes | Yes | Yes | Yes | iOS | Shared presentation capabilities, not subscription gates. |
| CAP-198 | Native Android product parity | Not built | Not built | Not built | Not built | Foundation | Compose/navigation foundation only. |

## Tournament Manager — web only, explicitly enabled clubs

| ID | Capability | Personal Free | Personal Plus | Club Member | Club Admin | Surface/status | Current behavior / qualification |
|---|---|---|---|---|---|---|---|
| CAP-199 | View club tournament list/details | — | — | Enabled | Enabled | Web/API | Feature flag required for club, independent of personal tier. |
| CAP-200 | View draft event/draw in club manager | — | — | Enabled | Enabled | Web/API | Member read endpoint is not restricted to published events. |
| CAP-201 | Create draft tournament | — | — | No | Enabled | Web/API | Internal/open events, supported format/options. |
| CAP-202 | Set grading and entry-size limits | — | — | No | Enabled | Web/API | Optional A–D grading and entry cap. |
| CAP-203 | Search canonical accounts/reusable players | — | — | No | Enabled | Web/API | Admin entrant-management lookup. |
| CAP-204 | Add/edit entrants and identity/ability/seed | — | — | No | Enabled | Web/API | Draft administration. |
| CAP-205 | Import duplicate-reviewed CSV entrants | — | — | No | Enabled | Web | Import is implemented; report export is a different capability. |
| CAP-206 | Generate reviewable knockout draw | — | — | No | Enabled | Web/API | Separated seed placement and top-seed byes. |
| CAP-207 | Edit first-round draw positions | — | — | No | Enabled | Web/API | Draft draw editing. |
| CAP-208 | View championship and plate brackets | — | — | Enabled | Enabled | Web | Horizontal bracket presentation. |
| CAP-209 | Publish draw and lock entries | — | — | No | Enabled | Web/API | Publication creates Live state and public draw key. |
| CAP-210 | Enable/disable public draw access | — | — | No | Enabled | Web/API | Can disable public access without returning draw to draft. |
| CAP-211 | Return published draw to draft | — | — | No | Enabled | Web/API | Subject to tournament state validation. |
| CAP-212 | Schedule playable published fixture | — | — | Enabled | Enabled | Web/API | Approved member can act; not admin-only. |
| CAP-213 | Enter published fixture result | — | — | Enabled | Enabled | Web/API | Approved member can act; fixture state rules apply. |
| CAP-214 | Correct manually entered result | — | — | No | Enabled | Web/API | Club admin correction flow. |
| CAP-215 | Advance knockout winners / populate plate | — | — | Automatic | Automatic | Backend | First-round losers feed plate for supported format. |
| CAP-216 | View sanitized public draw without login | Public | Public | Public | Public | Web | Valid enabled access key; no emails/account identifiers in public response. |
| CAP-217 | Enable Tournament Manager for club | — | — | No | Root only | Root admin | Not a self-service Club Pro purchase entitlement today. |
| CAP-218 | Automatic court/time allocation | — | — | Not built | Not built | Roadmap | Manual scheduling exists. |
| CAP-219 | Full Monrad placement progression | — | — | Automatic | Automatic | Web/API | Winners and losers route through fixed placement bands to final placing matches. |
| CAP-220 | Round-robin standings | — | — | Not built | Not built | Roadmap | Do not infer from tournament option labels. |
| CAP-221 | Native iOS Tournament Manager | — | — | Not built | Not built | Platform gap | Current tournament manager is web only. |

## Recommended member/admin decision matrix — proposal, not current enforcement

| Area | Suggested member baseline | Suggested admin baseline | Decision needed |
|---|---|---|---|
| Club matches | Read selected club matches | Read selected club matches | Should any matches be private, team-only or participant-only? |
| Scoring | Create/score own or assigned matches | Manage club scoring operations | Keep current all-member mutation rights, or introduce scorer assignment? |
| Basic club overview | Volume, sports and public club activity | Same overview | Which aggregates are safe/useful for all members? |
| Operational analytics | Hidden | Court hours, peak demand, concurrency, operational trends | Move overlapping App metrics behind admin capability where required. |
| Personal player reporting | Governed by personal plan | Same personal-plan rule | Keep club-funded basic stats or require Plus for all player metrics? |
| Other players | Names/results needed for club play | Operational access necessary to administer club | Who can inspect individual performance, and with what scope? |
| Member directory | Name, role and limited sporting information | Contact and membership administration | Restrict email, telephone and location fields returned to members? |
| Club settings | Read useful club information | Edit organisation, courts, users and defaults | Hide administrative sections or retain a limited view-only mode? |
| Display sharing | View authorized match/display as needed | Manage persistent court codes | Can any scorer disclose a court code, or only a temporary match code? |
| Tournaments | View events/draws | Manage entrants, draw and publication | May every member still schedule fixtures and submit results? |
| Club subscription | Plan summary if useful | Billing management if explicitly authorized | Is billing a separate permission from admin? |
| Multiple clubs | Access each approved membership | Admin only within clubs granting that role | No permission inheritance from one club to another. |

## Example: Personal Free + Club Demo Admin + Club Rackets Member

**Today:** personal context has three-match history, core scoring, basic activity reporting and no advanced personal performance. Club Demo context permits administration, club-wide App reporting, basic profile-linked Player reporting and admin Club reporting. Club Rackets context permits club reads and scoring mutations, club-wide App reporting, basic Player reporting and view-only Settings; it excludes admin Club reporting and settings mutations. The separate personal Free plan does not remove club Player reporting today.

**If adopting the proposed boundary:** retain Free personal context; show club operational reports only where admin; optionally give members a small club overview; require personal Plus for personal performance; decide whether basic club player statistics remain club funded. Implement the rule consistently in both UI and API. Cross-club personal aggregation and the persistent web context switcher remain separate work items.

## Packaging dimensions to keep separate

- **Personal subscription:** completed-history allowance, advanced personal reporting, scheduling and remote watching.
- **Club subscription:** shared club capabilities and future limits on members/courts/reporting; current Essentials/Pro split is not a complete enforced contract.
- **Membership role:** view versus manage, per club.
- **Data scope:** selected club, personal workspace, assigned match, public draw or future cross-club personal record.
- **Platform availability:** web, native iOS and future Android.
- **Feature rollout:** sport availability and explicit Tournament Manager enablement.
- **Operational prerequisites:** approved membership, valid session, compatible court, connectivity and match state.

An admin badge should grant permitted club actions; it should not automatically upgrade personal subscription benefits. A Plus subscription should not grant club administration.

## Suggested implementation roadmap

1. Agree data scopes and member-visible fields; resolve App analytics overlap, basic club player stats and scoring ownership first.
2. Define named capabilities such as club.matches.read, club.matches.score, club.analytics.overview, club.analytics.operations, club.members.read_contact, club.members.manage, club.courts.manage, club.display.manage and club.billing.manage. These names are proposed, not existing API permissions.
3. Derive capabilities from current membership role, relevant workspace subscription and rollout flags on the server; use the same response to drive web/iOS controls.
4. Improve membership switching and current-context visibility; preserve each club's independent role and plan.
5. Enforce chosen Essentials/Pro packaging, quotas and billing only after their commercial definitions are agreed.
6. Add stable player/account links before cross-club personal analytics. Establish what happens to historical player access when membership ends.
7. Add future organiser/scorer/billing roles only when the two-role model demonstrably fails a real use case.

## Evidence and review limits

Primary implementation references (repository relative):

- `backend/common/plan_entitlements.py`: authoritative personal history, performance and remote-watching contract.
- `backend/common/session_logic.py`: approved membership, admin checks and match authorization.
- `backend/functions/get_dashboard/handler.py`: member access and admin-only Club analytics inclusion.
- `backend/common/dashboard_logic.py`: App, basic Player, Club and advanced personal performance builders and history access.
- `frontend/src/pages/PerformancePage.jsx`: actual web reporting categories and presentation gates.
- `backend/common/organization_logic.py`: organisation/user serialization, court CRUD and last-admin protection.
- `backend/functions/get_organization_settings/handler.py`: member Settings reads and display-code redaction.
- `frontend/src/pages/OrganisationSettingsPage.jsx`: read-only member controls, timer defaults and subscription preview.
- `backend/functions/get_match_display_access/handler.py`: membership-authorized match/display code access.
- `backend/functions/{create_match,score_point,event_action,undo_action,end_match,start_scheduled_match}/handler.py`: match operation authorization.
- `backend/common/squash_match_logic.py`: shared personal concurrency and scheduling enforcement.
- `backend/common/match_watch_logic.py`: personal Plus remote viewing requirements.
- `backend/functions/*tournament*/handler.py` and `backend/common/tournament/`: member/admin tournament access split and club feature flag.
- `frontend/src/context/AuthContext.jsx`: membership selection at login.
- `mobile/ios/RcktScoreMobile/RcktScoreMobile/Views/DashboardView.swift`: native basic/Plus analytics, Association switching and settings permissions.
- `AGENTS.md`: current platform support, StoreKit release gates, offline scope and partial capabilities.

Some existing packaging prose in `docs/feature-payments-structure.md` is stale: its exclusions still list capabilities now implemented, including Padel, tournament progression and timer defaults. This inventory follows current implementation and the current operating guide where they differ. It does not change those source documents or assert production deployment.

Review method: static inspection of source and authorization paths; no application mutation, deployment, purchase or runtime test performed. Detailed client parity and unusual match-state edge cases should be verified before turning the final tier matrix into a public promise.
