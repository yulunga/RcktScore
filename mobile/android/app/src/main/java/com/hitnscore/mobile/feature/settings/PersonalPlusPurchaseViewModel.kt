package com.hitnscore.mobile.feature.settings

import android.app.Activity
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.ViewModelProvider.AndroidViewModelFactory.Companion.APPLICATION_KEY
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.hitnscore.mobile.HitNScoreApplication
import com.hitnscore.mobile.core.billing.GooglePlayBilling
import com.hitnscore.mobile.core.billing.PlayOffer
import com.hitnscore.mobile.core.billing.PlayPurchaseEvent
import com.hitnscore.mobile.core.network.ApiResult
import com.hitnscore.mobile.data.remote.GooglePlayPurchaseContext
import com.hitnscore.mobile.data.remote.SubscriptionApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class PersonalPlusPurchaseUiState(
    val isLoading: Boolean = false,
    /** Formatted yearly price from Play, e.g. "£24.99"; null until Play answers. */
    val price: String? = null,
    val canPurchase: Boolean = false,
    val isWorking: Boolean = false,
    /** Set once the backend has verified a Play purchase in this session. */
    val purchased: Boolean = false,
    val message: String? = null,
)

/**
 * Personal Plus through Google Play (yearly only). Play takes payment; the backend verifies
 * the token, grants the plan and acknowledges it. Club plans are never sold here.
 */
class PersonalPlusPurchaseViewModel(
    private val api: SubscriptionApi,
    private val billing: GooglePlayBilling,
    private val refreshSession: suspend () -> Unit,
) : ViewModel() {
    private val mutable = MutableStateFlow(PersonalPlusPurchaseUiState())
    val uiState: StateFlow<PersonalPlusPurchaseUiState> = mutable.asStateFlow()

    private var context: GooglePlayPurchaseContext? = null
    private var offer: PlayOffer? = null

    init {
        viewModelScope.launch {
            billing.purchaseEvents.collect { event ->
                when (event) {
                    is PlayPurchaseEvent.Purchased -> verify(event.purchaseToken, quiet = false)
                    PlayPurchaseEvent.Pending -> mutable.update { it.copy(isWorking = false, message = PENDING_MESSAGE) }
                    PlayPurchaseEvent.Cancelled -> mutable.update { it.copy(isWorking = false, message = null) }
                    is PlayPurchaseEvent.Failed -> mutable.update { it.copy(isWorking = false, message = "Google Play could not complete the purchase.") }
                }
            }
        }
    }

    /** Loads the Play offer for the Personal account and re-submits any purchase not yet verified. */
    fun load(organizationId: Int) {
        if (context?.organizationId == organizationId || mutable.value.isLoading) return
        mutable.update { it.copy(isLoading = true, message = null) }
        viewModelScope.launch {
            when (val result = api.googlePlayContext(organizationId)) {
                is ApiResult.Failure -> mutable.update { it.copy(isLoading = false, message = result.error.message) }
                is ApiResult.Success -> {
                    val purchaseContext = result.value
                    context = purchaseContext
                    if (!purchaseContext.purchasesEnabled) {
                        mutable.update { it.copy(isLoading = false, message = UNAVAILABLE_MESSAGE) }
                        return@launch
                    }
                    offer = billing.yearlyOffer(purchaseContext.productId, purchaseContext.basePlanId)
                    mutable.update {
                        it.copy(
                            isLoading = false,
                            price = offer?.formattedPrice,
                            canPurchase = offer != null,
                            message = if (offer == null) UNAVAILABLE_MESSAGE else null,
                        )
                    }
                    if (purchaseContext.currentPlan != PlanCodes.PERSONAL_PLUS) {
                        // A purchase whose verification never reached us (app closed, offline).
                        billing.ownedPurchaseTokens(purchaseContext.productId).forEach { verify(it, quiet = true) }
                    }
                }
            }
        }
    }

    fun buy(activity: Activity) {
        val purchaseContext = context ?: return
        val playOffer = offer ?: return
        if (mutable.value.isWorking) return
        mutable.update { it.copy(isWorking = true, message = null) }
        if (!billing.launch(activity, playOffer, purchaseContext.obfuscatedAccountId)) {
            mutable.update { it.copy(isWorking = false, message = "Google Play could not open the purchase sheet.") }
        }
    }

    private suspend fun verify(token: String, quiet: Boolean) {
        val organizationId = context?.organizationId ?: return
        mutable.update { it.copy(isWorking = true) }
        when (val result = api.verifyGooglePlay(organizationId, token)) {
            is ApiResult.Success -> {
                val plus = result.value.currentPlan == PlanCodes.PERSONAL_PLUS
                mutable.update { it.copy(isWorking = false, purchased = plus, message = null) }
                refreshSession()
            }
            // Quiet restores ignore tokens that belong to another HitnScore account on this Google account.
            is ApiResult.Failure -> mutable.update {
                it.copy(isWorking = false, message = if (quiet) it.message else result.error.message)
            }
        }
    }

    companion object {
        const val PENDING_MESSAGE = "Google Play is processing your payment. Personal Plus unlocks as soon as it completes."
        const val UNAVAILABLE_MESSAGE = "Personal Plus purchases through Google Play are not available yet."

        val Factory: ViewModelProvider.Factory = viewModelFactory {
            initializer {
                val container = (this[APPLICATION_KEY] as HitNScoreApplication).container
                PersonalPlusPurchaseViewModel(
                    container.subscriptionApi,
                    container.googlePlayBilling,
                ) { container.sessionRepository.refreshMemberships() }
            }
        }
    }
}
