package com.msob7y.eargaurd

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {

    private val channelName = "eargaurd/agent"
    private val bg = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val engine = AudioEngine(applicationContext)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startAgent" -> {
                        val i = Intent(this, EarGuardService::class.java)
                            .putExtra(EarGuardService.EXTRA_FROM_UI, true)
                        startForegroundService(i)
                        result.success(true)
                    }

                    "stopAgent" -> {
                        Prefs.setAgentEnabled(this, false)
                        stopService(Intent(this, EarGuardService::class.java))
                        result.success(true)
                    }

                    "isAgentRunning" -> result.success(EarGuardService.isRunning())

                    "getStatus" -> result.success(statusMap(engine))

                    "setVolume" -> {
                        engine.setVolume(call.argument<Int>("level") ?: 0)
                        result.success(statusMap(engine))
                    }

                    "stepVolume" -> {
                        engine.step(call.argument<Int>("delta") ?: 0)
                        result.success(statusMap(engine))
                    }

                    "setCap" -> {
                        Prefs.setCap(this, call.argument<Int>("level") ?: 8)
                        EarGuardService.instance?.onSettingsChanged()
                        result.success(statusMap(engine))
                    }

                    "setCapEnabled" -> {
                        Prefs.setCapEnabled(this, call.argument<Boolean>("on") ?: false)
                        EarGuardService.instance?.onSettingsChanged()
                        result.success(statusMap(engine))
                    }

                    "setThreshold" -> {
                        Prefs.setThreshold(this, (call.argument<Double>("value") ?: -45.0).toFloat())
                        result.success(statusMap(engine))
                    }

                    "setBand" -> {
                        Prefs.setMinHz(this, call.argument<Int>("minHz") ?: 8000)
                        Prefs.setMaxHz(this, call.argument<Int>("maxHz") ?: 20000)
                        result.success(statusMap(engine))
                    }

                    "analyze" -> {
                        val minHz = call.argument<Int>("minHz") ?: Prefs.minHz(this)
                        val maxHz = call.argument<Int>("maxHz") ?: Prefs.maxHz(this)
                        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) !=
                            PackageManager.PERMISSION_GRANTED
                        ) {
                            result.error("no_mic", "Microphone permission not granted", null)
                        } else {
                            bg.execute {
                                val a = engine.analyze(minHz, maxHz)
                                runOnUiThread {
                                    if (a == null) {
                                        result.error("analyze_failed", "Could not open microphone", null)
                                    } else {
                                        result.success(a.toMap())
                                    }
                                }
                            }
                        }
                    }

                    "warn" -> {
                        engine.playWarning()
                        result.success(true)
                    }

                    "check" -> {
                        val svc = EarGuardService.instance
                        if (svc == null) {
                            result.error("no_agent", "Start the agent first", null)
                        } else {
                            val (band, threshold, warned) = svc.checkAndWarn()
                            result.success(
                                mapOf(
                                    "band10k" to band,
                                    "threshold" to threshold,
                                    "warned" to warned,
                                    "micReady" to svc.micReady,
                                ),
                            )
                        }
                    }

                    "requestBatteryExemption" -> {
                        requestBatteryExemption()
                        result.success(true)
                    }

                    "serverInfo" -> result.success(mapOf("port" to Prefs.port(this)))

                    "getFlavor" -> result.success(BuildConfig.FLAVOR)

                    else -> result.notImplemented()
                }
            }
    }

    private fun statusMap(engine: AudioEngine): Map<String, Any> = mapOf(
        "volume" to engine.currentVolume(),
        "max" to engine.maxVolume(),
        "cap" to Prefs.cap(this),
        "capEnabled" to Prefs.capEnabled(this),
        "threshold" to Prefs.threshold(this).toDouble(),
        "minHz" to Prefs.minHz(this),
        "maxHz" to Prefs.maxHz(this),
        "running" to EarGuardService.isRunning(),
        "micReady" to (EarGuardService.instance?.micReady ?: false),
    )

    private fun requestBatteryExemption() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                startActivity(
                    Intent(
                        Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                        Uri.parse("package:$packageName"),
                    ),
                )
            } catch (_: Exception) {
            }
        }
    }
}
