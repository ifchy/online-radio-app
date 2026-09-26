// Source: audio_service README "Custom Android activity"; lock call mirrors Media3 WifiLockManager
package bg.izk.radio

import android.content.Context
import android.net.wifi.WifiManager
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        WifiLockChannel.register(flutterEngine, applicationContext)
    }
}

/**
 * Keeps the Wi-Fi radio awake with the screen off while a station plays or
 * reconnects (PLAT-03). The Dart engine acquires it only in Connecting,
 * Playing, Buffering and Reconnecting and releases it otherwise (PLAT-06).
 *
 * WIFI_MODE_FULL_HIGH_PERF is deprecated in API 34 but still what Media3 uses
 * (Pitfall J); WIFI_MODE_FULL_LOW_LATENCY only acts with the screen on. The
 * lock is not reference-counted, so one release always frees it, and it uses
 * the application context, so nothing leaks. WAKE_LOCK (already declared)
 * covers WifiLock.acquire.
 */
object WifiLockChannel {
    private var lock: WifiManager.WifiLock? = null
    fun register(engine: FlutterEngine, context: Context) {
        MethodChannel(engine.dartExecutor.binaryMessenger, "bg.izk.radio/wifi_lock")
            .setMethodCallHandler { call, result ->
                val wm = context.getSystemService(Context.WIFI_SERVICE) as WifiManager
                when (call.method) {
                    "acquire" -> {
                        @Suppress("DEPRECATION")
                        val l = lock ?: wm.createWifiLock(WifiManager.WIFI_MODE_FULL_HIGH_PERF, "eRadioto:stream")
                            .also { it.setReferenceCounted(false); lock = it }
                        if (!l.isHeld) l.acquire()
                        result.success(true)
                    }
                    "release" -> { lock?.let { if (it.isHeld) it.release() }; result.success(true) }
                    "isHeld" -> result.success(lock?.isHeld == true)
                    else -> result.notImplemented()
                }
            }
    }
}
