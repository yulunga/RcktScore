# HitNScore public website review and expansion blueprint

**Review date:** 10 September 2026  
**Website reviewed:** `https://www.hitnscore.com/`  
**Scope:** the standalone public marketing website in `weblanding/`, its public help page, the hand-off to `app.hitnscore.com`, and comparison with capabilities currently implemented in the RcktScore repository.

## Executive assessment

The current website has a pleasant, recognisable visual style, but it is still a teaser rather than a product website. It does not explain enough for a player, club manager, coach, or competition organiser to understand what HitNScore does, why it is different, which sports work now, what each plan contains, or what to do next.

The central recommendation is to rebuild the homepage around **real product proof**:

> Score the match. Keep the record. See how you improve.

Use genuine app screenshots, separate player and club journeys, an honest plan comparison, a clear supported-sports section, and repeated calls to action. The public site should position HitNScore as a working late-beta platform, not an idea that is merely “coming soon.”

### Indicative scorecard

| Area | Current assessment | Main issue |
|---|---:|---|
| Visual identity | 7/10 | Friendly and consistent, but the page is visually repetitive |
| Product explanation | 3/10 | Almost none of the implemented product is explained |
| Conversion journey | 3/10 | One vague “Want In?” action sends everyone to registration |
| Trust and proof | 2/10 | No real screenshots, examples, testimonials, status, or company detail |
| Plan clarity | 1/10 | No pricing or feature comparison |
| Search readiness | 2/10 | Sparse copy and incomplete metadata/discovery setup |
| Accessibility foundation | 6/10 | Clean semantic basics, but navigation, reduced motion, focus treatment, and help content need work |
| Overall marketing completeness | 3/10 | Attractive teaser; not yet a convincing product site |

## What visitors see today

### Homepage

The current homepage contains:

- a large logo header and one `Want In?` button
- a “Coming to the court soon” hero
- a CSS illustration of a match score rather than a product screenshot
- three short cards for live matches, clubs, and multi-sport readiness
- a small `Need Help?` link

What is missing:

- primary navigation
- a clear description of how the product works
- real product screenshots or a video
- separate content for players and clubs
- supported sports and honest availability states
- feature explanations
- Personal Free versus Personal Plus comparison
- club plan explanation
- testimonials, pilot-club proof, or quantified product evidence
- FAQ, privacy, terms, contact, and company footer links
- a clear sign-in action for existing users
- App Store availability/status or an honest beta availability explanation

### Help and early-access page

The help page contains a working feedback form and substantial beta-access copy. However, the hero lists “User Guides & Tutorials,” “Frequently Asked Questions,” and “System Status & Release Information” as plain text without providing those resources. This creates an expectation that the page does not fulfil.

The page also repeats the early-access message at length while providing little practical help. Support, guides, privacy, terms, account help, scoring help, and service status should be distinct destinations.

### Registration hand-off

The main website CTA opens the app’s registration form immediately. The form is functional and explains personal versus club use, but the visitor reaches it before being shown features, plan differences, pricing context, or product evidence.

Replace the single ambiguous CTA with:

- **Start free** — personal registration
- **Book a club demo** or **Talk to us about your club** — club enquiry
- **Sign in** — existing users

## Important content corrections

These should be corrected before expanding the site because they affect trust.

| Current public message | Product reality | Recommended correction |
|---|---|---|
| “Coming to the court soon” | Personal registration and substantial web/native flows already work in late beta | Use “Now in early access” or “Score your next match free” |
| “Squash first” | Squash, racketball, and tennis are implemented and enabled | Say “Live for squash, racketball and tennis” |
| Padel displayed beside live sports | Padel has a dispatcher module but live scoring is not implemented | Label it “planned” or remove it from the hero |
| Racketball is not mentioned | Racketball scoring is implemented | Add it everywhere supported sports are listed |
| “Real-time” scoring/display | WebSocket broadcast infrastructure remains partial | Use “live scoring” and avoid a guaranteed real-time-display claim |
| “Guides, FAQ, status” on Help | Those resources are not actually presented on the landing help page | Add the destinations or remove the claims |
| Hit N Score / HitnScore / Hit n Score / RcktScore | Naming varies across surfaces | Adopt one customer-facing spelling; keep internal names out of public copy |
| One `Want In?` CTA | Personal and club visitors have different journeys | Use explicit personal, club, and existing-user actions |

## Recommended public-site architecture

A focused launch site does not need dozens of pages. It needs the right pages with enough proof.

### Primary navigation

- Product
- For Players
- For Clubs
- Sports
- Plans
- Help
- **Sign in**
- **Start free**

### Recommended pages

1. **Home** — clear proposition, screenshots, audiences, key features, plans, FAQ, CTA.
2. **For Players** — scoring, match history, Personal Plus performance, offline continuation, cross-device record.
3. **For Clubs** — multi-user workspace, courts, scheduled matches, member controls, sports visibility, public display.
4. **Features** — scannable feature catalogue with screenshots and links into player/club detail.
5. **Plans** — Personal Free/Plus comparison and honest club enquiry cards.
6. **Sports** — squash, racketball, and tennis as available; other sports clearly marked planned.
7. **Help** — searchable practical help, account/password support, scoring guides, FAQ, feedback, and status.
8. **About** — product purpose, team/company identity, contact, and early-access posture.
9. **Legal** — privacy, terms, cookies, account deletion, and data information.

For the first iteration, most of these can be sections on one well-structured homepage plus separate Plans, Help, and Legal pages.

## Recommended homepage, section by section

### 1. Compact sticky header

Keep the mascot and wordmark but reduce the header height. Add navigation, `Sign in`, and one prominent `Start free` button.

### 2. Product-led hero

Suggested headline:

> **Every point. Every match. Your progress.**

Suggested supporting copy:

> Live scoring for squash, racketball and tennis—built for individual players and the clubs they play in. Score on court, keep your match history, and turn every result into useful insight.

Actions:

- **Start scoring free**
- **Explore club features**

Hero visual: a genuine iPhone live-scoring screenshot overlapping a web performance or club-dashboard screenshot. Replace the fictional CSS score card with the actual product.

Add a small availability line:

> Web access available now. Native iPhone app in active early access.

Only change this when the release state changes.

### 3. Immediate audience choice

Two large cards:

**For players**

- score squash, racketball, and tennis
- continue a previously opened match offline on iPhone
- revisit recent results
- upgrade for deeper history and performance insight

**For clubs**

- manage club users and courts
- run active and scheduled matches
- control which sports members can select
- open a public court display

Each card should lead to a dedicated explanation rather than the same registration form.

### 4. “How it works” strip

Use three clear steps with matching screenshots:

1. **Set up the match** — choose sport, format, players, referee, court, colours, and supported rules.
2. **Score on court** — points, lets/strokes, server, serve side, timer, undo, and match completion.
3. **Keep the story** — match timeline, history, results, and Personal Plus performance.

For tennis, mention singles/doubles, serve and receive selection, optional No-Ad, and the optional final-set 10-point match tiebreak.

### 5. Real screenshot feature story

Alternate image-and-copy sections rather than using a grid of identical cards:

- **Scoring that stays out of the way** — large live scorer screenshot.
- **Your record follows you** — history and completed-match screenshot.
- **See what the score alone misses** — Personal Plus performance screenshot.
- **Ready when the connection is not** — native offline indicator and queued-action explanation.
- **One place to run the club** — club users/courts/dashboard screenshot.
- **Put the score on the big screen** — public display screenshot, labelled beta while realtime delivery remains incomplete.

### 6. Supported sports

Use status labels rather than implying that all named sports work:

| Sport | Public label |
|---|---|
| Squash | Available |
| Racketball | Available |
| Tennis | Available |
| Padel | Planned |
| Table tennis | Planned |
| Badminton | Planned |
| Pickleball | Planned |

“Available” should still be subject to an organisation’s enabled-sports settings.

### 7. Plans and feature comparison

Publish the implemented personal entitlement difference. Do not invent club limits or a Club Pro advantage until those rules are decided and enforced.

| Capability | Personal Free | Personal Plus | Club Essentials | Club Pro |
|---|:---:|:---:|:---:|:---:|
| Core scoring for enabled sports | Yes | Yes | Yes | Yes |
| Active match | One personal match | One personal match | Yes | Yes |
| Readable completed history | Latest 3 | Latest 100 | Club history | Club history |
| Cross-device extended history | — | Yes | Workspace data | Workspace data |
| Performance dashboard | — | Yes | — | Do not promise yet |
| Results, game and point percentages | — | Yes | — | Do not promise yet |
| Serve-point, streak, opponent and scoreline insight | — | Yes | — | Do not promise yet |
| Weekly/monthly progress and sport splits | — | Yes | — | Do not promise yet |
| Shirt colours | Yes | Yes | Yes | Yes |
| Multi-user club workspace | — | — | Yes | Yes |
| User and role administration | — | — | Yes | Yes |
| Court management | — | — | Yes | Yes |
| Active and scheduled club matches | — | — | Yes | Yes |
| Public match display | — | — | Available/beta | Available/beta |
| Native offline continuation for a previously opened match | Yes | Yes | Yes | Yes |
| Price/action | Start free | Show live App Store price when enabled | Enquire | Enquire |

Club Essentials and Club Pro currently lack strongly differentiated, server-enforced commercial limits. Until that is resolved, either:

- show one **Club early access** offer, or
- show both club names with “final package details confirmed during onboarding.”

Do not publish invented maximum courts, users, matches, support response times, exports, or advanced reporting.

### 8. Personal Plus value section

Suggested positioning:

> **Turn your match record into a performance story.**

Use real tiles from the performance view:

- win percentage
- games and points won
- points won on serve
- playing time
- close-game/set record
- current and best streak
- opponents and head-to-head record
- scoreline wins
- results by sport
- weekly/monthly summaries and improvement

Important qualification: performance attribution depends on the registered first name and surname matching the recorded participant name. This should be handled gracefully in-product; it does not need to dominate the marketing copy.

### 9. Club workflow section

Avoid vague “built for clubs” wording. Show the operational workflow:

> Create the club workspace → invite users → add courts → enable sports → create or schedule matches → score on court → open the public display.

Suggested CTA: **Talk to us about your club**.

### 10. Trust and reliability

Use specific, supportable statements:

- expiring signed-in sessions
- tenant-aware club permissions
- duplicate-safe mobile score replay using action IDs
- backend-enforced Personal Free/Plus history limits
- cross-device notification read state
- privacy and account-deletion controls

Avoid broad “enterprise-grade security,” guaranteed uptime, production realtime, or complete offline-use claims.

### 11. FAQ

Recommended questions:

- Which sports can I score today?
- Is Personal Free really free?
- What does Personal Plus add?
- Can I use HitNScore without a connection?
- Can one email belong to more than one club or account?
- What can club administrators manage?
- Can spectators see a match score?
- Is there an iPhone app?
- How do I reset my password or delete my account?
- How do I register a club?

### 12. Complete footer

Include:

- Product, Players, Clubs, Sports, Plans
- Help, Contact, Feedback, Service status
- Privacy, Terms, Cookies, Account deletion
- Sign in and Start free
- consistent company/product name and copyright
- social links only if actively maintained

## Screenshot production plan

Screenshots should be treated as product evidence, not decoration. Capture them from seeded demo accounts using fictional names and no real customer data.

### Required screenshot set

| ID | Screen | Purpose | Best placement |
|---|---|---|---|
| S1 | Native live squash/racketball scorer | Show the core on-court experience | Hero |
| S2 | Native tennis scorer | Prove multi-sport depth | Sports/feature section |
| S3 | Match setup | Explain the first workflow step | How it works |
| S4 | Completed-match summary and timeline | Show the result is retained | How it works/history |
| S5 | Personal Plus performance dashboard | Sell the paid personal value | Personal Plus section |
| S6 | Native offline indicator/queued sync state | Prove resilient scoring | Reliability section |
| S7 | Web club dashboard with active/scheduled matches | Explain club operations | Clubs section |
| S8 | Web users and courts administration | Show real administration | Clubs detail page |
| S9 | Public scoreboard/display | Explain spectator viewing | Clubs/display section |
| S10 | Notification inbox | Show cross-device communication | Secondary feature gallery |

### Capture standards

- Use the same fictional club, courts, and players across every image so the site tells one coherent story.
- Use realistic match data; avoid blank or obviously staged dashboards.
- Crop tightly enough that labels remain readable on a phone-sized webpage.
- Provide desktop WebP/AVIF variants and responsive sizes rather than shipping raw screenshots.
- Add concise alt text describing the product state shown, not “app screenshot.”
- Do not place important copy inside the bitmap; keep headings and explanations as HTML.
- Use subtle device frames consistently; avoid mixing multiple frame styles.
- Include both light and dark native imagery only if the contrast helps tell a product story.
- Blur or replace email addresses, names, IDs, display codes, and notifications from real accounts.

## Copy direction

### Recommended message hierarchy

1. **Outcome:** score matches accurately and keep the record.
2. **Differentiation:** one platform for players and clubs across supported racket sports.
3. **Proof:** genuine scoring, history, analytics, offline continuation, and club administration screenshots.
4. **Offer:** free personal start; Personal Plus for deeper insight; guided club onboarding.
5. **Trust:** honest availability, clear data/privacy information, and practical support.

### Words to prefer

- live scoring
- match record
- performance insight
- on court
- players and clubs
- start free
- early access
- available / planned

### Words to avoid until they are supportable

- fully realtime
- every racket sport
- complete offline access
- advanced reporting or exports
- enterprise-grade
- unlimited clubs/users/courts/matches
- production ready
- “coming soon” as the dominant product message

## Visual and interaction recommendations

- Retain the current blue, pink, white, mascot, rounded surfaces, and friendly tone.
- Reduce the oversized header and repeated floating white-card treatment.
- Use darker navy sections to create rhythm and make real screenshots stand out.
- Give each section one clear visual hierarchy; the existing page often gives every container equal weight.
- Use one primary pink CTA and blue/outline secondary actions consistently.
- Add visible keyboard focus styles and verify colour contrast for muted grey text and pale borders.
- Add `prefers-reduced-motion` handling for the animated cards, chips, balls, and glows.
- Ensure all interactions remain usable at 320 CSS pixels, 200% zoom, and large text sizes.
- Keep touch targets at least 44 by 44 CSS pixels.
- Turn the help hero’s concatenated topics into actual linked cards or remove them.

## Search, sharing, performance, and measurement

### Search and social metadata

The current homepage title and description are generic and describe an outdated “starting with squash” position. Add:

- unique titles and descriptions per page
- canonical URLs
- Open Graph and X/Twitter card metadata
- a branded social-share image
- `Organization`, `SoftwareApplication`, `FAQPage`, and breadcrumb structured data where truthful
- `robots.txt` and `sitemap.xml`
- descriptive internal links between audience, features, plans, sports, help, and legal pages

Suggested homepage title:

> HitNScore — Live Racket-Sport Scoring for Players and Clubs

Suggested description:

> Score squash, racketball and tennis matches, keep your history, understand your performance and run club courts and matches with HitNScore.

### Performance

The site is static and structurally lightweight, which is a good foundation. The current brand PNG is approximately 665 KB and should be resized/optimised with responsive WebP or AVIF variants. Real product screenshots must also be served responsively and lazy-loaded below the fold.

### Measurement

Track a small, privacy-aware funnel:

- homepage visit
- player/club audience selection
- plan comparison viewed
- Start free clicked
- club enquiry started/completed
- registration started/completed
- sign-in clicked
- help/FAQ query
- feedback sent

Do not install measurement without updating the public privacy/cookie position. A cookie banner is needed only if the chosen technology and jurisdictional use require consent; privacy disclosure is required regardless.

## Delivery sequence

### Phase 1 — truth and conversion (highest priority)

1. Correct the sports, availability, naming, and realtime claims.
2. Replace `Want In?` with Start free, Club enquiry, and Sign in journeys.
3. Add compact navigation and a complete footer.
4. Add real hero, scoring, history, performance, club, and display screenshots.
5. Add the Personal Free/Plus comparison and cautious club offer.

### Phase 2 — content depth

1. Build Players, Clubs, Sports, Plans, and About content.
2. Replace the current Help page with practical guides, FAQ, account support, feedback, and status links.
3. Publish canonical privacy, terms, cookies, and account-deletion information.
4. Add social proof when genuine pilot users or clubs have approved it.

### Phase 3 — discovery and optimisation

1. Add metadata, structured data, sitemap, robots, and share imagery.
2. Optimise all images and run performance/accessibility checks.
3. Add privacy-aware funnel measurement.
4. Test headlines, screenshot order, player/club paths, and CTA wording using real conversion data.

## Acceptance criteria for the improved site

The revised site is ready for controlled public promotion when:

- a new visitor can identify the available sports, primary benefit, audiences, and free entry point within the first screen
- players and clubs have distinct journeys
- every availability and plan claim matches implemented, server-enforced behaviour
- at least six genuine product screenshots show scoring, history/analytics, and club operations
- the plan comparison does not invent Club Pro features or limits
- sign in, personal registration, club enquiry, help, privacy, terms, and feedback are easy to find
- all screenshot data is fictional or safely anonymised
- keyboard, reduced-motion, reflow, contrast, and mobile layout checks pass
- search/share metadata, sitemap, and robots setup are present
- page performance remains strong after screenshots are added

## Bottom line

The current website looks like a polished holding page. The product behind it is much richer. The next iteration should stop leading with anticipation and start showing the working experience: **live scoring, a lasting match record, meaningful personal insight, and practical club operations**.
