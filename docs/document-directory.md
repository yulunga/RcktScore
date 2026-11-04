# HitnScore Document Directory

Last audited: 4 November 2026

## Purpose

This is the master directory for repository-owned HitnScore documentation. It
separates current operating manuals from plans, historical reviews, test
artifacts, and supporting templates so dated material is not mistaken for the
current product contract.

Status meanings:

- **Current**: suitable as a present-tense reference.
- **Update proposed**: contains one or more claims that no longer match the code.
- **Historical**: valid evidence from a dated review or test session; do not use
  as the current product description.
- **Plan/reference**: intentionally describes future or staged work.
- **Draft**: useful but not yet tracked in Git.

## Core Product And Engineering

| Document | Purpose | Status |
| --- | --- | --- |
| [Repository operating guide](../AGENTS.md) | Current repository, product, security, platform, and verification guide | Update proposed |
| [Repository README](../README.md) | Top-level orientation and quick verification | Update proposed |
| [Backend API reference](backend-api.md) | Backend modules, routes, contracts, authorization, and known gaps | Update proposed |
| [Technical walkthrough](technical-walkthrough.md) | End-to-end request and lifecycle flows | Update proposed |
| [Troubleshooting guide](troubleshooting.md) | Operational diagnosis and verification commands | Update proposed |
| [Service relationships](service-relationships.md) | Hosting, providers, data flow, and service dependencies | Draft; Android section is stale |

## Product, Access, And Architecture

| Document | Purpose | Status |
| --- | --- | --- |
| [Feature packaging and entitlements](feature-payments-structure.md) | Code-backed capabilities and commercially safe claims | Update proposed |
| [Capability and access inventory](hitnscore-capability-and-access-inventory-2026-10-23.md) | Dated permissions and packaging inventory | Historical; update or supersede |
| [New-user onboarding walkthrough](new-user-onboarding-walkthrough.md) | Registration, approval, login, account context, and first-match flow | Update proposed |
| [Tournament Manager discovery](tournament-module-discovery.md) | Original tournament architecture and staged delivery proposal | Plan/reference; implementation-status update proposed |
| [Scoreboard V1 implementation](scoreboard-v1-implementation.md) | Court-display data model, routes, client flow, and test path | Update proposed |

## Mobile

| Document | Purpose | Status |
| --- | --- | --- |
| [Mobile documentation index](mobile/README.md) | Mobile manuals and current iOS/Android summary | Update proposed |
| [Mobile setup](mobile/setup.md) | Platform areas, dependencies, scope, and environments | Update proposed |
| [Mobile build](mobile/build.md) | iOS local build and verification guide | Current |
| [Mobile signing](mobile/signing.md) | iOS signing and distribution notes | Update proposed |
| [Mobile release notes](mobile/release-notes.md) | Current unreleased native iOS state and gaps | Update proposed |
| [iOS V1 plan](mobile/ios-v1-plan.md) | iOS baseline, hardening work, and release gate | Update proposed |
| [Android parity plan](mobile/android-parity-plan.md) | Android architecture and staged parity plan | Update proposed |
| [Mobile workspace README](../mobile/README.md) | Mobile folder orientation | Update proposed |
| [Android workspace README](../mobile/android/README.md) | Android M4 implementation, build, signing, CI, and remaining work | Current |
| [iOS workspace README](../mobile/ios/README.md) | iOS project shape and current feature coverage | Current |
| [iOS UI-test credentials and journeys](../mobile/ios/RcktScoreMobile/RcktScoreMobileUITests/README.md) | Local credentials and live native test runners | Current |
| [Mobile shared references](../mobile/shared/README.md) | Purpose of the shared mobile reference area | Update proposed |
| [Mobile API contracts](../mobile/shared/api-contracts/README.md) | Mobile response-envelope and contract reference area | Update proposed |
| [Mobile match states](../mobile/shared/match-states/README.md) | Mobile scoring-state reference area | Update proposed |

## User Knowledge Base

| Document | Purpose | Status |
| --- | --- | --- |
| [Register and sign in on iOS](knowledge-base/register-and-sign-in-ios.md) | Customer guide for registration, approval, login, biometrics, and recovery | Update proposed |
| [Register and sign in on web](knowledge-base/register-and-sign-in-web.md) | Customer guide for registration, approval, login, and recovery | Update proposed |

## Testing

| Document | Purpose | Status |
| --- | --- | --- |
| [Automated testing implementation plan](Testing-automated-testing-plan.md) | Test strategy, rollout, CI, and iOS signoff plan | Update proposed |
| [Legacy web test script](Testing-web-test-script.md) | Earlier manual end-to-end web script | Update proposed; consolidate or archive |
| [Testing index](../testing/README.md) | Test-folder orientation and workflow | Update proposed |
| [Automated testing index](../testing/automated/README.md) | Test-suite responsibilities | Update proposed |
| [Backend automation](../testing/automated/backend/README.md) | Pytest setup and backend coverage guide | Update proposed |
| [Mobile automation](../testing/automated/mobile/README.md) | Native reducer tests and credential-backed iOS journeys | Current |
| [Web automation](../testing/automated/web/README.md) | Playwright setup and implemented journeys | Current |
| [Manual fixtures](../testing/fixtures/README.md) | Non-production Personal Plus history fixture | Current |
| [Manual testing index](../testing/manual/README.md) | Purpose of human-led testing | Current |
| [UI and UX checklist](../testing/manual/ui-ux-checklist.md) | Short cross-device manual checklist | Update proposed |
| [Web client checklist](../testing/manual/web-client-checklist.md) | Current detailed manual web regression checklist | Current |
| [Web testing workbook](../testing/manual/HitnScore-Web-Testing-Workbook.docx) | Printable/result-recording workbook prepared 15 October 2026 | Update proposed |

## Release, Subscription, And Operations

| Document | Purpose | Status |
| --- | --- | --- |
| [Promotion runbook](promotion-runbook.md) | Migration ledger, staging/production promotion, rollback, and evidence | Current |
| [App Store subscription plan](app-store-subscription-production.md) | Concise Personal Plus purchase and production boundary | Update proposed |
| [Apple subscription production plan](apple-subscription-production.md) | Full StoreKit/backend lifecycle, deployment, and evidence checklist | Current plan/reference |
| [Landing-site AWS and GoDaddy deployment](weblanding-aws-godaddy-deployment.md) | Static-site deployment and DNS runbook | Current |
| [Marketing-site README](../weblanding/README.md) | Standalone landing-site purpose and current content | Current |

## Dated Reviews And Evidence

| Document | Purpose | Status |
| --- | --- | --- |
| [Production readiness review 8 September](production-readiness-and-personal-plus-review-2026-09-08.md) | Dated readiness and packaging assessment | Historical; archive label proposed |
| [Public website review 10 September](public-website-review-2026-09-10.md) | Dated website assessment and expansion blueprint | Historical; archive label proposed |
| [Production readiness four-day plan](../testing/reports/HitnScore-Production-Release-Readiness-and-Four-Day-Plan-2026-09-11.docx) | Dated release-readiness report and launch plan | Historical |
| [Apple subscription Sandbox report](../testing/reports/RcktScore-Apple-Subscription-Sandbox-Test-Report-2026-09-11.docx) | TestFlight/Sandbox lifecycle evidence from four test scenarios | Historical evidence |

## Supporting Text And Configuration Documents

These are repository documents but not product manuals:

- `backend/requirements.txt`
- `testing/automated/backend/requirements-test.txt`
- notification subject/body templates under `backend/notifications/templates/`

Generated dependency documentation under `screens/**/.pio/libdeps/` and the
reference-only `version1/` application are intentionally excluded from this
directory because HitnScore does not own or maintain those manuals as current v2
product documentation.

## Maintenance Rule

When a document is added, renamed, superseded, or archived, update this directory
in the same change. Present-tense product claims should point back to the
operating guide, API reference, technical walkthrough, or troubleshooting guide
rather than being copied into several independent sources.
