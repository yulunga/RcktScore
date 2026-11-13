package com.hitnscore.mobile.feature.settings

import androidx.annotation.StringRes
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.hitnscore.mobile.R
import com.hitnscore.mobile.core.designsystem.theme.HitNScoreTheme
import com.hitnscore.mobile.core.session.AccountContext
import com.hitnscore.mobile.core.session.AccountContextType
import com.hitnscore.mobile.core.session.SessionState

/** Plan codes as the backend sends them. */
internal object PlanCodes {
    const val PERSONAL_FREE = "personal_free"
    const val PERSONAL_PLUS = "personal_plus"
    const val CLUB_ESSENTIALS = "club_essentials"
    const val CLUB_PRO = "club_pro"

    /** From an account's plan (code or display name, e.g. "Personal Plus", "Club Pro"). */
    fun of(context: AccountContext): String {
        val plan = context.plan.lowercase()
        return if (context.type == AccountContextType.Personal) {
            if ("plus" in plan) PERSONAL_PLUS else PERSONAL_FREE
        } else {
            if ("pro" in plan) CLUB_PRO else CLUB_ESSENTIALS
        }
    }
}

/**
 * Subscription, as iOS Settings › Subscription: the Personal plans (Personal is current, or
 * Personal+; Personal can be upgraded to Personal+) and, for each club you belong to, the
 * club plans with that club's tier highlighted. Without a club, Club Essentials and Club Pro
 * are offered by enquiry. Every plan is billed annually.
 *
 * The Personal+ upgrade needs Google Play Billing (v1.1), so on Android it explains that
 * and does not take payment yet.
 */
@Composable
fun SubscriptionPage(session: SessionState.SignedIn, personalPlusOverride: Boolean? = null) {
    val enquiry: ClubEnquiryViewModel = viewModel(factory = ClubEnquiryViewModel.Factory)
    val enquiryState by enquiry.uiState.collectAsStateWithLifecycle()
    var upgradeOpen by rememberSaveable { mutableStateOf(false) }
    val personal = session.availableContexts.firstOrNull { it.type == AccountContextType.Personal }
    val clubs = session.availableContexts.filter { it.type == AccountContextType.Club }
    val isPlus = personalPlusOverride ?: (personal?.let { PlanCodes.of(it) } == PlanCodes.PERSONAL_PLUS)

    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        EditorCard(stringResource(R.string.settings_subscription), iconRes = R.drawable.ic_payment) {
            if (personal != null) {
                Kicker(stringResource(R.string.plan_section_personal))
                PlanOptionCard(
                    title = stringResource(R.string.plan_personal),
                    subtitle = stringResource(R.string.plan_personal_summary),
                    status = if (isPlus) PlanStatus.Available else PlanStatus.Current,
                )
                PlanOptionCard(
                    title = stringResource(R.string.plan_personal_plus),
                    subtitle = stringResource(R.string.plan_personal_plus_summary),
                    status = if (isPlus) PlanStatus.Current else PlanStatus.Upgrade,
                    expanded = upgradeOpen,
                    onClick = if (isPlus) null else ({ upgradeOpen = !upgradeOpen }),
                )
                AnimatedVisibility(visible = upgradeOpen && !isPlus) { UpgradePanel() }
                SubscriptionSourceLine(personal)
            }

            // As iOS: each club's current plan, then "Register another club" with the two plans.
            Kicker(stringResource(R.string.plan_section_club))
            if (clubs.isEmpty()) {
                EditorNote(stringResource(R.string.plan_no_club))
            } else {
                clubs.forEach { club ->
                    PlanOptionCard(
                        title = club.name,
                        subtitle = stringResource(planNameRes(PlanCodes.of(club))),
                        status = PlanStatus.Current,
                    )
                    SubscriptionSourceLine(club)
                }
            }
            Text(
                stringResource(R.string.plan_register_another_club),
                style = MaterialTheme.typography.labelLarge,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            ClubPlans(current = null) { plan -> enquiry.open(plan, "") }
            EditorNote(stringResource(R.string.plan_annual_only))
        }
        enquiryState.sent?.let { (plan, club) ->
            Text(
                stringResource(R.string.club_enquiry_sent, stringResource(planNameRes(plan)), club, session.username),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.primary,
            )
        }
    }

    if (enquiryState.plan != null) {
        val nameParts = personName(session).split(' ', limit = 2)
        ClubEnquiryDialog(
            state = enquiryState,
            viewModel = enquiry,
            onSend = { enquiry.send(nameParts.first(), nameParts.getOrElse(1) { "" }, session.username) },
        )
    }
}

@Composable
private fun SubscriptionSourceLine(context: AccountContext) {
    val provider = context.subscriptionProvider ?: return
    val providerName = when (provider.lowercase()) {
        "apple" -> "App Store"
        "google_play" -> "Google Play"
        "stripe" -> "Web / Stripe"
        "manual" -> "HitnScore administrator"
        else -> provider.replace('_', ' ').replaceFirstChar { it.uppercase() }
    }
    Text(
        text = "${if (context.subscriptionLastRenewedAt == null) "Purchased" else "Last renewed"} through $providerName",
        style = MaterialTheme.typography.labelMedium,
        color = MaterialTheme.colorScheme.primary,
    )
}

private enum class PlanStatus { Current, Available, Upgrade, Enquire }

@Composable
private fun ClubPlans(current: String?, onEnquire: (String) -> Unit) {
    listOf(
        Triple(PlanCodes.CLUB_ESSENTIALS, R.string.plan_club_essentials, R.string.plan_club_essentials_summary),
        Triple(PlanCodes.CLUB_PRO, R.string.plan_club_pro, R.string.plan_club_pro_summary),
    ).forEach { (code, name, summary) ->
        val isCurrent = code == current
        PlanOptionCard(
            title = stringResource(name),
            subtitle = stringResource(summary),
            status = if (isCurrent) PlanStatus.Current else PlanStatus.Enquire,
            onClick = if (isCurrent) null else ({ onEnquire(code) }),
        )
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
        modifier = Modifier.padding(top = 4.dp),
    )
}

/** iOS `subscriptionOptionCardContent`: the current plan has a green outline and a pink chip. */
@Composable
private fun PlanOptionCard(
    title: String,
    subtitle: String,
    status: PlanStatus,
    expanded: Boolean = false,
    onClick: (() -> Unit)? = null,
) {
    val green = HitNScoreTheme.colors.activeStatus
    val pink = HitNScoreTheme.colors.brandPink
    val blue = MaterialTheme.colorScheme.primary
    val chipColor = when (status) {
        PlanStatus.Current -> pink
        PlanStatus.Upgrade, PlanStatus.Enquire -> blue
        PlanStatus.Available -> MaterialTheme.colorScheme.onSurfaceVariant
    }
    val border = if (status == PlanStatus.Current) BorderStroke(2.dp, green) else BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.6f))
    val content: @Composable () -> Unit = {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
                Text(
                    stringResource(
                        when (status) {
                            PlanStatus.Current -> R.string.plan_current_chip
                            PlanStatus.Available -> R.string.plan_available
                            PlanStatus.Upgrade -> R.string.plan_upgrade
                            PlanStatus.Enquire -> R.string.plan_enquire
                        },
                    ),
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.Bold,
                    color = chipColor,
                    modifier = Modifier
                        .background(chipColor.copy(alpha = 0.14f), RoundedCornerShape(50))
                        .padding(horizontal = 12.dp, vertical = 6.dp),
                )
                if (onClick != null) {
                    Spacer(Modifier.width(6.dp))
                    Icon(
                        painterResource(
                            when {
                                status == PlanStatus.Upgrade && expanded -> R.drawable.ic_expand_less
                                status == PlanStatus.Upgrade -> R.drawable.ic_expand_more
                                else -> R.drawable.ic_chevron_right
                            },
                        ),
                        contentDescription = null,
                        tint = blue,
                        modifier = Modifier.size(20.dp),
                    )
                }
            }
            Text(subtitle, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
    if (onClick != null) {
        Surface(onClick = onClick, shape = RoundedCornerShape(20.dp), color = MaterialTheme.colorScheme.surface, border = border, modifier = Modifier.fillMaxWidth()) { content() }
    } else {
        Surface(shape = RoundedCornerShape(20.dp), color = MaterialTheme.colorScheme.surface, border = border, modifier = Modifier.fillMaxWidth()) { content() }
    }
}

/** Personal+ upgrade, opened from its card (as iOS). Payment arrives with Google Play Billing. */
@Composable
private fun UpgradePanel() {
    Surface(
        shape = RoundedCornerShape(20.dp),
        color = MaterialTheme.colorScheme.primary.copy(alpha = 0.06f),
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.primary.copy(alpha = 0.25f)),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(stringResource(R.string.plan_upgrade_title), style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold)
            listOf(R.string.plan_personal_plus_f1, R.string.plan_personal_plus_f2, R.string.plan_personal_plus_f3, R.string.plan_personal_plus_f4).forEach { feature ->
                Row {
                    Text("✓", color = HitNScoreTheme.colors.activeStatus, fontWeight = FontWeight.Bold, modifier = Modifier.width(22.dp))
                    Text(stringResource(feature), style = MaterialTheme.typography.bodyMedium)
                }
            }
            Text(stringResource(R.string.plan_billed_annually_pricing), style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.primary)
            Button(onClick = {}, enabled = false, modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(16.dp)) {
                Text(stringResource(R.string.plan_upgrade_button))
            }
            EditorNote(stringResource(R.string.plan_upgrade_note))
        }
    }
}

@Composable
private fun ClubEnquiryDialog(state: ClubEnquiryUiState, viewModel: ClubEnquiryViewModel, onSend: () -> Unit) {
    val plan = state.plan ?: return
    val form = state.form
    AlertDialog(
        onDismissRequest = { if (!state.isSending) viewModel.close() },
        title = { Text(stringResource(R.string.club_enquiry_title, stringResource(planNameRes(plan)))) },
        text = {
            Column(Modifier.verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                EditorNote(stringResource(R.string.club_enquiry_body))
                EditorField(stringResource(R.string.club_enquiry_name), form.clubName, { v -> viewModel.update { it.copy(clubName = v) } })
                EditorField(stringResource(R.string.settings_address), form.address, { v -> viewModel.update { it.copy(address = v) } })
                EditorField(stringResource(R.string.settings_postcode), form.postcode, { v -> viewModel.update { it.copy(postcode = v) } }, capitalization = KeyboardCapitalization.Characters)
                EditorField(stringResource(R.string.club_enquiry_email), form.email, { v -> viewModel.update { it.copy(email = v) } }, keyboardType = KeyboardType.Email)
                EditorField(stringResource(R.string.settings_website), form.website, { v -> viewModel.update { it.copy(website = v) } }, keyboardType = KeyboardType.Uri, capitalization = KeyboardCapitalization.None)
                EditorField(stringResource(R.string.settings_telephone), form.telephone, { v -> viewModel.update { it.copy(telephone = v) } }, keyboardType = KeyboardType.Phone)
                val problem = when (state.problem) {
                    ClubEnquiryProblem.Incomplete -> stringResource(R.string.club_enquiry_incomplete)
                    ClubEnquiryProblem.ClubEmail -> stringResource(R.string.club_enquiry_bad_email)
                    ClubEnquiryProblem.AccountEmail -> stringResource(R.string.club_enquiry_bad_account)
                    null -> state.serverError
                }
                problem?.let { Text(it, color = HitNScoreTheme.colors.brandPink, style = MaterialTheme.typography.bodyMedium) }
            }
        },
        confirmButton = {
            TextButton(onClick = onSend, enabled = !state.isSending) {
                if (state.isSending) CircularProgressIndicator(Modifier.size(18.dp), strokeWidth = 2.dp) else Text(stringResource(R.string.club_enquiry_send))
            }
        },
        dismissButton = { TextButton(onClick = viewModel::close, enabled = !state.isSending) { Text(stringResource(R.string.cancel)) } },
    )
}

/** The plan's display name. */
@StringRes
internal fun planNameRes(code: String?): Int = when (code?.lowercase()) {
    PlanCodes.PERSONAL_PLUS -> R.string.plan_personal_plus
    PlanCodes.PERSONAL_FREE -> R.string.plan_personal
    PlanCodes.CLUB_PRO -> R.string.plan_club_pro
    else -> R.string.plan_club_essentials
}
