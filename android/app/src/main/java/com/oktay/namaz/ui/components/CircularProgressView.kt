package com.oktay.namaz.ui.components

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.oktay.namaz.ui.theme.BorderGlass
import com.oktay.namaz.ui.theme.SurfaceGlass

@Composable
fun CircularProgressView(
    progress: Double,
    timeRemaining: String,
    nextPrayerName: String,
    modifier: Modifier = Modifier
) {
    val animatedProgress by animateFloatAsState(
        targetValue = progress.toFloat(),
        animationSpec = tween(durationMillis = 800),
        label = "ProgressAnimation"
    )

    Box(
        contentAlignment = Alignment.Center,
        modifier = modifier
            .size(250.dp)
            .background(SurfaceGlass, shape = CircleShape)
            .border(1.5.dp, BorderGlass, shape = CircleShape)
    ) {
        // Draw track and progress ring
        Canvas(modifier = Modifier.size(210.dp)) {
            // Track
            drawCircle(
                color = Color.White.copy(alpha = 0.15f),
                style = Stroke(width = 24f)
            )

            // Progress Arc
            drawArc(
                color = Color.White,
                startAngle = -90f,
                sweepAngle = 360f * animatedProgress,
                useCenter = false,
                style = Stroke(width = 24f, cap = StrokeCap.Round),
                size = Size(size.width, size.height)
            )
        }

        // Info Column
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier.padding(24.dp)
        ) {
            Text(
                text = nextPrayerName,
                fontSize = 13.sp,
                fontWeight = FontWeight.Medium,
                color = Color.White.copy(alpha = 0.7f),
                textAlign = TextAlign.Center
            )
            
            Spacer(modifier = Modifier.height(6.dp))
            
            Text(
                text = timeRemaining,
                fontSize = 34.sp,
                fontWeight = FontWeight.Bold,
                fontFamily = FontFamily.Monospace,
                color = Color.White,
                textAlign = TextAlign.Center
            )
        }
    }
}
