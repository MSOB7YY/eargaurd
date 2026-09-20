package com.msob7y.eargaurd

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (!Prefs.agentEnabled(context)) return
        val i = Intent(context, EarGuardService::class.java)
        try {
            context.startForegroundService(i)
        } catch (_: Exception) {
        }
    }
}
