package com.msob7y.eargaurd

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.database.ContentObserver
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkRequest
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import fi.iki.elonen.NanoHTTPD

class EarGuardService : Service() {

    private lateinit var engine: AudioEngine
    private var server: ApiServer? = null
    private var nsd: NsdAdvertiser? = null
    private var capObserver: ContentObserver? = null
    private var netCallback: ConnectivityManager.NetworkCallback? = null

    @Volatile var micReady: Boolean = false
        private set

    override fun onCreate() {
        super.onCreate()
        instance = this
        engine = AudioEngine(applicationContext)
        createChannel()
        startServer()
        registerCapObserver()
        registerNetworkCallback()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Prefs.setAgentEnabled(this, true)
        val fromUi = intent?.getBooleanExtra(EXTRA_FROM_UI, false) ?: false
        val hasMic = checkSelfPermission(Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED
        startForegroundCompat(allowMic = fromUi && hasMic)
        return START_STICKY
    }

    fun onSettingsChanged() {
        if (Prefs.capEnabled(this)) engine.enforceCap(Prefs.cap(this))
    }

    fun checkAndWarn(): Triple<Double, Double, Boolean> {
        if (!micReady) return Triple(-999.0, Prefs.threshold(this).toDouble(), false)
        val band = engine.captureBand10kDbfs()
        val threshold = Prefs.threshold(this).toDouble()
        val warned = band > threshold && band > -900
        if (warned) engine.playWarning()
        return Triple(band, threshold, warned)
    }

    private fun startServer() {
        val port = Prefs.port(this)
        try {
            server = ApiServer(this, engine, port).also {
                it.start(NanoHTTPD.SOCKET_READ_TIMEOUT, false)
            }
            nsd = NsdAdvertiser(this).also { it.register(port, serviceName()) }
        } catch (_: Exception) {
        }
    }

    private fun registerCapObserver() {
        val observer = object : ContentObserver(Handler(Looper.getMainLooper())) {
            override fun onChange(selfChange: Boolean) {
                if (Prefs.capEnabled(this@EarGuardService)) {
                    engine.enforceCap(Prefs.cap(this@EarGuardService))
                }
            }
        }
        capObserver = observer
        contentResolver.registerContentObserver(Settings.System.CONTENT_URI, true, observer)
    }

    private fun registerNetworkCallback() {
        val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val cb = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                nsd?.register(Prefs.port(this@EarGuardService), serviceName())
            }
        }
        netCallback = cb
        try {
            cm.registerNetworkCallback(NetworkRequest.Builder().build(), cb)
        } catch (_: Exception) {
        }
    }

    private fun startForegroundCompat(allowMic: Boolean) {
        val notif = buildNotification()
        try {
            when {
                Build.VERSION.SDK_INT >= 34 -> {
                    var type = ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
                    if (allowMic) type = type or ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
                    startForeground(NOTIF_ID, notif, type)
                }
                Build.VERSION.SDK_INT >= 29 -> {
                    if (allowMic) {
                        startForeground(NOTIF_ID, notif, ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE)
                    } else {
                        startForeground(NOTIF_ID, notif)
                    }
                }
                else -> startForeground(NOTIF_ID, notif)
            }
            micReady = allowMic
        } catch (e: Exception) {
            try {
                startForeground(NOTIF_ID, notif)
                micReady = false
            } catch (_: Exception) {
            }
        }
    }

    private fun createChannel() {
        val ch = NotificationChannel(CHANNEL_ID, "EarGuard", NotificationManager.IMPORTANCE_MIN)
        ch.setShowBadge(false)
        (getSystemService(NOTIFICATION_SERVICE) as NotificationManager).createNotificationChannel(ch)
    }

    private fun buildNotification(): Notification =
        Notification.Builder(this, CHANNEL_ID)
            .setContentTitle("EarGuard")
            .setContentText("Control server running")
            .setSmallIcon(android.R.drawable.ic_lock_silent_mode)
            .setOngoing(true)
            .build()

    private fun serviceName(): String = "EarGuard-${Build.MODEL}"

    override fun onDestroy() {
        try { server?.stop() } catch (_: Exception) {}
        nsd?.unregister()
        capObserver?.let { contentResolver.unregisterContentObserver(it) }
        netCallback?.let {
            try {
                (getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager)
                    .unregisterNetworkCallback(it)
            } catch (_: Exception) {}
        }
        instance = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        @Volatile
        var instance: EarGuardService? = null
            private set

        const val CHANNEL_ID = "eargaurd_service"
        const val NOTIF_ID = 4711
        const val EXTRA_FROM_UI = "from_ui"

        fun isRunning() = instance != null
    }
}
