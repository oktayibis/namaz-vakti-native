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
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.oktay.namaz.ui.theme.BorderGlass
import com.oktay.namaz.ui.theme.SurfaceGlass

@Composable
fun CircularProgressView(
    progress: Double,
    timeRemaining: String,
    nextPrayerName: String,
    modifier: Modifier = Modifier,
    size: Dp = 250.dp
) {
    val animatedProgress by animateFloatAsState(
        targetValue = progress.toFloat(),
        animationSpec = tween(durationMillis = 800),
        label = "ProgressAnimation"
    )

    val strokeWidth = size.value * 0.096f
    val canvasSize = size * 0.84f
    val isCompact = size < 200.dp
    val percentValue = (minOf(maxOf(progress, 0.0), 1.0) * 100).toInt()
    val accessibleDescription = "$nextPrayerName, $timeRemaining, %$percentValue"

    Box(
        contentAlignment = Alignment.Center,
        modifier = modifier
            .size(size)
            .background(SurfaceGlass, shape = CircleShape)
            .border(1.5.dp, BorderGlass, shape = CircleShape)
            .semantics(mergeDescendants = true) {
                contentDescription = accessibleDescription
            }
    ) {
        // Draw track and progress ring
        Canvas(modifier = Modifier.size(canvasSize)) {
            // Track
            drawCircle(
                color = Color.White.copy(alpha = 0.15f),
                style = Stroke(width = strokeWidth)
            )

            // Progress Arc
            drawArc(
                color = Color.White,
                startAngle = -90f,
                sweepAngle = 360f * animatedProgress,
                useCenter = false,
                style = Stroke(width = strokeWidth, cap = StrokeCap.Round),
                size = Size(this.size.width, this.size.height)
            )
        }

        // Info Column
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier.padding(if (isCompact) 10.dp else 24.dp)
        ) {
            Text(
                text = nextPrayerName,
                fontSize = if (isCompact) 11.sp else 13.sp,
                fontWeight = FontWeight.Medium,
                color = Color.White.copy(alpha = 0.7f),
                textAlign = TextAlign.Center
            )

            Spacer(modifier = Modifier.height(if (isCompact) 2.dp else 4.dp))

            Text(
                text = timeRemaining,
                fontSize = if (isCompact) 22.sp else 34.sp,
                fontWeight = FontWeight.Bold,
                fontFamily = FontFamily.Monospace,
                color = Color.White,
                textAlign = TextAlign.Center
            )

            Spacer(modifier = Modifier.height(if (isCompact) 2.dp else 4.dp))

            val percent = (animatedProgress * 100).toInt()
            Text(
                text = "%$percent",
                fontSize = if (isCompact) 11.sp else 13.sp,
                fontWeight = FontWeight.Medium,
                color = Color.White.copy(alpha = 0.7f)
            )
        }
    }
}
