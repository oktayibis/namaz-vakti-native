package com.oktay.namaz.service

import android.content.Context
import android.content.Intent
import com.batoulapps.adhan.CalculationMethod
import com.batoulapps.adhan.Coordinates
import com.batoulapps.adhan.Madhab
import com.batoulapps.adhan.PrayerTimes
import com.batoulapps.adhan.data.DateComponents
import com.google.gson.Gson
import com.oktay.namaz.model.LocationData
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.TimeZone

enum class PrayerType(val rawValue: String, val turkishName: String) {
    FAJR("fajr", "İmsak"),
    SUNRISE("sunrise", "Güneş"),
    DHUHR("dhuhr", "Öğle"),
    ASR("asr", "İkindi"),
    MAGHRIB("maghrib", "Akşam"),
    ISHA("isha", "Yatsı")
}

data class PrayerTimeItem(
    val type: PrayerType,
    val date: Date,
    val formattedTime: String
)

data class PrayerProgressInfo(
    val currentPrayer: PrayerType,
    val nextPrayer: PrayerType,
    val timeRemaining: Long,
    val progress: Double,
    val currentPrayerTime: Date,
    val nextPrayerTime: Date
)

// Aladhan API DTOs (Annual Response)
data class AladhanApiResponse(
    val code: Int,
    val status: String,
    val data: Map<String, List<AladhanDayData>>? // Month string ("1" to "12") -> Day list
)

data class AladhanDayData(
    val timings: Map<String, String>,
    val date: AladhanDate
)

data class AladhanDate(
    val readable: String,
    val timestamp: String,
    val gregorian: AladhanGregorian,
    val hijri: AladhanHijri
)

data class AladhanGregorian(
    val date: String, // "04-07-2026"
    val month: AladhanMonth,
    val year: String
)

data class AladhanMonth(
    val number: Int,
    val en: String
)

data class AladhanHijri(
    val date: String, // "20-01-1448"
    val day: String,
    val month: AladhanHijriMonth,
    val year: String
)

data class AladhanHijriMonth(
    val number: Int,
    val en: String,
    val ar: String
)

object PrayerCalculator {

    private val gson = Gson()
    private val scope = CoroutineScope(Dispatchers.IO)

    // In-memory copy of the parsed annual calendar; the raw JSON file is 1-2 MB and
    // callers (widget, 1s countdown timer) would otherwise re-read and re-parse it
    // from disk on every single call.
    private val memoryCache = mutableMapOf<String, AladhanApiResponse>()

    @Synchronized
    private fun loadAnnualCache(context: Context, cacheFilename: String): AladhanApiResponse? {
        memoryCache[cacheFilename]?.let { return it }
        val cacheFile = File(context.cacheDir, cacheFilename)
        if (!cacheFile.exists()) return null
        return try {
            val response = gson.fromJson(cacheFile.readText(), AladhanApiResponse::class.java)
            if (response != null && response.code == 200 && response.data != null) {
                memoryCache[cacheFilename] = response
                response
            } else {
                null
            }
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    @Synchronized
    private fun invalidateMemoryCache(cacheFilename: String? = null) {
        if (cacheFilename != null) memoryCache.remove(cacheFilename) else memoryCache.clear()
    }

    fun calculateLocalPrayerTimes(context: Context, location: LocationData, date: Date): Map<PrayerType, Date>? {
        val coordinates = Coordinates(location.latitude, location.longitude)
        
        val tz = TimeZone.getTimeZone(location.timezoneIdentifier)
        val calendar = Calendar.getInstance(tz)
        calendar.time = date
        
        val components = DateComponents(
            calendar.get(Calendar.YEAR),
            calendar.get(Calendar.MONTH) + 1,
            calendar.get(Calendar.DAY_OF_MONTH)
        )
        
        val prefs = context.getSharedPreferences("namaz_prefs", Context.MODE_PRIVATE)
        val methodId = prefs.getInt("calculation_method", 13) // Default to Diyanet (approximated)
        val schoolId = if (prefs.contains("asr_madhab")) prefs.getInt("asr_madhab", 0) else (if (methodId == 1) 1 else 0)
        
        val method = when (methodId) {
            13, 3 -> CalculationMethod.MUSLIM_WORLD_LEAGUE
            2 -> CalculationMethod.NORTH_AMERICA
            4 -> CalculationMethod.UMM_AL_QURA
            5 -> CalculationMethod.EGYPTIAN
            1 -> CalculationMethod.KARACHI
            else -> CalculationMethod.MUSLIM_WORLD_LEAGUE
        }
        
        val params = method.parameters
        params.madhab = if (schoolId == 1) Madhab.HANAFI else Madhab.SHAFI
        
        return try {
            val prayerTimes = PrayerTimes(coordinates, components, params)
            mapOf(
                PrayerType.FAJR to prayerTimes.fajr,
                PrayerType.SUNRISE to prayerTimes.sunrise,
                PrayerType.DHUHR to prayerTimes.dhuhr,
                PrayerType.ASR to prayerTimes.asr,
                PrayerType.MAGHRIB to prayerTimes.maghrib,
                PrayerType.ISHA to prayerTimes.isha
            )
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    fun calculatePrayerTimes(context: Context, location: LocationData, date: Date): Map<PrayerType, Date>? {
        val tz = TimeZone.getTimeZone(location.timezoneIdentifier)
        val calendar = Calendar.getInstance(tz)
        calendar.time = date
        
        val month = calendar.get(Calendar.MONTH) + 1
        val year = calendar.get(Calendar.YEAR)
        
        val cacheFilename = "namaz_cache_${location.id}_${year}.json"

        val response = loadAnnualCache(context, cacheFilename)
        if (response != null) {
            try {
                run {
                    val monthKey = month.toString()
                    val monthList = response.data!![monthKey]
                    if (!monthList.isNullOrEmpty()) {
                        val dayStr = String.format(Locale.US, "%02d", calendar.get(Calendar.DAY_OF_MONTH))
                        val monthStr = String.format(Locale.US, "%02d", month)
                        val dateKey = "$dayStr-$monthStr-$year" // matches format "dd-MM-yyyy"
                        
                        val dayData = monthList.firstOrNull { it.date.gregorian.date == dateKey }
                        if (dayData != null) {
                            val parsedTimes = mutableMapOf<PrayerType, Date>()
                            
                            val parser = SimpleDateFormat("dd-MM-yyyy HH:mm", Locale.US).apply {
                                timeZone = tz
                            }
                            
                            val keyMapping = mapOf(
                                PrayerType.FAJR to "Fajr",
                                PrayerType.SUNRISE to "Sunrise",
                                PrayerType.DHUHR to "Dhuhr",
                                PrayerType.ASR to "Asr",
                                PrayerType.MAGHRIB to "Maghrib",
                                PrayerType.ISHA to "Isha"
                            )
                            
                            for ((type, apiKey) in keyMapping) {
                                val rawTime = dayData.timings[apiKey] ?: return null
                                val cleanTime = rawTime.split(" ")[0]
                                val fullDateStr = "$dateKey $cleanTime"
                                val parsedDate = parser.parse(fullDateStr)
                                if (parsedDate != null) {
                                    parsedTimes[type] = parsedDate
                                }
                            }
                            
                            if (parsedTimes.size == 6) {
                                return parsedTimes
                            }
                        }
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
        
        // Trigger background fetch if network is available
        triggerCacheFetch(context, location, year)
        
        // Fallback to local astronomical calculations
        return calculateLocalPrayerTimes(context, location, date)
    }

    private fun triggerCacheFetch(context: Context, location: LocationData, year: Int) {
        val cacheFilename = "namaz_cache_${location.id}_${year}.json"
        val cacheFile = File(context.cacheDir, cacheFilename)
        
        val fetchingKey = "fetching_${location.id}_${year}"
        val prefs = context.getSharedPreferences("namaz_prefs", Context.MODE_PRIVATE)
        if (prefs.getBoolean(fetchingKey, false)) return
        
        prefs.edit().putBoolean(fetchingKey, true).apply()
        
        scope.launch {
            try {
                val method = prefs.getInt("calculation_method", 13)
                val school = if (prefs.contains("asr_madhab")) prefs.getInt("asr_madhab", 0) else (if (method == 1) 1 else 0)
                
                val urlString = "https://api.aladhan.com/v1/calendar/${year}?latitude=${location.latitude}&longitude=${location.longitude}&method=${method}&school=${school}"
                val url = URL(urlString)
                val connection = url.openConnection() as HttpURLConnection
                connection.requestMethod = "GET"
                connection.connectTimeout = 15000
                connection.readTimeout = 15000
                
                val responseCode = connection.responseCode
                if (responseCode == HttpURLConnection.HTTP_OK) {
                    val reader = BufferedReader(InputStreamReader(connection.inputStream))
                    val response = StringBuilder()
                    var line: String?
                    while (reader.readLine().also { line = it } != null) {
                        response.append(line)
                    }
                    reader.close()
                    
                    val parsed = gson.fromJson(response.toString(), AladhanApiResponse::class.java)
                    if (parsed.code == 200 && parsed.data != null) {
                        cacheFile.writeText(response.toString())
                        invalidateMemoryCache(cacheFilename)

                        val intent = Intent("com.oktay.namaz.ACTION_CACHE_UPDATED")
                        context.sendBroadcast(intent)
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
            } finally {
                prefs.edit().remove(fetchingKey).apply()
            }
        }
    }

    suspend fun fetchYearCalendar(context: Context, location: LocationData, year: Int): Boolean {
        val cacheFilename = "namaz_cache_${location.id}_${year}.json"
        val cacheFile = File(context.cacheDir, cacheFilename)
        val prefs = context.getSharedPreferences("namaz_prefs", Context.MODE_PRIVATE)
        val method = prefs.getInt("calculation_method", 13)
        val school = if (prefs.contains("asr_madhab")) prefs.getInt("asr_madhab", 0) else (if (method == 1) 1 else 0)
        
        return withContext(Dispatchers.IO) {
            try {
                val urlString = "https://api.aladhan.com/v1/calendar/${year}?latitude=${location.latitude}&longitude=${location.longitude}&method=${method}&school=${school}"
                val url = URL(urlString)
                val connection = url.openConnection() as HttpURLConnection
                connection.requestMethod = "GET"
                connection.connectTimeout = 15000
                connection.readTimeout = 15000
                
                if (connection.responseCode == HttpURLConnection.HTTP_OK) {
                    val reader = BufferedReader(InputStreamReader(connection.inputStream))
                    val response = StringBuilder()
                    var line: String?
                    while (reader.readLine().also { line = it } != null) {
                        response.append(line)
                    }
                    reader.close()
                    
                    val parsed = gson.fromJson(response.toString(), AladhanApiResponse::class.java)
                    if (parsed.code == 200 && parsed.data != null) {
                        cacheFile.writeText(response.toString())
                        invalidateMemoryCache(cacheFilename)
                        return@withContext true
                    }
                }
                false
            } catch (e: Exception) {
                e.printStackTrace()
                false
            }
        }
    }

    fun getPrayerTimesList(context: Context, location: LocationData, date: Date): List<PrayerTimeItem> {
        val times = calculatePrayerTimes(context, location, date) ?: return emptyList()
        val tz = TimeZone.getTimeZone(location.timezoneIdentifier)
        
        val formatter = SimpleDateFormat("HH:mm", Locale.getDefault()).apply {
            timeZone = tz
        }
        
        return PrayerType.values().map { type ->
            val dateVal = times[type] ?: Date()
            PrayerTimeItem(type, dateVal, formatter.format(dateVal))
        }
    }

    fun getProgressInfo(context: Context, location: LocationData, referenceDate: Date = Date()): PrayerProgressInfo? {
        val tz = TimeZone.getTimeZone(location.timezoneIdentifier)
        
        val yesterdayCalendar = Calendar.getInstance(tz).apply {
            time = referenceDate
            add(Calendar.DAY_OF_YEAR, -1)
        }
        val yesterdayTimes = calculatePrayerTimes(context, location, yesterdayCalendar.time)
        
        val todayTimes = calculatePrayerTimes(context, location, referenceDate)
        
        val tomorrowCalendar = Calendar.getInstance(tz).apply {
            time = referenceDate
            add(Calendar.DAY_OF_YEAR, 1)
        }
        val tomorrowTimes = calculatePrayerTimes(context, location, tomorrowCalendar.time)
        
        if (yesterdayTimes == null || todayTimes == null || tomorrowTimes == null) return null
        
        class Milestone(val type: PrayerType, val date: Date)
        
        val milestones = mutableListOf<Milestone>()
        
        yesterdayTimes[PrayerType.ISHA]?.let {
            milestones.add(Milestone(PrayerType.ISHA, it))
        }
        
        for (type in PrayerType.values()) {
            todayTimes[type]?.let {
                milestones.add(Milestone(type, it))
            }
        }
        
        tomorrowTimes[PrayerType.FAJR]?.let {
            milestones.add(Milestone(PrayerType.FAJR, it))
        }
        
        milestones.sortBy { it.date.time }
        
        val refTime = referenceDate.time
        
        for (i in 0 until milestones.size - 1) {
            val start = milestones[i]
            val end = milestones[i + 1]
            
            if (refTime >= start.date.time && refTime < end.date.time) {
                val totalInterval = end.date.time - start.date.time
                val elapsedInterval = refTime - start.date.time
                val timeRemaining = end.date.time - refTime
                
                val progress = if (totalInterval > 0) elapsedInterval.toDouble() / totalInterval else 0.0
                
                return PrayerProgressInfo(
                    currentPrayer = start.type,
                    nextPrayer = end.type,
                    timeRemaining = timeRemaining,
                    progress = progress,
                    currentPrayerTime = start.date,
                    nextPrayerTime = end.date
                )
            }
        }
        
        val first = milestones.firstOrNull()
        val last = milestones.lastOrNull()
        if (first != null && last != null) {
            return PrayerProgressInfo(
                currentPrayer = last.type,
                nextPrayer = first.type,
                timeRemaining = 0,
                progress = 1.0,
                currentPrayerTime = last.date,
                nextPrayerTime = first.date
            )
        }
        
        return null
    }

    fun getHijriDateString(context: Context, location: LocationData, date: Date): String? {
        val tz = TimeZone.getTimeZone(location.timezoneIdentifier)
        val calendar = Calendar.getInstance(tz)
        calendar.time = date
        
        val day = calendar.get(Calendar.DAY_OF_MONTH)
        val month = calendar.get(Calendar.MONTH) + 1
        val year = calendar.get(Calendar.YEAR)
        
        val cacheFilename = "namaz_cache_${location.id}_${year}.json"
        val response = loadAnnualCache(context, cacheFilename) ?: return null
        val data = response.data ?: return null
        
        val monthKey = month.toString()
        val monthList = data[monthKey] ?: return null
        
        val dayStr = String.format("%02d", day)
        val monthStr = String.format("%02d", month)
        val dateKey = "$dayStr-$monthStr-$year"
        
        val dayData = monthList.firstOrNull { it.date.gregorian.date == dateKey } ?: return null
        val h = dayData.date.hijri
        return "${h.day} ${h.month.en} ${h.year}"
    }

    fun clearCache(context: Context) {
        try {
            val files = context.cacheDir.listFiles { _, name -> name.startsWith("namaz_cache_") }
            files?.forEach { it.delete() }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        invalidateMemoryCache()
    }
}
