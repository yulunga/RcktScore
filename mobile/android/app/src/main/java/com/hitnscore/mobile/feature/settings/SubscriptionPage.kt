package com.hitnscore.mobile.feature.settings

import androidx.annotation.StringRes
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
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
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.hitnscore.mobile.R
import com.hitnscore.mobile.core.designsystem.components.CardGrid
import com.hitnscore.mobile.core.designsystem.theme.HitNScoreTheme

/** A plan on the Subscription page (same names and wording as the web `SubscriptionPreview`). */
internal data class PlanOption(
    val code: String,
    @param:StringRes val name: Int,
    @param:StringRes val eyebrow: Int,
    @param:StringRes val description: Int,
    val features: List<Int>,
    val featured: Boolean = false,
)

internal val PERSONAL_PLANS = listOf(
    PlanOption("personal_free", R.string.plan_personal, R.string.plan_personal_eyebrow, R.string.plan_personal_body,
        listOf(R.string.plan_personal_f1, R.string.plan_personal_f2, R.string.plan_personal_f3)),
    PlanOption("personal_plus", R.string.plan_personal_plus, R.string.plan_personal_plus_eyebrow, R.string.plan_personal_plus_body,
        listOf(R.string.plan_personal_plus_f1, R.string.plan_personal_plus_f2, R.string.plan_personal_plus_f3, R.string.plan_personal_plus_f4)),
)

internal val CLUB_PLANS = listOf(
    PlanOption("club_essentials", R.string.plan_club_essentials, R.string.plan_club_essentials_eyebrow, R.string.plan_club_essentials_body,
        listOf(R.string.plan_club_essentials_f1, R.string.plan_club_essentials_f2, R.string.plan_club_essentials_f3, R.string.plan_club_essentials_f4)),
    PlanOption("club_pro", R.string.plan_club_pro, R.string.plan_club_pro_eyebrow, R.string.plan_club_pro_body,
        listOf(R.string.plan_club_pro_f1, R.string.plan_club_pro_f2, R.string.plan_club_pro_f3, R.string.plan_club_pro_f4), featured = true),
)

/** The plan name shown as the current subscription (as the web `planName`). */
@StringRes
internal fun planNameRes(code: String?): Int = when (code?.lowercase()) {
    "personal_plus" -> R.string.plan_personal_plus
    "personal_free" -> R.string.plan_personal_free
    "club_pro" -> R.string.plan_club_pro
    else -> R.string.plan_club_essentials
}

/**
 * Subscription, as the web client's preview: a notice that billing isn't connected, the
 * current plan, then every plan with what it includes (Monthly / Annual switch). Personal
 * accounts see the Personal plans as well as the club plans. No purchase happens in the app
 * yet (Google Play Billing comes in v1.1), so plan cards have no buy button.
 */
@Composable
fun SubscriptionPage(planCode: String?, isPersonal: Boolean) {
    var annual by rememberSaveable { mutableStateOf(true) }
    val current = planCode?.lowercase() ?: if (isPersonal) "personal_free" else "club_essentials"
    Column(verticalArrangement = Arrangement.spacedBy(18.dp)) {
        PreviewNotice()
        CurrentPlanCard(planNameRes(current), isPersonal)
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Kicker(stringResource(R.string.plan_choose_kicker))
            Text(
                stringResource(if (isPersonal) R.string.plan_choose_title_personal else R.string.plan_choose_title_club),
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
            )
            Text(stringResource(R.string.plan_choose_body), style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        SingleChoiceSegmentedButtonRow {
            SegmentedButton(selected = !annual, onClick = { annual = false }, shape = SegmentedButtonDefaults.itemShape(0, 2)) {
                Text(stringResource(R.string.plan_monthly))
            }
            SegmentedButton(selected = annual, onClick = { annual = true }, shape = SegmentedButtonDefaults.itemShape(1, 2)) {
                Text(stringResource(R.string.plan_annual))
            }
        }
        val plans = if (isPersonal) PERSONAL_PLANS + CLUB_PLANS else CLUB_PLANS
        CardGrid(plans) { plan -> PlanCard(plan, isCurrent = plan.code == current, annual = annual) }
    }
}

@Composable
private fun Kicker(text: String) {
    Text(
        text.uppercase(),
        style = MaterialTheme.typography.labelMedium,
        fontWeight = FontWeight.Black,
        letterSpacing = 1.2.sp,
        color = MaterialTheme.colorScheme.primary,
    )
}

@Composable
private fun PreviewNotice() {
    Surface(
        shape = RoundedCornerShape(20.dp),
        color = MaterialTheme.colorScheme.primary.copy(alpha = 0.07f),
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.primary.copy(alpha = 0.25f)),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(
                stringResource(R.string.plan_preview_badge).uppercase(),
                color = Color.White,
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.Black,
                modifier = Modifier
                    .background(MaterialTheme.colorScheme.primary, RoundedCornerShape(50))
                    .padding(horizontal = 10.dp, vertical = 6.dp),
            )
            Spacer(Modifier.width(12.dp))
            Text(stringResource(R.string.plan_preview_body), style = MaterialTheme.typography.bodyMedium)
        }
    }
}

@Composable
private fun CurrentPlanCard(@StringRes name: Int, isPersonal: Boolean) {
    Surface(
        shape = RoundedCornerShape(24.dp),
        color = MaterialTheme.colorScheme.surface,
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.6f)),
        shadowElevation = 1.dp,
        modifier = Modifier.fillMaxWidth(),
    ) {
        Row(Modifier.padding(18.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(
                contentAlignment = Alignment.Center,
                modifier = Modifier
                    .size(52.dp)
                    .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.08f), RoundedCornerShape(16.dp)),
            ) {
                Icon(painterResource(R.drawable.ic_payment), contentDescription = null, tint = MaterialTheme.colorScheme.primary)
            }
            Spacer(Modifier.width(14.dp))
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Kicker(stringResource(R.string.plan_current_kicker))
                Text(stringResource(name), style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
                Text(
                    stringResource(if (isPersonal) R.string.plan_current_body_personal else R.string.plan_current_body_club),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Spacer(Modifier.width(8.dp))
            Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Chip(stringResource(R.string.plan_active))
                Text(stringResource(R.string.plan_billing_not_connected), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

@Composable
private fun Chip(text: String, dark: Boolean = false) {
    Text(
        text,
        style = MaterialTheme.typography.labelMedium,
        fontWeight = FontWeight.Bold,
        color = if (dark) Color.White else MaterialTheme.colorScheme.primary,
        modifier = Modifier
            .background(if (dark) HitNScoreTheme.colors.navy else MaterialTheme.colorScheme.primary.copy(alpha = 0.1f), RoundedCornerShape(50))
            .padding(horizontal = 10.dp, vertical = 5.dp),
    )
}

@Composable
private fun PlanCard(plan: PlanOption, isCurrent: Boolean, annual: Boolean) {
    val outline = if (plan.featured || isCurrent) MaterialTheme.colorScheme.primary.copy(alpha = 0.55f) else MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.6f)
    Surface(
        shape = RoundedCornerShape(26.dp),
        color = if (plan.featured) MaterialTheme.colorScheme.primary.copy(alpha = 0.04f) else MaterialTheme.colorScheme.surface,
        border = BorderStroke(if (isCurrent) 2.dp else 1.dp, outline),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(Modifier.weight(1f)) { Kicker(stringResource(plan.eyebrow)) }
                when {
                    isCurrent -> Chip(stringResource(R.string.plan_current_chip))
                    plan.featured -> Chip(stringResource(R.string.plan_preview_tier).uppercase(), dark = true)
                }
            }
            Text(stringResource(plan.name), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
            HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.6f))
            Column {
                Text(stringResource(R.string.plan_pricing_tbc), style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold, color = MaterialTheme.colorScheme.primary)
                Text(
                    stringResource(if (annual) R.string.plan_billed_annually else R.string.plan_billed_monthly),
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.6f))
            Text(stringResource(plan.description), style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            plan.features.forEach { feature ->
                Row {
                    Text("✓", color = HitNScoreTheme.colors.activeStatus, fontWeight = FontWeight.Bold, modifier = Modifier.width(24.dp))
                    Text(stringResource(feature), style = MaterialTheme.typography.bodyMedium)
                }
            }
        }
    }
}
