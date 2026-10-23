package com.hitnscore.mobile.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class AppNotification(
    val id: String,
    val title: String = "",
    val message: String = "",
    val audience: String = "",
    @SerialName("created_at") val createdAt: String? = null,
    @SerialName("read_at") val readAt: String? = null,
    @SerialName("is_read") val isRead: Boolean = false,
)

@Serializable
data class NotificationListResponseData(val notifications: List<AppNotification> = emptyList())

@Serializable
data class NotificationReadRequest(@SerialName("organization_id") val organizationId: Int)

@Serializable
data class NotificationReadResponseData(val read: Boolean = false)
