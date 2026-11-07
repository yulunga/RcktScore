import React from "react";

export const HELP_GUIDE_GROUPS = [
  {
    id: "getting-started",
    title: "Getting started",
    description: "Choose your device and learn how registration, approval and sign-in work.",
    items: [
      { id: "web-access", icon: "W", label: "Web client", description: "Register, sign in and move between Personal and club accounts." },
      { id: "ios-access", icon: "i", label: "iPhone & iPad", description: "Use the native iOS app, biometrics and supported offline scoring." },
      { id: "android-access", icon: "A", label: "Android", description: "Use the responsive web client while the native Android app is developed." },
    ],
  },
  {
    id: "accounts",
    title: "Accounts & access",
    description: "Understand plans, club roles and the tools available to each user.",
    items: [
      { id: "account-plans", icon: "◎", label: "Account types & capabilities", description: "A practical comparison of Personal, Personal Plus and club access." },
      { id: "personal-free", icon: "P", label: "Personal", description: "Score matches, view recent results and use basic Analytics." },
      { id: "personal-plus", icon: "+", label: "Personal Plus", description: "Scheduling, expanded history, live viewing and deeper player insight." },
      { id: "club-roles", icon: "C", label: "Club members & roles", description: "What administrators, scorers and read-only members can do." },
      { id: "club-admin", icon: "⚙", label: "Club administrator", description: "Configure the club, members, courts, sports, displays and tournaments." },
    ],
  },
  {
    id: "matches",
    title: "Matches & scoring",
    description: "Set up, score, schedule and review matches across supported racket sports.",
    items: [
      { id: "match-setup", icon: "＋", label: "Set up a match", description: "Choose the account, sport, court, players, colours and match rules." },
      { id: "squash-racketball-scoring", icon: "S", label: "Score Squash & Racketball", description: "Service, points, lets, strokes, Golden Point, timers and Undo." },
      { id: "tennis-padel-scoring", icon: "T", label: "Score Tennis & Padel", description: "Games, sets, serve order, deuce, Golden Point, tiebreaks and breaks." },
      { id: "scheduling-history", icon: "▣", label: "Scheduled matches & history", description: "Prepare fixtures, activate them later and review completed results." },
    ],
  },
  {
    id: "sharing",
    title: "Live sharing & displays",
    description: "Share live scores with invited viewers or a venue scoreboard.",
    items: [
      { id: "live-viewing", icon: "◉", label: "Live score viewing", description: "Use match viewing codes and save followed matches across devices." },
      { id: "spectator-scoreboards", icon: "▤", label: "Spectator scoreboards", description: "Set up court display codes and open the public venue scoreboard." },
    ],
  },
  {
    id: "more-capabilities",
    title: "Insights, tournaments & settings",
    description: "Use reporting, competition management, account settings and mobile resilience.",
    items: [
      { id: "analytics", icon: "↗", label: "Analytics", description: "Understand App, Player and club-level performance information." },
      { id: "tournaments", icon: "🏆", label: "Tournament Manager", description: "Create entrants, publish draws and progress tournament matches." },
      { id: "settings-security", icon: "✓", label: "Settings, profile & security", description: "Manage personal details, club associations, subscriptions and sessions." },
      { id: "notifications-offline", icon: "↻", label: "Notifications & offline iOS scoring", description: "Read cross-device messages and safely replay queued scoring actions." },
    ],
  },
];

export const HELP_GUIDE_IDS = HELP_GUIDE_GROUPS.flatMap((group) => group.items.map((item) => item.id));

const GUIDES = {
  "web-access": {
    kicker: "Web client guide",
    title: "Using HitnScore on the web",
    lead: "Register, sign in and use HitnScore from a modern phone, tablet or desktop browser.",
    sections: [
      {
        title: "Create a Personal account",
        steps: [
          "Open app.hitnscore.com and select Want In.",
          "Enter your first name, surname and email, then choose Personal use.",
          "Complete the human check and submit the registration.",
          "Open the confirmation email, verify the address and create a secure password.",
          "Return to the login page and sign in with that email and password.",
        ],
        note: "Personal registration is immediate. Club workspaces and club invitations follow the separate approval process below.",
      },
      {
        title: "Join or request a club",
        bullets: [
          "Choose Club use under Want In to send a club enquiry to the HitnScore team.",
          "A club enquiry does not immediately create a workspace; the team reviews it and contacts the requester.",
          "A club administrator can invite an existing or new identity. Accept the emailed invitation before signing in.",
          "When one email belongs to several approved accounts, use the header account menu to change context without another login.",
        ],
      },
      {
        title: "Sign in and session replacement",
        steps: [
          "Enter the account email in Username and provide the password.",
          "Select Sign In. HitnScore opens the preferred Personal account when available and retains every approved account in the context menu.",
          "If the identity already has an active session, choose whether to keep that session or sign it out and continue on this device.",
        ],
        note: "A replacement signs the previous web or mobile session out. Forgotten passwords can be recovered from Reset Password in this Help Centre.",
      },
      {
        title: "Responsive browser use",
        paragraphs: [
          "The same web client adapts to desktop, tablet, phone portrait and phone landscape. Core navigation, match setup and live scoring remain available at supported sizes.",
          "Keep the scoring tab visible during a live match. The web client validates the session while active and will return to login if another device replaces it.",
        ],
      },
    ],
  },
  "ios-access": {
    kicker: "iOS guide",
    title: "Using HitnScore on iPhone & iPad",
    lead: "Use the native app for registration, account switching, scoring, history, settings and supported offline recovery.",
    sections: [
      {
        title: "Register and sign in",
        steps: [
          "Open the app and select Want In.",
          "Choose Personal to create an immediate account, or Club to register an enquiry.",
          "For Personal registration, confirm the email and set a password before returning to the app.",
          "Sign in with the email and password. Choose the required account context when more than one is available.",
        ],
      },
      {
        title: "Face ID or Touch ID",
        paragraphs: [
          "After a normal online sign-in, enable biometric session unlock in Settings. Biometrics unlock the saved session on that device; they do not replace the account password.",
          "When the server session expires or is replaced by another login, the app requires the password again.",
        ],
      },
      {
        title: "Native app capabilities",
        bullets: [
          "Home, Current, Scheduled and History match views.",
          "Native setup and live scoring for Squash, Racketball, Tennis and doubles Padel when enabled for the account.",
          "Personal and club Analytics, profile and subscription settings, notifications and Help & Feedback.",
          "Personal Plus live match viewing and saved Viewed Matches.",
          "Previously loaded active-match scoring while offline, with ordered replay after reconnection.",
        ],
      },
      {
        title: "If access is pending",
        paragraphs: [
          "Personal accounts do not need staff approval after email confirmation. Club access remains pending until the invitation is accepted or a root administrator approves the membership.",
        ],
      },
    ],
  },
  "android-access": {
    kicker: "Android guide",
    title: "Using HitnScore on Android",
    lead: "The responsive web client is the supported Android experience while native Android product development remains in progress.",
    sections: [
      {
        title: "Open the web client",
        steps: [
          "Open a current version of Chrome or another modern Android browser.",
          "Visit app.hitnscore.com and sign in normally.",
          "Use the responsive header for Home, new match, Matches, Analytics, Settings and Help.",
          "Optionally add the page to the Android home screen from the browser menu for quicker access.",
        ],
      },
      {
        title: "What is available",
        paragraphs: [
          "Android browsers receive the web capabilities described throughout these guides, including responsive setup and live scoring. The Android/Compose project is currently only a technical foundation, so there is no production native Android app to install yet.",
        ],
        note: "Native iOS-only features such as Keychain biometric unlock and offline action replay are not available through the Android web client.",
      },
    ],
  },
  "account-plans": {
    kicker: "Account guide",
    title: "Account types & capabilities",
    lead: "Your plan controls personal features; your club role separately controls what you can do inside a club.",
    sections: [
      {
        title: "Personal",
        bullets: [
          "Create and score matches in enabled sports.",
          "Use the shared Home, Matches, Analytics, Settings and Help navigation.",
          "Open the latest 25 completed matches and basic scored-match Analytics.",
          "See an upgrade gate rather than creating scheduled Personal fixtures.",
        ],
      },
      {
        title: "Personal Plus",
        bullets: [
          "Access expanded cross-device history, currently up to the latest 100 completed matches.",
          "Schedule Personal matches and activate them when ready.",
          "Use deeper player performance reporting and live match viewing codes.",
          "Purchase and restore the supported subscription through the iOS Subscription experience.",
        ],
      },
      {
        title: "Club accounts",
        bullets: [
          "Club data, courts, enabled sports, displays and tournaments belong to the selected club context.",
          "Admin, Scorer and Read only roles are enforced by the server and are independent of the club package name.",
          "One identity can retain Personal and several club memberships and switch between them from the account menu.",
        ],
      },
    ],
  },
  "personal-free": {
    kicker: "Personal guide",
    title: "Personal account",
    lead: "The free Personal account covers everyday scoring, recent results and basic insight.",
    sections: [
      {
        title: "Score a match",
        paragraphs: [
          "Select the blue new-match control, confirm Personal in Score this match for, choose an enabled sport and complete setup. Personal scoring supports the same implemented sport rules as club scoring; a club court is not required.",
        ],
      },
      {
        title: "Matches and history",
        bullets: [
          "Current shows the active Personal match.",
          "Scheduled shows the Personal Plus upgrade route rather than fixture creation.",
          "History exposes the latest 25 completed matches, including direct match-detail access.",
          "Older restricted results are represented by an upgrade prompt without leaking match details.",
        ],
      },
      {
        title: "Analytics and settings",
        paragraphs: [
          "App Analytics summarises what has been scored, including sport mix, match volume and durations where recorded. Player reporting provides the basic results that can be linked to the profile name.",
          "Settings manages the profile, enabled Personal sports, timer defaults, account associations, password help and account deletion.",
        ],
      },
    ],
  },
  "personal-plus": {
    kicker: "Personal Plus guide",
    title: "Personal Plus",
    lead: "Personal Plus adds scheduling, broader history, deeper performance insight and cross-device live-score following.",
    sections: [
      {
        title: "Expanded match tools",
        bullets: [
          "Create scheduled fixtures and edit them before activation.",
          "Keep scheduling while another Personal match is active, but finish that active match before starting the next one.",
          "Access expanded completed history across signed-in devices.",
          "Enter an eight-character viewing code and save followed matches in Viewed Matches.",
        ],
      },
      {
        title: "Performance reporting",
        paragraphs: [
          "Player Analytics adds results, game or set and point percentages, serve-point performance where the event data supports it, court time, close contests, streaks, opponents, scorelines and progress over time.",
          "Personal matching is based on the signed-in profile name appearing in the recorded lineup, so keep profile and match names consistent.",
        ],
      },
      {
        title: "Subscription lifecycle",
        paragraphs: [
          "New Personal Plus purchases use the supported yearly StoreKit product in the iOS app. Restore Purchases reconnects an eligible App Store subscription to the signed-in identity. Cancelling renewal retains access until verified expiry; refunds or revocation can remove it sooner.",
        ],
      },
    ],
  },
  "club-roles": {
    kicker: "Club access guide",
    title: "Club members & roles",
    lead: "Club access follows least-privilege roles so each member sees only the information and actions needed for their work.",
    sections: [
      {
        title: "Administrator",
        paragraphs: [
          "Administrators can configure the club, members, roles, courts, sports, timer defaults, display access, subscription preview, reporting and match operations. They also manage enabled Tournament Manager features.",
        ],
      },
      {
        title: "Scorer",
        paragraphs: [
          "Scorers can create, schedule where permitted, start, score, undo and end club matches. They can view club matches, results and permitted Analytics, but cannot read the private member directory or change club administration settings.",
        ],
      },
      {
        title: "Read only",
        paragraphs: [
          "Read-only members can view club matches, history, results, live tournaments and permitted Analytics. Match mutation controls are hidden or disabled, and the server rejects direct scoring requests.",
        ],
      },
      {
        title: "Changing context",
        paragraphs: [
          "Use the header account menu to select Personal or a retained club. The chosen context controls the matches, courts, sports, tournaments and reporting shown; it does not alter membership in any other club.",
        ],
      },
    ],
  },
  "club-admin": {
    kicker: "Club administrator guide",
    title: "Administer a club account",
    lead: "Set up the club workspace before scorers create venue matches.",
    sections: [
      {
        title: "Club profile and members",
        steps: [
          "Open Settings, choose the club under Association and enter the club workspace.",
          "Complete the club name, venue address, primary contact and relevant social or competition details.",
          "Invite or create members with Admin, Scorer or Read only access.",
          "Review approval state and retain at least one administrator.",
        ],
      },
      {
        title: "Courts and sports",
        bullets: [
          "Create courts and assign each to a sport, or retain a legacy unassigned court for every enabled sport.",
          "Enable only the sports the club supports on each client platform.",
          "Set per-sport timer defaults; scorers can still override them for an individual match.",
          "Generate or rotate a court Display Code when a venue scoreboard is required.",
        ],
      },
      {
        title: "Reporting and tournaments",
        paragraphs: [
          "Club Analytics covers volume, demand, court usage, sports, simultaneous activity, scheduled demand and trends where the underlying data is recorded.",
          "When Tournament Manager is enabled for the club, administrators can create events, manage entrants, generate and publish draws, correct results and resolve early-ended fixtures.",
        ],
      },
      {
        title: "Privacy boundary",
        paragraphs: [
          "Only administrators receive the private member and tournament guest directory fields. Scorers receive the minimum name lookup needed for setup, while read-only members receive no match-setup directory access.",
        ],
      },
    ],
  },
  "match-setup": {
    kicker: "Match guide",
    title: "Set up a match",
    lead: "Use the same guided setup from Home or the header new-match button.",
    sections: [
      {
        title: "Choose where the match belongs",
        steps: [
          "Select the blue plus or Start New Match.",
          "Choose Personal, Personal Plus or one of the retained clubs under Score this match for.",
          "Choose Squash, Racketball, Tennis or Padel from the sports enabled for that account and client.",
        ],
        note: "Club matches need a compatible sport-specific court or a legacy unassigned court. Personal matches do not use the club court gate.",
      },
      {
        title: "Add participants",
        bullets: [
          "Enter first name and surname; club scorers can use the approved name-only lookup.",
          "Choose compact shirt-colour dots for each participant. Matching first names are disambiguated with surname initials during scoring.",
          "For club matches, an eligible signed-in user can identify themselves as referee when they are not also a player.",
          "Tennis supports Singles or Doubles. Padel is always Doubles.",
        ],
      },
      {
        title: "Choose match rules",
        bullets: [
          "Squash and Racketball: format, handicap, Golden Point and optional timed warm-up/game breaks.",
          "Tennis: best-of format, opening server/receiver order, advantage or Golden Point, optional final-set match tiebreak and timed breaks.",
          "Padel: doubles lineup, serve/receive order, advantage or Golden Point and timed breaks.",
          "Scheduled matches save these choices for later activation; starting a fresh live match moves directly to the opening-order confirmation.",
        ],
      },
    ],
  },
  "squash-racketball-scoring": {
    kicker: "Scoring guide",
    title: "Score Squash & Racketball",
    lead: "Confirm the opening server, then record every scoring action from the live match screen.",
    sections: [
      {
        title: "Live scoring controls",
        bullets: [
          "Use the named player controls to award a point.",
          "Use the service-side controls to record the current box; changing it replaces the current marker rather than adding a duplicate.",
          "Match Actions records No Let, Yes Let or Stroke with the relevant player where required.",
          "Undo reverses the latest effective scoring action while preserving the append-only audit trail.",
        ],
      },
      {
        title: "Rules and timing",
        paragraphs: [
          "The selected point format, handicap and Golden Point rule are enforced by the scoring engine. Golden Point ends the tied deciding situation with the next point according to the selected sport/format.",
          "When timing is enabled, use the warm-up and 90-second game-break presentation. The running match timer and recorded game durations flow into match history.",
        ],
      },
      {
        title: "Finish or end early",
        paragraphs: [
          "Natural completion opens the result summary automatically. End Match Early requires confirmation and an explicit player-win or draw/no-winner outcome. Tournament-linked early endings do not automatically advance a player until an administrator resolves the tournament outcome.",
        ],
      },
    ],
  },
  "tennis-padel-scoring": {
    kicker: "Scoring guide",
    title: "Score Tennis & Padel",
    lead: "Use the tennis-style scoreboard for points, games, sets, serve order, tiebreaks and match completion.",
    sections: [
      {
        title: "Points, games and sets",
        bullets: [
          "The backend supplies 0, 15, 30, 40 and Ad, or numeric points during a tiebreak.",
          "The scoreboard names the server and receiver and shows the Right or Left service side.",
          "Game and set completion create separate dividers in the timeline and update the match score.",
          "Undo restores the latest effective scoring state when tournament progression has not locked the result.",
        ],
      },
      {
        title: "Singles, doubles and Golden Point",
        paragraphs: [
          "Tennis Singles derives the receiver from the chosen opening server. Tennis Doubles and Padel preserve the chosen serve/receive order across all four participants.",
          "At Padel Golden Point, the receiving team chooses its Right- or Left-court partner before the deciding point. Tennis Golden Point follows the configured deciding-point service side.",
        ],
      },
      {
        title: "Tiebreaks and breaks",
        paragraphs: [
          "Standard sets move into the configured 6–6 tiebreak. Tennis can optionally replace the final set with a 10-point match tiebreak. Timed mode presents 90-second odd-game changeovers and 120-second set breaks.",
        ],
      },
    ],
  },
  "scheduling-history": {
    kicker: "Matches guide",
    title: "Scheduled matches & history",
    lead: "Prepare future fixtures, activate them when play begins and retain a sport-aware result record.",
    sections: [
      {
        title: "Schedule and activate",
        steps: [
          "Open Matches and choose Scheduled.",
          "Create the fixture with its account, sport, participants, court and rules.",
          "Edit the saved fixture if details change; its timer remains at 00:00 before activation.",
          "Select Start when the court is ready. A Personal account must not already have another active match.",
        ],
        note: "Personal scheduling requires Personal Plus. Club scheduling requires a match-capable role and the club's permitted courts.",
      },
      {
        title: "Current and completed matches",
        paragraphs: [
          "Current reopens active scoring. History provides text, sport and date filters, then opens the dedicated read-only result view with match information, start time, total duration and the sport-specific timeline.",
        ],
      },
      {
        title: "Historic terminology",
        paragraphs: [
          "Squash and Racketball report completed games and cumulative games. Tennis and Padel report games within sets, separate set boundaries and the final match result. Server markers appear where relevant without altering the recorded score.",
        ],
      },
    ],
  },
  "live-viewing": {
    kicker: "Live sharing guide",
    title: "Live score viewing",
    lead: "Follow a live HitnScore match remotely using an eight-character viewing code.",
    sections: [
      {
        title: "Share a match",
        steps: [
          "The scorer opens Game Settings during the live match.",
          "Copy the match Viewing Code and share it with the intended viewer.",
          "The viewer signs in with Personal Plus, opens Matches and enters the eight-character code.",
          "The live score and timeline refresh until completion, then retain the final result.",
        ],
      },
      {
        title: "Save followed matches",
        paragraphs: [
          "Select Add to Viewed Matches to retain the match in the signed-in account across web and iOS. The viewer cannot score, undo or otherwise change the source match.",
        ],
      },
      {
        title: "What streaming means",
        paragraphs: [
          "HitnScore streams score data and timeline updates. It does not currently broadcast live video or audio. Use Spectator Scoreboards when the goal is a public venue display rather than a private signed-in viewer.",
        ],
      },
    ],
  },
  "spectator-scoreboards": {
    kicker: "Display guide",
    title: "Spectator scoreboards",
    lead: "Connect a club court to a public display without giving the display device a member login.",
    sections: [
      {
        title: "Prepare a court display",
        steps: [
          "A club administrator opens Settings, selects the club and opens Courts.",
          "Open the required court and generate a Display Code. Rotate the code if access should be replaced.",
          "On the venue screen, open the public Scoreboard Display page and enter that code.",
          "Keep the display open while the court's active match is scored.",
        ],
      },
      {
        title: "Connect the live match",
        paragraphs: [
          "During a club match, Game Settings shows Spectator Display details for the selected court. The public screen receives live score information associated with the active court session.",
        ],
      },
      {
        title: "Display safety",
        bullets: [
          "The display code is not a club member password and does not grant Settings access.",
          "Rotate a code that has been shared beyond its intended venue.",
          "Only player names and match information intended for the scoreboard should be entered into a public-display match.",
        ],
      },
    ],
  },
  analytics: {
    kicker: "Insights guide",
    title: "Analytics",
    lead: "Use recorded match data to understand activity, player performance and club demand.",
    sections: [
      {
        title: "App Analytics",
        paragraphs: [
          "App reporting covers selected time periods and can include match volume, sport mix, completion or abandonment, match and game/set durations, activity by day/hour, trends, rules, formats, competitiveness, points and participant reuse.",
        ],
      },
      {
        title: "Player Analytics",
        paragraphs: [
          "Player reporting links the signed-in profile name to recorded participants. Basic results are available across Personal tiers; Personal Plus adds deeper results, playing time, point/game/set and serve performance where the required events exist, streaks, opponents, scorelines and progress.",
        ],
      },
      {
        title: "Club Analytics",
        paragraphs: [
          "Club administrators can review club volume, peak and off-peak demand, court matches and hours, simultaneous activity, scheduled demand, sport trends and the club digest. Historical values that were never captured are labelled untracked rather than estimated.",
        ],
      },
    ],
  },
  tournaments: {
    kicker: "Competition guide",
    title: "Tournament Manager",
    lead: "Run web-based club tournaments when the feature has been enabled for the selected club.",
    sections: [
      {
        title: "Create entrants and a draw",
        steps: [
          "Create a draft internal or open event with sport, format, dates, grading and entry limit as required.",
          "Search linked accounts or reusable players, add a guest manually, or import a reviewed CSV.",
          "Review identities, ability, grade and seed information before generating the draw.",
          "Review editable draft positions, then publish when the bracket is ready.",
        ],
      },
      {
        title: "Supported draw flows",
        bullets: [
          "Knockout with separated seeds and supported first-round byes.",
          "Knockout with Plate, where first-round losers populate the Plate.",
          "Monrad placement progression through the final finishing-position bands.",
          "A sanitised public draw key that can be disabled without returning the event to draft.",
        ],
      },
      {
        title: "Play tournament fixtures",
        paragraphs: [
          "Administrators and Scorers can schedule a published fixture into normal match scoring or record an authorised result. Natural final-point completion advances the winner. Early-ended or stale fixtures wait for an administrator to resolve played, retired, conceded, walkover or abandoned outcomes; abandoned matches advance nobody.",
        ],
      },
      {
        title: "Guest players",
        paragraphs: [
          "A guest tournament entry does not create app or club access. When an email is available, an administrator can share a Personal or Personal Plus signup route. Registration links that player to the canonical account without automatically granting club membership.",
        ],
      },
    ],
  },
  "settings-security": {
    kicker: "Account guide",
    title: "Settings, profile & security",
    lead: "Keep personal details accurate, review associations and understand how HitnScore protects sessions.",
    sections: [
      {
        title: "Personal profile",
        paragraphs: [
          "Settings opens on a read-only Personal Profile. Enter Edit mode to update email, name, surname, telephone, location and country. Changing the email updates the sign-in identity and revokes existing sessions so the new address can be used securely.",
        ],
      },
      {
        title: "Associations and app settings",
        paragraphs: [
          "Association lists approved club memberships and their roles without switching the current scoring context. App Settings contains Personal sport visibility and saved timer defaults; club administrators receive the separate club workspace controls described in the Club Administrator guide.",
        ],
      },
      {
        title: "Passwords and sessions",
        bullets: [
          "Use Reset Password when the current password is unavailable.",
          "A replacement login revokes the previous identity session across web and mobile.",
          "Role, sport-access, email and password changes can deliberately revoke sessions so permissions are refreshed.",
          "Personal-account deletion uses repeated destructive confirmation and removes the owned Personal workspace, Personal matches and scoring data, active sessions, and all club associations. Club-owned match records remain with the relevant club.",
        ],
      },
    ],
  },
  "notifications-offline": {
    kicker: "Mobile resilience guide",
    title: "Notifications & offline iOS scoring",
    lead: "Keep up with service messages and continue a previously opened match through a temporary connection loss.",
    sections: [
      {
        title: "Notifications",
        paragraphs: [
          "System messages are stored against the signed-in identity and share read state across web and iOS. Open Messages or the iOS notification inbox, review unread items and explicitly mark them read. Push delivery and background badges are not yet implemented, so the inbox currently refreshes through the app.",
        ],
      },
      {
        title: "Offline iOS scoring",
        bullets: [
          "Open the active match online at least once before connectivity is lost.",
          "Continue supported Squash, Racketball, Tennis or Padel scoring from the native app.",
          "Actions are stored with client-generated identifiers and replayed in order after reconnection.",
          "Do not sign in on another device while offline work is waiting, because replacing the session can require recovery before replay.",
        ],
      },
      {
        title: "Offline limits",
        paragraphs: [
          "Creating a new match, activating a scheduled match, loading unseen history, changing settings and opening a match never loaded on the device still require connectivity. The web and Android-browser clients do not provide native offline scoring.",
        ],
      },
    ],
  },
};

function GuideSection({ section }) {
  return (
    <section className="knowledge-guide-section">
      <h2>{section.title}</h2>
      {(section.paragraphs || []).map((paragraph) => <p key={paragraph}>{paragraph}</p>)}
      {section.steps?.length ? (
        <ol>{section.steps.map((step) => <li key={step}>{step}</li>)}</ol>
      ) : null}
      {section.bullets?.length ? (
        <ul>{section.bullets.map((bullet) => <li key={bullet}>{bullet}</li>)}</ul>
      ) : null}
      {section.note ? <div className="knowledge-guide-note">{section.note}</div> : null}
    </section>
  );
}

export function HelpGuideArticle({ guideId }) {
  const guide = GUIDES[guideId];
  if (!guide) return null;

  return (
    <article className="knowledge-article help-copy">
      <p className="knowledge-kicker">{guide.kicker}</p>
      <h1>{guide.title}</h1>
      <p className="knowledge-lead">{guide.lead}</p>
      <div className="knowledge-guide-sections">
        {guide.sections.map((section) => <GuideSection key={section.title} section={section} />)}
      </div>
    </article>
  );
}
