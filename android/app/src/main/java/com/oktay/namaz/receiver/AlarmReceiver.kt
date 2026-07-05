package com.oktay.namaz.receiver

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import com.oktay.namaz.MainActivity
import com.oktay.namaz.R
import com.oktay.namaz.widget.PrayerAppWidget

class AlarmReceiver : BroadcastReceiver() {

    private val channelId = "namaz_vakitleri_channel"

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != "com.oktay.namaz.ACTION_PRAYER_ALARM") return

        val prayerName = intent.getStringExtra("prayer_name") ?: return
        val cityName = intent.getStringExtra("city_name") ?: "Konum"
        val offset = intent.getIntExtra("offset", 0)
        val requestCode = intent.getIntExtra("request_code", 0)

        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // Create notification channel for Android O+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "Namaz Vakitleri Bildirimleri",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Namaz vakti hatırlatıcı bildirimleri"
                enableLights(true)
                enableVibration(true)
            }
            notificationManager.createNotificationChannel(channel)
        }

        // Click action: open MainActivity
        val clickIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            requestCode,
            clickIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Determine content copy
        val title: String
        val body: String

        if (offset == 0) {
            title = "$prayerName Vakti"
            body = "$prayerName vakti girdi. Namazınızı kılabilirsiniz."
        } else if (offset == 30) {
            title = "$prayerName Vaktine Az Kaldı"
            body = "$prayerName vaktinin girmesine 30 dakika kaldı."
        } else {
            title = "$prayerName Hatırlatıcısı"
            body = "$prayerName vaktine $offset dakika kaldı."
        }

        // Build notification
        val builder = NotificationCompat.Builder(context, channelId)
            // Use system location icon or alarm icon as fallback
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(title)
            .setContentText(body)
            .setSubText(cityName)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)

        // Show notification (use requestCode as unique ID so multiple notifications can coexist)
        notificationManager.notify(requestCode, builder.build())

        // A prayer boundary just passed; refresh widgets so current/next flip on time
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
