package com.msob7y.eargaurd

import android.content.Context

object Prefs {
    private const val FILE = "eargaurd"
    const val DEFAULT_PORT = 8723

    private fun sp(c: Context) = c.getSharedPreferences(FILE, Context.MODE_PRIVATE)

    fun agentEnabled(c: Context) = sp(c).getBoolean("agent_enabled", false)
    fun setAgentEnabled(c: Context, v: Boolean) = sp(c).edit().putBoolean("agent_enabled", v).apply()

    fun capEnabled(c: Context) = sp(c).getBoolean("cap_enabled", false)
    fun setCapEnabled(c: Context, v: Boolean) = sp(c).edit().putBoolean("cap_enabled", v).apply()

    fun cap(c: Context) = sp(c).getInt("cap", 8)
    fun setCap(c: Context, v: Int) = sp(c).edit().putInt("cap", v).apply()

    fun threshold(c: Context) = sp(c).getFloat("threshold", -45f)
    fun setThreshold(c: Context, v: Float) = sp(c).edit().putFloat("threshold", v).apply()

    fun port(c: Context) = sp(c).getInt("port", DEFAULT_PORT)
}
