package com.hitnscore.mobile.feature.analytics

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider.AndroidViewModelFactory.Companion.APPLICATION_KEY
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.hitnscore.mobile.HitNScoreApplication
import com.hitnscore.mobile.core.network.ApiClient
import com.hitnscore.mobile.core.network.ApiResult
import com.hitnscore.mobile.data.model.AppAnalytics
import com.hitnscore.mobile.data.model.DashboardResponseData
import com.hitnscore.mobile.data.model.Dashboard
import com.hitnscore.mobile.data.remote.HitNScoreApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class AnalyticsUiState(
    /** Dashboards fetched for accounts other than the active one, by organisation id. */
    val dashboards: Map<Int, Dashboard> = emptyMap(),
    val loading: Set<Int> = emptySet(),
    val errors: Map<Int, String> = emptyMap(),
    /** Reporting period for app usage: 7, 30, 90, 365 days or 0 for all time (as iOS). */
    val periodDays: Int = 30,
    /** App usage for (organisation, period), fetched with `analytics_period_days`. */
    val appUsage: Map<Pair<Int, Int>, AppAnalytics> = emptyMap(),
    val appUsageLoading: Set<Pair<Int, Int>> = emptySet(),
)

/**
 * The Personal / Club switch on Analytics shows the other account's figures without
 * changing the active account, so that account's dashboard is fetched here (as iOS loads
 * the personal dashboard alongside a club's).
 */
class AnalyticsViewModel(
    private val api: HitNScoreApi,
    private val client: ApiClient? = null,
) : ViewModel() {
    private val mutableState = MutableStateFlow(AnalyticsUiState())
    val uiState: StateFlow<AnalyticsUiState> = mutableState.asStateFlow()

    fun load(organizationId: Int, force: Boolean = false) {
        val state = mutableState.value
        if (organizationId in state.loading) return
        if (!force && organizationId in state.dashboards) return
        mutableState.update { it.copy(loading = it.loading + organizationId, errors = it.errors - organizationId) }
        viewModelScope.launch {
            val result = api.dashboard(organizationId)
            mutableState.update {
                when (result) {
                    is ApiResult.Success -> it.copy(dashboards = it.dashboards + (organizationId to result.value), loading = it.loading - organizationId)
                    is ApiResult.Failure -> it.copy(errors = it.errors + (organizationId to result.error.message), loading = it.loading - organizationId)
                }
            }
        }
    }

    fun selectPeriod(days: Int) = mutableState.update { it.copy(periodDays = days) }

    /** App usage (matches scored, active days, setups) for the period, as iOS Personal Analytics. */
    fun loadAppUsage(organizationId: Int, force: Boolean = false) {
        val client = client ?: return
        val key = organizationId to mutableState.value.periodDays
        val state = mutableState.value
        if (key in state.appUsageLoading) return
        if (!force && key in state.appUsage) return
        mutableState.update { it.copy(appUsageLoading = it.appUsageLoading + key) }
        viewModelScope.launch {
            val result = client.get(
                "dashboard/$organizationId?active_limit=0&recent_limit=0&analytics_period_days=${key.second}",
                DashboardResponseData.serializer(),
            )
            mutableState.update {
                val usage = (result as? ApiResult.Success)?.value?.dashboard?.appAnalytics
                it.copy(
                    appUsage = if (usage != null) it.appUsage + (key to usage) else it.appUsage,
                    appUsageLoading = it.appUsageLoading - key,
                )
            }
        }
    }

    companion object {
        val PERIODS = listOf(7 to "7 days", 30 to "30 days", 90 to "90 days", 365 to "12 months", 0 to "All time")

        val Factory = viewModelFactory {
            initializer {
                val container = (this[APPLICATION_KEY] as HitNScoreApplication).container
                AnalyticsViewModel(container.api, container.apiClient)
            }
        }
    }
}
