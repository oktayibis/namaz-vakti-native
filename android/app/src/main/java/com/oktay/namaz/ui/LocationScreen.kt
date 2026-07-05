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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Map
import androidx.compose.material.icons.filled.MyLocation
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Divider
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.oktay.namaz.model.LocationData
import com.oktay.namaz.service.LocationManager
import com.oktay.namaz.ui.theme.AmberAccent
import com.oktay.namaz.ui.theme.MidnightBg
import kotlinx.coroutines.launch
import kotlinx.coroutines.delay

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LocationScreen(
    viewModel: AppViewModel,
    onBack: () -> Unit,
    modifier: Modifier = Modifier
) {
    val savedLocations by viewModel.savedLocations.collectAsState()
    val activeLocation by viewModel.activeLocation.collectAsState()
    val isDetectingLocation by viewModel.isDetectingLocation.collectAsState()

    var searchQuery by remember { mutableStateOf("") }
    var searchResults by remember { mutableStateOf<List<LocationData>>(emptyList()) }
    var isSearching by remember { mutableStateOf(false) }

    val coroutineScope = rememberCoroutineScope()
    val locationManager = remember { LocationManager(viewModel.getApplication()) }

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

    Column(
        modifier = modifier
            .fillMaxSize()
            .background(MidnightBg)
    ) {
        // App Bar
        TopAppBar(
            title = {
                Text(
                    text = "Konum Yönetimi",
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

        // Search Text Field
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
            trailingIcon = {
                if (searchQuery.isNotEmpty()) {
                    IconButton(onClick = { searchQuery = "" }) {
                        Icon(
                            imageVector = Icons.Default.Close,
                            contentDescription = "Temizle",
                            tint = Color.Gray
                        )
                    }
                }
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
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 8.dp)
        )

        if (isSearching) {
            Box(
                contentAlignment = Alignment.Center,
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f)
                    .padding(top = 40.dp)
            ) {
                CircularProgressIndicator(color = AmberAccent)
            }
        } else if (searchResults.isNotEmpty()) {
            // Search Results List
            LazyColumn(modifier = Modifier.weight(1f)) {
                items(searchResults) { location ->
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable {
                                viewModel.addLocation(location)
                                onBack()
                            }
                            .padding(horizontal = 16.dp, vertical = 14.dp)
                    ) {
                        Text(
                            text = location.name,
                            fontSize = 15.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = Color.White
                        )
                        Text(
                            text = location.country,
                            fontSize = 12.sp,
                            color = Color.Gray
                        )
                    }
                    Divider(color = Color.White.copy(alpha = 0.1f))
                }
            }
        } else {
            // Saved Locations List
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = "Kaydedilen Konumlar",
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color.Gray,
                    modifier = Modifier.padding(start = 16.dp, end = 16.dp, top = 16.dp, bottom = 8.dp)
                )

                LazyColumn {
                    // Use Current Location Button inside list
                    item {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable(enabled = !isDetectingLocation) {
                                    viewModel.detectCurrentLocation()
                                    onBack()
                                }
                                .padding(horizontal = 16.dp, vertical = 16.dp)
                        ) {
                            Icon(
                                imageVector = Icons.Default.MyLocation,
                                contentDescription = "Konum",
                                tint = AmberAccent
                            )
                            Spacer(modifier = Modifier.width(12.dp))
                            Text(
                                text = "Mevcut Konumu Kullan",
                                fontSize = 15.sp,
                                fontWeight = FontWeight.SemiBold,
                                color = Color.White
                            )
                            Spacer(modifier = Modifier.weight(1f))
                            if (isDetectingLocation) {
                                CircularProgressIndicator(
                                    color = Color.White,
                                    modifier = Modifier.size(20.dp)
                                )
                            }
                        }
                        Divider(color = Color.White.copy(alpha = 0.1f))
                    }

                    if (savedLocations.isEmpty()) {
                        item {
                            Column(
                                horizontalAlignment = Alignment.CenterHorizontally,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(vertical = 80.dp)
                            ) {
                                Icon(
                                    imageVector = Icons.Default.Map,
                                    contentDescription = "Boş",
                                    tint = Color.Gray,
                                    modifier = Modifier.size(40.dp)
                                )
                                Spacer(modifier = Modifier.height(16.dp))
                                Text(
                                    text = "Henüz kaydedilmiş bir konum yok.",
                                    color = Color.Gray,
                                    fontSize = 14.sp
                                )
                            }
                        }
                    } else {
                        items(savedLocations) { location ->
                            val isActive = activeLocation?.id == location.id
                            
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .background(
                                        if (isActive) Color.White.copy(alpha = 0.12f) else Color.White.copy(alpha = 0.05f)
                                    )
                                    .clickable {
                                        viewModel.selectLocation(location)
                                        onBack()
                                    }
                                    .padding(horizontal = 16.dp, vertical = 14.dp)
                            ) {
                                Column(modifier = Modifier.weight(1f)) {
                                    Text(
                                        text = location.name,
                                        fontSize = 15.sp,
                                        fontWeight = if (isActive) FontWeight.Bold else FontWeight.SemiBold,
                                        color = if (isActive) AmberAccent else Color.White
                                    )
                                    Text(
                                        text = location.country,
                                        fontSize = 12.sp,
                                        color = Color.Gray
                                    )
                                }
                                
                                if (isActive) {
                                    Icon(
                                        imageVector = Icons.Default.CheckCircle,
                                        contentDescription = "Seçili",
                                        tint = AmberAccent
                                    )
                                    Spacer(modifier = Modifier.width(16.dp))
                                }
                                
                                IconButton(onClick = { viewModel.removeLocation(location) }) {
                                    Icon(
                                        imageVector = Icons.Default.Delete,
                                        contentDescription = "Sil",
                                        tint = Color.Red.copy(alpha = 0.8f)
                                    )
                                }
                            }
                            Divider(color = Color.White.copy(alpha = 0.1f))
                        }
                    }
                }
            }
        }
    }
}
