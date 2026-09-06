package com.oktay.namaz.service

import com.batoulapps.adhan.CalculationParameters
import com.batoulapps.adhan.Coordinates
import com.batoulapps.adhan.HighLatitudeRule
import com.batoulapps.adhan.PrayerTimes
import com.batoulapps.adhan.data.DateComponents
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.TimeZone

class PrayerCalculatorTest {

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
}
