package com.msob7y.eargaurd

import android.content.Context
import android.os.Build
import fi.iki.elonen.NanoHTTPD
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

                "/warn" -> {
                    engine.playWarning()
                    json(JSONObject().put("warned", true))
                }

                "/check" -> {
                    val svc = EarGuardService.instance
                    if (svc == null || !svc.micReady) {
                        json(
                            JSONObject()
                                .put("band10k", -999.0)
                                .put("threshold", Prefs.threshold(context).toDouble())
                                .put("warned", false)
                                .put("micReady", false),
                        )
                    } else {
                        val band = engine.captureBand10kDbfs()
                        val threshold = Prefs.threshold(context).toDouble()
                        val warned = band > threshold && band > -900
                        if (warned) engine.playWarning()
                        json(
                            JSONObject()
                                .put("band10k", round2(band))
                                .put("threshold", threshold)
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
        .put("micReady", EarGuardService.instance?.micReady ?: false)

    private fun json(o: JSONObject): Response =
        newFixedLengthResponse(Response.Status.OK, "application/json", o.toString())

    private fun round2(v: Double): Double =
        if (v.isFinite()) Math.round(v * 100) / 100.0 else -999.0
}
