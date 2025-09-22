import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'adhelper.dart';

class AppOpenAdManager {
  static final AppOpenAdManager _instance = AppOpenAdManager._internal();
  factory AppOpenAdManager() => _instance;
  AppOpenAdManager._internal();

  AppOpenAd? _appOpenAd;
  bool _isShowingAd = false;
  bool _isAdLoaded = false;
  DateTime? _appOpenLoadTime;
  
  // Callbacks for splash screen
  VoidCallback? _onAdDismissedCallback;
  VoidCallback? _onAdFailedCallback;
  
  // Show ad only if app was in background for at least 4 hours
  static const Duration _minBackgroundDuration = Duration(hours: 4);
  DateTime? _lastAdShownTime;

  /// Initialize the App Open Ad Manager
  void initialize() {
    // Load app open ad immediately
    _loadAppOpenAd();
    
    // Listen to app lifecycle changes
    WidgetsBinding.instance.addObserver(_AppLifecycleObserver(this));
  }

  /// Load an App Open Ad (with immediate retry for splash screen)
  void _loadAppOpenAd() {
    if (_isAdLoaded) return;

    AppOpenAd.load(
      adUnitId: AdHelper.appOpenAdUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (AppOpenAd ad) {
          _appOpenAd = ad;
          _appOpenLoadTime = DateTime.now();
          _isAdLoaded = true;
          _setupAdCallbacks();
          print('App Open Ad loaded successfully');
        },
        onAdFailedToLoad: (LoadAdError error) {
          _isAdLoaded = false;
          print('App Open Ad failed to load: ${error.message}');
          // For splash screen, retry immediately once, then give up
          if (_lastAdShownTime == null) {
            Future.delayed(const Duration(seconds: 1), _loadAppOpenAd);
          }
        },
      ),
    );
  }

  void _setupAdCallbacks() {
    _appOpenAd?.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (AppOpenAd ad) {
        _isShowingAd = true;
        _lastAdShownTime = DateTime.now();
        print('App Open Ad showed');
      },
      onAdDismissedFullScreenContent: (AppOpenAd ad) {
        _isShowingAd = false;
        _isAdLoaded = false;
        ad.dispose();
        _appOpenAd = null;
        print('App Open Ad dismissed');
        
        // Call callback if set (for splash screen)
        _onAdDismissedCallback?.call();
        _onAdDismissedCallback = null;
        _onAdFailedCallback = null;
        
        // Preload next ad
        _loadAppOpenAd();
      },
      onAdFailedToShowFullScreenContent: (AppOpenAd ad, AdError error) {
        _isShowingAd = false;
        _isAdLoaded = false;
        ad.dispose();
        _appOpenAd = null;
        print('App Open Ad failed to show: ${error.message}');
        
        // Call failure callback if set (for splash screen)
        _onAdFailedCallback?.call();
        _onAdDismissedCallback = null;
        _onAdFailedCallback = null;
        
        // Try to load another ad
        _loadAppOpenAd();
      },
    );
  }

  /// Show the App Open Ad if conditions are met
  void showAdIfAvailable() {
    if (!_canShowAd()) return;
    _appOpenAd?.show();
  }

  /// Check if ad is ready for display
  bool isAdReady() {
    return _isAdLoaded && _appOpenAd != null && !_isShowingAd;
  }

  /// Show ad with callbacks (for splash screen)
  void showAdWithCallback({
    VoidCallback? onAdDismissed,
    VoidCallback? onAdFailedToShow,
  }) {
    _onAdDismissedCallback = onAdDismissed;
    _onAdFailedCallback = onAdFailedToShow;
    
    if (isAdReady()) {
      _appOpenAd?.show();
    } else {
      // Ad not ready, call failure callback immediately
      onAdFailedToShow?.call();
    }
  }

  bool _canShowAd() {
    // Don't show if already showing an ad
    if (_isShowingAd) return false;
    
    // Don't show if ad is not loaded
    if (!_isAdLoaded || _appOpenAd == null) return false;
    
    // Don't show if ad is too old (over 4 hours)
    if (_appOpenLoadTime != null) {
      final adAge = DateTime.now().difference(_appOpenLoadTime!);
      if (adAge > const Duration(hours: 4)) {
        _disposeCurrentAd();
        return false;
      }
    }
    
    // For splash screen (first launch), always show if ad is ready
    if (_lastAdShownTime == null) return true;
    
    // Don't show if we recently showed an ad (within 4 hours)
    final timeSinceLastAd = DateTime.now().difference(_lastAdShownTime!);
    if (timeSinceLastAd < _minBackgroundDuration) return false;
    
    return true;
  }

  void _disposeCurrentAd() {
    _appOpenAd?.dispose();
    _appOpenAd = null;
    _isAdLoaded = false;
    _appOpenLoadTime = null;
  }

  /// Dispose of the current ad and stop loading new ones
  void dispose() {
    _disposeCurrentAd();
  }
}

class _AppLifecycleObserver extends WidgetsBindingObserver {
  final AppOpenAdManager _appOpenAdManager;
  
  _AppLifecycleObserver(this._appOpenAdManager);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App came to foreground, try to show app open ad
      _appOpenAdManager.showAdIfAvailable();
    }
  }
}
