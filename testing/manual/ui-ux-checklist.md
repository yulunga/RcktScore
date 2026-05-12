# UI / UX Manual Testing Checklist

Use this checklist after UI changes and before releases.

## Authentication

- Open `/login`
- Confirm username and password fields are clear
- Confirm sign-in error messages are understandable
- Confirm help and reset-password paths are easy to find

## Navigation

- Open `/dashboard`, `/matches`, `/history`, `/settings`, and `/display`
- Confirm the user can always tell where they are
- Confirm important actions are visible without hunting

## Match flow

- Create a match
- Start the match
- Score several points
- Use undo
- End the match
- Confirm the history/result feels correct to a real scorer

## Club admin flow

- Check court management
- Check user management
- Confirm admin-only actions are visible only to the right user

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

