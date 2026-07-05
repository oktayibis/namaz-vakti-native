package com.oktay.namaz.ui

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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.MyLocation
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Divider
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.RadioButton
import androidx.compose.material3.RadioButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
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
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.oktay.namaz.model.LocationData
import com.oktay.namaz.service.LocationManager
import com.oktay.namaz.ui.theme.AmberAccent
import com.oktay.namaz.ui.theme.MidnightBg
import com.oktay.namaz.ui.theme.SurfaceGlass
import kotlinx.coroutines.delay

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun OnboardingScreen(
    viewModel: AppViewModel,
    onRequestLocationPermission: () -> Unit,
    onFinishOnboarding: () -> Unit,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    val isDetecting by viewModel.isDetectingLocation.collectAsState()
    val onboardingLoading by viewModel.onboardingLoading.collectAsState()
    val detectedLocation by viewModel.detectedLocation.collectAsState()
    
    var currentStep by remember { mutableStateOf(1) } // 1: Location, 2: Settings
    var searchQuery by remember { mutableStateOf("") }
    var searchResults by remember { mutableStateOf<List<LocationData>>(emptyList()) }
    var isSearching by remember { mutableStateOf(false) }
    
    val locationManager = remember { LocationManager(context) }
    
    // Calculation selections
    var selectedMethod by remember { mutableStateOf(13) } // Türkiye (Diyanet)
    var selectedSchool by remember { mutableStateOf(1) } // Hanafi
    
    val calculationMethods = listOf(
        13 to "Türkiye (Diyanet)",
        3 to "Muslim World League",
        2 to "ISNA (Kuzey Amerika)",
        4 to "Umm Al-Qura (Mekke)",
        5 to "Mısır Genel Araştırma",
        1 to "Karaçi (İslami İlimler)"
    )
    
    val schools = listOf(
        1 to "Hanefi (Çift Gölge)",
        0 to "Şafii / Maliki / Hanbeli"
    )
    
    // When location is detected, auto-preselect parameters
    LaunchedEffect(detectedLocation) {
        detectedLocation?.let {
            val defaults = viewModel.determineDefaultParameters(it)
            selectedMethod = defaults.first
            selectedSchool = defaults.second
        }
    }
    
    // Search query listener with debounce
    LaunchedEffect(searchQuery) {
        if (searchQuery.length >= 2) {
            delay(300)
            isSearching = true
            searchResults = locationManager.searchCity(searchQuery)
            isSearching = false
        } else {
            searchResults = emptyList()
        }
    }
    
    Box(
        modifier = modifier
            .fillMaxSize()
            .background(MidnightBg)
    ) {
        if (onboardingLoading) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier
                    .align(Alignment.Center)
                    .padding(32.dp)
            ) {
                CircularProgressIndicator(color = AmberAccent, modifier = Modifier.size(50.dp))
                Spacer(modifier = Modifier.height(16.dp))
                Text(
                    text = "Namaz takvimi hazırlanıyor...\nTüm yıl çevrimdışı kullanım için indiriliyor.",
                    color = Color.White,
                    fontSize = 15.sp,
                    fontWeight = FontWeight.Medium,
                    textAlign = TextAlign.Center
                )
            }
        } else {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(24.dp)
            ) {
                // Header progress
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 16.dp, bottom = 24.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = "Kurulum Sihirbazı",
                        color = Color.White,
                        fontSize = 18.sp,
                        fontWeight = FontWeight.Bold
                    )
                    Spacer(modifier = Modifier.weight(1f))
                    Text(
                        text = "$currentStep / 2",
                        color = AmberAccent,
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Bold
                    )
                }
                
                if (currentStep == 1) {
                    // Step 1: Location Setup
                    Text(
                        text = "Namaz vakitlerini hesaplamak için bir konum seçin.",
                        color = Color.Gray,
                        fontSize = 15.sp,
                        modifier = Modifier.padding(bottom = 20.dp)
                    )
                    
                    if (detectedLocation != null) {
                        // Display selected location card
                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .background(SurfaceGlass, shape = RoundedCornerShape(12.dp))
                                .padding(16.dp)
                        ) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Icon(
                                    imageVector = Icons.Default.LocationOn,
                                    contentDescription = "Konum",
                                    tint = AmberAccent,
                                    modifier = Modifier.size(28.dp)
                                )
                                Spacer(modifier = Modifier.width(12.dp))
                                Column {
                                    Text(
                                        text = detectedLocation!!.name,
                                        color = Color.White,
                                        fontSize = 18.sp,
                                        fontWeight = FontWeight.Bold
                                    )
                                    Text(
                                        text = detectedLocation!!.country,
                                        color = Color.Gray,
                                        fontSize = 14.sp
                                    )
                                }
                                Spacer(modifier = Modifier.weight(1f))
                                IconButton(onClick = { viewModel.setDetectedLocation(null) }) {
                                    Icon(
                                        imageVector = Icons.Default.Close,
                                        contentDescription = "Değiştir",
                                        tint = Color.Gray
                                    )
                                }
                            }
                        }
                        
                        Spacer(modifier = Modifier.weight(1f))
                        
                        Button(
                            onClick = { currentStep = 2 },
                            colors = ButtonDefaults.buttonColors(containerColor = AmberAccent),
                            shape = RoundedCornerShape(12.dp),
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(50.dp)
                        ) {
                            Text("Devam Et", color = Color.Black, fontWeight = FontWeight.Bold, fontSize = 16.sp)
                        }
                    } else {
                        // GPS Request Button
                        Button(
                            onClick = onRequestLocationPermission,
                            colors = ButtonDefaults.buttonColors(containerColor = Color.White),
                            shape = RoundedCornerShape(12.dp),
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(50.dp)
                        ) {
                            if (isDetecting) {
                                CircularProgressIndicator(color = Color.Black, modifier = Modifier.size(24.dp))
                            } else {
                                Icon(
                                    imageVector = Icons.Default.MyLocation,
                                    contentDescription = "GPS",
                                    tint = Color.Black
                                )
                                Spacer(modifier = Modifier.width(8.dp))
                                Text("Konumumu Otomatik Bul", color = Color.Black, fontWeight = FontWeight.Bold)
                            }
                        }
                        
                        Spacer(modifier = Modifier.height(16.dp))
                        
                        Text(
                            text = "veya şehir arayın:",
                            color = Color.Gray,
                            fontSize = 14.sp,
                            modifier = Modifier.align(Alignment.CenterHorizontally)
                        )
                        
                        Spacer(modifier = Modifier.height(12.dp))
                        
                        // Manual search field
                        OutlinedTextField(
                            value = searchQuery,
                            onValueChange = { searchQuery = it },
                            placeholder = { Text("Şehir Ara...", color = Color.Gray) },
                            leadingIcon = {
                                Icon(
                                    imageVector = Icons.Default.Search,
                                    contentDescription = "Ara",
                                    tint = Color.Gray
                                )
                            },
                            singleLine = true,
                            colors = OutlinedTextFieldDefaults.colors(
                                focusedTextColor = Color.White,
                                unfocusedTextColor = Color.White,
                                focusedBorderColor = AmberAccent,
                                unfocusedBorderColor = Color.White.copy(alpha = 0.2f),
                                focusedContainerColor = Color.White.copy(alpha = 0.05f),
                                unfocusedContainerColor = Color.White.copy(alpha = 0.05f)
                            ),
                            modifier = Modifier.fillMaxWidth()
                        )
                        
                        Spacer(modifier = Modifier.height(16.dp))
                        
                        if (isSearching) {
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .weight(1f)
                                    .padding(top = 20.dp),
                                contentAlignment = Alignment.Center
                            ) {
                                CircularProgressIndicator(color = AmberAccent)
                            }
                        } else {
                            LazyColumn(modifier = Modifier.weight(1f)) {
                                items(searchResults) { location ->
                                    Row(
                                        verticalAlignment = Alignment.CenterVertically,
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .clickable { viewModel.setDetectedLocation(location) }
                                            .padding(vertical = 12.dp, horizontal = 4.dp)
                                    ) {
                                        Icon(
                                            imageVector = Icons.Default.LocationOn,
                                            contentDescription = "Şehir",
                                            tint = Color.Gray,
                                            modifier = Modifier.size(20.dp)
                                        )
                                        Spacer(modifier = Modifier.width(8.dp))
                                        Column {
                                            Text(location.name, color = Color.White, fontSize = 15.sp)
                                            Text(location.country, color = Color.Gray, fontSize = 12.sp)
                                        }
                                    }
                                    Divider(color = Color.White.copy(alpha = 0.05f))
                                }
                            }
                        }
                    }
                } else {
                    // Step 2: Settings Configuration
                    Column(
                        modifier = Modifier
                            .weight(1f)
                            .verticalScroll(rememberScrollState())
                    ) {
                        Text(
                            text = "Konumunuza göre varsayılan hesaplama ayarları seçildi. Değiştirmek isterseniz düzenleyin:",
                            color = Color.Gray,
                            fontSize = 15.sp,
                            modifier = Modifier.padding(bottom = 20.dp)
                        )
                        
                        Text(
                            text = "Hesaplama Metodu (Kaynak)",
                            color = Color.White,
                            fontWeight = FontWeight.Bold,
                            fontSize = 15.sp,
                            modifier = Modifier.padding(bottom = 8.dp)
                        )
                        
                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .background(SurfaceGlass, shape = RoundedCornerShape(12.dp))
                                .padding(8.dp)
                        ) {
                            calculationMethods.forEach { (id, name) ->
                                val isSelected = selectedMethod == id
                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .clickable { selectedMethod = id }
                                        .padding(horizontal = 12.dp, vertical = 10.dp)
                                ) {
                                    RadioButton(
                                        selected = isSelected,
                                        onClick = { selectedMethod = id },
                                        colors = RadioButtonDefaults.colors(
                                            selectedColor = AmberAccent,
                                            unselectedColor = Color.Gray
                                        )
                                    )
                                    Spacer(modifier = Modifier.width(8.dp))
                                    Text(text = name, color = Color.White, fontSize = 14.sp)
                                }
                            }
                        }
                        
                        Spacer(modifier = Modifier.height(24.dp))
                        
                        Text(
                            text = "İkindi Mezhebi",
                            color = Color.White,
                            fontWeight = FontWeight.Bold,
                            fontSize = 15.sp,
                            modifier = Modifier.padding(bottom = 8.dp)
                        )
                        
                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .background(SurfaceGlass, shape = RoundedCornerShape(12.dp))
                                .padding(8.dp)
                        ) {
                            schools.forEach { (id, name) ->
                                val isSelected = selectedSchool == id
                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .clickable { selectedSchool = id }
                                        .padding(horizontal = 12.dp, vertical = 10.dp)
                                ) {
                                    RadioButton(
                                        selected = isSelected,
                                        onClick = { selectedSchool = id },
                                        colors = RadioButtonDefaults.colors(
                                            selectedColor = AmberAccent,
                                            unselectedColor = Color.Gray
                                        )
                                    )
                                    Spacer(modifier = Modifier.width(8.dp))
                                    Text(text = name, color = Color.White, fontSize = 14.sp)
                                }
                            }
                        }
                        
                        Spacer(modifier = Modifier.height(30.dp))
                    }
                    
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(top = 16.dp)
                    ) {
                        TextButton(
                            onClick = { currentStep = 1 },
                            modifier = Modifier.height(50.dp)
                        ) {
                            Text("Geri", color = Color.White, fontWeight = FontWeight.Bold)
                        }
                        Spacer(modifier = Modifier.width(16.dp))
                        Button(
                            onClick = {
                                detectedLocation?.let { loc ->
                                    viewModel.completeOnboarding(
                                        location = loc,
                                        methodId = selectedMethod,
                                        schoolId = selectedSchool,
                                        onComplete = onFinishOnboarding
                                    )
                                }
                            },
                            colors = ButtonDefaults.buttonColors(containerColor = AmberAccent),
                            shape = RoundedCornerShape(12.dp),
                            modifier = Modifier
                                .weight(1f)
                                .height(50.dp)
                        ) {
                            Text("Başlayalım", color = Color.Black, fontWeight = FontWeight.Bold, fontSize = 16.sp)
                        }
                    }
                }
            }
        }
    }
}
