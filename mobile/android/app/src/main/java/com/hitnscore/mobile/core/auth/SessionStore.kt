package com.hitnscore.mobile.core.auth

import android.content.SharedPreferences
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import java.security.KeyStore
import java.util.Base64
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import kotlinx.serialization.json.Json

/** Persists the one signed-in session. */
interface SessionStore {
    fun load(): StoredSession?
    fun save(session: StoredSession)
    fun clear()
}

/** Encrypts and decrypts small secrets. */
interface SecretCipher {
    fun encrypt(plain: ByteArray): ByteArray
    fun decrypt(encrypted: ByteArray): ByteArray
}

/**
 * AES-256-GCM with a key that never leaves the Android Keystore. The key is
 * device-bound and is not included in backups (see data_extraction_rules.xml).
 */
class KeystoreCipher(private val keyAlias: String = "hitnscore.session.v1") : SecretCipher {
    private val keyStore: KeyStore by lazy { KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) } }

    private fun secretKey(): SecretKey {
        (keyStore.getKey(keyAlias, null) as? SecretKey)?.let { return it }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEYSTORE).run {
            init(
                KeyGenParameterSpec.Builder(
                    keyAlias,
                    KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
                )
                    .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                    .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                    .setKeySize(256)
                    .build(),
            )
            generateKey()
        }
    }

    override fun encrypt(plain: ByteArray): ByteArray {
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, secretKey())
        return cipher.iv + cipher.doFinal(plain)
    }

    override fun decrypt(encrypted: ByteArray): ByteArray {
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(
            Cipher.DECRYPT_MODE,
            secretKey(),
            GCMParameterSpec(TAG_LENGTH_BITS, encrypted, 0, IV_LENGTH_BYTES),
        )
        return cipher.doFinal(encrypted, IV_LENGTH_BYTES, encrypted.size - IV_LENGTH_BYTES)
    }

    private companion object {
        const val ANDROID_KEYSTORE = "AndroidKeyStore"
        const val TRANSFORMATION = "AES/GCM/NoPadding"
        const val IV_LENGTH_BYTES = 12
        const val TAG_LENGTH_BITS = 128
    }
}

class EncryptedSessionStore(
    private val preferences: SharedPreferences,
    private val cipher: SecretCipher,
    private val json: Json,
) : SessionStore {

    override fun load(): StoredSession? {
        val encoded = preferences.getString(KEY_SESSION, null) ?: return null
        return try {
            val plain = cipher.decrypt(Base64.getDecoder().decode(encoded))
            json.decodeFromString(StoredSession.serializer(), plain.decodeToString())
        } catch (ignored: Exception) {
            // Key invalidated (e.g. device restored) or data from an older format: start clean.
            clear()
            null
        }
    }

    override fun save(session: StoredSession) {
        val plain = json.encodeToString(StoredSession.serializer(), session).encodeToByteArray()
        val encoded = Base64.getEncoder().encodeToString(cipher.encrypt(plain))
        preferences.edit().putString(KEY_SESSION, encoded).apply()
    }

    override fun clear() {
        preferences.edit().remove(KEY_SESSION).apply()
    }

    private companion object {
        const val KEY_SESSION = "session"
    }
}
