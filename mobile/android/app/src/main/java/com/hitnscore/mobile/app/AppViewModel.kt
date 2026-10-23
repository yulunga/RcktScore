package com.hitnscore.mobile.app

import android.os.SystemClock
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.ViewModelProvider.AndroidViewModelFactory.Companion.APPLICATION_KEY
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.hitnscore.mobile.HitNScoreApplication
import com.hitnscore.mobile.core.session.AccountContext
import com.hitnscore.mobile.core.session.SessionRepository
import com.hitnscore.mobile.core.session.SessionState
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

/** Root state holder: decides between splash, sign-in, lock and the signed-in shell. */
class AppViewModel(private val sessionRepository: SessionRepository) : ViewModel() {

    val sessionState: StateFlow<SessionState> = sessionRepository.state
    val biometricUnlockEnabled: StateFlow<Boolean> = sessionRepository.biometricUnlockEnabled

    private var backgroundedAtMillis: Long? = null

    init {
        viewModelScope.launch { sessionRepository.restore() }
    }

    fun selectContext(context: AccountContext) = sessionRepository.selectContext(context)

    fun signOut() = sessionRepository.signOut()

    fun unlock() = sessionRepository.unlock()

    fun setBiometricUnlockEnabled(enabled: Boolean) = sessionRepository.setBiometricUnlockEnabled(enabled)

    fun onAppBackgrounded() {
        backgroundedAtMillis = SystemClock.elapsedRealtime()
    }

    /** Re-checks expiry, and re-locks after the same 5-minute grace period as iOS. */
    fun onAppForegrounded() {
        sessionRepository.validateExpiry()
        val backgroundedAt = backgroundedAtMillis ?: return
        backgroundedAtMillis = null
        if (SystemClock.elapsedRealtime() - backgroundedAt >= BIOMETRIC_GRACE_PERIOD_MS) {
            sessionRepository.lock()
        }
    }

    companion object {
        private const val BIOMETRIC_GRACE_PERIOD_MS = 5 * 60 * 1000L

        val Factory: ViewModelProvider.Factory = viewModelFactory {
            initializer {
                val application = this[APPLICATION_KEY] as HitNScoreApplication
                AppViewModel(application.container.sessionRepository)
            }
        }
    }
}
