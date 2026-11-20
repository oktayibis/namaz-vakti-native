# ==============================================================================
# ProGuard / R8 Rules for Namaz Vakti (Google Play Production Release)
# ==============================================================================

# Preserve line numbers and source file names for readable Play Console & Crashlytics stack traces
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Preserve generic signatures, annotations, and enclosing methods required by Gson TypeToken & reflection
-keepattributes Signature,InnerClasses,EnclosingMethod,*Annotation*

# Preserve Enum members for Gson & Kotlin serialization
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# ------------------------------------------------------------------------------
# 1. Data Models & API JSON Models (Gson Serialization / Deserialization)
# ------------------------------------------------------------------------------
-keep class com.oktay.namaz.model.** { *; }
-keep class com.oktay.namaz.service.OpenMeteoResponse { *; }
-keep class com.oktay.namaz.service.OpenMeteoCity { *; }
-keep class com.oktay.namaz.service.PrayerType { *; }
-keep class com.oktay.namaz.service.PrayerTimeItem { *; }
-keep class com.oktay.namaz.service.PrayerProgressInfo { *; }
-keep class com.oktay.namaz.service.CitySearchResult { *; }

# Keep any class or field annotated with @Keep or @SerializedName
-keep @androidx.annotation.Keep class * { *; }
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# ------------------------------------------------------------------------------
# 2. Gson & TypeToken Reflection Rules
# ------------------------------------------------------------------------------
-keep class com.google.gson.** { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keepclassmembers,allowobfuscation class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
-dontwarn com.google.gson.**

# ------------------------------------------------------------------------------
# 3. Adhan Astronomical Prayer Time Library
# ------------------------------------------------------------------------------
-keep class com.batoulapps.adhan.** { *; }

# ------------------------------------------------------------------------------
# 4. WorkManager & Background Sync Worker
# ------------------------------------------------------------------------------
-keep class * extends androidx.work.Worker
-keep class * extends androidx.work.CoroutineWorker
-keep class * extends androidx.work.ListenableWorker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}
-keep class com.oktay.namaz.service.NotificationSyncWorker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
    *;
}

# ------------------------------------------------------------------------------
# 5. Android Manifest Components (Widget, Alarm & Boot Receivers, MainActivity)
# ------------------------------------------------------------------------------
-keep public class com.oktay.namaz.MainActivity
-keep public class com.oktay.namaz.widget.PrayerAppWidget {
    public <init>();
    *;
}
-keep public class com.oktay.namaz.receiver.AlarmReceiver {
    public <init>();
    *;
}
-keep public class com.oktay.namaz.receiver.BootReceiver {
    public <init>();
    *;
}

# ------------------------------------------------------------------------------
# 6. Google Play Services Location & Firebase Crashlytics / Analytics Compatibility
# ------------------------------------------------------------------------------
-keep class com.google.android.gms.common.api.internal.** { *; }
-keep class com.google.android.gms.location.** { *; }
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**
