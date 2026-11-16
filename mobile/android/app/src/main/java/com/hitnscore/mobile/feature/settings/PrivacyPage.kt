package com.hitnscore.mobile.feature.settings

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.hitnscore.mobile.core.designsystem.components.InnerCard

/** The online policy, for the full and latest version. */
const val PRIVACY_POLICY_URL = "https://app.hitnscore.com/help?section=privacy"

/**
 * Help & Feedback › Privacy & Data: the privacy policy in the app, as iOS. The text follows
 * the iOS page; "Information stored on this device" and "Security" describe Android storage.
 */
internal val PRIVACY_SECTIONS = listOf(
    "Who we are" to
        "Hit n Score is operated by ucingo, which acts as the data controller for personal information processed through the service. Privacy questions can be sent to privacy@hitnscore.com.",
    "Information we collect" to
        "We collect account and profile information such as your name, email address, telephone number, country and club or organisation membership. We also process the match, player, court, scoring and timing information you create, together with essential login, session, device and support information needed to operate and secure the service.",
    "How information is used" to
        "Information is used to create and manage accounts, provide match setup and scoring, synchronise offline actions, display match history, administer clubs, respond to support requests, prevent misuse and maintain the reliability and security of Hit n Score. We do not sell personal information or use it for cross-app advertising or tracking.",
    "Legal basis" to
        "We process information where it is necessary to provide the service you requested, where we have a legitimate interest in operating and securing the service, where you have given consent, or where processing is required by law.",
    "Storage and service providers" to
        "The service uses contracted infrastructure and communication providers, including AWS for application services and Supabase-hosted PostgreSQL for primary data storage. Those providers process information only as needed to deliver the service. Information may be processed outside your country with appropriate contractual and legal safeguards.",
    "Information stored on this device" to
        "Your login session is stored on the device, encrypted with a key held in the Android Keystore. Matches you are scoring and their queued scoring actions may be stored temporarily on the device for offline use. A selected profile photograph is cropped, compressed and stored in HitnScore's private cloud storage so it can be shared across your clients, with a copy kept on the device for display. Fingerprint and face unlock data is managed by Android and is never received or stored by Hit n Score. App data is excluded from cloud backup and device transfer.",
    "Retention and deletion" to
        "Account data is retained while the account is active and only as long as reasonably necessary for service, security, legal and operational purposes. Personal-account owners can request deletion from Profile settings. Access is disabled immediately and the account is marked delete pending; the Personal workspace, its matches and scoring records are cleared after 12 months, except for limited information that must be retained by law or in time-limited backups.",
    "Your rights" to
        "Depending on your location, you may have rights to access, correct, erase, restrict or object to processing of your information and to request data portability. Contact privacy@hitnscore.com to exercise these rights or raise a privacy concern.",
    "Security and children" to
        "We use HTTPS, password hashing, access controls, expiring sessions and Android Keystore-protected storage to safeguard information. No system can guarantee absolute security. Hit n Score is not directed to children under 13; clubs and guardians are responsible for ensuring any junior use is appropriately authorised and supervised.",
    "Changes and contact" to
        "We may update this policy when the service or legal requirements change. The current version and its update date will remain available in the app. General enquiries can be sent to hello@hitnscore.com and privacy enquiries to privacy@hitnscore.com.",
)

@Composable
internal fun PrivacyPage() {
    val uriHandler = LocalUriHandler.current
    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Text("Privacy Policy", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
        Text("Last updated: September 2026", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        PRIVACY_SECTIONS.forEach { (title, text) ->
            InnerCard(shape = RoundedCornerShape(18.dp)) {
                Column(Modifier.fillMaxWidth().padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                    Text(text, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }
        TextButton(onClick = { uriHandler.openUri(PRIVACY_POLICY_URL) }) {
            Text("View the online Privacy Policy", fontWeight = FontWeight.SemiBold)
        }
    }
}
