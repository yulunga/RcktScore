# Automated Testing

Automated testing in this repo is split by responsibility:

- `web/` for browser-based behavior
- `backend/` for Python business logic

This keeps tests easier to understand and easier to run.

## What to add where

Put a test in `web/` when:
- a user clicks, types, navigates, signs in, or completes a flow
- you need mobile, tablet, or desktop confidence

Put a test in `backend/` when:
- the logic can be checked without a browser
- the rule should stay true regardless of UI changes
- the code decides permissions, validation, session handling, or scoring outcomes

## Simple rule of thumb

If the bug is about behavior on screen, start with Playwright.

If the bug is about data, rules, or calculations, start with Pytest.

