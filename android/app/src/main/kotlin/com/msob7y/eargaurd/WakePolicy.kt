// by claude
package com.msob7y.eargaurd

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.wifi.WifiManager
import android.os.Build
import android.os.PowerManager
import java.time.Duration
import java.time.LocalTime
import java.time.ZonedDateTime

class WakePolicy(private val context: Context) {

    private val wakeLock = createWakeLock()
    private val wifiLock = createWifiLock()
    private val alarms = context.getSystemService(AlarmManager::class.java)
    private val alarmIntent = createAlarmIntent()

    val isAwake: Boolean get() = wakeLock.isHeld

    fun apply() {
        if (!Prefs.shouldStayReachable(context)) {
            release()
            return
        }
        val now = ZonedDateTime.now()
        val startMinute = Prefs.activeStartMinuteOfDay(context)
        val endMinute = Prefs.activeEndMinuteOfDay(context)
        val nowMinute = now.hour * 60 + now.minute
        val isActive = isWithinWindow(nowMinute, startMinute, endMinute)
        val boundaryMinute = if (isActive) endMinute else startMinute
        val nextBoundary = nextOccurrence(now, boundaryMinute)
        if (isActive) {
            val holdMS = Duration.between(now, nextBoundary).toMillis() + RELEASE_MARGIN_MS
            wakeLock.acquire(holdMS)
            wifiLock?.acquire()
        } else {
            releaseLocks()
        }
        schedule(nextBoundary)
    }

    fun release() {
        releaseLocks()
        alarms.cancel(alarmIntent)
    }

    private fun releaseLocks() {
        if (wakeLock.isHeld) wakeLock.release()
        val wifiLock = wifiLock ?: return
        if (wifiLock.isHeld) wifiLock.release()
    }

    private fun schedule(at: ZonedDateTime) {
        val triggerAtMS = at.toInstant().toEpochMilli()
        val canScheduleExact = Build.VERSION.SDK_INT < Build.VERSION_CODES.S || alarms.canScheduleExactAlarms()
        if (canScheduleExact) {
            alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMS, alarmIntent)
        } else {
            alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMS, alarmIntent)
        }
    }

    private fun createWakeLock(): PowerManager.WakeLock {
        val power = context.getSystemService(PowerManager::class.java)
        val lock = power.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, LOCK_TAG)
        lock.setReferenceCounted(false)
        return lock
    }

    @Suppress("DEPRECATION")
    private fun createWifiLock(): WifiManager.WifiLock? {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) return null
        val appContext = context.applicationContext
        val wifi = appContext.getSystemService(WifiManager::class.java)
        val lock = wifi.createWifiLock(WifiManager.WIFI_MODE_FULL_HIGH_PERF, LOCK_TAG)
        lock.setReferenceCounted(false)
        return lock
    }

    private fun createAlarmIntent(): PendingIntent {
        val intent = Intent(context, ReachabilityAlarmReceiver::class.java)
        val flags = PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        return PendingIntent.getBroadcast(context, 0, intent, flags)
    }

    private companion object {
        const val LOCK_TAG = "eargaurd:reachable"
        const val RELEASE_MARGIN_MS = 60_000L

        fun isWithinWindow(minute: Int, startMinute: Int, endMinute: Int): Boolean = when {
            startMinute == endMinute -> true
            startMinute < endMinute -> minute in startMinute until endMinute
            else -> minute >= startMinute || minute < endMinute
        }

        fun nextOccurrence(now: ZonedDateTime, minuteOfDay: Int): ZonedDateTime {
            val hour = minuteOfDay / 60
            val minute = minuteOfDay % 60
            val time = LocalTime.of(hour, minute)
            val date = now.toLocalDate()
            val today = ZonedDateTime.of(date, time, now.zone)
            if (today.isAfter(now)) return today
            return today.plusDays(1)
        }
    }
}

class ReachabilityAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val service = EarGuardService.instance
        if (service == null) {
            EarGuardService.startIfEnabled(context)
            return
        }
        service.applyWakePolicy()
    }
}
