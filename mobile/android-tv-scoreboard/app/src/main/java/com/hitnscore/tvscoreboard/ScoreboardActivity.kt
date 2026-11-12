package com.hitnscore.tvscoreboard

import android.annotation.SuppressLint
import android.graphics.Color
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.webkit.RenderProcessGoneDetail
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.OnBackPressedCallback
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import androidx.webkit.WebViewCompat
import androidx.webkit.WebViewFeature

/**
 * HitnScore Scoreboard for Google TV / Android TV.
 *
 * Shows the public web scoreboard (app.hitnscore.com/scoreboard) full screen, exactly as a
 * browser would: pairing by QR code or by the court's 12-character display code, the layouts
 * and live updates all come from the web page, so this app never needs updating when the
 * scoreboard changes. The app adds what a browser on a TV stick lacks: it starts from the TV
 * launcher, keeps the screen awake, remembers the pairing (web storage persists), recovers
 * by itself when the network drops or the page crashes, and only ever loads HitnScore pages.
 */
class ScoreboardActivity : ComponentActivity() {

    private lateinit var root: FrameLayout
    private var webView: WebView? = null
    private lateinit var loadingView: View
    private lateinit var offlineView: View
    private val handler = Handler(Looper.getMainLooper())
    private var lastBackPress = 0L
    private var pageFailed = false

    private val retry = Runnable { reload() }

    /** Scales the web scoreboard to the screen and turns off scrolling (assets/tv_scoreboard.js). */
    private val fitScript: String by lazy { assets.open("tv_scoreboard.js").bufferedReader().use { it.readText() } }

    private val networkCallback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) {
            // Connection back: reload if the last attempt failed.
            handler.post { if (pageFailed) reload() }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // A scoreboard must never dim or go to the screensaver.
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        WindowCompat.setDecorFitsSystemWindows(window, false)
        WindowInsetsControllerCompat(window, window.decorView).apply {
            hide(WindowInsetsCompat.Type.systemBars())
            systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        }

        root = FrameLayout(this).apply { setBackgroundColor(getColor(R.color.background)) }
        loadingView = buildLoadingView()
        offlineView = buildOfflineView().apply { visibility = View.GONE }
        setContentView(root)
        createWebView()
        root.addView(loadingView, matchParent())
        root.addView(offlineView, matchParent())

        if (savedInstanceState == null || webView?.restoreState(savedInstanceState) == null) {
            webView?.loadUrl(BuildConfig.SCOREBOARD_URL)
        }

        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                val view = webView
                when {
                    view != null && view.canGoBack() -> view.goBack()
                    // Two presses to close, so a stray remote press doesn't end the scoreboard.
                    SystemClock.elapsedRealtime() - lastBackPress < EXIT_WINDOW_MS -> finish()
                    else -> {
                        lastBackPress = SystemClock.elapsedRealtime()
                        Toast.makeText(this@ScoreboardActivity, R.string.exit_hint, Toast.LENGTH_SHORT).show()
                    }
                }
            }
        })

        getSystemService(ConnectivityManager::class.java)?.registerDefaultNetworkCallback(networkCallback)
    }

    @SuppressLint("SetJavaScriptEnabled") // The web scoreboard is a JavaScript app; no JS bridge is exposed.
    private fun createWebView() {
        val view = WebView(this).apply {
            setBackgroundColor(getColor(R.color.background))
            isFocusable = true
            isFocusableInTouchMode = true
            settings.apply {
                javaScriptEnabled = true
                domStorageEnabled = true // keeps the court pairing between restarts
                mediaPlaybackRequiresUserGesture = false
                cacheMode = WebSettings.LOAD_DEFAULT
                allowFileAccess = false
                allowContentAccess = false
                useWideViewPort = true
                loadWithOverviewMode = true
                setSupportZoom(false)
                builtInZoomControls = false
                // Ignore the TV's accessibility font size so the layout matches the web.
                textZoom = 100
            }
            isVerticalScrollBarEnabled = false
            isHorizontalScrollBarEnabled = false
            overScrollMode = View.OVER_SCROLL_NEVER
            webViewClient = ScoreboardClient()
        }
        // Fit the page to the screen with no scrolling, from the first paint where supported.
        if (WebViewFeature.isFeatureSupported(WebViewFeature.DOCUMENT_START_SCRIPT)) {
            WebViewCompat.addDocumentStartJavaScript(view, fitScript, setOf("https://hitnscore.com", "https://*.hitnscore.com"))
        }
        webView = view
        root.addView(view, 0, matchParent())
        view.requestFocus()
    }

    private inner class ScoreboardClient : WebViewClient() {
        override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean =
            // Stay on HitnScore: anything else (links in the page) is ignored on a TV.
            !isAllowed(request.url)

        override fun onPageStarted(view: WebView, url: String?, favicon: android.graphics.Bitmap?) {
            pageFailed = false
        }

        override fun onPageFinished(view: WebView, url: String?) {
            // Older TV WebViews without document-start scripts: add the fit script now.
            if (url != null && isAllowed(Uri.parse(url))) view.evaluateJavascript(fitScript, null)
            loadingView.visibility = View.GONE
            if (!pageFailed) {
                offlineView.visibility = View.GONE
                view.visibility = View.VISIBLE
                view.requestFocus()
            }
        }

        override fun onReceivedError(view: WebView, request: WebResourceRequest, error: WebResourceError) {
            // Only the page itself failing matters; a missing image doesn't.
            if (request.isForMainFrame) showOffline()
        }

        override fun onRenderProcessGone(view: WebView, detail: RenderProcessGoneDetail): Boolean {
            // The page crashed or was killed for memory (common on TV sticks): start a fresh one.
            root.removeView(view)
            view.destroy()
            webView = null
            createWebView()
            webView?.loadUrl(BuildConfig.SCOREBOARD_URL)
            return true
        }
    }

    private fun isAllowed(uri: Uri): Boolean {
        val host = uri.host?.lowercase() ?: return false
        return uri.scheme == "https" && (host == "hitnscore.com" || host.endsWith(".hitnscore.com"))
    }

    private fun showOffline() {
        pageFailed = true
        loadingView.visibility = View.GONE
        webView?.visibility = View.INVISIBLE
        offlineView.visibility = View.VISIBLE
        offlineView.findViewWithTag<View>(RETRY_TAG)?.requestFocus()
        handler.removeCallbacks(retry)
        handler.postDelayed(retry, RETRY_DELAY_MS)
    }

    private fun reload() {
        handler.removeCallbacks(retry)
        if (!isOnline()) {
            handler.postDelayed(retry, RETRY_DELAY_MS)
            return
        }
        offlineView.visibility = View.GONE
        loadingView.visibility = View.VISIBLE
        val view = webView ?: return
        if (view.url.isNullOrBlank() || !isAllowed(Uri.parse(view.url))) view.loadUrl(BuildConfig.SCOREBOARD_URL) else view.reload()
    }

    private fun isOnline(): Boolean {
        val manager = getSystemService(ConnectivityManager::class.java) ?: return true
        val caps = manager.getNetworkCapabilities(manager.activeNetwork) ?: return false
        return caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
    }

    private fun buildLoadingView(): View = LinearLayout(this).apply {
        orientation = LinearLayout.VERTICAL
        gravity = Gravity.CENTER
        setBackgroundColor(getColor(R.color.background))
        addView(ProgressBar(context).apply { isIndeterminate = true })
        addView(label(getString(R.string.loading), 22f, getColor(R.color.text_muted)))
    }

    private fun buildOfflineView(): View = LinearLayout(this).apply {
        orientation = LinearLayout.VERTICAL
        gravity = Gravity.CENTER
        setBackgroundColor(getColor(R.color.background))
        addView(label(getString(R.string.offline_title), 34f, Color.WHITE))
        addView(label(getString(R.string.offline_body), 20f, getColor(R.color.text_muted)))
        addView(
            Button(context).apply {
                text = getString(R.string.retry)
                tag = RETRY_TAG
                isFocusable = true
                setOnClickListener { reload() }
            },
            LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
                topMargin = (24 * resources.displayMetrics.density).toInt()
            },
        )
    }

    private fun label(text: String, sizeSp: Float, color: Int) = TextView(this).apply {
        this.text = text
        textSize = sizeSp
        setTextColor(color)
        gravity = Gravity.CENTER
        setPadding(0, (12 * resources.displayMetrics.density).toInt(), 0, 0)
    }

    private fun matchParent() = FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT)

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        webView?.saveState(outState)
    }

    override fun onResume() {
        super.onResume()
        webView?.onResume()
    }

    override fun onPause() {
        webView?.onPause()
        super.onPause()
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        runCatching { getSystemService(ConnectivityManager::class.java)?.unregisterNetworkCallback(networkCallback) }
        webView?.destroy()
        webView = null
        super.onDestroy()
    }

    private companion object {
        const val RETRY_DELAY_MS = 15_000L
        const val EXIT_WINDOW_MS = 2_000L
        const val RETRY_TAG = "retry"
    }
}
