import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'adhelper.dart';

class RewardAdWidget extends StatefulWidget {
  final VoidCallback? onRewardEarned;
  final int rewardAmount;

  const RewardAdWidget({
    super.key,
    this.onRewardEarned,
    this.rewardAmount = 10,
  });

  @override
  State<RewardAdWidget> createState() => _RewardAdWidgetState();
}

class _RewardAdWidgetState extends State<RewardAdWidget> {
  RewardedAd? _rewardedAd;
  bool _isLoading = false;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _loadRewardedAd();
  }

  void _loadRewardedAd() {
    setState(() => _isLoading = true);
    
    RewardedAd.load(
      adUnitId: AdHelper.rewardAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          _rewardedAd = ad;
          _setupAdCallbacks();
          if (mounted) {
            setState(() {
              _isLoading = false;
              _isReady = true;
            });
          }
        },
        onAdFailedToLoad: (LoadAdError error) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _isReady = false;
            });
          }
          _showErrorMessage('Failed to load reward ad: ${error.message}');
        },
      ),
    );
  }

  void _setupAdCallbacks() {
    _rewardedAd?.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (RewardedAd ad) {
        // Ad showed successfully
      },
      onAdDismissedFullScreenContent: (RewardedAd ad) {
        ad.dispose();
        setState(() => _isReady = false);
        _loadRewardedAd(); // Preload next ad
      },
      onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
        ad.dispose();
        setState(() => _isReady = false);
        _showErrorMessage('Failed to show reward ad: ${error.message}');
        _loadRewardedAd(); // Try to load again
      },
    );
  }

  void _showRewardedAd() {
    if (_rewardedAd != null && _isReady) {
      _rewardedAd!.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
          // User earned reward
          _handleRewardEarned(reward);
        },
      );
    }
  }

  void _handleRewardEarned(RewardItem reward) {
    if (mounted) {
      _showRewardDialog(reward);
      widget.onRewardEarned?.call();
    }
  }

  void _showRewardDialog(RewardItem reward) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🎉 Reward Earned!'),
        content: Text(
          'You earned ${reward.amount} ${reward.type}!\n'
          'Keep watching ads to earn more rewards!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Awesome!'),
          ),
        ],
      ),
    );
  }

  void _showErrorMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _rewardedAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: _isReady ? _showRewardedAd : null,
      icon: _isLoading 
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.card_giftcard),
      label: Text(
        _isLoading 
          ? 'Loading...'
          : _isReady 
            ? 'Watch Ad for ${widget.rewardAmount} Coins'
            : 'Ad Not Ready',
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: _isReady ? Colors.green : Colors.grey,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}
