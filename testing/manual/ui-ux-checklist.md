# UI / UX Manual Testing Checklist

**Naming:** HitnScore is the customer-facing application. `RcktScore` is the internal project and repository code name.

Use this checklist after UI changes and before releases.

## Authentication

- Open `/login`
- Confirm username and password fields are clear
- Confirm sign-in error messages are understandable
- Confirm help and reset-password paths are easy to find

## Central profile image

- Upload JPEG, PNG and WebP source images from web, iOS and Android; each must be no larger than 5 MB and at least 256 × 256 pixels
- Confirm the saved photograph is square, correctly oriented and visibly compressed without looking blurred
- Sign in on the other two clients and confirm the same image appears from the central profile
- Attempt an oversized, undersized and unsupported file and confirm the existing image remains unchanged
- Replace the image and confirm the previous version disappears across clients; then remove it and confirm initials return everywhere
- Inspect the Club and public surfaces and confirm the photograph is not exposed where the user has not explicitly been told it will appear

## Navigation

- Open `/dashboard`, `/matches`, `/history`, `/settings`, and `/display`
- Confirm the user can always tell where they are
- Confirm important actions are visible without hunting

## Match flow

- Create a match
- In a club context on web and iOS, select Referee → Me and confirm the signed-in profile name is filled; then enter that same person as any singles/doubles player and confirm Me clears and becomes unavailable
- Start the match
- Score several points
- Use undo
- End the match
- Confirm the history/result feels correct to a real scorer

## Club admin flow

- Check court management
- Check user management
- Confirm admin-only actions are visible only to the right user

## Analytics and reporting

- On web and native iOS, confirm Analytics uses Personal and Club sections with the same 7-day, 30-day, 90-day, 12-month and All-time reporting periods
- Confirm Personal Free shows limited app-usage and match-setup analytics without an export action
- Confirm Personal Plus adds game/player analytics and can prepare and share or download a CSV report
- In a club context, confirm Admin, Scorer and Read only members can see aggregate Club analytics regardless of club tier
- Confirm the Club CSV contains court and match-use aggregates but no player names, member names, usernames, email addresses or member directory data
- Start and abandon one setup, then complete another on both web and iOS; confirm the setup figures update without blocking match creation if analytics recording fails

## Responsive checks

- iPhone portrait
- iPhone landscape
- Android portrait
- iPad landscape
- Desktop Chrome

For each device:

- No horizontal scroll unless intentionally designed
- Buttons remain tappable
- Text does not overlap
- Tables and cards stay readable

## Accessibility quick pass

- Keyboard navigation works
- Focus state is visible
- Color contrast is readable
- Labels and headings are descriptive

## Release notes

- What changed:
- What was tested:
- What passed:
- What failed:
- Follow-up actions:

