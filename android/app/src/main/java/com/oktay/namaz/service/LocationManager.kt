package com.oktay.namaz.service

import android.annotation.SuppressLint
import android.content.Context
import android.location.Geocoder
import android.location.Location
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.gson.Gson
import com.oktay.namaz.model.LocationData
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.util.Locale
import java.util.TimeZone

class LocationManager(private val context: Context) {

    private val fusedLocationClient = LocationServices.getFusedLocationProviderClient(context)
    private val geocoder = Geocoder(context, Locale.getDefault())
    private val gson = Gson()

    @SuppressLint("MissingPermission")
    suspend fun getCurrentLocation(): LocationData? = withContext(Dispatchers.IO) {
        try {
            // Request location from FusedLocationClient
            val location: Location? = withContext(Dispatchers.IO) {
                val task = fusedLocationClient.getCurrentLocation(
                    Priority.PRIORITY_BALANCED_POWER_ACCURACY,
                    null
                )
                try {
                    // Block in thread to convert Task to direct result (since we are on Dispatchers.IO)
                    val result = com.google.android.gms.tasks.Tasks.await(task)
                    result
                } catch (e: Exception) {
                    e.printStackTrace()
                    null
                }
            }

            if (location != null) {
                // Reverse geocode
                val addresses = geocoder.getFromLocation(location.latitude, location.longitude, 1)
                if (!addresses.isNullOrEmpty()) {
                    val address = addresses[0]
                    val city = address.locality ?: address.subAdminArea ?: address.adminArea ?: "Mevcut Konum"
                    val country = address.countryName ?: ""
                    val timezone = TimeZone.getDefault().id // default to device timezone for current location
                    
                    LocationData(
                        name = city,
                        country = country,
                        latitude = location.latitude,
                        longitude = location.longitude,
                        timezoneIdentifier = timezone
                    )
                } else {
                    LocationData(
                        name = "Mevcut Konum",
                        country = "",
                        latitude = location.latitude,
                        longitude = location.longitude,
                        timezoneIdentifier = TimeZone.getDefault().id
                    )
                }
            } else {
                null
            }
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    suspend fun searchCity(query: String): List<LocationData> = withContext(Dispatchers.IO) {
        if (query.isEmpty()) return@withContext emptyList()

        try {
            val encodedQuery = URLEncoder.encode(query, "UTF-8")
            val urlString = "https://geocoding-api.open-meteo.com/v1/search?name=$encodedQuery&count=10&language=tr&format=json"
            val url = URL(urlString)
            val connection = url.openConnection() as HttpURLConnection
            connection.requestMethod = "GET"
            connection.connectTimeout = 5000
            connection.readTimeout = 5000

            val responseCode = connection.responseCode
            if (responseCode == HttpURLConnection.HTTP_OK) {
                val reader = BufferedReader(InputStreamReader(connection.inputStream))
                val response = StringBuilder()
                var line: String?
                while (reader.readLine().also { line = it } != null) {
                    response.append(line)
                }
                reader.close()

                val searchResponse = gson.fromJson(response.toString(), OpenMeteoResponse::class.java)
                searchResponse.results?.map { result ->
                    LocationData(
                        name = result.name,
                        country = result.country ?: "",
                        latitude = result.latitude,
                        longitude = result.longitude,
                        timezoneIdentifier = result.timezone ?: TimeZone.getDefault().id
                    )
                } ?: emptyList()
            } else {
                emptyList()
            }
        } catch (e: Exception) {
            e.printStackTrace()
            emptyList()
        }
    }
}

// Data structures for JSON decoding
data class OpenMeteoResponse(
    val results: List<OpenMeteoCity>?
)

data class OpenMeteoCity(
    val id: Long,
    val name: String,
    val latitude: Double,
    val longitude: Double,
    val country: String?,
    val timezone: String?
)
