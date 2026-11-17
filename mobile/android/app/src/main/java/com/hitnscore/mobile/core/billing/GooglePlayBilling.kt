package com.hitnscore.mobile.core.billing

import android.app.Activity
import android.content.Context
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingClientStateListener
import com.android.billingclient.api.BillingFlowParams
import com.android.billingclient.api.BillingResult
import com.android.billingclient.api.PendingPurchasesParams
import com.android.billingclient.api.ProductDetails
import com.android.billingclient.api.Purchase
import com.android.billingclient.api.QueryProductDetailsParams
import com.android.billingclient.api.QueryPurchasesParams
import com.android.billingclient.api.queryProductDetails
import com.android.billingclient.api.queryPurchasesAsync
import kotlin.coroutines.resume
import kotlinx.coroutines.channels.BufferOverflow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.suspendCancellableCoroutine

/** The yearly Personal Plus offer, ready to launch. */
data class PlayOffer(val productDetails: ProductDetails, val offerToken: String, val formattedPrice: String)

/** One outcome of the Play purchase sheet. */
sealed interface PlayPurchaseEvent {
    data class Purchased(val purchaseToken: String) : PlayPurchaseEvent
    /** Slow payment method (e.g. cash): access waits for Play to confirm. */
    data object Pending : PlayPurchaseEvent
    data object Cancelled : PlayPurchaseEvent
    data class Failed(val code: Int, val message: String) : PlayPurchaseEvent
}

/**
 * Thin wrapper over Play Billing for the single yearly Personal Plus subscription.
 * The app never acknowledges or grants access itself: every token goes to the backend.
 */
class GooglePlayBilling(context: Context) {
    private val events = MutableSharedFlow<PlayPurchaseEvent>(extraBufferCapacity = 4, onBufferOverflow = BufferOverflow.DROP_OLDEST)
    val purchaseEvents: SharedFlow<PlayPurchaseEvent> = events

    private val client: BillingClient = BillingClient.newBuilder(context.applicationContext)
        .setListener { result, purchases ->
            when (result.responseCode) {
                BillingClient.BillingResponseCode.OK -> purchases.orEmpty().forEach { purchase ->
                    events.tryEmit(
                        if (purchase.purchaseState == Purchase.PurchaseState.PURCHASED) {
                            PlayPurchaseEvent.Purchased(purchase.purchaseToken)
                        } else {
                            PlayPurchaseEvent.Pending
                        },
                    )
                }
                BillingClient.BillingResponseCode.USER_CANCELED -> events.tryEmit(PlayPurchaseEvent.Cancelled)
                else -> events.tryEmit(PlayPurchaseEvent.Failed(result.responseCode, result.debugMessage))
            }
        }
        .enablePendingPurchases(PendingPurchasesParams.newBuilder().enableOneTimeProducts().build())
        .enableAutoServiceReconnection()
        .build()

    private suspend fun connect(): Boolean {
        if (client.isReady) return true
        return suspendCancellableCoroutine { continuation ->
            client.startConnection(object : BillingClientStateListener {
                override fun onBillingSetupFinished(result: BillingResult) {
                    if (continuation.isActive) continuation.resume(result.responseCode == BillingClient.BillingResponseCode.OK)
                }

                override fun onBillingServiceDisconnected() {
                    if (continuation.isActive) continuation.resume(false)
                }
            })
        }
    }

    /** The yearly base-plan offer, or null when Play is unavailable or the product is not set up. */
    suspend fun yearlyOffer(productId: String, basePlanId: String): PlayOffer? {
        if (!connect()) return null
        val params = QueryProductDetailsParams.newBuilder()
            .setProductList(
                listOf(
                    QueryProductDetailsParams.Product.newBuilder()
                        .setProductId(productId)
                        .setProductType(BillingClient.ProductType.SUBS)
                        .build(),
                ),
            ).build()
        val details = client.queryProductDetails(params).productDetailsList?.firstOrNull() ?: return null
        // Only the yearly base plan; prefer its plain base offer over any promotional one.
        val offer = details.subscriptionOfferDetails
            ?.filter { it.basePlanId == basePlanId }
            ?.minByOrNull { if (it.offerId == null) 0 else 1 }
            ?: return null
        val price = offer.pricingPhases.pricingPhaseList.lastOrNull()?.formattedPrice.orEmpty()
        return PlayOffer(details, offer.offerToken, price)
    }

    /** Opens the Play purchase sheet; the result arrives on [purchaseEvents]. */
    fun launch(activity: Activity, offer: PlayOffer, obfuscatedAccountId: String): Boolean {
        val params = BillingFlowParams.newBuilder()
            .setProductDetailsParamsList(
                listOf(
                    BillingFlowParams.ProductDetailsParams.newBuilder()
                        .setProductDetails(offer.productDetails)
                        .setOfferToken(offer.offerToken)
                        .build(),
                ),
            )
            .setObfuscatedAccountId(obfuscatedAccountId)
            .build()
        return client.launchBillingFlow(activity, params).responseCode == BillingClient.BillingResponseCode.OK
    }

    /** Purchased tokens this Google account already owns, e.g. after reinstall or a lost verify. */
    suspend fun ownedPurchaseTokens(productId: String): List<String> {
        if (!connect()) return emptyList()
        val params = QueryPurchasesParams.newBuilder().setProductType(BillingClient.ProductType.SUBS).build()
        return client.queryPurchasesAsync(params).purchasesList
            .filter { it.purchaseState == Purchase.PurchaseState.PURCHASED && productId in it.products }
            .map { it.purchaseToken }
    }
}
