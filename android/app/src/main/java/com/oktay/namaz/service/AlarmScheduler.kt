package com.oktay.namaz.service

import android.annotation.SuppressLint
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import com.oktay.namaz.model.LocationData
import com.oktay.namaz.receiver.AlarmReceiver
import java.util.Calendar
import java.util.Date
import java.util.TimeZone

class AlarmScheduler(private val context: Context) {

    private val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
    private val prefs = context.getSharedPreferences("namaz_prefs", Context.MODE_PRIVATE)
    private val gson = Gson()

    private val enabledPrayersKey = "enabled_prayers"
    private val reminderOffsetsKey = "reminder_offsets"

    fun getEnabledPrayers(): Set<PrayerType> {
        val defaultPrayers = setOf(PrayerType.FAJR, PrayerType.DHUHR, PrayerType.ASR, PrayerType.MAGHRIB, PrayerType.ISHA)
        val json = prefs.getString(enabledPrayersKey, null) ?: return defaultPrayers
        return try {
            val type = object : TypeToken<Set<PrayerType>>() {}.type
            gson.fromJson(json, type) ?: defaultPrayers
        } catch (e: Exception) {
            defaultPrayers
        }
    }

    fun setEnabledPrayers(prayers: Set<PrayerType>) {
        prefs.edit().putString(enabledPrayersKey, gson.toJson(prayers)).apply()
    }

    fun getReminderOffsets(): List<Int> {
        val defaultOffsets = listOf(30, 0)
        val json = prefs.getString(reminderOffsetsKey, null) ?: return defaultOffsets
        return try {
            val type = object : TypeToken<List<Int>>() {}.type
            val list = gson.fromJson<List<Int>>(json, type) ?: defaultOffsets
            list.sortedDescending()
        } catch (e: Exception) {
            defaultOffsets
        }
    }

    fun setReminderOffsets(offsets: List<Int>) {
        val trimmed = offsets.sortedDescending().take(3)
        prefs.edit().putString(reminderOffsetsKey, gson.toJson(trimmed)).apply()
    }

    @SuppressLint("ScheduleExactAlarm")
    fun scheduleAlarms(location: LocationData) {
        // Cancel all current alarms first to prevent duplicates
        cancelAlarms()

        val enabledPrayers = getEnabledPrayers()
        val offsets = getReminderOffsets()

        if (enabledPrayers.isEmpty() || offsets.isEmpty()) return

        val calendar = Calendar.getInstance(TimeZone.getTimeZone(location.timezoneIdentifier))
        val now = Date()

        // Collect request codes and persist them once at the end; writing prefs per
        // alarm made scheduling O(n²) JSON work on the caller's thread.
        val scheduledCodes = mutableSetOf<Int>()

        // Schedule alarms for the next 7 days
        val daysToSchedule = 7

        for (dayOffset in 0 until daysToSchedule) {
            val dateCalendar = Calendar.getInstance(TimeZone.getTimeZone(location.timezoneIdentifier)).apply {
                time = now
                add(Calendar.DAY_OF_YEAR, dayOffset)
            }

            val prayerTimes = PrayerCalculator.calculatePrayerTimes(context, location, dateCalendar.time) ?: continue

            for (prayerType in enabledPrayers) {
                val prayerDate = prayerTimes[prayerType] ?: continue

                for (minutesBefore in offsets) {
                    val triggerCalendar = Calendar.getInstance(TimeZone.getTimeZone(location.timezoneIdentifier)).apply {
                        time = prayerDate
                        add(Calendar.MINUTE, -minutesBefore)
                    }

                    val triggerTimeMs = triggerCalendar.timeInMillis

                    // Only schedule future alarms
                    if (triggerTimeMs > now.time) {
                        val requestCode = generateRequestCode(location, dateCalendar, prayerType, minutesBefore)
                        scheduledCodes.add(requestCode)

                        val intent = Intent(context, AlarmReceiver::class.java).apply {
                            action = "com.oktay.namaz.ACTION_PRAYER_ALARM"
                            putExtra("prayer_name", prayerType.turkishName)
                            putExtra("city_name", location.name)
                            putExtra("offset", minutesBefore)
                            putExtra("request_code", requestCode)
                        }

                        val pendingIntent = PendingIntent.getBroadcast(
                            context,
                            requestCode,
                            intent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        )

                        // Schedule exact alarm with idle wake capability. On Android 12+
                        // exact alarms throw SecurityException if the user revoked the
                        // "Alarms & reminders" special access, so fall back to inexact.
                        val canExact = Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
                            alarmManager.canScheduleExactAlarms()
                        when {
                            !canExact -> alarmManager.setAndAllowWhileIdle(
                                AlarmManager.RTC_WAKEUP,
                                triggerTimeMs,
                                pendingIntent
                            )
                            Build.VERSION.SDK_INT >= Build.VERSION_CODES.M -> alarmManager.setExactAndAllowWhileIdle(
                                AlarmManager.RTC_WAKEUP,
                                triggerTimeMs,
                                pendingIntent
                            )
                            else -> alarmManager.setExact(
                                AlarmManager.RTC_WAKEUP,
                                triggerTimeMs,
                                pendingIntent
                            )
                        }
                    }
                }
            }
        }

        prefs.edit().putString("active_alarm_codes", gson.toJson(scheduledCodes)).apply()
    }

    fun cancelAlarms() {
        // Since we don't have a direct list of scheduled PendingIntents (the OS handles it),
        // we can save all active request codes in SharedPreferences and cancel them one by one.
        val activeCodesJson = prefs.getString("active_alarm_codes", null)
        if (activeCodesJson != null) {
            try {
                val type = object : TypeToken<Set<Int>>() {}.type
                val activeCodes: Set<Int> = gson.fromJson(activeCodesJson, type) ?: emptySet()
                
                val intent = Intent(context, AlarmReceiver::class.java).apply {
                    action = "com.oktay.namaz.ACTION_PRAYER_ALARM"
                }

                for (code in activeCodes) {
                    val pendingIntent = PendingIntent.getBroadcast(
                        context,
                        code,
                        intent,
                        PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
                    )
                    if (pendingIntent != null) {
                        alarmManager.cancel(pendingIntent)
                        pendingIntent.cancel()
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
        prefs.edit().remove("active_alarm_codes").apply()
    }

    private fun generateRequestCode(location: LocationData, calendar: Calendar, prayer: PrayerType, offset: Int): Int {
        val year = calendar.get(Calendar.YEAR)
        val dayOfYear = calendar.get(Calendar.DAY_OF_YEAR)
        val prayerId = prayer.ordinal
        
        // Generate a unique deterministic integer hash for the alarm
        val hashString = "${location.id}_${year}_${dayOfYear}_${prayerId}_${offset}"
        return hashString.hashCode()
    }
}
