import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.compose.compiler)
    alias(libs.plugins.kotlin.serialization)
}

// Production API used by the iOS app. Not a secret: it ships inside every client.
val productionApiBaseUrl = "https://st3nn5zsm6.execute-api.eu-west-2.amazonaws.com/prod"
val unconfiguredApiBaseUrl = "https://example.invalid"

/**
 * Resolves the API base URL for one environment. Order:
 * HITNSCORE_API_BASE_URL_<ENV>, then HITNSCORE_API_BASE_URL, then [fallback].
 * Set these in ~/.gradle/gradle.properties or with -P on the command line.
 */
fun apiBaseUrl(environment: String, fallback: String): String =
    providers.gradleProperty("HITNSCORE_API_BASE_URL_$environment")
        .orElse(providers.gradleProperty("HITNSCORE_API_BASE_URL"))
        .orElse(fallback)
        .get()
        .trimEnd('/')

val identityFirstLoginEnabled = providers.gradleProperty("HITNSCORE_IDENTITY_FIRST_LOGIN_ENABLED")
    .orElse("true")
// CI passes a monotonically increasing number, e.g. -PHITNSCORE_VERSION_CODE=$GITHUB_RUN_NUMBER
val appVersionCode = providers.gradleProperty("HITNSCORE_VERSION_CODE").orElse("1").get().toInt()
val appVersionName = providers.gradleProperty("HITNSCORE_VERSION_NAME").orElse("0.1.0").get()

// Upload-key signing is optional locally. keystore.properties is git-ignored and holds
// storeFile, storePassword, keyAlias and keyPassword. Play App Signing holds the app key.
val keystorePropertiesFile = rootProject.file("keystore.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        keystorePropertiesFile.inputStream().use { load(it) }
    }
}
val hasUploadKey = keystorePropertiesFile.exists()

android {
    namespace = "com.hitnscore.mobile"
    compileSdk = 37

    defaultConfig {
        // Final Play application ID (confirmed 23 Oct 2026). Never change after first upload.
        applicationId = "com.hitnscore.mobile"
        minSdk = 26
        targetSdk = 37
        versionCode = appVersionCode
        versionName = appVersionName

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        buildConfigField(
            "boolean",
            "IDENTITY_FIRST_LOGIN_ENABLED",
            identityFirstLoginEnabled.get(),
        )
    }

    flavorDimensions += "environment"
    productFlavors {
        create("dev") {
            dimension = "environment"
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
            // Matches iOS development builds, which fall back to the production API.
            buildConfigField("String", "API_BASE_URL", "\"${apiBaseUrl("DEV", productionApiBaseUrl)}\"")
            buildConfigField("String", "ENVIRONMENT_NAME", "\"development\"")
            resValue("string", "app_name", "HitNScore Dev")
        }
        create("staging") {
            dimension = "environment"
            applicationIdSuffix = ".staging"
            versionNameSuffix = "-staging"
            buildConfigField("String", "API_BASE_URL", "\"${apiBaseUrl("STAGING", unconfiguredApiBaseUrl)}\"")
            buildConfigField("String", "ENVIRONMENT_NAME", "\"staging\"")
            resValue("string", "app_name", "HitNScore Staging")
        }
        create("prod") {
            dimension = "environment"
            buildConfigField("String", "API_BASE_URL", "\"${apiBaseUrl("PROD", productionApiBaseUrl)}\"")
            buildConfigField("String", "ENVIRONMENT_NAME", "\"production\"")
            resValue("string", "app_name", "HitNScore")
        }
    }

    signingConfigs {
        if (hasUploadKey) {
            create("upload") {
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        debug {
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
        }
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            if (hasUploadKey) {
                signingConfig = signingConfigs.getByName("upload")
            }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        buildConfig = true
        compose = true
        resValues = true
    }

    packaging {
        resources.excludes += "/META-INF/{AL2.0,LGPL2.1}"
    }
}

dependencies {
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.biometric)
    implementation(libs.androidx.core.splashscreen)
    implementation(libs.androidx.fragment)
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.compose.material3)
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.ui.tooling.preview)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.androidx.navigation.compose)
    implementation(libs.kotlinx.coroutines.android)
    implementation(libs.kotlinx.serialization.json)
    implementation(libs.okhttp)

    debugImplementation(libs.androidx.compose.ui.tooling)
    debugImplementation(libs.androidx.compose.ui.test.manifest)

    testImplementation(libs.junit)
    testImplementation(libs.kotlinx.coroutines.test)

    androidTestImplementation(platform(libs.androidx.compose.bom))
    androidTestImplementation(libs.androidx.compose.ui.test.junit4)
    androidTestImplementation(libs.androidx.test.ext.junit)
    androidTestImplementation(libs.androidx.test.runner)
}
