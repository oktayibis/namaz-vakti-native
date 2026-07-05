package com.oktay.namaz.receiver

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import com.google.gson.Gson
import com.oktay.namaz.model.LocationData
import com.oktay.namaz.service.AlarmScheduler
import com.oktay.namaz.widget.PrayerAppWidget

/**
 * Reschedules prayer alarms whenever previously set alarms may have been lost or
 * drifted: device reboot, app update, and clock/timezone changes (alarms are RTC
 * based, so a timezone change shifts every trigger).
 */
class BootReceiver : BroadcastReceiver() {

    private val handledActions = setOf(
        Intent.ACTION_BOOT_COMPLETED,
        Intent.ACTION_MY_PACKAGE_REPLACED,
        Intent.ACTION_TIMEZONE_CHANGED,
        Intent.ACTION_TIME_CHANGED
    )

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action !in handledActions) return

        val prefs = context.getSharedPreferences("namaz_prefs", Context.MODE_PRIVATE)
        val activeLocationId = prefs.getString("active_location_id", null)
        val locationsJson = prefs.getString("saved_locations", null)

        if (activeLocationId != null && locationsJson != null) {
            try {
                val gson = Gson()
                val type = object : com.google.gson.reflect.TypeToken<List<LocationData>>() {}.type
                val locations = gson.fromJson<List<LocationData>>(locationsJson, type) ?: emptyList()
                val activeLocation = locations.firstOrNull { it.id == activeLocationId }

                if (activeLocation != null) {
                    val scheduler = AlarmScheduler(context)
                    scheduler.scheduleAlarms(activeLocation)
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        // Times shown on widgets shift too (especially on timezone change)
        val widgetIntent = Intent(context, PrayerAppWidget::class.java).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            val ids = AppWidgetManager.getInstance(context).getAppWidgetIds(
                ComponentName(context, PrayerAppWidget::class.java)
            )
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
        }
        context.sendBroadcast(widgetIntent)
    }
}
