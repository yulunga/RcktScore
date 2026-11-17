package com.hitnscore.mobile.feature.settings

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class SubscriptionSummaryTest {
    @Test
    fun activeGooglePlayShowsExpiryAndSource() {
        assertEquals(
            "Valid until 17 Nov 2027, renews automatically · Purchased through Google Play",
            subscriptionSummary("google_play", "active", "2027-11-17T12:00:00.123456+00:00", null),
        )
    }

    @Test
    fun cancelledAppleRenewalStillValidUntilExpiry() {
        assertEquals(
            "Valid until 1 Jan 2027, will not renew · Last renewed through the App Store",
            subscriptionSummary("apple", "cancelled", "2027-01-01T00:00:00+00:00", "2026-01-01T00:00:00+00:00"),
        )
    }

    @Test
    fun noProviderShowsNothing() {
        assertNull(subscriptionSummary(null, "active", null, null))
    }
}
