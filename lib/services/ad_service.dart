import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart'; 

class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;
  bool _isInterstitialLoaded = false;
  bool _isRewardedLoaded = false;

  // --- REAL ADMOB UNIT IDS ---

  String get interstitialAdUnitId {
    if (kIsWeb) return 'ca-app-pub-3981723159904347/2162838259'; 
    return Platform.isAndroid 
        ? 'ca-app-pub-3981723159904347/2162838259' 
        : 'ca-app-pub-3981723159904347/2162838259';
  }

  String get rewardedAdUnitId {
    if (kIsWeb) return 'ca-app-pub-3981723159904347/1967397133'; 
    return Platform.isAndroid 
        ? 'ca-app-pub-3981723159904347/1967397133' 
        : 'ca-app-pub-3981723159904347/1967397133';
  }

  // ADDED: Native Ad ID for the Reality Feed
  String get nativeAdUnitId {
    if (kIsWeb) return 'ca-app-pub-3981723159904347/5941660536';
    return Platform.isAndroid 
        ? 'ca-app-pub-3981723159904347/5941660536' 
        : 'ca-app-pub-3981723159904347/5941660536';
  }

  // --- INITIALIZATION ---
  Future<void> initAds() async {
    await MobileAds.instance.initialize();
    loadInterstitial();
    loadRewarded();
  }

  // --- INTERSTITIAL LOGIC ---
  void loadInterstitial() {
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialLoaded = true;
          _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _isInterstitialLoaded = false;
              loadInterstitial(); 
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _isInterstitialLoaded = false;
              loadInterstitial();
            },
          );
        },
        onAdFailedToLoad: (err) {
          _isInterstitialLoaded = false;
          print("Interstitial Failed: $err");
        },
      ),
    );
  }

  void showInterstitial() {
    if (_isInterstitialLoaded && _interstitialAd != null) {
      _interstitialAd!.show();
    } else {
      loadInterstitial(); 
    }
  }

  // --- REWARDED LOGIC ---
  void loadRewarded() {
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedLoaded = true;
        },
        onAdFailedToLoad: (err) {
          _isRewardedLoaded = false;
          print("Rewarded Failed: $err");
        },
      ),
    );
  }

  void showRewarded(Function(int) onUserEarnedReward) {
    if (_isRewardedLoaded && _rewardedAd != null) {
      _rewardedAd!.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
          final User? user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            FirebaseFirestore.instance.collection('users').doc(user.uid).update({
              'aura': FieldValue.increment(50), 
            });
            onUserEarnedReward(50);
          }
        },
      );
      _isRewardedLoaded = false;
      loadRewarded(); 
    } else {
      loadRewarded(); 
    }
  }
}