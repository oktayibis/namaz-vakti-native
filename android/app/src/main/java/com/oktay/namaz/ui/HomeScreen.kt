package com.oktay.namaz.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
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
    val activeLocation by viewModel.activeLocation.collectAsState()
    val todayTimes by viewModel.todayTimes.collectAsState()
    val progressInfo by viewModel.progressInfo.collectAsState()
    val timeRemaining by viewModel.timeRemainingString.collectAsState()
    val progress by viewModel.progress.collectAsState()
    val isDetectingLocation by viewModel.isDetectingLocation.collectAsState()
    
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

        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(bottom = 30.dp)
        ) {
            // Header
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(start = 16.dp, end = 16.dp, top = 40.dp)
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
                            contentDescription = "Konum",
                            tint = Color.White,
                            modifier = Modifier.size(16.dp)
                        )
                        Spacer(modifier = Modifier.width(6.dp))
                        Text(
                            text = activeLocation?.name ?: "Konum Seçin",
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
                        .size(40.dp)
                        .background(Color.White.copy(alpha = 0.12f), shape = CircleShape)
                ) {
                    Icon(
                        imageVector = Icons.Default.Settings,
                        contentDescription = "Ayarlar",
                        tint = Color.White
                    )
                }
            }

            Spacer(modifier = Modifier.height(24.dp))

            if (activeLocation == null) {
                // First Launch / No Location Selected
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 30.dp, vertical = 80.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.LocationOff,
                        contentDescription = "Konum Yok",
                        tint = Color.White.copy(alpha = 0.8f),
                        modifier = Modifier.size(80.dp)
                    )
                    Spacer(modifier = Modifier.height(20.dp))
                    Text(
                        text = "Namaz vakitlerini görüntülemek için lütfen bir konum ekleyin.",
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
                                    contentDescription = "Bul",
                                    tint = Color.Black
                                )
                                Spacer(modifier = Modifier.width(8.dp))
                                Text(
                                    text = "Mevcut Konumu Kullan",
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
                            text = "Şehir Arama",
                            color = Color.White,
                            fontWeight = FontWeight.Bold,
                            fontSize = 16.sp
                        )
                    }
                }
            } else {
                // Countdown ring
                progressInfo?.let { info ->
                    Box(
                        contentAlignment = Alignment.Center,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        CircularProgressView(
                            progress = progress,
                            timeRemaining = timeRemaining,
                            nextPrayerName = "${info.nextPrayer.turkishName} vaktine kalan"
                        )
                    }
                }

                Spacer(modifier = Modifier.height(24.dp))

                // Prayer List Card
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp)
                        .background(SurfaceGlass, shape = RoundedCornerShape(20.dp))
                        .border(1.5.dp, BorderGlass, shape = RoundedCornerShape(20.dp))
                ) {
                    Text(
                        text = "Bugün Vakitler",
                        color = Color.White.copy(alpha = 0.9f),
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Bold,
                        modifier = Modifier.padding(horizontal = 16.dp, vertical = 16.dp)
                    )
                    
                    Divider(color = Color.White.copy(alpha = 0.15f))
                    
                    todayTimes.forEach { item ->
                        val isActive = progressInfo?.currentPrayer == item.type
                        
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier
                                .fillMaxWidth()
                                .background(
                                    if (isActive) Color.White.copy(alpha = 0.14f) else Color.Transparent
                                )
                                .padding(horizontal = 16.dp, vertical = 16.dp)
                        ) {
                            Text(
                                text = item.type.turkishName,
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
                                    contentDescription = "Aktif",
                                    tint = AmberAccent,
                                    modifier = Modifier.size(10.dp)
                                )
                            }
                        }
                    }
                }
            }
        }
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
        
        Canvas(modifier = Modifier.fillMaxWidth().fillMaxHeight(0.35f)) {
            val width = size.width
            val height = size.height
            
            starPositions.forEach { (xPercent, yPercent) ->
                drawCircle(
                    color = Color.White.copy(alpha = (0.3f..0.8f).random()),
                    radius = (2f..5f).random(),
                    center = androidx.compose.ui.geometry.Offset(width * xPercent, height * yPercent)
                )
            }
        }
    }
}

// Helper utility for generating random numbers in ClosedRange
private fun ClosedRange<Float>.random() = (Math.random() * (endInclusive - start) + start).toFloat()
