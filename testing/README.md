# Testing

This folder turns the testing plans in [docs/Testing-automated-testing-plan.md](/Users/glennrowe/Development/Projects/RcktScore/docs/Testing-automated-testing-plan.md) and [docs/Testing-web-test-script.md](/Users/glennrowe/Development/Projects/RcktScore/docs/Testing-web-test-script.md) into a practical working structure.

## Folder layout

`testing/automated/web/`
- Browser automation for the React web app.
- Uses Playwright.
- Best for login, redirects, match lifecycle, permissions, and responsive route checks.

`testing/automated/backend/`
- Fast Python tests for backend logic.
- Uses Pytest.
- Best for session rules, scoring rules, validation, and regression tests.

`testing/manual/`
- Human-led testing for UI, UX, visual quality, accessibility, and device checks.

## Recommended beginner workflow

1. Build a feature.
2. Add or update one automated test for the behavior you changed.
3. Run the automated checks.
4. Do a short manual UI pass on phone, tablet, or desktop as needed.
5. If you find a bug, fix it and add a regression test when possible.

## Why this split works

- Playwright covers what the user actually does in the browser.
- Pytest covers logic that should stay correct even as the UI changes.
- Manual testing catches feel, layout, clarity, and usability issues that scripts do not judge well.

## First things to automate

Follow the priority already defined in your docs:

1. Login and session persistence
2. Match lifecycle
3. Club admin CRUD
4. Permissions boundaries
5. Responsive smoke checks

## How to grow this over time

Start small:
- 3 to 5 smoke tests for public pages and login protection
- 5 to 10 backend rule tests for session and match logic

Then expand:
- Add one test for each bug you fix
- Add one end-to-end flow per important release
- Add role and permission coverage before adding lots of visual checks

Aim for confidence, not volume. A smaller stable suite is much better than a large flaky one.

