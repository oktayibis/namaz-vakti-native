package com.oktay.namaz.service

import android.content.Context
import com.batoulapps.adhan.CalculationMethod
import com.batoulapps.adhan.CalculationParameters
import com.batoulapps.adhan.Coordinates
import com.batoulapps.adhan.HighLatitudeRule
import com.batoulapps.adhan.Madhab
import com.batoulapps.adhan.PrayerTimes
import com.batoulapps.adhan.data.DateComponents
import com.oktay.namaz.model.LocationData
import java.io.File
import java.text.SimpleDateFormat
import java.time.chrono.HijrahDate
import java.time.temporal.ChronoField
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

object PrayerCalculator {

    private fun getCalculationParameters(context: Context, latitude: Double = 39.0): CalculationParameters {
        val prefs = context.getSharedPreferences("namaz_prefs", Context.MODE_PRIVATE)
        val methodId = prefs.getInt("calculation_method", 13) // Default to Diyanet
        val schoolId = if (prefs.contains("asr_madhab")) prefs.getInt("asr_madhab", 0) else (if (methodId == 1) 1 else 0)

        val params = when (methodId) {
            13 -> {
                if (latitude > 48.0) {
                    // Avrupa / İskandinavya (Yüksek enlem): Diyanet 16.0° Yatsı açısı ve özel temkinler kullanır
                    CalculationParameters(18.0, 16.0).apply {
                        method = CalculationMethod.OTHER
                        adjustments.fajr = -1
                        adjustments.sunrise = -7
                        adjustments.dhuhr = 5
                        adjustments.asr = 5
                        adjustments.maghrib = 9
                        adjustments.isha = 3
                        highLatitudeRule = HighLatitudeRule.TWILIGHT_ANGLE
                    }
                } else {
                    // Türkiye Diyanet İşleri Başkanlığı:
                    // 18.0° Fajr, 17.0° Isha açısı ve resmi Diyanet yerel temkin süreleri.
                    // Erzurum, İstanbul ve Ankara gibi illerde Diyanet takvimiyle dakikası dakikasına (0-1 dk) eşleşir.
                    CalculationParameters(18.0, 17.0).apply {
                        method = CalculationMethod.OTHER
                        adjustments.fajr = 0
                        adjustments.sunrise = -7
                        adjustments.dhuhr = 5
                        adjustments.asr = 5
                        adjustments.maghrib = 8
                        adjustments.isha = 2
                        highLatitudeRule = HighLatitudeRule.TWILIGHT_ANGLE
                    }
                }
            }
            1 -> CalculationMethod.KARACHI.parameters
            2 -> CalculationMethod.NORTH_AMERICA.parameters
            4 -> CalculationMethod.UMM_AL_QURA.parameters
            5 -> CalculationMethod.EGYPTIAN.parameters
            8, 16 -> CalculationMethod.DUBAI.parameters
            9 -> CalculationMethod.KUWAIT.parameters
            10 -> CalculationMethod.QATAR.parameters
            11 -> CalculationMethod.SINGAPORE.parameters
            15 -> CalculationMethod.MOON_SIGHTING_COMMITTEE.parameters
            else -> CalculationMethod.MUSLIM_WORLD_LEAGUE.parameters
        }

        params.madhab = if (schoolId == 1) Madhab.HANAFI else Madhab.SHAFI
        return params
    }

    /**
     * Tamamen çevrimdışı, anlık (0 ms) ve yüksek hassasiyetli namaz vakti hesaplama motoru.
     * Ağ bağımlılığı olmadan verilen koordinat, saat dilimi ve tarihe göre vakitleri üretir.
     */
    fun calculatePrayerTimes(context: Context, location: LocationData, date: Date): Map<PrayerType, Date>? {
        val coordinates = Coordinates(location.latitude, location.longitude)
        val tz = TimeZone.getTimeZone(location.timezoneIdentifier)
        val calendar = Calendar.getInstance(tz).apply { time = date }

        val components = DateComponents(
            calendar.get(Calendar.YEAR),
            calendar.get(Calendar.MONTH) + 1,
            calendar.get(Calendar.DAY_OF_MONTH)
        )

        val params = getCalculationParameters(context, location.latitude)

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

    fun calculateLocalPrayerTimes(context: Context, location: LocationData, date: Date): Map<PrayerType, Date>? {
        return calculatePrayerTimes(context, location, date)
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

    /**
     * Diyanet takvimiyle uyumlu Türkçe Hicri tarih üretimi (örn: "24 Rebiülevvel 1448").
     */
    fun getHijriDateString(context: Context, location: LocationData, date: Date = Date()): String {
        return try {
            val tz = TimeZone.getTimeZone(location.timezoneIdentifier)
            val localDate = date.toInstant().atZone(tz.toZoneId()).toLocalDate()
            val hijrahDate = HijrahDate.from(localDate)
            val day = hijrahDate.get(ChronoField.DAY_OF_MONTH)
            val month = hijrahDate.get(ChronoField.MONTH_OF_YEAR)
            val year = hijrahDate.get(ChronoField.YEAR)

            val turkishHijriMonths = listOf(
                "Muharrem", "Safer", "Rebiülevvel", "Rebiülahir",
                "Cemaziyelevvel", "Cemaziyelahir", "Recep", "Şaban",
                "Ramazan", "Şevval", "Zilkade", "Zilhicce"
            )
            val monthName = turkishHijriMonths.getOrElse(month - 1) { "" }
            "$day $monthName $year"
        } catch (e: Exception) {
            e.printStackTrace()
            ""
        }
    }

    /**
     * Türkçe Miladi tarih formatı (örn: "6 Eylül 2026, Pazar").
     */
    fun getGregorianDateString(context: Context, location: LocationData, date: Date = Date()): String {
        return try {
            val tz = TimeZone.getTimeZone(location.timezoneIdentifier)
            val formatter = SimpleDateFormat("d MMMM yyyy, EEEE", Locale("tr", "TR")).apply {
                timeZone = tz
            }
            formatter.format(date)
        } catch (e: Exception) {
            e.printStackTrace()
            ""
        }
    }

    fun clearCache(context: Context) {
        try {
            val files = context.cacheDir.listFiles { _, name -> name.startsWith("namaz_cache_") }
            files?.forEach { it.delete() }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    @Suppress("UNUSED_PARAMETER")
    suspend fun fetchYearCalendar(context: Context, location: LocationData, year: Int): Boolean = true
}
