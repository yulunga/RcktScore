package com.hitnscore.mobile

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.hitnscore.mobile.app.HitNScoreApp
import com.hitnscore.mobile.core.designsystem.theme.HitNScoreTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            HitNScoreTheme {
                HitNScoreApp()
            }
        }
    }
}
