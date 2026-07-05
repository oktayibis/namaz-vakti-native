package com.oktay.namaz.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.widget.RemoteViews
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import com.oktay.namaz.MainActivity
import com.oktay.namaz.R
import com.oktay.namaz.model.LocationData
import com.oktay.namaz.service.PrayerCalculator
import com.oktay.namaz.service.PrayerType
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

class PrayerAppWidget : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    // Re-render with the appropriate layout when the user resizes the widget
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        updateAppWidget(context, appWidgetManager, appWidgetId)
    }

    private fun loadActiveLocation(context: Context): LocationData? {
        val prefs = context.getSharedPreferences("namaz_prefs", Context.MODE_PRIVATE)
        val locationsJson = prefs.getString("saved_locations", null) ?: return null
        return try {
            val type = object : TypeToken<List<LocationData>>() {}.type
            val locations: List<LocationData> = Gson().fromJson(locationsJson, type) ?: return null
            val activeId = prefs.getString("active_location_id", null)
            locations.firstOrNull { it.id == activeId } ?: locations.firstOrNull()
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    private fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
        // Below ~4 launcher cells the all-times grid doesn't fit; show the compact
        // current+next layout instead.
        val minWidth = appWidgetManager.getAppWidgetOptions(appWidgetId)
            .getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 250)
        val isSmall = minWidth in 1 until 240

        val views = RemoteViews(
            context.packageName,
            if (isSmall) R.layout.prayer_widget_small else R.layout.prayer_widget
        )

        val location = loadActiveLocation(context)
        if (location == null) {
            if (isSmall) {
                views.setTextViewText(R.id.widget_city_name, "Konum Seçilmedi")
                views.setTextViewText(R.id.widget_current_prayer, "")
                views.setTextViewText(R.id.widget_next_label, "Uygulamayı açın")
                views.setTextViewText(R.id.widget_next_time, "")
            } else {
                views.setTextViewText(R.id.widget_city_name, "Konum Seçilmedi")
                views.setTextViewText(R.id.widget_next_prayer, "Lütfen uygulamayı açın")
            }
        } else {
            // Times are computed on the fly instead of being cached at save time, so
            // the widget can never show a stale "time remaining" text.
            val times = PrayerCalculator.getPrayerTimesList(context, location, Date())
            val info = PrayerCalculator.getProgressInfo(context, location)

            val formatter = SimpleDateFormat("HH:mm", Locale.getDefault()).apply {
                timeZone = TimeZone.getTimeZone(location.timezoneIdentifier)
            }
            val nextName = info?.nextPrayer?.turkishName ?: ""
            val nextTime = info?.nextPrayerTime?.let { formatter.format(it) } ?: ""
            val currentName = info?.currentPrayer?.turkishName ?: ""

            if (isSmall) {
                views.setTextViewText(R.id.widget_city_name, location.name)
                views.setTextViewText(
                    R.id.widget_current_prayer,
                    if (currentName.isNotEmpty()) "Şu an: $currentName" else ""
                )
                views.setTextViewText(
                    R.id.widget_next_label,
                    if (nextName.isNotEmpty()) "Sıradaki: $nextName" else "Vakitler yükleniyor..."
                )
                views.setTextViewText(R.id.widget_next_time, nextTime)
            } else {
                views.setTextViewText(R.id.widget_city_name, location.name)
                views.setTextViewText(
                    R.id.widget_next_prayer,
                    if (nextName.isNotEmpty()) "Sıradaki: $nextName $nextTime" else "Vakitler yükleniyor..."
                )

                val timeViewIds = mapOf(
                    PrayerType.FAJR to R.id.time_fajr,
                    PrayerType.SUNRISE to R.id.time_sunrise,
                    PrayerType.DHUHR to R.id.time_dhuhr,
                    PrayerType.ASR to R.id.time_asr,
                    PrayerType.MAGHRIB to R.id.time_maghrib,
                    PrayerType.ISHA to R.id.time_isha
                )
                val containerIds = mapOf(
                    PrayerType.FAJR to R.id.container_fajr,
                    PrayerType.SUNRISE to R.id.container_sunrise,
                    PrayerType.DHUHR to R.id.container_dhuhr,
                    PrayerType.ASR to R.id.container_asr,
                    PrayerType.MAGHRIB to R.id.container_maghrib,
                    PrayerType.ISHA to R.id.container_isha
                )

                for (item in times) {
                    timeViewIds[item.type]?.let { views.setTextViewText(it, item.formattedTime) }
                }
                for ((type, containerId) in containerIds) {
                    views.setInt(
                        containerId,
                        "setBackgroundResource",
                        if (info?.currentPrayer == type) R.drawable.widget_active_bg else 0
                    )
                }
            }
        }

        // Tap anywhere: open the app
        val clickIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            appWidgetId,
            clickIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }
}
