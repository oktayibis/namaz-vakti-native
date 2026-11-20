package com.oktay.namaz.model

import androidx.annotation.Keep
import com.google.gson.annotations.SerializedName
import java.util.UUID
import kotlin.math.abs

@Keep
data class LocationData(
    @SerializedName("id") val id: String = UUID.randomUUID().toString(),
    @SerializedName("name") val name: String,
    @SerializedName("country") val country: String,
    @SerializedName("latitude") val latitude: Double,
    @SerializedName("longitude") val longitude: Double,
    @SerializedName("timezoneIdentifier") val timezoneIdentifier: String
) {
    fun isSameLocation(other: LocationData): Boolean {
        return abs(this.latitude - other.latitude) < 0.001 &&
               abs(this.longitude - other.longitude) < 0.001
    }
}
