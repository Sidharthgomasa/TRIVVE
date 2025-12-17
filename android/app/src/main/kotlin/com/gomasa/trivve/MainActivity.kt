package com.gomasa.trivve

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

class MainActivity: FlutterActivity() {
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Register the Native Ad Factory
        GoogleMobileAdsPlugin.registerNativeAdFactory(
            flutterEngine, "adFactoryExample", NativeAdFactory(layoutInflater)
        )
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        // Unregister the factory when the engine is destroyed
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "adFactoryExample")
        super.cleanUpFlutterEngine(flutterEngine)
    }
} // <-- This brace must be at the very end of the file