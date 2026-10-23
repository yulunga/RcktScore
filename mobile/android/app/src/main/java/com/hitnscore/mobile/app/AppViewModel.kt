package com.hitnscore.mobile.app

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

/** Root state holder: decides between splash, sign-in and the signed-in shell. */
class AppViewModel(private val sessionRepository: SessionRepository) : ViewModel() {

    val sessionState: StateFlow<SessionState> = sessionRepository.state

    init {
        viewModelScope.launch { sessionRepository.restore() }
    }

    fun startPreviewSession() = sessionRepository.startPreviewSession()

    fun selectContext(context: AccountContext) = sessionRepository.selectContext(context)

    fun signOut() = sessionRepository.signOut()

    companion object {
        val Factory: ViewModelProvider.Factory = viewModelFactory {
            initializer {
                val application = this[APPLICATION_KEY] as HitNScoreApplication
                AppViewModel(application.container.sessionRepository)
            }
        }
    }
}
