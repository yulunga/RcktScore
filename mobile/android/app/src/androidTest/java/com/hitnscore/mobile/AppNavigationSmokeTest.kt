package com.hitnscore.mobile

import android.content.Context
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextInput
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.hitnscore.mobile.feature.auth.TestTags
import org.junit.Rule
import org.junit.Test
import org.junit.rules.ExternalResource
import org.junit.runner.RunWith

/**
 * Offline smoke test of the sign-in screen. A full sign-in journey needs a staging
 * backend and test credentials, so it is run manually until staging exists.
 */
@RunWith(AndroidJUnit4::class)
class AppNavigationSmokeTest {

    /** Starts from a signed-out app, whatever an earlier manual run left behind. */
    @get:Rule(order = 0)
    val signedOut = object : ExternalResource() {
        override fun before() {
            val context = InstrumentationRegistry.getInstrumentation().targetContext
            context.getSharedPreferences("hitnscore_session", Context.MODE_PRIVATE).edit().clear().commit()
            context.getSharedPreferences("hitnscore_preferences", Context.MODE_PRIVATE).edit().clear().commit()
        }
    }

    @get:Rule(order = 1)
    val composeRule = createAndroidComposeRule<MainActivity>()

    @Test
    fun signInNeedsBothFieldsAndPasswordResetOpens() {
        composeRule.onNodeWithTag(TestTags.SIGN_IN).assertIsDisplayed().assertIsNotEnabled()

        composeRule.onNodeWithTag(TestTags.USERNAME).performTextInput("player@example.com")
        composeRule.onNodeWithTag(TestTags.SIGN_IN).assertIsNotEnabled()
        composeRule.onNodeWithTag(TestTags.PASSWORD).performTextInput("secret")
        composeRule.onNodeWithTag(TestTags.SIGN_IN).assertIsEnabled()

        composeRule.onNodeWithContentDescription("Show password").performClick()
        composeRule.onNodeWithContentDescription("Hide password").assertIsDisplayed()

        composeRule.onNodeWithText("Need Help? Reset your password").performClick()
        composeRule.onNodeWithText("Password Reset").assertIsDisplayed()
        composeRule.onNodeWithText("Cancel").performClick()
    }
}
