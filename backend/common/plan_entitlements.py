PERSONAL_PLAN_ENTITLEMENTS = {
    "personal_free": {
        "history_limit": 3,
        "performance_enabled": False,
    },
    "personal_plus": {
        "history_limit": 100,
        "performance_enabled": True,
    },
}


def personal_plan_entitlements(plan):
    return PERSONAL_PLAN_ENTITLEMENTS.get(plan or "personal_free", PERSONAL_PLAN_ENTITLEMENTS["personal_free"])


def personal_plan_contract():
    return {plan: dict(values) for plan, values in PERSONAL_PLAN_ENTITLEMENTS.items()}
