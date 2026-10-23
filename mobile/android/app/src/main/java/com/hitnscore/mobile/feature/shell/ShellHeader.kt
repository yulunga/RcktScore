package com.hitnscore.mobile.feature.shell

import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.hitnscore.mobile.R
import com.hitnscore.mobile.core.designsystem.theme.HitNScoreTheme
import com.hitnscore.mobile.core.session.AccountContext
import com.hitnscore.mobile.core.session.AccountContextSwitcher
import com.hitnscore.mobile.core.session.SessionState
import com.hitnscore.mobile.feature.auth.BrandWordmark

private val OfflineOrange = Color(0xFFF08A24)

/**
 * Brand header at the top of each tab, as iOS: logo, wordmark, notifications bell
 * (yellow when unread) or an offline indicator, and the account-context switcher.
 */
@Composable
fun ShellHeader(
    session: SessionState.SignedIn,
    isOnline: Boolean,
    hasUnreadNotifications: Boolean,
    contextLabel: String,
    onOpenNotifications: () -> Unit,
    onContextSelected: (AccountContext) -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(modifier.fillMaxWidth()) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Image(
                painter = painterResource(R.drawable.splash_logo),
                contentDescription = null,
                modifier = Modifier.size(56.dp),
            )
            Spacer(Modifier.width(8.dp))
            BrandWordmark(modifier = Modifier.weight(1f), fontSize = 26.sp)
            if (isOnline) {
                IconButton(onClick = onOpenNotifications) {
                    Icon(
                        painter = painterResource(
                            if (hasUnreadNotifications) R.drawable.ic_notifications else R.drawable.ic_notifications_none,
                        ),
                        contentDescription = stringResource(
                            if (hasUnreadNotifications) R.string.notifications_unread else R.string.notifications,
                        ),
                        tint = if (hasUnreadNotifications) HitNScoreTheme.colors.gameScore else MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            } else {
                Icon(
                    painter = painterResource(R.drawable.ic_wifi_off),
                    contentDescription = stringResource(R.string.offline),
                    tint = OfflineOrange,
                    modifier = Modifier.padding(12.dp),
                )
            }
        }
        Spacer(Modifier.height(12.dp))
        AccountContextSwitcher(
            activeContext = session.activeContext,
            availableContexts = session.availableContexts,
            label = contextLabel,
            onContextSelected = onContextSelected,
            modifier = Modifier.fillMaxWidth(),
        )
    }
}
