package com.hitnscore.mobile.feature.shell

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.hitnscore.mobile.R
import com.hitnscore.mobile.core.designsystem.theme.HitNScoreTheme
import com.hitnscore.mobile.core.session.AccountContext
import com.hitnscore.mobile.core.session.AccountContextType
import com.hitnscore.mobile.core.session.SessionState
import com.hitnscore.mobile.data.model.ClubRoles

private val OfflineOrange = Color(0xFFF08A24)

object ShellHeaderTags {
    const val CONTEXT_PILL = "shell_context_pill"
    const val SIGN_OUT = "shell_sign_out"
}

/**
 * Brand header at the top of each tab, as the web client: the logo on the left; on the
 * right the notifications bell (yellow when unread, or an offline indicator) and a pill
 * with the account context's name. The pill opens the account menu: each context with
 * its plan or club role (Current / Switch), then Logout.
 */
@Composable
fun ShellHeader(
    session: SessionState.SignedIn,
    isOnline: Boolean,
    hasUnreadNotifications: Boolean,
    onOpenNotifications: () -> Unit,
    onContextSelected: (AccountContext) -> Unit,
    onSignOut: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Image(
            painter = painterResource(R.drawable.splash_logo),
            contentDescription = stringResource(R.string.app_logo),
            modifier = Modifier.size(56.dp),
        )
        Spacer(Modifier.weight(1f))
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
        Spacer(Modifier.width(4.dp))
        AccountMenu(session, onContextSelected, onSignOut)
    }
}

@Composable
private fun AccountMenu(
    session: SessionState.SignedIn,
    onContextSelected: (AccountContext) -> Unit,
    onSignOut: () -> Unit,
) {
    var expanded by rememberSaveable { mutableStateOf(false) }
    val active = session.activeContext
    val description = stringResource(R.string.context_switch_description, contextTitle(active))
    Box {
        Surface(
            onClick = { expanded = true },
            shape = RoundedCornerShape(50),
            color = MaterialTheme.colorScheme.surface,
            border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant),
            modifier = Modifier
                .widthIn(max = 200.dp)
                .testTag(ShellHeaderTags.CONTEXT_PILL)
                .semantics { contentDescription = description },
        ) {
            Row(
                Modifier.padding(start = 16.dp, end = 12.dp, top = 10.dp, bottom = 10.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                Text(
                    contextTitle(active),
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.Bold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f, fill = false),
                )
                Icon(painterResource(R.drawable.ic_menu), contentDescription = null, modifier = Modifier.size(20.dp))
            }
        }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }, shape = RoundedCornerShape(20.dp)) {
            session.availableContexts.forEach { context ->
                val current = context.membershipId == active.membershipId
                DropdownMenuItem(
                    text = {
                        Column(Modifier.widthIn(min = 200.dp)) {
                            Text(contextTitle(context), style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
                            Text(contextSubtitle(context), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    },
                    trailingIcon = {
                        Text(
                            stringResource(if (current) R.string.context_current else R.string.context_switch),
                            style = MaterialTheme.typography.labelLarge,
                            color = MaterialTheme.colorScheme.primary,
                        )
                    },
                    onClick = {
                        expanded = false
                        if (!current) onContextSelected(context)
                    },
                )
            }
            HorizontalDivider(Modifier.padding(vertical = 4.dp), color = MaterialTheme.colorScheme.outlineVariant)
            DropdownMenuItem(
                text = {
                    Column {
                        Text(stringResource(R.string.logout), style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold, color = HitNScoreTheme.colors.completedStatus)
                        Text(stringResource(R.string.logout_body), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                },
                onClick = {
                    expanded = false
                    onSignOut()
                },
                modifier = Modifier.testTag(ShellHeaderTags.SIGN_OUT),
            )
        }
    }
}

/** The tier for a Personal account ("Personal" or "Personal+"), or the club's name. */
@Composable
internal fun contextTitle(context: AccountContext): String = when {
    context.type != AccountContextType.Personal -> context.name
    context.plan.contains("plus", ignoreCase = true) -> stringResource(R.string.context_personal_plus)
    else -> stringResource(R.string.context_personal)
}

/** As the web menu: the plan for Personal ("Personal Free"), the club role for clubs. */
@Composable
internal fun contextSubtitle(context: AccountContext): String =
    if (context.type == AccountContextType.Personal) {
        context.plan
    } else {
        stringResource(
            when (ClubRoles.normalize(context.role)) {
                ClubRoles.ADMIN -> R.string.context_role_admin
                ClubRoles.READ_ONLY -> R.string.context_role_read_only
                else -> R.string.context_role_scorer
            },
        )
    }
