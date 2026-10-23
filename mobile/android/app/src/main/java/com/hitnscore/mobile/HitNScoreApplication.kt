package com.hitnscore.mobile

import android.app.Application
import com.hitnscore.mobile.app.AppContainer

class HitNScoreApplication : Application() {
    /** App-wide singletons. Survives rotation; recreated after process death. */
    val container: AppContainer by lazy { AppContainer(this) }
}
