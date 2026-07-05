package com.oktay.namaz.model

import java.util.UUID
import kotlin.math.abs

data class LocationData(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    val country: String,
    val latitude: Double,
    val longitude: Double,
    val timezoneIdentifier: String
) {
    fun isSameLocation(other: LocationData): Boolean {
        return abs(this.latitude - other.latitude) < 0.001 &&
               abs(this.longitude - other.longitude) < 0.001
    }
}
