package com.hitnscore.mobile.feature.settings

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.hitnscore.mobile.HitNScoreApplication
import com.hitnscore.mobile.R
import com.hitnscore.mobile.core.designsystem.theme.BrandBlue
import com.hitnscore.mobile.core.designsystem.theme.BrandPink
import com.hitnscore.mobile.core.profile.ProfilePhotoImage
import com.hitnscore.mobile.core.profile.ProfilePhotoStore
import kotlinx.coroutines.launch

object ProfilePhotoTags {
    const val AVATAR = "profile_photo_avatar"
}

/** Up to two initials from the display name, "HS" when there are none (as iOS). */
internal fun profileInitials(displayName: String): String =
    displayName.trim().split(Regex("\\s+")).filter { it.isNotEmpty() }.take(2)
        .joinToString("") { it.first().uppercase() }
        .ifEmpty { "HS" }

/** The saved photo for [username], reloaded whenever it is changed or removed. */
@Composable
fun rememberProfilePhoto(store: ProfilePhotoStore, username: String): ImageBitmap? {
    val versions by store.versions.collectAsStateWithLifecycle()
    val version = remember(versions, username) { store.versionOf(username) }
    val photo by produceState<ImageBitmap?>(initialValue = null, username, version) {
        value = store.read(username)?.let(ProfilePhotoImage::decodeSaved)?.asImageBitmap()
    }
    return photo
}

/**
 * The Personal settings header from iOS: a round photo (or initials) with an edit badge,
 * then the name and email. Tapping it picks a photo with the system photo picker, which
 * needs no storage permission. The photo stays on this phone.
 */
@Composable
fun ProfilePhotoHeader(username: String, displayName: String, email: String?) {
    val context = LocalContext.current
    val store = remember(context) { (context.applicationContext as HitNScoreApplication).container.profilePhotos }
    val photo = rememberProfilePhoto(store, username)
    val scope = rememberCoroutineScope()
    var menuOpen by remember { mutableStateOf(false) }
    var isSaving by remember { mutableStateOf(false) }
    var failed by rememberSaveable { mutableStateOf(false) }

    val picker = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        isSaving = true
        failed = false
        scope.launch {
            val jpeg = ProfilePhotoImage.prepare(context.contentResolver, uri)
            failed = jpeg == null || runCatching { store.save(username, jpeg) }.isFailure
            isSaving = false
        }
    }
    val pick = { picker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) }

    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp),
        modifier = Modifier.fillMaxWidth().padding(horizontal = 18.dp, vertical = 14.dp),
    ) {
        Box {
            val description = stringResource(if (photo == null) R.string.profile_photo_add else R.string.profile_photo_change)
            Box(
                modifier = Modifier
                    .testTag(ProfilePhotoTags.AVATAR)
                    .clickable(onClickLabel = description, role = Role.Button) {
                        if (photo == null) pick() else menuOpen = true
                    },
            ) {
                ProfileAvatar(photo = photo, displayName = displayName, size = 92.dp, isBusy = isSaving)
                EditBadge(Modifier.align(Alignment.BottomEnd))
            }
            DropdownMenu(expanded = menuOpen, onDismissRequest = { menuOpen = false }) {
                DropdownMenuItem(
                    text = { Text(stringResource(R.string.profile_photo_choose)) },
                    onClick = { menuOpen = false; pick() },
                )
                DropdownMenuItem(
                    text = { Text(stringResource(R.string.profile_photo_remove)) },
                    onClick = {
                        menuOpen = false
                        scope.launch { store.remove(username) }
                    },
                )
            }
        }
        Text(
            displayName.ifBlank { username },
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center,
        )
        if (!email.isNullOrBlank()) {
            Text(email, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant, textAlign = TextAlign.Center)
        }
        if (failed) {
            Text(stringResource(R.string.profile_photo_failed), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.error)
        }
    }
}

/** Round photo, or white initials on the brand pink-to-blue gradient, with a white ring. */
@Composable
fun ProfileAvatar(photo: ImageBitmap?, displayName: String, size: Dp, isBusy: Boolean = false) {
    Box(
        contentAlignment = Alignment.Center,
        modifier = Modifier
            .size(size)
            .shadow(10.dp, CircleShape, ambientColor = Color.Black.copy(alpha = 0.08f), spotColor = Color.Black.copy(alpha = 0.08f))
            .clip(CircleShape)
            .background(Brush.linearGradient(listOf(BrandPink.copy(alpha = 0.9f), BrandBlue.copy(alpha = 0.78f))))
            .border(3.dp, Color.White.copy(alpha = 0.85f), CircleShape),
    ) {
        if (photo != null) {
            Image(photo, contentDescription = null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize())
        } else {
            Text(
                profileInitials(displayName),
                color = Color.White,
                fontSize = (size.value * 0.34f).sp,
                fontWeight = FontWeight.ExtraBold,
            )
        }
        if (isBusy) CircularProgressIndicator(color = Color.White, strokeWidth = 3.dp, modifier = Modifier.size(size / 3))
    }
}

@Composable
private fun EditBadge(modifier: Modifier = Modifier) {
    Box(
        contentAlignment = Alignment.Center,
        modifier = modifier
            .size(24.dp)
            .clip(CircleShape)
            .background(MaterialTheme.colorScheme.primary)
            .border(2.dp, Color.White, CircleShape),
    ) {
        Icon(painterResource(R.drawable.ic_edit), contentDescription = null, tint = Color.White, modifier = Modifier.size(12.dp))
    }
}
