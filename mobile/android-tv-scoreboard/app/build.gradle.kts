import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
}

// The public web scoreboard this app shows. Override with -PHITNSCORE_SCOREBOARD_URL=...
val scoreboardUrl = providers.gradleProperty("HITNSCORE_SCOREBOARD_URL")
    .orElse("https://app.hitnscore.com/scoreboard").get()
val appVersionCode = providers.gradleProperty("HITNSCORE_VERSION_CODE").orElse("1").get().toInt()
val appVersionName = providers.gradleProperty("HITNSCORE_VERSION_NAME").orElse("1.0.0").get()

val keystorePropertiesFile = rootProject.file("keystore.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) keystorePropertiesFile.inputStream().use { load(it) }
}
val hasUploadKey = keystorePropertiesFile.exists()

android {
    namespace = "com.hitnscore.tvscoreboard"
    compileSdk = 37

    defaultConfig {
        // Own Play listing, separate from com.hitnscore.mobile. Never change after first upload.
        applicationId = "com.hitnscore.tvscoreboard"
        minSdk = 26
        targetSdk = 37
        versionCode = appVersionCode
        versionName = appVersionName
        buildConfigField("String", "SCOREBOARD_URL", "\"$scoreboardUrl\"")
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
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            if (hasUploadKey) signingConfig = signingConfigs.getByName("upload")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        buildConfig = true
    }
}

dependencies {
    implementation(libs.androidx.activity)
    implementation(libs.androidx.core)
    implementation(libs.androidx.webkit)
}
