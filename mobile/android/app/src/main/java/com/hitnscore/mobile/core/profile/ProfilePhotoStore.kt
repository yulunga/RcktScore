package com.hitnscore.mobile.core.profile

import java.io.File
import java.security.MessageDigest
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.withContext

/**
 * Offline display cache for the user's centrally stored profile photograph.
 *
 * One compressed JPEG per user is named by a hash of the username so the file name does not
 * reveal the email address. It remains in the app's no-backup folder; the private S3 object is
 * the canonical copy shared with web and iOS. Another account on this phone gets its own cache.
 */
class ProfilePhotoStore(
    private val directory: File,
    private val ioDispatcher: CoroutineDispatcher = Dispatchers.IO,
) {
    private val mutableVersions = MutableStateFlow<Map<String, Int>>(emptyMap())

    /** Bumped per user whenever their photo is saved or removed, so screens reload it. */
    val versions: StateFlow<Map<String, Int>> = mutableVersions.asStateFlow()

    fun versionOf(username: String): Int = mutableVersions.value[key(username)] ?: 0

    /** The saved JPEG, or null when the user has not chosen a photo. */
    suspend fun read(username: String): ByteArray? = withContext(ioDispatcher) {
        fileFor(username).takeIf { it.isFile }?.readBytes()
    }

    suspend fun save(username: String, jpeg: ByteArray) {
        withContext(ioDispatcher) {
            directory.mkdirs()
            val target = fileFor(username)
            val partial = File(directory, target.name + ".tmp")
            partial.writeBytes(jpeg)
            // Replace in one step so a half-written photo is never shown.
            if (!partial.renameTo(target)) {
                target.delete()
                check(partial.renameTo(target)) { "Could not save the profile photo" }
            }
        }
        bump(username)
    }

    suspend fun remove(username: String) {
        withContext(ioDispatcher) { fileFor(username).delete() }
        bump(username)
    }

    internal fun fileFor(username: String): File = File(directory, "${key(username)}.jpg")

    private fun bump(username: String) {
        val key = key(username)
        mutableVersions.update { it + (key to (it[key] ?: 0) + 1) }
    }

    private fun key(username: String): String =
        MessageDigest.getInstance("SHA-256")
            .digest(username.trim().lowercase().toByteArray(Charsets.UTF_8))
            .joinToString("") { "%02x".format(it) }
}
