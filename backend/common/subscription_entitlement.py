"""Cross-provider Personal Plus entitlement checks.

One identity may hold Personal Plus through Apple, Google Play, Stripe or a
manual grant. A provider that loses its own entitlement must not downgrade the
account while another verified source still covers it.
"""

ENTITLED_SOURCE_STATUSES = ("active", "grace_period", "cancelled")


def other_source_entitled(
    cursor,
    organization_id,
    now,
    *,
    exclude_provider,
    exclude_subscription_id=None,
):
    """True when a verified source other than the excluded one still grants Plus.

    exclude_subscription_id=None excludes the whole provider (Apple keeps one
    subscription per account); a value excludes only that provider record so a
    re-subscribed Google Play token can keep the account entitled.
    """
    cursor.execute(
        """
        SELECT 1
        FROM subscription_sources
        WHERE organization_id = %(organization_id)s
          AND plan = 'personal_plus'
          AND status IN ('active', 'grace_period', 'cancelled')
          AND current_period_end > %(now)s
          AND NOT (
                provider = %(exclude_provider)s
                AND (
                    %(exclude_subscription_id)s::text IS NULL
                    OR provider_subscription_id = %(exclude_subscription_id)s
                )
              )
        LIMIT 1
        """,
        {
            "organization_id": int(organization_id),
            "now": now,
            "exclude_provider": exclude_provider,
            "exclude_subscription_id": exclude_subscription_id,
        },
    )
    return cursor.fetchone() is not None
