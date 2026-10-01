package com.msob7y.eargaurd

import android.content.Context

object Prefs {
    private const val FILE = "eargaurd"
    const val DEFAULT_PORT = 8723
    const val DEFAULT_ACTIVE_START_MINUTE = 10 * 60
    const val DEFAULT_ACTIVE_END_MINUTE = 1 * 60

    private fun sp(c: Context) = c.getSharedPreferences(FILE, Context.MODE_PRIVATE)

    fun agentEnabled(c: Context) = sp(c).getBoolean("agent_enabled", false)
    fun setAgentEnabled(c: Context, v: Boolean) = sp(c).edit().putBoolean("agent_enabled", v).apply()

    fun capEnabled(c: Context) = sp(c).getBoolean("cap_enabled", false)
    fun setCapEnabled(c: Context, v: Boolean) = sp(c).edit().putBoolean("cap_enabled", v).apply()

    fun cap(c: Context) = sp(c).getInt("cap", 8)
    fun setCap(c: Context, v: Int) = sp(c).edit().putInt("cap", v).apply()

    fun threshold(c: Context) = sp(c).getFloat("threshold", -45f)
    fun setThreshold(c: Context, v: Float) = sp(c).edit().putFloat("threshold", v).apply()

    fun minHz(c: Context) = sp(c).getInt("min_hz", 8000)
    fun setMinHz(c: Context, v: Int) = sp(c).edit().putInt("min_hz", v).apply()

    fun maxHz(c: Context) = sp(c).getInt("max_hz", 20000)
    fun setMaxHz(c: Context, v: Int) = sp(c).edit().putInt("max_hz", v).apply()

    fun shouldStayReachable(c: Context) = sp(c).getBoolean("stay_reachable", true)
    fun activeStartMinuteOfDay(c: Context) = sp(c).getInt("active_start_minute", DEFAULT_ACTIVE_START_MINUTE)
    fun activeEndMinuteOfDay(c: Context) = sp(c).getInt("active_end_minute", DEFAULT_ACTIVE_END_MINUTE)

    fun setReachability(c: Context, shouldStayReachable: Boolean, startMinute: Int, endMinute: Int) =
        sp(c).edit()
            .putBoolean("stay_reachable", shouldStayReachable)
            .putInt("active_start_minute", startMinute)
            .putInt("active_end_minute", endMinute)
            .apply()

    fun port(c: Context) = sp(c).getInt("port", DEFAULT_PORT)
}
