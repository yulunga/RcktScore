package com.hitnscore.mobile.data.remote

import com.hitnscore.mobile.core.network.ApiClient
import com.hitnscore.mobile.core.network.ApiResult
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** `GET /analytics/export/{organization_id}?period_days=N`, as iOS `AnalyticsExportPayload`. */
@Serializable
data class AnalyticsExport(
    @SerialName("report_type") val reportType: String = "",
    val filename: String = "hitnscore-analytics.csv",
    @SerialName("content_type") val contentType: String = "text/csv",
    @SerialName("csv_content") val csvContent: String = "",
    @SerialName("contains_personal_details") val containsPersonalDetails: Boolean = false,
)

@Serializable
data class AnalyticsExportResponseData(val export: AnalyticsExport)

class AnalyticsExportApi(private val client: ApiClient) {
    /** [periodDays] 7, 30, 90, 365, or 0 for all time. */
    suspend fun export(organizationId: Int, periodDays: Int): ApiResult<AnalyticsExport> =
        client.get("analytics/export/$organizationId?period_days=$periodDays", AnalyticsExportResponseData.serializer())
            .map { it.export }
}
