package com.oktay.namaz.service

import com.batoulapps.adhan.CalculationParameters
import com.batoulapps.adhan.Coordinates
import com.batoulapps.adhan.HighLatitudeRule
import com.batoulapps.adhan.PrayerTimes
import com.batoulapps.adhan.data.DateComponents
import com.oktay.namaz.model.CalculationMethodRegistry
import com.oktay.namaz.model.LocationData
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import java.util.TimeZone

class PrayerCalculatorTest {

    private val istanbul = LocationData(
        id = "loc-istanbul",
        name = "İstanbul",
        country = "Türkiye",
        latitude = 41.0082,
        longitude = 28.9784,
        timezoneIdentifier = "Europe/Istanbul"
    )

    private val copenhagen = LocationData(
        id = "loc-copenhagen",
        name = "Copenhagen",
        country = "Denmark",
        latitude = 55.659,
        longitude = 12.518,
        timezoneIdentifier = "Europe/Copenhagen"
    )

    @Before
    fun setUp() {
        PrayerCalculator.invalidateTimesCache()
    }

    @Test
    fun testDiyanetIstanbulAccurateWithinOneMinute() {
        // Istanbul coordinates: 41.0082, 28.9784
        val coords = Coordinates(41.0082, 28.9784)
        val dc = DateComponents(2026, 9, 6)

        val params = CalculationParameters(18.0, 17.0).apply {
            adjustments.fajr = 0
            adjustments.sunrise = -7
            adjustments.dhuhr = 5
            adjustments.asr = 5
            adjustments.maghrib = 8
            adjustments.isha = 2
            highLatitudeRule = HighLatitudeRule.TWILIGHT_ANGLE
        }

        val prayerTimes = PrayerTimes(coords, dc, params)

        val sdf = SimpleDateFormat("HH:mm", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("Europe/Istanbul")
        }

        // Official Diyanet published for 06 September 2026:
        // İmsak: 05:00, Güneş: 06:28, Öğle: 13:08, İkindi: 16:45, Akşam: 19:37, Yatsı: 21:00
        assertEquals("05:00", sdf.format(prayerTimes.fajr))
        // Tolerances are <= 1 minute
        val sunrise = sdf.format(prayerTimes.sunrise)
        assertTrue(sunrise == "06:28" || sunrise == "06:29")

        val dhuhr = sdf.format(prayerTimes.dhuhr)
        assertTrue(dhuhr == "13:07" || dhuhr == "13:08")

        val asr = sdf.format(prayerTimes.asr)
        assertTrue(asr == "16:44" || asr == "16:45")

        assertEquals("19:37", sdf.format(prayerTimes.maghrib))
        assertEquals("21:00", sdf.format(prayerTimes.isha))
    }

    @Test
    fun testDiyanetCopenhagenHighLatitudeMatchesExact() {
        // Copenhagen / Valby coordinates: 55.659, 12.518
        val coords = Coordinates(55.659, 12.518)
        val dc = DateComponents(2026, 9, 6)

        val params = CalculationParameters(18.0, 16.0).apply {
            adjustments.fajr = -1
            adjustments.sunrise = -7
            adjustments.dhuhr = 5
            adjustments.asr = 5
            adjustments.maghrib = 9
            adjustments.isha = 3
            highLatitudeRule = HighLatitudeRule.TWILIGHT_ANGLE
        }

        val prayerTimes = PrayerTimes(coords, dc, params)

        val sdf = SimpleDateFormat("HH:mm", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("Europe/Copenhagen")
        }

        // Official Diyanet published for Copenhagen on 06 September 2026:
        // İmsak: 04:04, Güneş: 06:17, Öğle: 13:13, İkindi: 16:49, Akşam: 20:00, Yatsı: 21:53
        assertEquals("04:04", sdf.format(prayerTimes.fajr))
        assertEquals("06:17", sdf.format(prayerTimes.sunrise))
        assertEquals("13:13", sdf.format(prayerTimes.dhuhr))
        assertEquals("16:49", sdf.format(prayerTimes.asr))
        assertEquals("20:00", sdf.format(prayerTimes.maghrib))
        assertEquals("21:53", sdf.format(prayerTimes.isha))
    }

    @Test
    fun testCalculatePrayerTimesMemoizationAndCacheLimit() {
        val tz = TimeZone.getTimeZone(istanbul.timezoneIdentifier)
        val cal = Calendar.getInstance(tz).apply {
            set(2026, Calendar.SEPTEMBER, 6, 12, 0, 0)
            set(Calendar.MILLISECOND, 0)
        }

        val firstCall = PrayerCalculator.calculatePrayerTimes(istanbul, cal.time, methodId = 13, schoolId = 0)
        val secondCall = PrayerCalculator.calculatePrayerTimes(istanbul, cal.time, methodId = 13, schoolId = 0)

        assertNotNull(firstCall)
        assertSame("Memoized cache should return the exact same Map instance", firstCall, secondCall)
        assertEquals(1, PrayerCalculator.getCacheSizeForTesting())

        // Fill cache beyond CACHE_LIMIT (12) and verify bounded size
        for (day in 1..15) {
            val dayCal = Calendar.getInstance(tz).apply {
                set(2026, Calendar.OCTOBER, day, 12, 0, 0)
            }
            PrayerCalculator.calculatePrayerTimes(istanbul, dayCal.time, methodId = 13, schoolId = 0)
            assertTrue("Cache size must not exceed 12", PrayerCalculator.getCacheSizeForTesting() <= 12)
        }

        PrayerCalculator.invalidateTimesCache()
        assertEquals(0, PrayerCalculator.getCacheSizeForTesting())
    }

    @Test
    fun testGetProgressInfoMiddayAndMidnightCrossings() {
        val tz = TimeZone.getTimeZone(istanbul.timezoneIdentifier)

        // 1. Midday on 2026-09-06 at 15:00 Istanbul time (between Dhuhr 13:08 and Asr 16:45)
        val middayCal = Calendar.getInstance(tz).apply {
            set(2026, Calendar.SEPTEMBER, 6, 15, 0, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val middayInfo = PrayerCalculator.getProgressInfo(istanbul, middayCal.time, methodId = 13, schoolId = 0)
        assertNotNull(middayInfo)
        assertEquals(PrayerType.DHUHR, middayInfo!!.currentPrayer)
        assertEquals(PrayerType.ASR, middayInfo.nextPrayer)
        assertTrue(middayInfo.timeRemaining > 0)
        assertTrue(middayInfo.progress in 0.01..0.99)

        // 2. Late night on 2026-09-06 at 22:30 Istanbul time (after Isha 21:00 -> next is tomorrow's Fajr)
        val lateNightCal = Calendar.getInstance(tz).apply {
            set(2026, Calendar.SEPTEMBER, 6, 22, 30, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val lateNightInfo = PrayerCalculator.getProgressInfo(istanbul, lateNightCal.time, methodId = 13, schoolId = 0)
        assertNotNull(lateNightInfo)
        assertEquals(PrayerType.ISHA, lateNightInfo!!.currentPrayer)
        assertEquals(PrayerType.FAJR, lateNightInfo.nextPrayer)
        assertTrue(lateNightInfo.timeRemaining > 0)

        // 3. Pre-dawn on 2026-09-06 at 03:30 Istanbul time (after yesterday's Isha -> before today's Fajr)
        val preDawnCal = Calendar.getInstance(tz).apply {
            set(2026, Calendar.SEPTEMBER, 6, 3, 30, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val preDawnInfo = PrayerCalculator.getProgressInfo(istanbul, preDawnCal.time, methodId = 13, schoolId = 0)
        assertNotNull(preDawnInfo)
        assertEquals(PrayerType.ISHA, preDawnInfo!!.currentPrayer)
        assertEquals(PrayerType.FAJR, preDawnInfo.nextPrayer)
        assertTrue(preDawnInfo.timeRemaining > 0)
    }

    @Test
    fun testHijriAndGregorianDateLocalization() {
        val tz = TimeZone.getTimeZone(istanbul.timezoneIdentifier)
        val cal = Calendar.getInstance(tz).apply {
            set(2026, Calendar.SEPTEMBER, 6, 12, 0, 0)
        }

        val hijriTr = PrayerCalculator.getHijriDateString(istanbul, cal.time, Locale("tr"))
        val hijriEn = PrayerCalculator.getHijriDateString(istanbul, cal.time, Locale.ENGLISH)
        val hijriAr = PrayerCalculator.getHijriDateString(istanbul, cal.time, Locale("ar"))

        assertTrue("Turkish Hijri date should not be empty", hijriTr.isNotEmpty())
        assertTrue("English Hijri date should not be empty", hijriEn.isNotEmpty())
        assertTrue("Arabic Hijri date should end with هـ", hijriAr.endsWith("هـ"))

        val gregorianEn = PrayerCalculator.getGregorianDateString(istanbul, cal.time, Locale.ENGLISH)
        assertTrue("Gregorian date should contain year 2026", gregorianEn.contains("2026"))
    }

    @Test
    fun testLocationDataAndGeocodingLanguageFallback() {
        val nearIstanbul = istanbul.copy(id = "loc-2", latitude = 41.0085, longitude = 28.9786)
        assertTrue(istanbul.isSameLocation(nearIstanbul))
        assertFalse(istanbul.isSameLocation(copenhagen))

        // Open-Meteo does not support Arabic ('ar') and must fall back to 'en'
        assertEquals("en", LocationManager.resolveGeocodingLanguage("ar"))
        assertEquals("tr", LocationManager.resolveGeocodingLanguage("tr"))
        assertEquals("de", LocationManager.resolveGeocodingLanguage("de"))
        assertEquals("fr", LocationManager.resolveGeocodingLanguage("fr"))
        assertEquals("en", LocationManager.resolveGeocodingLanguage("en"))

        assertTrue(CalculationMethodRegistry.methods.isNotEmpty())
        assertTrue(CalculationMethodRegistry.getMethodName(13).contains("Diyanet"))
    }
}
