package com.oktay.namaz.service

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import com.oktay.namaz.model.LocationData

class NotificationSyncWorker(
    context: Context,
    workerParams: WorkerParameters
) : CoroutineWorker(context, workerParams) {

    override suspend fun doWork(): Result {
        val prefs = applicationContext.getSharedPreferences("namaz_prefs", Context.MODE_PRIVATE)
        val activeLocationId = prefs.getString("active_location_id", null)
        val locationsJson = prefs.getString("saved_locations", null)

        if (activeLocationId != null && locationsJson != null) {
            try {
                val gson = Gson()
                val type = object : TypeToken<List<LocationData>>() {}.type
                val locations = gson.fromJson<List<LocationData>>(locationsJson, type) ?: emptyList()
                val activeLocation = locations.firstOrNull { it.id == activeLocationId }

                if (activeLocation != null) {
                    val scheduler = AlarmScheduler(applicationContext)
                    scheduler.scheduleAlarms(activeLocation)
                }
            } catch (e: Exception) {
                e.printStackTrace()
                return Result.retry()
            }
        }
        return Result.success()
    }
}
