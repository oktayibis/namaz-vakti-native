package com.oktay.namaz

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.viewModels
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Surface
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.core.content.ContextCompat
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import com.oktay.namaz.service.NotificationSyncWorker
import com.oktay.namaz.ui.AppViewModel
import com.oktay.namaz.ui.HomeScreen
import com.oktay.namaz.ui.LocationScreen
import com.oktay.namaz.ui.SettingsScreen
import com.oktay.namaz.ui.OnboardingScreen
import com.oktay.namaz.ui.theme.MidnightBg
import com.oktay.namaz.ui.theme.NamazVaktiTheme
import java.util.concurrent.TimeUnit

class MainActivity : ComponentActivity() {

    private val viewModel: AppViewModel by viewModels()

    // Activity level permission launcher for Location. Onboarding needs the result to
    // land in detectedLocation (step 1 card -> step 2), not to be added directly.
    private val locationPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { permissions ->
        val fineGranted = permissions[Manifest.permission.ACCESS_FINE_LOCATION] ?: false
        val coarseGranted = permissions[Manifest.permission.ACCESS_COARSE_LOCATION] ?: false
        if (fineGranted || coarseGranted) {
            viewModel.detectLocationForOnboarding()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Enqueue background sync work to keep scheduled notifications fresh
        val syncWorkRequest = PeriodicWorkRequestBuilder<NotificationSyncWorker>(24, TimeUnit.HOURS).build()
        WorkManager.getInstance(applicationContext).enqueueUniquePeriodicWork(
            "NotificationSyncWork",
            ExistingPeriodicWorkPolicy.KEEP,
            syncWorkRequest
        )

        setContent {
            NamazVaktiTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MidnightBg
                ) {
                    val navController = rememberNavController()

                    // Tracks notification permission state
                    var hasNotificationPermission by remember {
                        mutableStateOf(
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                                ContextCompat.checkSelfPermission(
                                    this@MainActivity,
                                    Manifest.permission.POST_NOTIFICATIONS
                                ) == PackageManager.PERMISSION_GRANTED
                            } else {
                                true
                            }
                        )
                    }

                    // Notification permission launcher
                    val notificationPermissionLauncher = rememberLauncherForActivityResult(
                        contract = ActivityResultContracts.RequestPermission()
                    ) { isGranted ->
                        hasNotificationPermission = isGranted
                    }

                    // Onboarding or Home navigation coordinator
                    val startDest = remember {
                        if (viewModel.activeLocation.value == null) "onboarding" else "home"
                    }

                    NavHost(
                        navController = navController,
                        startDestination = startDest
                    ) {
                        composable("onboarding") {
                            OnboardingScreen(
                                viewModel = viewModel,
                                onRequestLocationPermission = {
                                    requestLocationPermissions()
                                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                                        notificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
                                    }
                                },
                                onFinishOnboarding = {
                                    navController.navigate("home") {
                                        popUpTo("onboarding") { inclusive = true }
                                    }
                                }
                            )
                        }
                        composable("home") {
                            HomeScreen(
                                viewModel = viewModel,
                                onOpenLocations = { navController.navigate("locations") },
                                onOpenSettings = { navController.navigate("settings") }
                            )
                        }
                        composable("locations") {
                            LocationScreen(
                                viewModel = viewModel,
                                onBack = { navController.popBackStack() }
                            )
                        }
                        composable("settings") {
                            SettingsScreen(
                                viewModel = viewModel,
                                onBack = { navController.popBackStack() },
                                hasNotificationPermission = hasNotificationPermission,
                                onRequestNotificationPermission = {
                                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                                        notificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
                                    }
                                }
                            )
                        }
                    }
                }
            }
        }
    }

    private fun requestLocationPermissions() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            locationPermissionLauncher.launch(
                arrayOf(
                    Manifest.permission.ACCESS_FINE_LOCATION,
                    Manifest.permission.ACCESS_COARSE_LOCATION
                )
            )
        } else {
            // Permission already granted: the launcher callback never fires, so start
            // detection directly or the button silently does nothing.
            viewModel.detectLocationForOnboarding()
        }
    }
}
