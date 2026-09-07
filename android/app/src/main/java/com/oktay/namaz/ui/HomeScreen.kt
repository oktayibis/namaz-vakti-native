package com.oktay.namaz.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.layout.displayCutoutPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBackIosNew
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.LocationOff
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.MyLocation
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Divider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import android.content.res.Configuration
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import com.oktay.namaz.model.LocationData
import kotlinx.coroutines.delay
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.oktay.namaz.R
import com.oktay.namaz.service.PrayerProgressInfo
import com.oktay.namaz.service.PrayerTimeItem
import com.oktay.namaz.service.PrayerType
import com.oktay.namaz.ui.components.CircularProgressView
import com.oktay.namaz.ui.theme.AmberAccent
import com.oktay.namaz.ui.theme.BorderGlass
import com.oktay.namaz.ui.theme.SurfaceGlass
import com.oktay.namaz.ui.theme.getPrayerGradient

@Composable
fun HomeScreen(
    viewModel: AppViewModel,
    onOpenLocations: () -> Unit,
    onOpenSettings: () -> Unit,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    val configuration = LocalConfiguration.current
    val isLandscapePhone = configuration.orientation == Configuration.ORIENTATION_LANDSCAPE && configuration.screenHeightDp < 500
    val isTablet = configuration.screenWidthDp >= 600 && !isLandscapePhone

    var currentTime by remember { mutableStateOf("") }
    LaunchedEffect(Unit) {
        val formatter = SimpleDateFormat("HH:mm:ss", Locale.getDefault())
        while (true) {
            currentTime = formatter.format(Date())
            delay(1000L)
        }
    }

    val activeLocation by viewModel.activeLocation.collectAsState()
    val todayTimes by viewModel.todayTimes.collectAsState()
    val progressInfo by viewModel.progressInfo.collectAsState()
    val timeRemaining by viewModel.timeRemainingString.collectAsState()
    val progress by viewModel.progress.collectAsState()
    val isDetectingLocation by viewModel.isDetectingLocation.collectAsState()
    val gregorianDate by viewModel.gregorianDateString.collectAsState()
    val hijriDate by viewModel.hijriDateString.collectAsState()

    val currentPrayerType = progressInfo?.currentPrayer ?: PrayerType.ISHA
    val bgBrush = getPrayerGradient(currentPrayerType)

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(bgBrush)
    ) {
        // Draw stars overlay if night or dawn
        if (currentPrayerType == PrayerType.ISHA || currentPrayerType == PrayerType.FAJR) {
            StarsOverlay()
        }

        if (activeLocation != null && isLandscapePhone) {
            // Dedicated StandBy / Desk Clock Mode for Phones in Landscape
            LandscapeDeskClockView(
                currentTime = currentTime,
                activeLocation = activeLocation,
                todayTimes = todayTimes,
                progressInfo = progressInfo,
                progress = progress,
                timeRemaining = timeRemaining,
                gregorianDate = gregorianDate,
                hijriDate = hijriDate,
                onOpenLocations = onOpenLocations,
                onOpenSettings = onOpenSettings
            )
        } else {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(bottom = 30.dp)
            ) {
                // Header (bounded to max-width on large screens)
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .widthIn(max = 1040.dp)
                        .fillMaxWidth()
                        .padding(start = 20.dp, end = 20.dp, top = 40.dp)
                ) {
                    // Location Switcher Trigger
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(20.dp))
                            .background(Color.White.copy(alpha = 0.12f))
                            .clickable { onOpenLocations() }
                            .padding(horizontal = 14.dp, vertical = 8.dp)
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(
                                imageVector = Icons.Default.LocationOn,
                                contentDescription = stringResource(R.string.select_location),
                                tint = Color.White,
                                modifier = Modifier.size(16.dp)
                            )
                            Spacer(modifier = Modifier.width(6.dp))
                            Text(
                                text = activeLocation?.name ?: stringResource(R.string.select_location),
                                fontSize = 14.sp,
                                fontWeight = FontWeight.SemiBold,
                                color = Color.White
                            )
                        }
                    }

                    Spacer(modifier = Modifier.weight(1f))

                    // Settings button
                    IconButton(
                        onClick = onOpenSettings,
                        modifier = Modifier
                            .background(Color.White.copy(alpha = 0.12f), shape = CircleShape)
                            .size(40.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.Settings,
                            contentDescription = stringResource(R.string.settings),
                            tint = Color.White,
                            modifier = Modifier.size(20.dp)
                        )
                    }
                }

                Spacer(modifier = Modifier.height(24.dp))

                if (activeLocation == null) {
                    // First Launch / No Location Selected (centered and max-width clamped)
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        modifier = Modifier
                            .widthIn(max = 480.dp)
                            .fillMaxWidth()
                            .padding(horizontal = 30.dp, vertical = 60.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.LocationOff,
                            contentDescription = stringResource(R.string.no_location_title),
                            tint = Color.White.copy(alpha = 0.8f),
                            modifier = Modifier.size(80.dp)
                        )
                        Spacer(modifier = Modifier.height(20.dp))
                        Text(
                            text = stringResource(R.string.no_location_desc),
                            fontSize = 15.sp,
                            color = Color.White.copy(alpha = 0.8f),
                            textAlign = androidx.compose.ui.text.style.TextAlign.Center
                        )
                        Spacer(modifier = Modifier.height(30.dp))
                        Button(
                            onClick = { viewModel.detectCurrentLocation() },
                            colors = ButtonDefaults.buttonColors(containerColor = Color.White),
                            shape = RoundedCornerShape(16.dp),
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(56.dp),
                            enabled = !isDetectingLocation
                        ) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                if (isDetectingLocation) {
                                    CircularProgressIndicator(
                                        color = Color.Black,
                                        modifier = Modifier.size(24.dp)
                                    )
                                } else {
                                    Icon(
                                        imageVector = Icons.Default.MyLocation,
                                        contentDescription = stringResource(R.string.detect_location),
                                        tint = Color.Black
                                    )
                                    Spacer(modifier = Modifier.width(8.dp))
                                    Text(
                                        text = stringResource(R.string.use_current_location),
                                        color = Color.Black,
                                        fontWeight = FontWeight.Bold,
                                        fontSize = 16.sp
                                    )
                                }
                            }
                        }
                        Spacer(modifier = Modifier.height(16.dp))
                        Button(
                            onClick = onOpenLocations,
                            colors = ButtonDefaults.buttonColors(containerColor = Color.White.copy(alpha = 0.15f)),
                            shape = RoundedCornerShape(16.dp),
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(56.dp)
                                .border(1.dp, Color.White.copy(alpha = 0.3f), RoundedCornerShape(16.dp))
                        ) {
                            Text(
                                text = stringResource(R.string.search_city),
                                color = Color.White,
                                fontWeight = FontWeight.Bold,
                                fontSize = 16.sp
                            )
                        }
                    }
                } else if (isTablet) {
                    // Adaptive Two-Column Dashboard for Tablets / Foldables
                    Row(
                        modifier = Modifier
                            .widthIn(max = 1040.dp)
                            .fillMaxWidth()
                            .padding(horizontal = 24.dp),
                        horizontalArrangement = Arrangement.spacedBy(32.dp),
                        verticalAlignment = Alignment.Top
                    ) {
                        // Left Column: Digital Clock + Hero Countdown Ring
                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally,
                            modifier = Modifier
                                .weight(1f)
                                .padding(top = 8.dp)
                        ) {
                            Text(
                                text = currentTime,
                                fontSize = 38.sp,
                                fontWeight = FontWeight.Bold,
                                fontFamily = FontFamily.Monospace,
                                color = Color.White
                            )
                            Spacer(modifier = Modifier.height(16.dp))

                            progressInfo?.let { info ->
                                val localizedPrayerName = info.nextPrayer.getLocalizedName(context)
                                CircularProgressView(
                                    progress = progress,
                                    timeRemaining = timeRemaining,
                                    nextPrayerName = stringResource(R.string.time_remaining_label, localizedPrayerName)
                                )
                            }
                        }

                        // Right Column: Prayer Schedule Card
                        Box(
                            modifier = Modifier.weight(1.15f)
                        ) {
                            PrayerTimesCard(
                                todayTimes = todayTimes,
                                progressInfo = progressInfo,
                                gregorianDate = gregorianDate,
                                hijriDate = hijriDate,
                                modifier = Modifier.fillMaxWidth()
                            )
                        }
                    }
                } else {
                    // Standard Single-Column Flow for Phones in Portrait
                    Text(
                        text = currentTime,
                        fontSize = 26.sp,
                        fontWeight = FontWeight.SemiBold,
                        fontFamily = FontFamily.Monospace,
                        color = Color.White.copy(alpha = 0.9f)
                    )
                    Spacer(modifier = Modifier.height(10.dp))

                    progressInfo?.let { info ->
                        Box(
                            contentAlignment = Alignment.Center,
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            val localizedPrayerName = info.nextPrayer.getLocalizedName(context)
                            CircularProgressView(
                                progress = progress,
                                timeRemaining = timeRemaining,
                                nextPrayerName = stringResource(R.string.time_remaining_label, localizedPrayerName)
                            )
                        }
                    }

                    Spacer(modifier = Modifier.height(24.dp))

                    PrayerTimesCard(
                        todayTimes = todayTimes,
                        progressInfo = progressInfo,
                        gregorianDate = gregorianDate,
                        hijriDate = hijriDate,
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp)
                    )
                }
            }
        }
    }
}

@Composable
private fun PrayerTimesCard(
    todayTimes: List<PrayerTimeItem>,
    progressInfo: PrayerProgressInfo?,
    gregorianDate: String,
    hijriDate: String,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current

    Column(
        modifier = modifier
            .background(SurfaceGlass, shape = RoundedCornerShape(20.dp))
            .border(1.5.dp, BorderGlass, shape = RoundedCornerShape(20.dp))
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 18.dp, vertical = 14.dp)
        ) {
            Column {
                Text(
                    text = stringResource(R.string.today_prayers),
                    color = Color.White.copy(alpha = 0.95f),
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold
                )
                if (gregorianDate.isNotEmpty()) {
                    Text(
                        text = gregorianDate,
                        color = Color.White.copy(alpha = 0.65f),
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Normal
                    )
                }
            }
            Spacer(modifier = Modifier.weight(1f))
            if (hijriDate.isNotEmpty()) {
                Text(
                    text = hijriDate,
                    color = AmberAccent.copy(alpha = 0.95f),
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Medium
                )
            }
        }

        Divider(color = Color.White.copy(alpha = 0.15f))

        for (item in todayTimes) {
            val isActive = progressInfo?.currentPrayer == item.type

            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier
                    .fillMaxWidth()
                    .background(
                        if (isActive) Color.White.copy(alpha = 0.14f) else Color.Transparent
                    )
                    .padding(horizontal = 18.dp, vertical = 15.dp)
            ) {
                Text(
                    text = item.type.getLocalizedName(context),
                    color = if (isActive) Color.White else Color.White.copy(alpha = 0.85f),
                    fontWeight = if (isActive) FontWeight.Bold else FontWeight.Normal,
                    fontSize = 15.sp
                )

                Spacer(modifier = Modifier.weight(1f))

                Text(
                    text = item.formattedTime,
                    color = if (isActive) Color.White else Color.White.copy(alpha = 0.85f),
                    fontWeight = if (isActive) FontWeight.Bold else FontWeight.Normal,
                    fontFamily = FontFamily.Monospace,
                    fontSize = 15.sp
                )

                if (isActive) {
                    Spacer(modifier = Modifier.width(6.dp))
                    Icon(
                        imageVector = Icons.Default.ArrowBackIosNew,
                        contentDescription = stringResource(R.string.active),
                        tint = AmberAccent,
                        modifier = Modifier.size(10.dp)
                    )
                }
            }
        }
    }
}

@Composable
private fun LandscapeDeskClockView(
    currentTime: String,
    activeLocation: LocationData?,
    todayTimes: List<PrayerTimeItem>,
    progressInfo: PrayerProgressInfo?,
    progress: Double,
    timeRemaining: String,
    gregorianDate: String,
    hijriDate: String,
    onOpenLocations: () -> Unit,
    onOpenSettings: () -> Unit,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current

    Column(
        modifier = modifier
            .fillMaxSize()
            .systemBarsPadding()
            .displayCutoutPadding()
            .padding(horizontal = 20.dp, vertical = 8.dp)
    ) {
        // Minimalist Top Bar
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.fillMaxWidth()
        ) {
            // Location Chip
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(16.dp))
                    .background(Color.White.copy(alpha = 0.12f))
                    .clickable { onOpenLocations() }
                    .padding(horizontal = 12.dp, vertical = 6.dp)
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(
                        imageVector = Icons.Default.LocationOn,
                        contentDescription = stringResource(R.string.select_location),
                        tint = AmberAccent,
                        modifier = Modifier.size(14.dp)
                    )
                    Spacer(modifier = Modifier.width(6.dp))
                    Text(
                        text = activeLocation?.name ?: stringResource(R.string.select_location),
                        fontSize = 13.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = Color.White
                    )
                }
            }

            Spacer(modifier = Modifier.weight(1f))

            if (hijriDate.isNotEmpty()) {
                Text(
                    text = hijriDate,
                    color = AmberAccent,
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Medium
                )
            }

            Spacer(modifier = Modifier.weight(1f))

            IconButton(
                onClick = onOpenSettings,
                modifier = Modifier
                    .size(36.dp)
                    .background(Color.White.copy(alpha = 0.12f), shape = CircleShape)
            ) {
                Icon(
                    imageVector = Icons.Default.Settings,
                    contentDescription = stringResource(R.string.settings),
                    tint = Color.White,
                    modifier = Modifier.size(18.dp)
                )
            }
        }

        Spacer(modifier = Modifier.weight(1f))

        // 3-Column Desk Clock Body
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.fillMaxWidth()
        ) {
            // Column 1: Live Digital Clock & Dates
            Column(
                modifier = Modifier
                    .weight(1f)
                    .padding(start = 8.dp)
            ) {
                Text(
                    text = currentTime,
                    fontSize = 42.sp,
                    fontWeight = FontWeight.Bold,
                    fontFamily = FontFamily.Monospace,
                    color = Color.White,
                    maxLines = 1
                )
                if (gregorianDate.isNotEmpty()) {
                    Text(
                        text = gregorianDate,
                        fontSize = 13.sp,
                        color = Color.White.copy(alpha = 0.8f),
                        fontWeight = FontWeight.Medium
                    )
                }
                Spacer(modifier = Modifier.height(8.dp))
                progressInfo?.let { info ->
                    val currentName = info.currentPrayer.getLocalizedName(context)
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier
                            .background(AmberAccent.copy(alpha = 0.15f), shape = RoundedCornerShape(12.dp))
                            .padding(horizontal = 10.dp, vertical = 4.dp)
                    ) {
                        Box(
                            modifier = Modifier
                                .size(8.dp)
                                .background(AmberAccent, shape = CircleShape)
                        )
                        Spacer(modifier = Modifier.width(6.dp))
                        Text(
                            text = currentName,
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Bold,
                            color = AmberAccent
                        )
                    }
                }
            }

            // Column 2: Compact Circular Progress
            Box(
                contentAlignment = Alignment.Center,
                modifier = Modifier.weight(0.9f)
            ) {
                progressInfo?.let { info ->
                    val localizedPrayerName = info.nextPrayer.getLocalizedName(context)
                    CircularProgressView(
                        progress = progress,
                        timeRemaining = timeRemaining,
                        nextPrayerName = stringResource(R.string.time_remaining_label, localizedPrayerName),
                        size = 155.dp
                    )
                }
            }

            // Column 3: 2x3 Grid of Mini Prayer Pills
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier
                    .weight(1.3f)
                    .padding(end = 8.dp)
            ) {
                val leftPrayers = todayTimes.take(3)
                val rightPrayers = todayTimes.drop(3).take(3)

                Column(
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                    modifier = Modifier.weight(1f)
                ) {
                    for (item in leftPrayers) {
                        MiniPrayerPill(
                            item = item,
                            isActive = progressInfo?.currentPrayer == item.type
                        )
                    }
                }

                Column(
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                    modifier = Modifier.weight(1f)
                ) {
                    for (item in rightPrayers) {
                        MiniPrayerPill(
                            item = item,
                            isActive = progressInfo?.currentPrayer == item.type
                        )
                    }
                }
            }
        }

        Spacer(modifier = Modifier.weight(1f))
    }
}

@Composable
private fun MiniPrayerPill(
    item: PrayerTimeItem,
    isActive: Boolean,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    val shape = RoundedCornerShape(8.dp)

    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = modifier
            .fillMaxWidth()
            .background(
                if (isActive) Color.White.copy(alpha = 0.18f) else Color.White.copy(alpha = 0.07f),
                shape = shape
            )
            .border(
                1.dp,
                if (isActive) AmberAccent.copy(alpha = 0.7f) else Color.White.copy(alpha = 0.08f),
                shape = shape
            )
            .padding(horizontal = 8.dp, vertical = 6.dp)
    ) {
        Text(
            text = item.type.getLocalizedName(context),
            fontSize = 11.sp,
            fontWeight = if (isActive) FontWeight.Bold else FontWeight.Normal,
            color = if (isActive) Color.White else Color.White.copy(alpha = 0.85f),
            maxLines = 1
        )
        Spacer(modifier = Modifier.weight(1f))
        Text(
            text = item.formattedTime,
            fontSize = 11.sp,
            fontWeight = if (isActive) FontWeight.Bold else FontWeight.Normal,
            fontFamily = FontFamily.Monospace,
            color = if (isActive) AmberAccent else Color.White.copy(alpha = 0.85f)
        )
    }
}

// Stars Overlay for Dark sky background in Android Compose
@Composable
fun StarsOverlay() {
    Box(modifier = Modifier.fillMaxSize()) {
        val starPositions = listOf(
            0.1f to 0.15f, 0.25f to 0.08f, 0.45f to 0.2f, 0.65f to 0.12f, 0.85f to 0.05f,
            0.05f to 0.25f, 0.18f to 0.28f, 0.35f to 0.14f, 0.55f to 0.25f, 0.72f to 0.18f,
            0.92f to 0.22f, 0.12f to 0.04f, 0.5f to 0.03f, 0.8f to 0.27f, 0.3f to 0.26f
        )
        Canvas(modifier = Modifier.fillMaxSize()) {
            val width = size.width
            val height = size.height
            starPositions.forEach { (relX, relY) ->
                drawCircle(
                    color = Color.White.copy(alpha = 0.5f),
                    radius = 2.dp.toPx(),
                    center = androidx.compose.ui.geometry.Offset(relX * width, relY * height)
                )
            }
        }
    }
}
