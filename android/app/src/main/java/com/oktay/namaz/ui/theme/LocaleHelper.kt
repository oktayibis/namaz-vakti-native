package com.oktay.namaz.ui.theme

import android.content.res.Configuration
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.unit.LayoutDirection
import java.util.Locale

@Composable
fun ProvideAppLanguage(
    languageCode: String,
    content: @Composable () -> Unit
) {
    val context = LocalContext.current
    val locale = remember(languageCode) {
        if (languageCode == "system" || languageCode.isEmpty()) Locale.getDefault() else Locale(languageCode)
    }
    val configuration = remember(locale, context) {
        Configuration(context.resources.configuration).apply {
            setLocale(locale)
            setLayoutDirection(locale)
        }
    }
    val localizedContext = remember(configuration, context) {
        context.createConfigurationContext(configuration)
    }
    val layoutDirection = if (locale.language == "ar") LayoutDirection.Rtl else LayoutDirection.Ltr

    CompositionLocalProvider(
        LocalConfiguration provides configuration,
        LocalContext provides localizedContext,
        LocalLayoutDirection provides layoutDirection
    ) {
        content()
    }
}
