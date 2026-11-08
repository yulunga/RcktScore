package com.hitnscore.mobile.core.profile

import android.content.ContentResolver
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageDecoder
import android.graphics.Matrix
import android.media.ExifInterface
import android.net.Uri
import android.os.Build
import java.io.ByteArrayOutputStream
import kotlin.math.max
import kotlin.math.min
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * Turns a photo picked from the gallery into the small square JPEG that is kept on the phone:
 * upright, centre-cropped and at most [SIZE_PX] pixels across, so a 12 MP camera photo
 * becomes about 40 KB.
 */
object ProfilePhotoImage {
    const val SIZE_PX = 512
    private const val JPEG_QUALITY = 85

    /** The prepared JPEG, or null when the picked file is not a readable image. */
    suspend fun prepare(resolver: ContentResolver, uri: Uri): ByteArray? = withContext(Dispatchers.IO) {
        runCatching {
            val decoded = decode(resolver, uri) ?: return@runCatching null
            val square = centreSquare(decoded)
            ByteArrayOutputStream().use { out ->
                square.compress(Bitmap.CompressFormat.JPEG, JPEG_QUALITY, out)
                out.toByteArray()
            }
        }.getOrNull()
    }

    fun decodeSaved(jpeg: ByteArray): Bitmap? = BitmapFactory.decodeByteArray(jpeg, 0, jpeg.size)

    private fun decode(resolver: ContentResolver, uri: Uri): Bitmap? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            // ImageDecoder applies the camera's EXIF rotation itself and downsamples while decoding.
            ImageDecoder.decodeBitmap(ImageDecoder.createSource(resolver, uri)) { decoder, info, _ ->
                decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
                val shortSide = min(info.size.width, info.size.height)
                if (shortSide > SIZE_PX) {
                    val scale = SIZE_PX.toFloat() / shortSide
                    decoder.setTargetSize(
                        max(1, (info.size.width * scale).toInt()),
                        max(1, (info.size.height * scale).toInt()),
                    )
                }
            }
        } else {
            decodeLegacy(resolver, uri)
        }

    /** Android 8.x: decode at a reduced size, then rotate by the EXIF orientation. */
    private fun decodeLegacy(resolver: ContentResolver, uri: Uri): Bitmap? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        resolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, bounds) }
        val shortSide = min(bounds.outWidth, bounds.outHeight)
        if (shortSide <= 0) return null
        var sample = 1
        while (shortSide / (sample * 2) >= SIZE_PX) sample *= 2
        val bitmap = resolver.openInputStream(uri)?.use {
            BitmapFactory.decodeStream(it, null, BitmapFactory.Options().apply { inSampleSize = sample })
        } ?: return null
        val degrees = resolver.openInputStream(uri)?.use { stream ->
            when (ExifInterface(stream).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)) {
                ExifInterface.ORIENTATION_ROTATE_90 -> 90f
                ExifInterface.ORIENTATION_ROTATE_180 -> 180f
                ExifInterface.ORIENTATION_ROTATE_270 -> 270f
                else -> 0f
            }
        } ?: 0f
        if (degrees == 0f) return bitmap
        return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, Matrix().apply { postRotate(degrees) }, true)
    }

    private fun centreSquare(source: Bitmap): Bitmap {
        val side = min(source.width, source.height)
        val cropped = Bitmap.createBitmap(source, (source.width - side) / 2, (source.height - side) / 2, side, side)
        return if (side > SIZE_PX) Bitmap.createScaledBitmap(cropped, SIZE_PX, SIZE_PX, true) else cropped
    }
}
