package com.hitnscore.mobile

import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class AppNavigationSmokeTest {
    @get:Rule
    val composeRule = createAndroidComposeRule<MainActivity>()

    @Test
    fun previewOpensTheIosEquivalentShellAndSwitchesTabs() {
        composeRule.onNodeWithText("HitNScore").assertIsDisplayed()
        composeRule.onNodeWithText("Preview app navigation").performClick()

        // "Home" appears twice: the tab label and the screen heading.
        composeRule.onAllNodesWithText("Home").assertCountEquals(2)

        composeRule.onNodeWithText("Matches").performClick()
        composeRule.onAllNodesWithText("Matches").assertCountEquals(2)
        composeRule.onNodeWithText("Showing matches for").assertIsDisplayed()

        composeRule.onNodeWithText("Settings").performClick()
        composeRule.onNodeWithText("Sign out").performClick()
        composeRule.onNodeWithText("Preview app navigation").assertIsDisplayed()
    }
}
