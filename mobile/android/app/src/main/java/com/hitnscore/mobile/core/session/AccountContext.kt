package com.hitnscore.mobile.core.session

import com.hitnscore.mobile.core.auth.UserMembership

enum class AccountContextType {
    Personal,
    Club,
}

/** One account the signed-in user can act in, as shown in the context switcher. */
data class AccountContext(
    val membershipId: Int,
    val organizationId: Int,
    val name: String,
    val type: AccountContextType,
    val role: String,
    /** Display name of the plan, e.g. "Personal Plus". */
    val plan: String,
)

fun UserMembership.toAccountContext() = AccountContext(
    membershipId = id,
    organizationId = organizationId,
    name = organizationName,
    type = if (isPersonal) AccountContextType.Personal else AccountContextType.Club,
    role = role,
    plan = planDisplayName(plan, isPersonal),
)

/** Matches iOS `UserSession.planDisplayName`. */
fun planDisplayName(plan: String?, isPersonal: Boolean): String = when (plan?.lowercase()) {
    "personal_plus" -> "Personal Plus"
    "personal_free" -> "Personal Free"
    "club_pro" -> "Club Pro"
    "club_essentials" -> "Club Essentials"
    else -> if (isPersonal) "Personal Free" else "Club Essentials"
}
