package com.msob7y.eargaurd

import android.content.Context
import android.os.Build
import fi.iki.elonen.NanoHTTPD
import org.json.JSONArray
import org.json.JSONObject

class ApiServer(
    private val context: Context,
    private val engine: AudioEngine,
    port: Int,
) : NanoHTTPD(port) {

    override fun serve(session: IHTTPSession): Response {
        return try {
            when (session.uri.trimEnd('/').ifEmpty { "/status" }) {
                "/status" -> json(status())

                "/volume" -> {
                    param(session, "level")?.toIntOrNull()?.let { engine.setVolume(it) }
                    json(status())
                }

                "/volume/step" -> {
                    engine.step(param(session, "delta")?.toIntOrNull() ?: 0)
                    json(status())
                }

                "/cap" -> {
                    param(session, "level")?.toIntOrNull()?.let {
                        Prefs.setCap(context, it)
                        EarGuardService.instance?.onSettingsChanged()
                    }
                    json(status())
                }

                "/cap/enable" -> {
                    param(session, "on")?.toBooleanStrictOrNull()?.let {
                        Prefs.setCapEnabled(context, it)
                        EarGuardService.instance?.onSettingsChanged()
                    }
                    json(status())
                }

                "/threshold" -> {
                    param(session, "value")?.toFloatOrNull()?.let { Prefs.setThreshold(context, it) }
                    json(status())
                }

                "/band" -> {
                    param(session, "minHz")?.toIntOrNull()?.let { Prefs.setMinHz(context, it) }
                    param(session, "maxHz")?.toIntOrNull()?.let { Prefs.setMaxHz(context, it) }
                    json(status())
                }

                "/warn" -> {
                    engine.playWarning()
                    json(JSONObject().put("warned", true))
                }

                "/analyze" -> {
                    val a = EarGuardService.instance?.analyze()
                    if (a == null) {
                        json(JSONObject().put("micReady", false))
                    } else {
                        json(analysisJson(a).put("micReady", true))
                    }
                }

                "/check" -> {
                    val svc = EarGuardService.instance
                    val threshold = Prefs.threshold(context).toDouble()
                    if (svc == null || !svc.micReady) {
                        json(
                            JSONObject()
                                .put("band10k", -999.0)
                                .put("threshold", threshold)
                                .put("warned", false)
                                .put("micReady", false),
                        )
                    } else {
                        val (band, thr, warned) = svc.checkAndWarn()
                        json(
                            JSONObject()
                                .put("band10k", round2(band))
                                .put("threshold", thr)
                                .put("warned", warned)
                                .put("micReady", true),
                        )
                    }
                }

                else -> newFixedLengthResponse(
                    Response.Status.NOT_FOUND, "application/json", """{"error":"not found"}""",
                )
            }
        } catch (e: Exception) {
            newFixedLengthResponse(
                Response.Status.INTERNAL_ERROR, "application/json",
                JSONObject().put("error", e.message ?: "error").toString(),
            )
        }
    }

    private fun param(session: IHTTPSession, key: String): String? =
        session.parameters[key]?.firstOrNull()

    private fun status(): JSONObject = JSONObject()
        .put("name", Build.MODEL)
        .put("volume", engine.currentVolume())
        .put("max", engine.maxVolume())
        .put("cap", Prefs.cap(context))
        .put("capEnabled", Prefs.capEnabled(context))
        .put("threshold", Prefs.threshold(context).toDouble())
        .put("minHz", Prefs.minHz(context))
        .put("maxHz", Prefs.maxHz(context))
        .put("micReady", EarGuardService.instance?.micReady ?: false)

    private fun analysisJson(a: Analysis): JSONObject = JSONObject()
        .put("sampleRate", a.sampleRate)
        .put("binHz", a.binHz)
        .put("bars", JSONArray(a.bars.map { round2(it) }))
        .put("peakHz", round2(a.peakHz))
        .put("peakDb", round2(a.peakDb))
        .put("bandPeakHz", round2(a.bandPeakHz))
        .put("bandPeakDb", round2(a.bandPeakDb))

    private fun json(o: JSONObject): Response =
        newFixedLengthResponse(Response.Status.OK, "application/json", o.toString())

    private fun round2(v: Double): Double =
        if (v.isFinite()) Math.round(v * 100) / 100.0 else -999.0
}
