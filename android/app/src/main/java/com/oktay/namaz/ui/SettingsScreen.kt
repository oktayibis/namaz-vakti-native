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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
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
    
    val alarmScheduler = remember { AlarmScheduler(context) }
    
    var enabledPrayers by remember { mutableStateOf(alarmScheduler.getEnabledPrayers()) }
    var reminderOffsets by remember { mutableStateOf(alarmScheduler.getReminderOffsets()) }
    
    var showOffsetDialog by remember { mutableStateOf(false) }
    var selectedOffsetIndex by remember { mutableStateOf(4) } // Default to 30 mins
    
    val offsetOptions = listOf(0, 5, 10, 15, 20, 30, 45, 60)
    
    var showMethodDialog by remember { mutableStateOf(false) }
    var showMadhabDialog by remember { mutableStateOf(false) }
    
    val calculationMethods = listOf(
        13 to "Türkiye (Diyanet)",
        3 to "Muslim World League (Dünya İslam Birliği)",
        2 to "ISNA (Kuzey Amerika)",
        4 to "Umm Al-Qura (Mekke)",
        5 to "Mısır Genel Araştırma Kurumu",
        1 to "Karaçi (İslami İlimler Üni.)"
    )
    
    val schools = listOf(
        1 to "Hanefi (Çift Gölge)",
        0 to "Şafii / Maliki / Hanbeli (Tek Gölge)"
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
                    text = "Bildirim Ayarları",
                    color = Color.White,
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Bold
                )
            },
            navigationIcon = {
                IconButton(onClick = onBack) {
                    Icon(
                        imageVector = Icons.Default.ArrowBack,
                        contentDescription = "Geri",
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
                            contentDescription = "Uyarı",
                            tint = Color.Red
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            text = "Bildirim İzni Devre Dışı",
                            color = Color.White,
                            fontWeight = FontWeight.Bold,
                            fontSize = 15.sp
                        )
                    }
                    Spacer(modifier = Modifier.height(6.dp))
                    Text(
                        text = "Namaz vakitlerinde hatırlatıcı alabilmek için lütfen bildirim izni verin.",
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
                        colors = ButtonDefaults.buttonColors(containerColor = AmberAccent),
                        shape = RoundedCornerShape(8.dp),
                        modifier = Modifier.height(36.dp)
                    ) {
                        Text("İzin Ver", color = Color.Black, fontWeight = FontWeight.Bold)
                    }
                }
            }
            
            // Prayers Selection Section
            Text(
                text = "Vakit Seçimi",
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
                val list = listOf(
                    PrayerType.FAJR to "imsak",
                    PrayerType.DHUHR to "dhuhr",
                    PrayerType.ASR to "asr",
                    PrayerType.MAGHRIB to "maghrib",
                    PrayerType.ISHA to "isha"
                )
                
                list.forEachIndexed { index, (prayer, _) ->
                    val isChecked = enabledPrayers.contains(prayer)
                    
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp, vertical = 10.dp)
                    ) {
                        Text(
                            text = prayer.turkishName,
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
            
            // Reminder Offsets Section
            Text(
                text = "Hatırlatıcı Zamanları",
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
                            text = if (offset == 0) "Namaz Vaktinde" else "$offset dakika önce",
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
                                contentDescription = "Sil",
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
                            contentDescription = "Ekle",
                            tint = AmberAccent
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            text = "Hatırlatıcı Ekle",
                            color = AmberAccent,
                            fontSize = 15.sp,
                            fontWeight = FontWeight.SemiBold
                        )
                    }
                }
            }
            
            // Calculation Parameters Section
            Text(
                text = "Hesaplama Ayarları",
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
                // 1. Calculation Method Row
                val currentMethodId = viewModel.getCalculationMethod()
                val methodName = calculationMethods.firstOrNull { it.first == currentMethodId }?.second ?: "Muslim World League"
                
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { showMethodDialog = true }
                        .padding(horizontal = 16.dp, vertical = 16.dp)
                ) {
                    Column {
                        Text(
                            text = "Hesaplama Metodu",
                            color = Color.White,
                            fontSize = 15.sp,
                            fontWeight = FontWeight.Medium
                        )
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = methodName,
                            color = AmberAccent,
                            fontSize = 13.sp
                        )
                    }
                }
                
                Divider(color = Color.White.copy(alpha = 0.1f))
                
                // 2. Asr Madhab Row
                val currentSchoolId = viewModel.getAsrMadhab()
                val schoolName = schools.firstOrNull { it.first == currentSchoolId }?.second ?: "Şafii / Maliki / Hanbeli"
                
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { showMadhabDialog = true }
                        .padding(horizontal = 16.dp, vertical = 16.dp)
                ) {
                    Column {
                        Text(
                            text = "İkindi Vakti Mezhebi",
                            color = Color.White,
                            fontSize = 15.sp,
                            fontWeight = FontWeight.Medium
                        )
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = schoolName,
                            color = AmberAccent,
                            fontSize = 13.sp
                        )
                    }
                }
            }
        }
    }
    
    // Add offset dialog
    if (showOffsetDialog) {
        AlertDialog(
            onDismissRequest = { showOffsetDialog = false },
            title = { Text("Hatırlatıcı Süresi Ekle", fontWeight = FontWeight.Bold) },
            text = {
                Column {
                    Text("Namaz vaktinden ne kadar önce hatırlatıcı almak istersiniz?", fontSize = 14.sp)
                    Spacer(modifier = Modifier.height(16.dp))
                    
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
                                text = if (option == 0) "Namaz Vaktinde" else "$option dakika önce",
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
                    Text("Ekle", color = AmberAccent)
                }
            },
            dismissButton = {
                TextButton(onClick = { showOffsetDialog = false }) {
                    Text("İptal", color = Color.White)
                }
            },
            containerColor = Color(0xFF1E1E2E)
        )
    }
    
    // Calculation Method dialog
    if (showMethodDialog) {
        AlertDialog(
            onDismissRequest = { showMethodDialog = false },
            title = { Text("Hesaplama Metodu Seçin", fontWeight = FontWeight.Bold) },
            text = {
                Column {
                    calculationMethods.forEach { (id, name) ->
                        val isSelected = viewModel.getCalculationMethod() == id
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable {
                                    viewModel.setCalculationMethod(id)
                                    showMethodDialog = false
                                }
                                .padding(vertical = 12.dp)
                        ) {
                            Text(
                                text = name,
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
                TextButton(onClick = { showMethodDialog = false }) {
                    Text("Kapat", color = Color.White)
                }
            },
            containerColor = Color(0xFF1E1E2E)
        )
    }
    
    // Asr Madhab dialog
    if (showMadhabDialog) {
        AlertDialog(
            onDismissRequest = { showMadhabDialog = false },
            title = { Text("İkindi Vakti Mezhebi Seçin", fontWeight = FontWeight.Bold) },
            text = {
                Column {
                    schools.forEach { (id, name) ->
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
                                text = name,
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
                    Text("Kapat", color = Color.White)
                }
            },
            containerColor = Color(0xFF1E1E2E)
        )
    }
}
