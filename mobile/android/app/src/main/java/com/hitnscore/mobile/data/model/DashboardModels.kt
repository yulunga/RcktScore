package com.hitnscore.mobile.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class DashboardResponseData(val dashboard: Dashboard)

/** `GET /dashboard/{organization_id}`, as iOS `DashboardResponse`. */
@Serializable
data class Dashboard(
    val organization: OrganizationSummary? = null,
    @SerialName("active_matches") val activeMatches: List<MatchSummary> = emptyList(),
    @SerialName("scheduled_matches") val scheduledMatches: List<MatchSummary> = emptyList(),
    @SerialName("recent_matches") val recentMatches: List<MatchSummary> = emptyList(),
    @SerialName("viewed_matches") val viewedMatches: List<MatchSummary> = emptyList(),
    val performance: PersonalPerformance? = null,
)

@Serializable
data class OrganizationSummary(
    val id: Int,
    val name: String? = null,
    val type: String? = null,
    val plan: String? = null,
    @SerialName("history_limit") val historyLimit: Int? = null,
    @SerialName("court_count") val courtCount: Int? = null,
    @SerialName("user_count") val userCount: Int? = null,
    val roles: List<String> = emptyList(),
    @SerialName("completed_match_count") val completedMatchCount: Int? = null,
    @SerialName("locked_history_count") val lockedHistoryCount: Int? = null,
    val entitlements: PlanEntitlements? = null,
)

@Serializable
data class PlanEntitlements(
    @SerialName("history_limit") val historyLimit: Int = 0,
    @SerialName("performance_enabled") val performanceEnabled: Boolean = false,
)

/** Personal Plus performance report (`build_personal_performance`). */
@Serializable
data class PersonalPerformance(
    @SerialName("classified_match_count") val classifiedMatchCount: Int = 0,
    @SerialName("unclassified_match_count") val unclassifiedMatchCount: Int = 0,
    @SerialName("matches_played") val matchesPlayed: Int = 0,
    @SerialName("matches_won") val matchesWon: Int = 0,
    @SerialName("matches_lost") val matchesLost: Int = 0,
    @SerialName("win_percentage") val winPercentage: Double? = null,
    @SerialName("games_won") val gamesWon: Int = 0,
    @SerialName("games_lost") val gamesLost: Int = 0,
    @SerialName("game_win_percentage") val gameWinPercentage: Double? = null,
    @SerialName("points_won") val pointsWon: Int = 0,
    @SerialName("points_lost") val pointsLost: Int = 0,
    @SerialName("point_win_percentage") val pointWinPercentage: Double? = null,
    @SerialName("playing_time_seconds") val playingTimeSeconds: Int = 0,
    @SerialName("close_games_played") val closeGamesPlayed: Int = 0,
    @SerialName("close_games_won") val closeGamesWon: Int = 0,
    @SerialName("close_game_win_percentage") val closeGameWinPercentage: Double? = null,
    @SerialName("service_points_won") val servicePointsWon: Int = 0,
    @SerialName("service_points_lost") val servicePointsLost: Int = 0,
    @SerialName("service_point_win_percentage") val servicePointWinPercentage: Double? = null,
    @SerialName("current_win_streak") val currentWinStreak: Int = 0,
    @SerialName("best_win_streak") val bestWinStreak: Int = 0,
    @SerialName("scoreline_wins") val scorelineWins: List<PerformanceScoreline> = emptyList(),
    val opponents: List<PerformanceOpponent> = emptyList(),
    val sports: List<PerformanceSport> = emptyList(),
    @SerialName("monthly_improvement") val monthlyImprovement: List<PerformanceMonthlyImprovement> = emptyList(),
    @SerialName("weekly_summary") val weeklySummary: PerformancePeriodSummary = PerformancePeriodSummary(),
    @SerialName("monthly_summary") val monthlySummary: PerformancePeriodSummary = PerformancePeriodSummary(),
)

@Serializable
data class PerformanceScoreline(val scoreline: String = "", val count: Int = 0)

@Serializable
data class PerformanceOpponent(
    val name: String = "",
    @SerialName("matches_played") val matchesPlayed: Int = 0,
    val won: Int = 0,
    val lost: Int = 0,
    @SerialName("win_percentage") val winPercentage: Double? = null,
)

@Serializable
data class PerformanceSport(
    val sport: String = "",
    @SerialName("matches_played") val matchesPlayed: Int = 0,
    val won: Int = 0,
    val lost: Int = 0,
    @SerialName("win_percentage") val winPercentage: Double? = null,
    @SerialName("playing_time_seconds") val playingTimeSeconds: Int = 0,
)

@Serializable
data class PerformanceMonthlyImprovement(
    val sport: String = "",
    @SerialName("current_month_matches") val currentMonthMatches: Int = 0,
    @SerialName("current_month_win_percentage") val currentMonthWinPercentage: Double? = null,
    @SerialName("previous_month_matches") val previousMonthMatches: Int = 0,
    @SerialName("previous_month_win_percentage") val previousMonthWinPercentage: Double? = null,
    @SerialName("percentage_point_change") val percentagePointChange: Double? = null,
)

@Serializable
data class PerformancePeriodSummary(
    @SerialName("matches_played") val matchesPlayed: Int = 0,
    @SerialName("matches_won") val matchesWon: Int = 0,
    @SerialName("matches_lost") val matchesLost: Int = 0,
    @SerialName("win_percentage") val winPercentage: Double? = null,
    @SerialName("playing_time_seconds") val playingTimeSeconds: Int = 0,
)
