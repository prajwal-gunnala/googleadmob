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
}
