package com.hitnscore.mobile.core.session

enum class AccountContextType {
    Personal,
    Club,
}

data class AccountContext(
    val membershipId: Int,
    val organizationId: Int,
    val name: String,
    val type: AccountContextType,
    val role: String,
    val plan: String,
)
