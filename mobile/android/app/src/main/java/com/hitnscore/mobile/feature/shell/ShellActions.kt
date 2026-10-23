package com.hitnscore.mobile.feature.shell

import com.hitnscore.mobile.core.session.AccountContext
import com.hitnscore.mobile.data.model.MatchSummary

/** Navigation and data actions shared by the signed-in tabs. */
data class ShellActions(
    val onRefresh: () -> Unit,
    val onOpenMatch: (MatchSummary) -> Unit,
    val onOpenNotifications: () -> Unit,
    val onShowMatches: (MatchesCategory) -> Unit,
    val onSelectMatchesCategory: (MatchesCategory) -> Unit,
    val onOpenSubscription: () -> Unit,
    val onContextSelected: (AccountContext) -> Unit,
)
