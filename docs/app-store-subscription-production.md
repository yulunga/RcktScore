# Personal Plus App Store Subscription Plan

## Current implementation boundary

The repository now has persistence for verified App Store subscriptions and incoming lifecycle events in migration `024_app_store_subscription_lifecycle.sql`. The native app also has a Debug-only StoreKit 2 service for monthly/yearly product loading, local verified purchases, transaction updates, current entitlements, Restore Purchases and Manage Subscription. Its controls expand from the Personal Plus plan card for 20 seconds. During Debug StoreKit testing, a fresh current-entitlement check selects Personal or Personal Plus and applies a neutral card body, green current-plan outline and pink Current badge. This deliberately does not update the backend plan. The app must not grant Personal Plus from an unverified device response, and the existing root-admin plan switch remains a testing/admin mechanism rather than proof of payment.

There is no free trial in the intended product: a Personal Free user chooses Upgrade, confirms the App Store purchase, and receives Personal Plus only after server verification.

## Production purchase path

1. Create a `Personal Plus` auto-renewable subscription group in App Store Connect with at least one product, for example a monthly product. Do not configure an introductory or trial offer.
2. Complete Paid Apps agreements, banking, tax, price, localisation, review screenshot, subscription description, privacy policy, and terms links in App Store Connect.
3. Promote the existing Debug StoreKit 2 purchase service to production only after step 4 and step 5 are connected. It already loads both products, shows Apple's localised prices, calls `purchase`, handles verified local transactions, exposes Restore Purchases, and links to Apple's Manage Subscriptions screen.
4. Obtain a stable UUID `appAccountToken` from the backend for the authenticated personal account and pass it into each purchase. This binds the Apple transaction to the correct Hit n Score account without trusting an email in the receipt.
5. Add an authenticated backend verification endpoint. It must verify Apple's signed JWS certificate chain and payload, confirm bundle ID, product ID, environment, transaction ownership, expiry and revocation state, then upsert `app_store_subscriptions` idempotently.
6. Configure App Store Server Notifications V2. The public webhook verifies every signed payload before inserting `app_store_subscription_events`, then updates the authoritative subscription row for purchase, renewal, billing retry, grace period, expiry, refund and revocation events.
7. Change `personal_plan` to `personal_plus` only from a verified active/grace-period subscription. Downgrade to `personal_free` on verified expiry or revocation while retaining stored match data; access returns to the latest-three window.
8. Add reconciliation using App Store Server API history/status queries so missed webhooks cannot leave stale entitlements. Run it on purchase/restore and periodically for subscriptions near or beyond expiry.
9. Return subscription status and the shared entitlement contract to web/iOS/admin. Web can display status but, under Apple's rules and the chosen product approach, iOS should be the purchase surface unless an approved external-purchase entitlement applies.
10. Test new purchase, renewal, cancel-at-period-end, billing retry, grace period, expiry, refund, revoke, upgrade restore, reinstall, device change, account change, Sandbox and TestFlight before production release.

## Operational and review requirements

- Keep Apple private keys in the deployment secret store, never in source control or the app bundle.
- Make webhook and transaction processing idempotent using notification UUIDs and transaction IDs.
- Record entitlement changes in an audit log and alert on verification failures, webhook backlog and unexpected plan drift.
- Publish subscription terms that state price, billing period, auto-renewal behaviour, cancellation route and what access changes after expiry.
- Provide Restore Purchases and Manage Subscription controls in the app.
- Decide whether grace-period users keep Plus access; the recommended contract is yes until Apple's grace expiry.
- Ensure account deletion handles the Hit n Score account while explaining that App Store subscription cancellation is managed separately by Apple.
- Never delete completed match data merely because Plus expires. Restrict visibility to the Free entitlement so it is available again after a later upgrade.

## Current product contract

- Personal Free: latest 3 completed matches, no performance dashboard.
- Personal Plus: latest 100 completed matches and the implemented performance dashboard.
- Both: core scoring and shirt-colour selection.

The source of truth is `backend/common/plan_entitlements.py`. API responses expose the current values under `organization.entitlements` and both plans under `organization.available_plan_entitlements`, allowing web and iOS copy to follow the backend contract.
