plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // ✅ FIXED: Kotlin Syntax for Google Services
    id("com.google.gms.google-services") 
}

android {
    namespace = "com.example.trivve" // ⚠️ Double check this matches your package name!
    compileSdk = 34

    defaultConfig {
        applicationId = "com.example.trivve"
        minSdk = 23
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
    
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // ✅ FIXED: Correct Kotlin syntax for JVM target
    kotlinOptions {
        jvmTarget = "17"
    }
}

dependencies {
    // ✅ FIXED: Parentheses and Double Quotes for all dependencies
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.appcompat:appcompat:1.6.1")
    implementation("com.google.android.material:material:1.11.0")
    implementation("androidx.constraintlayout:constraintlayout:2.1.4")
    
    // Firebase & Maps
    implementation(platform("com.google.firebase:firebase-bom:32.7.2"))
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-firestore")
    implementation("com.google.android.gms:play-services-maps:18.2.0")
    implementation("com.google.android.gms:play-services-location:21.1.0")
    
    // Geolocator
    implementation("com.google.android.gms:play-services-location:21.2.0")
}