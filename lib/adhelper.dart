// adhelper.dart
import 'dart:io';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdHelper {
  // Official Google Test Ad Unit IDs
  static const String _androidStandardBannerId = 'ca-app-pub-3940256099942544/9214589741';
  static const String _androidMediumRectangleId = 'ca-app-pub-3940256099942544/6300978111';
  static const String _iosBannerId = 'ca-app-pub-3940256099942544/2435281174';
  static const String _androidInterstitialId = 'ca-app-pub-3940256099942544/1033173712';
  static const String _iosInterstitialId = 'ca-app-pub-3940256099942544/4411468910';
  static const String _androidRewardId = 'ca-app-pub-3940256099942544/5224354917';
  static const String _iosRewardId = 'ca-app-pub-3940256099942544/1712485313';
  static const String _androidAppOpenId = 'ca-app-pub-3940256099942544/9257395921';
  static const String _iosAppOpenId = 'ca-app-pub-3940256099942544/5575463023';

  static String getBannerAdUnitId(AdSize size) {
    if (Platform.isAndroid) {
      // Return specific ID based on banner size
      if (size == AdSize.mediumRectangle) {
        return _androidMediumRectangleId;
      } 
      return _androidStandardBannerId;
    } else if (Platform.isIOS) {
      return _iosBannerId;
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  static String get interstitialAdUnitId {
    if (Platform.isAndroid) {
      return _androidInterstitialId;
    } else if (Platform.isIOS) {
      return _iosInterstitialId;
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  /// Get reward ad unit ID based on platform
  static String get rewardAdUnitId {
    if (Platform.isAndroid) return _androidRewardId;
    if (Platform.isIOS) return _iosRewardId;
    throw UnsupportedError('Unsupported platform');
  }

  /// Get app open ad unit ID based on platform
  static String get appOpenAdUnitId {
    if (Platform.isAndroid) return _androidAppOpenId;
    if (Platform.isIOS) return _iosAppOpenId;
    throw UnsupportedError('Unsupported platform');
  }
}
