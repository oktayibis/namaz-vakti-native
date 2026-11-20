import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

val keystoreProperties = Properties().apply {
    val propsFile = listOf(
        rootProject.file("keystore.properties"),
        project.file("keystore.properties")
    ).firstOrNull { it.exists() && it.isFile }
    if (propsFile != null) {
        FileInputStream(propsFile).use { load(it) }
    }
}

fun resolveSigningValue(envKey: String, propKey: String): String? {
    val fromEnv = System.getenv(envKey)?.takeIf { it.isNotBlank() }
    if (fromEnv != null) return fromEnv
    val fromProp = (keystoreProperties.getProperty(propKey) ?: keystoreProperties.getProperty(envKey))
        ?.takeIf { it.isNotBlank() }
    return fromProp
}

val keystorePath = resolveSigningValue("ANDROID_KEYSTORE_PATH", "storeFile")
val keystorePassword = resolveSigningValue("ANDROID_KEYSTORE_PASSWORD", "storePassword")
val keyAliasValue = resolveSigningValue("ANDROID_KEY_ALIAS", "keyAlias")
val keyPasswordValue = resolveSigningValue("ANDROID_KEY_PASSWORD", "keyPassword") ?: keystorePassword

val resolvedKeystoreFile = keystorePath?.let { path ->
    val direct = File(path)
    when {
        direct.isAbsolute && direct.exists() -> direct
        rootProject.file(path).exists() -> rootProject.file(path)
        project.file(path).exists() -> project.file(path)
        else -> direct
    }
}

val hasReleaseSigning = resolvedKeystoreFile != null &&
    resolvedKeystoreFile.exists() &&
    !keystorePassword.isNullOrBlank() &&
    !keyAliasValue.isNullOrBlank() &&
    !keyPasswordValue.isNullOrBlank()

val resolvedVersionCode = (project.findProperty("versionCode")?.toString()
    ?: System.getenv("ANDROID_VERSION_CODE")
    ?: System.getenv("VERSION_CODE"))
    ?.toIntOrNull() ?: 1

val resolvedVersionName = (project.findProperty("versionName")?.toString()
    ?: System.getenv("ANDROID_VERSION_NAME")
    ?: System.getenv("VERSION_NAME"))
    ?.takeIf { it.isNotBlank() } ?: "1.0.0"

android {
    namespace = "com.oktay.namaz"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.oktay.namaz"
        minSdk = 26
        targetSdk = 35
        versionCode = resolvedVersionCode
        versionName = resolvedVersionName

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        vectorDrawables {
            useSupportLibrary = true
        }
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = resolvedKeystoreFile
                storePassword = keystorePassword
                keyAlias = keyAliasValue
                keyPassword = keyPasswordValue
                enableV1Signing = true
                enableV2Signing = true
                enableV3Signing = true
                enableV4Signing = true
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
    buildFeatures {
        compose = true
    }
    composeOptions {
        kotlinCompilerExtensionVersion = "1.5.8"
    }
    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.7.0")
    implementation("androidx.activity:activity-compose:1.8.2")
    // A transitive dependency drags in fragment 1.0.0, which breaks
    // registerForActivityResult (and fails lintVitalRelease); pin a modern version.
    implementation("androidx.fragment:fragment-ktx:1.6.2")

    // 2024.01.00 pairs material3 1.1.2 with animation-core 1.6.0, which crashes with
    // NoSuchMethodError (KeyframesSpecConfig.at) whenever CircularProgressIndicator shows.
    val composeBom = platform("androidx.compose:compose-bom:2024.06.00")
    implementation(composeBom)
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-graphics")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.animation:animation")
    implementation("androidx.compose.animation:animation-core")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("androidx.navigation:navigation-compose:2.7.7")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.7.0")

    implementation("androidx.work:work-runtime-ktx:2.9.0")
    implementation("com.google.android.gms:play-services-location:21.1.0")
    implementation("com.batoulapps.adhan:adhan:1.2.1")
    implementation("com.google.code.gson:gson:2.10.1")

    testImplementation("junit:junit:4.13.2")
    androidTestImplementation("androidx.test.ext:junit:1.1.5")
    androidTestImplementation("androidx.test.espresso:espresso-core:3.5.1")
    androidTestImplementation(composeBom)
    androidTestImplementation("androidx.compose.ui:ui-test-junit4")
    debugImplementation("androidx.compose.ui:ui-tooling")
    debugImplementation("androidx.compose.ui:ui-test-manifest")
}
