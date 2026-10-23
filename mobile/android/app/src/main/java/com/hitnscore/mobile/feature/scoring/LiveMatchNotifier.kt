package com.hitnscore.mobile.feature.scoring

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.hitnscore.mobile.MainActivity
import com.hitnscore.mobile.R
import com.hitnscore.mobile.data.model.MatchDetail

/**
 * Ongoing local notification while a match is being scored (approved UX change 3).
 * Shows the score and returns to the scorer when tapped. Not a push notification.
 */
class LiveMatchNotifier(private val context: Context) {

    fun show(match: MatchDetail) {
        if (!canPost()) return
        ensureChannel()
        val state = match.state
        val p1 = match.player1Name.ifBlank { "Player 1" }
        val p2 = match.player2Name.ifBlank { "Player 2" }
        val title = "$p1 ${state?.player1GamesWon ?: 0}–${state?.player2GamesWon ?: 0} $p2"
        val text = if (TennisRules.isTennis(match)) {
            // Set number, games in the set, then the point score ("40–15").
            context.getString(
                R.string.live_notification_tennis_text,
                state?.currentGameNumber ?: 1,
                state?.player1SetGames ?: 0,
                state?.player2SetGames ?: 0,
                state?.player1ScoreLabel ?: (state?.player1Score ?: 0).toString(),
                state?.player2ScoreLabel ?: (state?.player2Score ?: 0).toString(),
            )
        } else {
            context.getString(
                R.string.live_notification_text,
                state?.currentGameNumber ?: 1,
                state?.player1Score ?: 0,
                state?.player2Score ?: 0,
            )
        }
        val openApp = PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_match)
            .setContentTitle(title)
            .setContentText(text)
            .setContentIntent(openApp)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setCategory(NotificationCompat.CATEGORY_STATUS)
            .setColor(ContextCompat.getColor(context, R.color.brand_blue))
            .build()
        try {
            NotificationManagerCompat.from(context).notify(NOTIFICATION_ID, notification)
        } catch (denied: SecurityException) {
            // Permission revoked between the check and the call: skip quietly.
        }
    }

    fun cancel() {
        NotificationManagerCompat.from(context).cancel(NOTIFICATION_ID)
    }

    private fun canPost(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED

    private fun ensureChannel() {
        val manager = context.getSystemService(NotificationManager::class.java)
        if (manager.getNotificationChannel(CHANNEL_ID) == null) {
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, context.getString(R.string.live_notification_channel), NotificationManager.IMPORTANCE_LOW),
            )
        }
    }

    private companion object {
        const val CHANNEL_ID = "live_match"
        const val NOTIFICATION_ID = 4101
    }
}
