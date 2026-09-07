package com.oktay.namaz.model

data class CalculationMethodInfo(
    val id: Int,
    val name: String,
    val region: String
)

object CalculationMethodRegistry {
    val methods = listOf(
        CalculationMethodInfo(13, "Türkiye (Diyanet)", "Türkiye & Avrupa"),
        CalculationMethodInfo(3, "Muslim World League (MWL)", "Europe & Global Default"),
        CalculationMethodInfo(4, "Umm Al-Qura (Makkah)", "Saudi Arabia & Gulf"),
        CalculationMethodInfo(2, "ISNA", "North America (USA & Canada)"),
        CalculationMethodInfo(15, "Moonsighting Committee", "North America & UK"),
        CalculationMethodInfo(1, "Karachi (Univ. of Islamic Sciences)", "Pakistan, India, Bangladesh"),
        CalculationMethodInfo(5, "Egyptian General Authority", "Egypt & North Africa"),
        CalculationMethodInfo(16, "Dubai (Islamic Affairs)", "United Arab Emirates"),
        CalculationMethodInfo(11, "Singapore (MUIS)", "Singapore & SE Asia"),
        CalculationMethodInfo(9, "Kuwait", "Kuwait"),
        CalculationMethodInfo(10, "Qatar", "Qatar")
    )

    fun getMethodName(id: Int): String {
        return methods.firstOrNull { it.id == id }?.let { "${it.name} (${it.region})" } ?: "Muslim World League (MWL)"
    }
}
