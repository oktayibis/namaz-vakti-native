package com.oktay.namaz.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import com.oktay.namaz.service.PrayerType

// Color Tokens
val MidnightBg = Color(0xFF050514)
val SurfaceGlass = Color(0x14FFFFFF)
val BorderGlass = Color(0x1FFFFFFF)
val AmberAccent = Color(0xFFFEC343)
val TextPrimary = Color(0xFFFFFFFF)
val TextSecondary = Color(0xFF9CA3AF)

// Gradients
val FajrGradient = Brush.verticalGradient(listOf(Color(0xFF0A0F2D), Color(0xFFFD934C)))
val DhuhrGradient = Brush.verticalGradient(listOf(Color(0xFF2C77D8), Color(0xFF5A788C)))
val AsrGradient = Brush.verticalGradient(listOf(Color(0xFF225AB4), Color(0xFF788CA0)))
val MaghribGradient = Brush.verticalGradient(listOf(Color(0xFFDC444E), Color(0xFF320F46)))
val IshaGradient = Brush.verticalGradient(listOf(Color(0xFF050514), Color(0xFF192850)))

@Composable
fun getPrayerGradient(prayerType: PrayerType): Brush {
    return when (prayerType) {
        PrayerType.FAJR, PrayerType.SUNRISE -> FajrGradient
        PrayerType.DHUHR -> DhuhrGradient
        PrayerType.ASR -> AsrGradient
        PrayerType.MAGHRIB -> MaghribGradient
        PrayerType.ISHA -> IshaGradient
    }
}

private val DarkColorScheme = darkColorScheme(
    primary = AmberAccent,
    background = MidnightBg,
    surface = MidnightBg,
    onPrimary = Color.Black,
    onBackground = Color.White,
    onSurface = Color.White
)

@Composable
fun NamazVaktiTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = DarkColorScheme,
        content = content
    )
}
