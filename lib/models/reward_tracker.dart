class RewardTracker {
  static int _totalCoins = 0;
  static int _adsWatched = 0;

  static int get totalCoins => _totalCoins;
  static int get adsWatched => _adsWatched;

  static void addReward(int amount) {
    _totalCoins += amount;
    _adsWatched++;
  }

  static void reset() {
    _totalCoins = 0;
    _adsWatched = 0;
  }
}
