package com.oktay.namaz.ui

import android.app.Application
import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import com.oktay.namaz.model.LocationData
import com.oktay.namaz.service.AlarmScheduler
import com.oktay.namaz.service.LocationManager
import com.oktay.namaz.service.PrayerCalculator
import com.oktay.namaz.service.PrayerProgressInfo
import com.oktay.namaz.service.PrayerTimeItem
import com.oktay.namaz.service.PrayerType
import com.oktay.namaz.widget.PrayerAppWidget
import android.os.Build
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.util.Calendar
import java.util.Date

@OptIn(ExperimentalCoroutinesApi::class)
class AppViewModel(application: Application) : AndroidViewModel(application) {

    private val context = application.applicationContext
    private val prefs = context.getSharedPreferences("namaz_prefs", Context.MODE_PRIVATE)
    private val gson = Gson()
    private val locationManager = LocationManager(context)
    private val alarmScheduler = AlarmScheduler(context)

    private val locationsKey = "saved_locations"
    private val activeLocationIdKey = "active_location_id"

    private val _savedLocations = MutableStateFlow<List<LocationData>>(emptyList())
    val savedLocations: StateFlow<List<LocationData>> = _savedLocations.asStateFlow()

    private val _activeLocation = MutableStateFlow<LocationData?>(null)
    val activeLocation: StateFlow<LocationData?> = _activeLocation.asStateFlow()

    private val _todayTimes = MutableStateFlow<List<PrayerTimeItem>>(emptyList())
    val todayTimes: StateFlow<List<PrayerTimeItem>> = _todayTimes.asStateFlow()

    private val _progressInfo = MutableStateFlow<PrayerProgressInfo?>(null)
    val progressInfo: StateFlow<PrayerProgressInfo?> = _progressInfo.asStateFlow()

    private val _timeRemainingString = MutableStateFlow("00:00:00")
    val timeRemainingString: StateFlow<String> = _timeRemainingString.asStateFlow()

    private val _progress = MutableStateFlow(0.0)
    val progress: StateFlow<Double> = _progress.asStateFlow()

    private val _isDetectingLocation = MutableStateFlow(false)
    val isDetectingLocation: StateFlow<Boolean> = _isDetectingLocation.asStateFlow()

    private val _showFirstLaunchLocationRequest = MutableStateFlow(false)
    val showFirstLaunchLocationRequest: StateFlow<Boolean> = _showFirstLaunchLocationRequest.asStateFlow()

    private val _onboardingLoading = MutableStateFlow(false)
    val onboardingLoading: StateFlow<Boolean> = _onboardingLoading.asStateFlow()

    private val _detectedLocation = MutableStateFlow<LocationData?>(null)
    val detectedLocation: StateFlow<LocationData?> = _detectedLocation.asStateFlow()

    private var timerJob: Job? = null

    // Prayer-time math reads/parses the annual calendar cache and talks to
    // AlarmManager; run all of it serially off the main thread so taps and
    // recompositions never wait on it.
    private val workDispatcher = Dispatchers.Default.limitedParallelism(1)

    private val cacheReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == "com.oktay.namaz.ACTION_CACHE_UPDATED") {
                updateTimes()
                saveLocations()
            }
        }
    }

    init {
        loadData()
        startTimer()
        
        // Register receiver for background cache updates
        val filter = IntentFilter("com.oktay.namaz.ACTION_CACHE_UPDATED")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(cacheReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            context.registerReceiver(cacheReceiver, filter)
        }
    }

    override fun onCleared() {
        super.onCleared()
        try {
            context.unregisterReceiver(cacheReceiver)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    fun loadData() {
        // Load saved locations
        val locationsJson = prefs.getString(locationsKey, null)
        if (locationsJson != null) {
            try {
                val type = object : TypeToken<List<LocationData>>() {}.type
                _savedLocations.value = gson.fromJson(locationsJson, type) ?: emptyList()
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        // Load active location
        val activeId = prefs.getString(activeLocationIdKey, null)
        if (activeId != null) {
            _activeLocation.value = _savedLocations.value.firstOrNull { it.id == activeId }
        }

        // Fallback to first if active location is not found
        if (_activeLocation.value == null && _savedLocations.value.isNotEmpty()) {
            _activeLocation.value = _savedLocations.value.first()
            prefs.edit().putString(activeLocationIdKey, _activeLocation.value?.id).apply()
        }

        if (_activeLocation.value == null) {
            _showFirstLaunchLocationRequest.value = true
        } else {
            updateTimes()
        }
    }

    private fun saveLocations() {
        viewModelScope.launch(workDispatcher) { saveLocationsNow() }
    }

    private fun saveLocationsNow() {
        prefs.edit().putString(locationsKey, gson.toJson(_savedLocations.value)).apply()

        // Trigger AppWidget update; the widget computes its own times from saved state
        val intent = Intent(context, PrayerAppWidget::class.java).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            val ids = AppWidgetManager.getInstance(context).getAppWidgetIds(
                ComponentName(context, PrayerAppWidget::class.java)
            )
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
        }
        context.sendBroadcast(intent)
    }

    fun selectLocation(location: LocationData) {
        _activeLocation.value = location
        prefs.edit().putString(activeLocationIdKey, location.id).apply()
        updateTimes()
        saveLocations()

        // Reschedule alarms
        viewModelScope.launch(workDispatcher) {
            alarmScheduler.scheduleAlarms(location)
        }
    }

    fun addLocation(location: LocationData) {
        val existing = _savedLocations.value.firstOrNull { it.isSameLocation(location) }
        if (existing != null) {
            selectLocation(existing)
            return
        }

        val updated = _savedLocations.value.toMutableList().apply { add(location) }
        _savedLocations.value = updated
        selectLocation(location)
    }

    fun removeLocation(location: LocationData) {
        val activeIdBefore = _activeLocation.value?.id
        val updated = _savedLocations.value.toMutableList().apply { remove(location) }
        _savedLocations.value = updated

        if (updated.isEmpty()) {
            _activeLocation.value = null
            prefs.edit().remove(activeLocationIdKey).apply()
            saveLocations()
        } else if (activeIdBefore != null && activeIdBefore == location.id) {
            // Select first remaining
            selectLocation(updated.first())
        } else {
            saveLocations()
        }
    }

    fun detectLocationForOnboarding() {
        _isDetectingLocation.value = true
        viewModelScope.launch {
            val location = locationManager.getCurrentLocation()
            _isDetectingLocation.value = false
            if (location != null) {
                _detectedLocation.value = location
            }
        }
    }

    fun setDetectedLocation(location: LocationData?) {
        _detectedLocation.value = location
    }

    fun detectCurrentLocation() {
        _isDetectingLocation.value = true
        viewModelScope.launch {
            val location = locationManager.getCurrentLocation()
            _isDetectingLocation.value = false
            if (location != null) {
                val defaults = determineDefaultParameters(location)
                if (!prefs.contains("calculation_method")) {
                    prefs.edit().putInt("calculation_method", defaults.first).apply()
                }
                if (!prefs.contains("asr_madhab")) {
                    prefs.edit().putInt("asr_madhab", defaults.second).apply()
                }
                addLocation(location)
                _showFirstLaunchLocationRequest.value = false
            }
        }
    }

    fun determineDefaultParameters(location: LocationData): Pair<Int, Int> {
        val countryLower = location.country.lowercase()
        val defaultMethod = when {
            countryLower.contains("turkey") || countryLower.contains("türkiye") -> 13 // Diyanet
            countryLower.contains("saudi") || countryLower.contains("arabia") || countryLower.contains("makkah") -> 4 // Umm Al-Qura
            countryLower.contains("egypt") -> 5 // Egyptian General Authority
            countryLower.contains("pakistan") || countryLower.contains("india") || countryLower.contains("bangladesh") -> 1 // Karachi
            countryLower.contains("united states") || countryLower.contains("canada") || countryLower.contains("america") -> 2 // ISNA
            else -> 3 // Muslim World League
        }
        
        val defaultSchool = when {
            countryLower.contains("turkey") || countryLower.contains("türkiye") ||
            countryLower.contains("pakistan") || countryLower.contains("india") || countryLower.contains("bangladesh") -> 1 // Hanafi
            else -> 0 // Shafi/Standard
        }
        return Pair(defaultMethod, defaultSchool)
    }

    fun completeOnboarding(
        location: LocationData,
        methodId: Int,
        schoolId: Int,
        onComplete: () -> Unit
    ) {
        _onboardingLoading.value = true
        viewModelScope.launch {
            prefs.edit()
                .putInt("calculation_method", methodId)
                .putInt("asr_madhab", schoolId)
                .apply()
            
            // Clear any old cache files
            PrayerCalculator.clearCache(context)
            
            // Attempt to pre-fetch the annual calendar
            val currentYear = Calendar.getInstance().get(Calendar.YEAR)
            PrayerCalculator.fetchYearCalendar(context, location, currentYear)
            
            _onboardingLoading.value = false
            
            // Add location and complete onboarding even if offline fetch fails,
            // fallback mathematical calculations will be used.
            addLocation(location)
            _showFirstLaunchLocationRequest.value = false
            onComplete()
        }
    }

    fun getCalculationMethod(): Int {
        return prefs.getInt("calculation_method", 13)
    }

    fun setCalculationMethod(methodId: Int) {
        prefs.edit().putInt("calculation_method", methodId).apply()
        PrayerCalculator.clearCache(context)
        updateTimes()
        activeLocation.value?.let {
            viewModelScope.launch(workDispatcher) { alarmScheduler.scheduleAlarms(it) }
        }
        saveLocations()
    }

    fun getAsrMadhab(): Int {
        return prefs.getInt("asr_madhab", 1)
    }

    fun setAsrMadhab(schoolId: Int) {
        prefs.edit().putInt("asr_madhab", schoolId).apply()
        PrayerCalculator.clearCache(context)
        updateTimes()
        activeLocation.value?.let {
            viewModelScope.launch(workDispatcher) { alarmScheduler.scheduleAlarms(it) }
        }
        saveLocations()
    }

    fun rescheduleAlarms() {
        val active = _activeLocation.value ?: return
        viewModelScope.launch(workDispatcher) { alarmScheduler.scheduleAlarms(active) }
    }

    fun updateTimes() {
        val active = _activeLocation.value ?: return

        viewModelScope.launch(workDispatcher) {
            _todayTimes.value = PrayerCalculator.getPrayerTimesList(context, active, Date())
            _progressInfo.value = PrayerCalculator.getProgressInfo(context, active)

            updateTimerTick()
        }
    }

    private fun startTimer() {
        timerJob?.cancel()
        timerJob = viewModelScope.launch(workDispatcher) {
            while (true) {
                updateTimerTick()
                delay(1000)
            }
        }
    }

    private fun updateTimerTick() {
        val active = _activeLocation.value ?: return
        val info = PrayerCalculator.getProgressInfo(context, active) ?: return
        
        _progressInfo.value = info
        _progress.value = info.progress
        
        val hours = info.timeRemaining / 3600000
        val minutes = (info.timeRemaining % 3600000) / 60000
        val seconds = (info.timeRemaining % 60000) / 1000
        _timeRemainingString.value = String.format("%02d:%02d:%02d", hours, minutes, seconds)
    }
}
