package com.oktay.namaz.ui

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Language
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Divider
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.oktay.namaz.R
import com.oktay.namaz.model.CalculationMethodRegistry
import com.oktay.namaz.service.AlarmScheduler
import com.oktay.namaz.service.PrayerType
import com.oktay.namaz.ui.theme.AmberAccent
import com.oktay.namaz.ui.theme.MidnightBg
import com.oktay.namaz.ui.theme.SurfaceGlass

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    viewModel: AppViewModel,
    onBack: () -> Unit,
    hasNotificationPermission: Boolean,
    onRequestNotificationPermission: () -> Unit,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    val activeLocation by viewModel.activeLocation.collectAsState()
    val appLanguage by viewModel.appLanguage.collectAsState()
    
    val alarmScheduler = remember { AlarmScheduler(context) }
    
    var enabledPrayers by remember { mutableStateOf(alarmScheduler.getEnabledPrayers()) }
    var reminderOffsets by remember { mutableStateOf(alarmScheduler.getReminderOffsets()) }
    
    var showOffsetDialog by remember { mutableStateOf(false) }
    var selectedOffsetIndex by remember { mutableStateOf(4) } // Default to 30 mins
    val offsetOptions = listOf(0, 5, 10, 15, 20, 30, 45, 60)
    
    var showMethodDialog by remember { mutableStateOf(false) }
    var showMadhabDialog by remember { mutableStateOf(false) }
    var showLanguageDialog by remember { mutableStateOf(false) }

    val languages = listOf(
        "system" to stringResource(R.string.language_system),
        "tr" to stringResource(R.string.language_tr),
        "en" to stringResource(R.string.language_en),
        "de" to stringResource(R.string.language_de),
        "ar" to stringResource(R.string.language_ar),
        "fr" to stringResource(R.string.language_fr)
    )
    
    fun saveChanges() {
        alarmScheduler.setEnabledPrayers(enabledPrayers)
        alarmScheduler.setReminderOffsets(reminderOffsets)
        viewModel.rescheduleAlarms()
    }
    
    Column(
        modifier = modifier
            .fillMaxSize()
            .background(MidnightBg)
    ) {
        TopAppBar(
            title = {
                Text(
                    text = stringResource(R.string.settings),
                    color = Color.White,
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Bold
                )
            },
            navigationIcon = {
                IconButton(onClick = onBack) {
                    Icon(
                        imageVector = Icons.Default.ArrowBack,
                        contentDescription = stringResource(R.string.back_btn),
                        tint = Color.White
                    )
                }
            },
            colors = TopAppBarDefaults.topAppBarColors(containerColor = MidnightBg)
        )
        
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(bottom = 30.dp)
        ) {
            // Permission Warning Banner
            if (!hasNotificationPermission) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(16.dp)
                        .background(Color.Red.copy(alpha = 0.15f), shape = RoundedCornerShape(12.dp))
                        .padding(16.dp)
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(
                            imageVector = Icons.Default.Notifications,
                            contentDescription = stringResource(R.string.notifications),
                            tint = Color.Red
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            text = stringResource(R.string.notification_permission_required),
                            color = Color.White,
                            fontWeight = FontWeight.Bold,
                            fontSize = 15.sp
                        )
                    }
                    Spacer(modifier = Modifier.height(6.dp))
                    Text(
                        text = stringResource(R.string.notification_permission_desc),
                        color = Color.Gray,
                        fontSize = 13.sp
                    )
                    Spacer(modifier = Modifier.height(10.dp))
                    Button(
                        onClick = {
                            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
                                onRequestNotificationPermission()
                            } else {
                                val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                    data = Uri.fromParts("package", context.packageName, null)
                                }
                                context.startActivity(intent)
                            }
                        },
                        colors = ButtonDefaults.buttonColors(containerColor = Color.Red.copy(alpha = 0.8f)),
                        shape = RoundedCornerShape(8.dp)
                    ) {
                        Text(stringResource(R.string.open_settings), color = Color.White)
                    }
                }
            }
            
            // 1. Language Section
            Text(
                text = stringResource(R.string.app_language),
                color = Color.Gray,
                fontSize = 13.sp,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(start = 16.dp, end = 16.dp, top = 16.dp, bottom = 8.dp)
            )

            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp)
                    .background(SurfaceGlass, shape = RoundedCornerShape(12.dp))
            ) {
                val currentLangLabel = languages.firstOrNull { it.first == appLanguage }?.second ?: stringResource(R.string.language_system)
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { showLanguageDialog = true }
                        .padding(horizontal = 16.dp, vertical = 16.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.Language,
                        contentDescription = stringResource(R.string.app_language),
                        tint = AmberAccent,
                        modifier = Modifier.size(22.dp)
                    )
                    Spacer(modifier = Modifier.width(12.dp))
                    Column {
                        Text(
                            text = stringResource(R.string.app_language),
                            color = Color.White,
                            fontSize = 15.sp,
                            fontWeight = FontWeight.Medium
                        )
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = currentLangLabel,
                            color = AmberAccent,
                            fontSize = 13.sp
                        )
                    }
                }
            }

            // 2. Prayer Notifications Switch Section
            Text(
                text = stringResource(R.string.prayer_notifications),
                color = Color.Gray,
                fontSize = 13.sp,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(start = 16.dp, end = 16.dp, top = 24.dp, bottom = 8.dp)
            )
            
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp)
                    .background(SurfaceGlass, shape = RoundedCornerShape(12.dp))
            ) {
                val list = listOf(
                    PrayerType.FAJR,
                    PrayerType.DHUHR,
                    PrayerType.ASR,
                    PrayerType.MAGHRIB,
                    PrayerType.ISHA
                )
                
                list.forEachIndexed { index, prayer ->
                    val isChecked = enabledPrayers.contains(prayer)
                    
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp, vertical = 10.dp)
                    ) {
                        Text(
                            text = prayer.getLocalizedName(context),
                            color = Color.White,
                            fontSize = 15.sp,
                            fontWeight = FontWeight.Medium
                        )
                        
                        Spacer(modifier = Modifier.weight(1f))
                        
                        Switch(
                            checked = isChecked,
                            onCheckedChange = { isEnabled ->
                                enabledPrayers = if (isEnabled) {
                                    enabledPrayers + prayer
                                } else {
                                    enabledPrayers - prayer
                                }
                                saveChanges()
                            },
                            colors = SwitchDefaults.colors(
                                checkedThumbColor = Color.Black,
                                checkedTrackColor = AmberAccent
                            )
                        )
                    }
                    
                    if (index < list.size - 1) {
                        Divider(color = Color.White.copy(alpha = 0.1f))
                    }
                }
            }
            
            // 3. Reminder Timing Section
            Text(
                text = stringResource(R.string.notification_timing),
                color = Color.Gray,
                fontSize = 13.sp,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(start = 16.dp, end = 16.dp, top = 24.dp, bottom = 8.dp)
            )
            
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp)
                    .background(SurfaceGlass, shape = RoundedCornerShape(12.dp))
            ) {
                reminderOffsets.forEachIndexed { index, offset ->
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp, vertical = 12.dp)
                    ) {
                        Text(
                            text = if (offset == 0) stringResource(R.string.exact_time) else stringResource(R.string.mins_before, offset),
                            color = Color.White,
                            fontSize = 15.sp
                        )
                        
                        Spacer(modifier = Modifier.weight(1f))
                        
                        IconButton(onClick = {
                            reminderOffsets = reminderOffsets - offset
                            saveChanges()
                        }) {
                            Icon(
                                imageVector = Icons.Default.Delete,
                                contentDescription = stringResource(R.string.delete),
                                tint = Color.Red.copy(alpha = 0.8f)
                            )
                        }
                    }
                    
                    if (index < reminderOffsets.size - 1) {
                        Divider(color = Color.White.copy(alpha = 0.1f))
                    }
                }
                
                if (reminderOffsets.size < 3) {
                    Divider(color = Color.White.copy(alpha = 0.1f))
                    
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { showOffsetDialog = true }
                            .padding(horizontal = 16.dp, vertical = 16.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.Add,
                            contentDescription = stringResource(R.string.continue_btn),
                            tint = AmberAccent
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            text = stringResource(R.string.notification_timing),
                            color = AmberAccent,
                            fontSize = 15.sp,
                            fontWeight = FontWeight.SemiBold
                        )
                    }
                }
            }
            
            // 4. Calculation Parameters Section
            Text(
                text = stringResource(R.string.calculation_settings),
                color = Color.Gray,
                fontSize = 13.sp,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(start = 16.dp, end = 16.dp, top = 24.dp, bottom = 8.dp)
            )
            
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp)
                    .background(SurfaceGlass, shape = RoundedCornerShape(12.dp))
            ) {
                // Method Row
                val currentMethodId = viewModel.getCalculationMethod()
                val currentMethod = CalculationMethodRegistry.methods.firstOrNull { it.id == currentMethodId }
                    ?: CalculationMethodRegistry.methods.first { it.id == 3 }
                
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { showMethodDialog = true }
                        .padding(horizontal = 16.dp, vertical = 16.dp)
                ) {
                    Column {
                        Text(
                            text = stringResource(R.string.calculation_method),
                            color = Color.White,
                            fontSize = 15.sp,
                            fontWeight = FontWeight.Medium
                        )
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = "${currentMethod.name} — ${currentMethod.region}",
                            color = AmberAccent,
                            fontSize = 13.sp
                        )
                    }
                }

                Divider(color = Color.White.copy(alpha = 0.1f))

                // Asr Madhab Row
                val currentMadhabId = viewModel.getAsrMadhab()
                val madhabLabel = if (currentMadhabId == 1) stringResource(R.string.madhab_hanafi) else stringResource(R.string.madhab_standard)

                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { showMadhabDialog = true }
                        .padding(horizontal = 16.dp, vertical = 16.dp)
                ) {
                    Column {
                        Text(
                            text = stringResource(R.string.asr_madhab),
                            color = Color.White,
                            fontSize = 15.sp,
                            fontWeight = FontWeight.Medium
                        )
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = madhabLabel,
                            color = AmberAccent,
                            fontSize = 13.sp
                        )
                    }
                }
            }

            // 5. About & Privacy Section
            Text(
                text = stringResource(R.string.about),
                color = Color.Gray,
                fontSize = 13.sp,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(start = 16.dp, end = 16.dp, top = 24.dp, bottom = 8.dp)
            )

            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp)
                    .background(SurfaceGlass, shape = RoundedCornerShape(12.dp))
                    .padding(16.dp)
            ) {
                Text(
                    text = stringResource(R.string.app_name) + " v1.0",
                    color = Color.White,
                    fontSize = 15.sp,
                    fontWeight = FontWeight.Bold
                )
                Spacer(modifier = Modifier.height(6.dp))
                Text(
                    text = stringResource(R.string.about_desc),
                    color = Color.White.copy(alpha = 0.7f),
                    fontSize = 13.sp,
                    lineHeight = 18.sp
                )
            }
        }
    }
    
    // Dialog: App Language
    if (showLanguageDialog) {
        AlertDialog(
            onDismissRequest = { showLanguageDialog = false },
            title = { Text(stringResource(R.string.app_language), fontWeight = FontWeight.Bold) },
            text = {
                Column {
                    languages.forEach { (code, label) ->
                        val isSelected = appLanguage == code
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable {
                                    viewModel.setAppLanguage(code)
                                    showLanguageDialog = false
                                }
                                .padding(vertical = 12.dp)
                        ) {
                            Text(
                                text = label,
                                color = if (isSelected) AmberAccent else Color.White,
                                fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                                fontSize = 16.sp
                            )
                        }
                        Divider(color = Color.White.copy(alpha = 0.05f))
                    }
                }
            },
            confirmButton = {},
            dismissButton = {
                TextButton(onClick = { showLanguageDialog = false }) {
                    Text(stringResource(R.string.close), color = Color.White)
                }
            },
            containerColor = Color(0xFF1E1E2E)
        )
    }

    // Dialog: Add Offset
    if (showOffsetDialog) {
        AlertDialog(
            onDismissRequest = { showOffsetDialog = false },
            title = { Text(stringResource(R.string.notification_timing), fontWeight = FontWeight.Bold) },
            text = {
                Column {
                    offsetOptions.forEachIndexed { index, option ->
                        val isSelected = selectedOffsetIndex == index
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable { selectedOffsetIndex = index }
                                .padding(vertical = 10.dp)
                        ) {
                            Text(
                                text = if (option == 0) stringResource(R.string.exact_time) else stringResource(R.string.mins_before, option),
                                color = if (isSelected) AmberAccent else Color.White,
                                fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                                fontSize = 15.sp
                            )
                        }
                        if (index < offsetOptions.size - 1) {
                            Divider(color = Color.White.copy(alpha = 0.05f))
                        }
                    }
                }
            },
            confirmButton = {
                TextButton(onClick = {
                    val selected = offsetOptions[selectedOffsetIndex]
                    if (!reminderOffsets.contains(selected)) {
                        reminderOffsets = (reminderOffsets + selected).sortedDescending()
                        saveChanges()
                    }
                    showOffsetDialog = false
                }) {
                    Text(stringResource(R.string.continue_btn), color = AmberAccent)
                }
            },
            dismissButton = {
                TextButton(onClick = { showOffsetDialog = false }) {
                    Text(stringResource(R.string.cancel), color = Color.White)
                }
            },
            containerColor = Color(0xFF1E1E2E)
        )
    }
    
    // Dialog: Calculation Method
    if (showMethodDialog) {
        AlertDialog(
            onDismissRequest = { showMethodDialog = false },
            title = { Text(stringResource(R.string.calculation_method), fontWeight = FontWeight.Bold) },
            text = {
                Column(modifier = Modifier.verticalScroll(rememberScrollState())) {
                    CalculationMethodRegistry.methods.forEach { method ->
                        val isSelected = viewModel.getCalculationMethod() == method.id
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable {
                                    viewModel.setCalculationMethod(method.id)
                                    showMethodDialog = false
                                }
                                .padding(vertical = 12.dp)
                        ) {
                            Column {
                                Text(
                                    text = method.name,
                                    color = if (isSelected) AmberAccent else Color.White,
                                    fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                                    fontSize = 15.sp
                                )
                                Spacer(modifier = Modifier.height(2.dp))
                                Text(
                                    text = method.region,
                                    color = Color.Gray,
                                    fontSize = 12.sp
                                )
                            }
                        }
                        Divider(color = Color.White.copy(alpha = 0.05f))
                    }
                }
            },
            confirmButton = {},
            dismissButton = {
                TextButton(onClick = { showMethodDialog = false }) {
                    Text(stringResource(R.string.close), color = Color.White)
                }
            },
            containerColor = Color(0xFF1E1E2E)
        )
    }

    // Dialog: Asr Madhab
    if (showMadhabDialog) {
        AlertDialog(
            onDismissRequest = { showMadhabDialog = false },
            title = { Text(stringResource(R.string.asr_madhab), fontWeight = FontWeight.Bold) },
            text = {
                Column {
                    listOf(
                        0 to stringResource(R.string.madhab_standard),
                        1 to stringResource(R.string.madhab_hanafi)
                    ).forEach { (id, label) ->
                        val isSelected = viewModel.getAsrMadhab() == id
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable {
                                    viewModel.setAsrMadhab(id)
                                    showMadhabDialog = false
                                }
                                .padding(vertical = 12.dp)
                        ) {
                            Text(
                                text = label,
                                color = if (isSelected) AmberAccent else Color.White,
                                fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                                fontSize = 15.sp
                            )
                        }
                        Divider(color = Color.White.copy(alpha = 0.05f))
                    }
                }
            },
            confirmButton = {},
            dismissButton = {
                TextButton(onClick = { showMadhabDialog = false }) {
                    Text(stringResource(R.string.close), color = Color.White)
                }
            },
            containerColor = Color(0xFF1E1E2E)
        )
    }
}
