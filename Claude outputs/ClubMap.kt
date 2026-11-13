package com.hitnscore.mobile.feature.settings

import android.annotation.SuppressLint
import android.content.Context
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.util.Locale
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray

/**
 * Club Map: the club's address on OpenStreetMap. The address is looked up once with
 * OpenStreetMap's Nominatim search and the position is remembered on the phone, so the
 * search service is not asked again for the same address.
 */
@Composable
fun ClubMap(address: String, postcode: String, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val query = listOf(address, postcode).map { it.trim() }.filter { it.isNotEmpty() }.joinToString(", ")
    var position by remember(query) { mutableStateOf(ClubMapCache.read(context, query)) }
    var searching by remember(query) { mutableStateOf(position == null && query.isNotEmpty()) }

    LaunchedEffect(query) {
        if (query.isEmpty() || position != null) return@LaunchedEffect
        position = geocode(query)?.also { ClubMapCache.write(context, query, it) }
        searching = false
    }

    val shape = RoundedCornerShape(16.dp)
    Box(
        modifier
            .fillMaxWidth()
            .height(200.dp)
            .clip(shape),
        contentAlignment = Alignment.Center,
    ) {
        val found = position
        when {
            found != null -> OsmWebView(found.first, found.second)
            searching -> CircularProgressIndicator()
            else -> Text(
                if (query.isEmpty()) "Add the club's address to show it on the map." else "The club's address could not be found on the map.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@SuppressLint("SetJavaScriptEnabled")
@Composable
private fun OsmWebView(lat: Double, lon: Double) {
    val url = osmEmbedUrl(lat, lon)
    AndroidView(
        modifier = Modifier.fillMaxWidth().height(200.dp),
        factory = { context ->
            WebView(context).apply {
                settings.javaScriptEnabled = true
                webViewClient = WebViewClient()
                loadUrl(url)
            }
        },
        update = { if (it.url != url) it.loadUrl(url) },
    )
}

/** OpenStreetMap's embeddable map (with its own attribution), centred on the club with a pin. */
internal fun osmEmbedUrl(lat: Double, lon: Double): String {
    val dLat = 0.004
    val dLon = 0.007
    fun f(v: Double) = String.format(Locale.US, "%.6f", v)
    return "https://www.openstreetmap.org/export/embed.html" +
        "?bbox=${f(lon - dLon)}%2C${f(lat - dLat)}%2C${f(lon + dLon)}%2C${f(lat + dLat)}" +
        "&layer=mapnik&marker=${f(lat)}%2C${f(lon)}"
}

/** Nominatim search (OpenStreetMap). Returns null when nothing is found or offline. */
private suspend fun geocode(query: String): Pair<Double, Double>? = withContext(Dispatchers.IO) {
    runCatching {
        val url = URL(
            "https://nominatim.openstreetmap.org/search?format=json&limit=1&q=" +
                URLEncoder.encode(query, Charsets.UTF_8.name()),
        )
        val connection = (url.openConnection() as HttpURLConnection).apply {
            // Nominatim's usage policy asks for an identifying User-Agent.
            setRequestProperty("User-Agent", "HitnScore Android app (https://app.hitnscore.com)")
            connectTimeout = 10_000
            readTimeout = 10_000
        }
        try {
            if (connection.responseCode != 200) return@runCatching null
            val results = JSONArray(connection.inputStream.bufferedReader().use { it.readText() })
            if (results.length() == 0) return@runCatching null
            val first = results.getJSONObject(0)
            first.getString("lat").toDouble() to first.getString("lon").toDouble()
        } finally {
            connection.disconnect()
        }
    }.getOrNull()
}

/** Remembers each address's position so the map opens straight away next time. */
private object ClubMapCache {
    private const val FILE = "hitnscore_club_map"

    fun read(context: Context, query: String): Pair<Double, Double>? {
        if (query.isEmpty()) return null
        val value = context.getSharedPreferences(FILE, Context.MODE_PRIVATE).getString(query.lowercase(), null) ?: return null
        val parts = value.split(',')
        return parts.getOrNull(0)?.toDoubleOrNull()?.let { lat -> parts.getOrNull(1)?.toDoubleOrNull()?.let { lon -> lat to lon } }
    }

    fun write(context: Context, query: String, position: Pair<Double, Double>) {
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE).edit()
            .putString(query.lowercase(), "${position.first},${position.second}")
            .apply()
    }
}
