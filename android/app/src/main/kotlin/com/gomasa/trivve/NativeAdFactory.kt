// 1. CHANGE THIS TO YOUR NEW PACKAGE NAME
package com.gomasa.trivve

// 2. ADD THIS CRITICAL IMPORT (This resolves the 'R' errors)
import com.gomasa.trivve.R 

import android.view.LayoutInflater
import android.view.View
import android.widget.ImageView
import android.widget.TextView
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin.NativeAdFactory
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
    // Rest of your code remains the same...
class NativeAdFactory(private val layoutInflater: LayoutInflater) : NativeAdFactory {

    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: MutableMap<String, Any>?
    ): NativeAdView {
        // We use a simple layout for the ad
        val adView = layoutInflater.inflate(R.layout.list_tile_native_ad, null) as NativeAdView

        // Map the Headline
        val headlineView = adView.findViewById<TextView>(R.id.ad_headline)
        headlineView.text = nativeAd.headline
        adView.headlineView = headlineView

        // Map the Body
        val bodyView = adView.findViewById<TextView>(R.id.ad_body)
        bodyView.text = nativeAd.body
        adView.bodyView = bodyView

        // Map the App Icon
        val iconView = adView.findViewById<ImageView>(R.id.ad_app_icon)
        if (nativeAd.icon != null) {
            iconView.setImageDrawable(nativeAd.icon!!.drawable)
        }
        adView.iconView = iconView

        // Important: Call this to associate the ad data with the view
        adView.setNativeAd(nativeAd)

        return adView
    }
}