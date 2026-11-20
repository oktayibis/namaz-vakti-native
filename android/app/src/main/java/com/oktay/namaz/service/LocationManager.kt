package com.oktay.namaz.service

import android.annotation.SuppressLint
import android.content.Context
import android.location.Geocoder
import android.location.Location
import androidx.annotation.Keep
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.gson.Gson
import com.google.gson.annotations.SerializedName
import com.oktay.namaz.model.LocationData
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.withContext
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.net.UnknownHostException
import java.util.Locale
import java.util.TimeZone

@Keep
sealed class CitySearchResult {
    data class Success(val locations: List<LocationData>) : CitySearchResult()
    object Offline : CitySearchResult()
    object Error : CitySearchResult()
}

class LocationManager(private val context: Context) {

    private val fusedLocationClient = LocationServices.getFusedLocationProviderClient(context)
    private val geocoder = Geocoder(context, Locale.getDefault())
    private val gson = Gson()

    companion object {
        private val SUPPORTED_GEOCODING_LANGUAGES = setOf("en", "de", "fr", "es", "it", "pt", "ru", "tr")

        fun resolveGeocodingLanguage(languageCode: String = Locale.getDefault().language): String {
            val normalized = languageCode.lowercase(Locale.ROOT)
            return if (SUPPORTED_GEOCODING_LANGUAGES.contains(normalized)) normalized else "en"
        }
    }

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
                @Suppress("DEPRECATION")
                val addresses = geocoder.getFromLocation(location.latitude, location.longitude, 1)
                val defaultLocationName = context.getString(com.oktay.namaz.R.string.current_location)
                if (!addresses.isNullOrEmpty()) {
                    val address = addresses[0]
                    val city = address.locality ?: address.subAdminArea ?: address.adminArea ?: defaultLocationName
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
                        name = defaultLocationName,
                        country = "",
                        latitude = location.latitude,
                        longitude = location.longitude,
                        timezoneIdentifier = TimeZone.getDefault().id
                    )
                }
            } else {
                null
            }
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    private fun getGeocodingLanguage(): String = resolveGeocodingLanguage(Locale.getDefault().language)

    suspend fun searchCityWithStatus(query: String): CitySearchResult = withContext(Dispatchers.IO) {
        val trimmed = query.trim()
        if (trimmed.isEmpty()) return@withContext CitySearchResult.Success(emptyList())

        var connection: HttpURLConnection? = null
        try {
            coroutineContext.ensureActive()
            val encodedQuery = URLEncoder.encode(trimmed, "UTF-8")
            val lang = getGeocodingLanguage()
            val urlString = "https://geocoding-api.open-meteo.com/v1/search?name=$encodedQuery&count=10&language=$lang&format=json"
            val url = URL(urlString)
            connection = (url.openConnection() as HttpURLConnection).apply {
                requestMethod = "GET"
                connectTimeout = 5000
                readTimeout = 5000
            }

            val responseCode = connection.responseCode
            coroutineContext.ensureActive()
            if (responseCode == HttpURLConnection.HTTP_OK) {
                val response = BufferedReader(InputStreamReader(connection.inputStream)).use { reader ->
                    reader.readText()
                }
                coroutineContext.ensureActive()
                val searchResponse = gson.fromJson(response, OpenMeteoResponse::class.java)
                val list = searchResponse?.results?.map { result ->
                    LocationData(
                        name = result.name,
                        country = result.country ?: "",
                        latitude = result.latitude,
                        longitude = result.longitude,
                        timezoneIdentifier = result.timezone ?: TimeZone.getDefault().id
                    )
                } ?: emptyList()
                CitySearchResult.Success(list)
            } else {
                CitySearchResult.Error
            }
        } catch (e: CancellationException) {
            throw e
        } catch (e: UnknownHostException) {
            CitySearchResult.Offline
        } catch (e: Exception) {
            e.printStackTrace()
            CitySearchResult.Error
        } finally {
            connection?.disconnect()
        }
    }

    suspend fun searchCity(query: String): List<LocationData> {
        return when (val result = searchCityWithStatus(query)) {
            is CitySearchResult.Success -> result.locations
            else -> emptyList()
        }
    }
}

// Data structures for JSON decoding
@Keep
data class OpenMeteoResponse(
    @SerializedName("results") val results: List<OpenMeteoCity>?
)

@Keep
data class OpenMeteoCity(
    @SerializedName("id") val id: Long,
    @SerializedName("name") val name: String,
    @SerializedName("latitude") val latitude: Double,
    @SerializedName("longitude") val longitude: Double,
    @SerializedName("country") val country: String?,
    @SerializedName("timezone") val timezone: String?
)
