// full_page_ad.dart
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'adhelper.dart';

class FullPageAdWidget extends StatefulWidget {
  const FullPageAdWidget({super.key});

  @override
  State<FullPageAdWidget> createState() => _FullPageAdWidgetState();
}

class _FullPageAdWidgetState extends State<FullPageAdWidget> {
  InterstitialAd? _interstitialAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    InterstitialAd.load(
      adUnitId: AdHelper.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isLoaded = true;
          _setFullScreenContentCallback();
          if (mounted) setState(() {});
        },
        onAdFailedToLoad: (error) {
          print('Interstitial ad failed to load: $error');
          _isLoaded = false;
        },
      ),
    );
  }

  void _setFullScreenContentCallback() {
    _interstitialAd?.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadAd(); // Load next ad
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        print('Interstitial ad failed to show: $error');
        ad.dispose();
        _loadAd(); // Load next ad
      },
    );
  }

  void _showAd() {
    if (_isLoaded && _interstitialAd != null) {
      _interstitialAd!.show();
    } else {
      print('Interstitial ad not ready');
      _loadAd();
    }
  }

  @override
  void dispose() {
    _interstitialAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: _showAd,
      icon: Icon(_isLoaded ? Icons.fullscreen : Icons.hourglass_empty),
      label: const Text('Show Ad'),
    );
  }
}
  