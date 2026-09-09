def _iso(value):
    return value.isoformat() if value else None


def get_root_admin_subscriptions(connection, organization_id=None):
    filters = []
    params = {}
    if organization_id is not None:
        params["organization_id"] = int(organization_id)
        filters.append("s.organization_id = %(organization_id)s")
    where = f"WHERE {' AND '.join(filters)}" if filters else ""

    with connection.cursor() as cursor:
        cursor.execute(
            """
            SELECT
                COUNT(*) AS total,
                COUNT(*) FILTER (WHERE status = 'active') AS active,
                COUNT(*) FILTER (WHERE status = 'grace_period') AS grace_period,
                COUNT(*) FILTER (WHERE status = 'billing_retry') AS billing_retry,
                COUNT(*) FILTER (WHERE status = 'expired') AS expired,
                COUNT(*) FILTER (WHERE status = 'revoked') AS revoked,
                COUNT(*) FILTER (WHERE auto_renew_enabled = false) AS cancelling
            FROM app_store_subscriptions
            """
        )
        summary = cursor.fetchone() or {}

        cursor.execute(
            f"""
            SELECT s.*, o.organization_name, o.owner_username, o.plan
            FROM app_store_subscriptions AS s
            JOIN "SkwshOrgSettings" AS o ON o.id = s.organization_id
            {where}
            ORDER BY s.updated_at DESC
            """,
            params,
        )
        subscriptions = cursor.fetchall()

        audit_where = "WHERE a.organization_id = %(organization_id)s" if organization_id is not None else ""
        cursor.execute(
            f"""
            SELECT a.*, o.organization_name
            FROM subscription_entitlement_audit AS a
            LEFT JOIN "SkwshOrgSettings" AS o ON o.id = a.organization_id
            {audit_where}
            ORDER BY a.created_at DESC, a.id DESC
            """,
            params,
        )
        audit = cursor.fetchall()

        event_where = "WHERE e.organization_id = %(organization_id)s" if organization_id is not None else ""
        cursor.execute(
            f"""
            SELECT e.*, o.organization_name
            FROM app_store_subscription_events AS e
            LEFT JOIN "SkwshOrgSettings" AS o ON o.id = e.organization_id
            {event_where}
            ORDER BY e.verified_at DESC, e.id DESC
            LIMIT 500
            """,
            params,
        )
        events = cursor.fetchall()

    return {
        "summary": {key: int(summary.get(key) or 0) for key in (
            "total", "active", "grace_period", "billing_retry", "expired", "revoked", "cancelling"
        )},
        "subscriptions": [
            {
                "id": row["id"],
                "organization_id": row["organization_id"],
                "organization_name": row.get("organization_name"),
                "username": row.get("username"),
                "plan": row.get("plan"),
                "product_id": row.get("product_id"),
                "environment": row.get("environment"),
                "status": row.get("status"),
                "auto_renew_enabled": row.get("auto_renew_enabled"),
                "purchased_at": _iso(row.get("purchased_at")),
                "expires_at": _iso(row.get("expires_at")),
                "grace_period_expires_at": _iso(row.get("grace_period_expires_at")),
                "revoked_at": _iso(row.get("revoked_at")),
                "last_verified_at": _iso(row.get("last_verified_at")),
                "last_reconciled_at": _iso(row.get("last_reconciled_at")),
                "next_reconciliation_at": _iso(row.get("next_reconciliation_at")),
                "reconciliation_error": row.get("reconciliation_error"),
                "reconciliation_retry_count": row.get("reconciliation_retry_count") or 0,
                "original_transaction_id": row.get("original_transaction_id"),
                "latest_transaction_id": row.get("latest_transaction_id"),
            }
            for row in subscriptions
        ],
        "audit": [
            {
                "id": row["id"],
                "organization_id": row["organization_id"],
                "organization_name": row.get("organization_name"),
                "account_username": row.get("account_username"),
                "previous_plan": row.get("previous_plan"),
                "new_plan": row.get("new_plan"),
                "source": row.get("source"),
                "reason": row.get("reason"),
                "transaction_id": row.get("transaction_id"),
                "notification_uuid": row.get("notification_uuid"),
                "effective_at": _iso(row.get("effective_at")),
                "created_at": _iso(row.get("created_at")),
            }
            for row in audit
        ],
        "events": [
            {
                "id": row["id"],
                "organization_id": row.get("organization_id"),
                "organization_name": row.get("organization_name"),
                "notification_uuid": row.get("notification_uuid"),
                "notification_type": row.get("notification_type"),
                "subtype": row.get("subtype"),
                "environment": row.get("environment"),
                "status_before": row.get("subscription_status_before"),
                "status_after": row.get("subscription_status_after"),
                "plan_before": row.get("plan_before"),
                "plan_after": row.get("plan_after"),
                "processing_error": row.get("processing_error"),
                "attempts": row.get("processing_attempt_count") or 0,
                "verified_at": _iso(row.get("verified_at")),
                "processed_at": _iso(row.get("processed_at")),
            }
            for row in events
        ],
    }
