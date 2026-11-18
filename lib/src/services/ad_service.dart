import 'dart:async';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../config/ad_config.dart';

/// Contract for advertising services across disabled, test, and production environments.
abstract class AdService {
  AdConfig get config;
  bool get isInitialized;
  bool get isRewardedAdAvailable;
  bool get isInterstitialAdAvailable;

  Future<void> initialize();

  /// Preloads a rewarded ad if supported by the active configuration.
  void loadRewardedAd();

  /// Preloads an interstitial ad if supported by the active configuration.
  void loadInterstitialAd();

  /// Presents a rewarded ad to the player.
  /// [onUserEarnedReward] is ONLY called when the SDK triggers the verified reward callback.
  Future<bool> showRewardedAd({
    required void Function() onUserEarnedReward,
    void Function()? onAdDismissed,
    void Function(String error)? onAdFailedToShow,
  });

  /// Evaluates whether an interstitial ad is eligible to be shown right now.
  bool isInterstitialEligible({
    required int currentLevel,
    required int levelsCompletedSinceLastAd,
    required int lastAdTimestampMs,
  });

  /// Presents an interstitial ad at a natural level boundary if all frequency gates pass.
  Future<bool> showInterstitialIfEligible({
    required int currentLevel,
    required int levelsCompletedSinceLastAd,
    required int lastAdTimestampMs,
    void Function()? onAdDismissed,
  });

  void dispose();
}

/// Safe default service: performs no network requests and never displays ads.
class DisabledAdService implements AdService {
  @override
  final AdConfig config = AdConfig.disabledConfig;

  @override
  bool get isInitialized => true;

  @override
  bool get isRewardedAdAvailable => false;

  @override
  bool get isInterstitialAdAvailable => false;

  @override
  Future<void> initialize() async {}

  @override
  void loadRewardedAd() {}

  @override
  void loadInterstitialAd() {}

  @override
  Future<bool> showRewardedAd({
    required void Function() onUserEarnedReward,
    void Function()? onAdDismissed,
    void Function(String error)? onAdFailedToShow,
  }) async {
    // When ads are disabled, offline free hint fallback is used by the controller
    return false;
  }

  @override
  bool isInterstitialEligible({
    required int currentLevel,
    required int levelsCompletedSinceLastAd,
    required int lastAdTimestampMs,
  }) =>
      false;

  @override
  Future<bool> showInterstitialIfEligible({
    required int currentLevel,
    required int levelsCompletedSinceLastAd,
    required int lastAdTimestampMs,
    void Function()? onAdDismissed,
  }) async {
    return false;
  }

  @override
  void dispose() {}
}

/// Controllable mock ad service for automated tests.
class FakeAdService implements AdService {
  @override
  final AdConfig config;

  @override
  bool isInitialized = false;

  @override
  bool isRewardedAdAvailable = false;

  @override
  bool isInterstitialAdAvailable = false;

  bool shouldGrantReward = true;
  bool shouldFailToShow = false;
  int interstitialShownCount = 0;
  int rewardedShownCount = 0;

  FakeAdService({AdConfig? config})
      : config = config ?? AdConfig.testConfig;

  @override
  Future<void> initialize() async {
    isInitialized = true;
  }

  @override
  void loadRewardedAd() {
    isRewardedAdAvailable = true;
  }

  @override
  void loadInterstitialAd() {
    isInterstitialAdAvailable = true;
  }

  @override
  Future<bool> showRewardedAd({
    required void Function() onUserEarnedReward,
    void Function()? onAdDismissed,
    void Function(String error)? onAdFailedToShow,
  }) async {
    if (!isRewardedAdAvailable || shouldFailToShow) {
      onAdFailedToShow?.call('Ad not ready or simulated failure');
      return false;
    }
    rewardedShownCount++;
    isRewardedAdAvailable = false;
    if (shouldGrantReward) {
      onUserEarnedReward();
    }
    onAdDismissed?.call();
    return true;
  }

  @override
  bool isInterstitialEligible({
    required int currentLevel,
    required int levelsCompletedSinceLastAd,
    required int lastAdTimestampMs,
  }) {
    if (config.mode == AdMode.disabled) return false;
    if (currentLevel < config.minLevelToEnableInterstitials) return false;
    if (levelsCompletedSinceLastAd <
        config.minCompletedLevelsBetweenInterstitials) {
      return false;
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final elapsedSec = (nowMs - lastAdTimestampMs) ~/ 1000;
    if (elapsedSec < config.minSecondsBetweenInterstitials) return false;
    return true;
  }

  @override
  Future<bool> showInterstitialIfEligible({
    required int currentLevel,
    required int levelsCompletedSinceLastAd,
    required int lastAdTimestampMs,
    void Function()? onAdDismissed,
  }) async {
    if (!isInterstitialEligible(
      currentLevel: currentLevel,
      levelsCompletedSinceLastAd: levelsCompletedSinceLastAd,
      lastAdTimestampMs: lastAdTimestampMs,
    )) {
      return false;
    }
    if (!isInterstitialAdAvailable || shouldFailToShow) {
      return false;
    }
    interstitialShownCount++;
    isInterstitialAdAvailable = false;
    onAdDismissed?.call();
    return true;
  }

  @override
  void dispose() {}
}

/// Official AdMob implementation wrapping Google Mobile Ads SDK.
class AdMobAdService implements AdService {
  @override
  final AdConfig config;

  RewardedAd? _rewardedAd;
  InterstitialAd? _interstitialAd;

  bool _isInitialized = false;
  bool _isLoadingRewarded = false;
  bool _isLoadingInterstitial = false;

  AdMobAdService({required this.config});

  @override
  bool get isInitialized => _isInitialized;

  @override
  bool get isRewardedAdAvailable => _rewardedAd != null;

  @override
  bool get isInterstitialAdAvailable => _interstitialAd != null;

  @override
  Future<void> initialize() async {
    if (_isInitialized || config.mode == AdMode.disabled) return;
    try {
      await MobileAds.instance.initialize();
      _isInitialized = true;
      loadRewardedAd();
      loadInterstitialAd();
    } catch (_) {
      // Graceful error handling: ad initialization failure must never crash the game
      _isInitialized = false;
    }
  }

  @override
  void loadRewardedAd() {
    if (config.mode == AdMode.disabled ||
        _isLoadingRewarded ||
        _rewardedAd != null) {
      return;
    }
    _isLoadingRewarded = true;
    RewardedAd.load(
      adUnitId: config.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isLoadingRewarded = false;
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          _isLoadingRewarded = false;
        },
      ),
    );
  }

  @override
  void loadInterstitialAd() {
    if (config.mode == AdMode.disabled ||
        _isLoadingInterstitial ||
        _interstitialAd != null) {
      return;
    }
    _isLoadingInterstitial = true;
    InterstitialAd.load(
      adUnitId: config.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isLoadingInterstitial = false;
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
          _isLoadingInterstitial = false;
        },
      ),
    );
  }

  @override
  Future<bool> showRewardedAd({
    required void Function() onUserEarnedReward,
    void Function()? onAdDismissed,
    void Function(String error)? onAdFailedToShow,
  }) async {
    final ad = _rewardedAd;
    if (ad == null) {
      onAdFailedToShow?.call('Rewarded ad is not ready yet');
      loadRewardedAd();
      return false;
    }

    bool earned = false;
    final completer = Completer<bool>();

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd();
        onAdDismissed?.call();
        if (!completer.isCompleted) completer.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd();
        onAdFailedToShow?.call(error.message);
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    ad.show(
      onUserEarnedReward: (AdWithoutView adView, RewardItem reward) {
        earned = true;
        onUserEarnedReward();
      },
    );

    return completer.future;
  }

  @override
  bool isInterstitialEligible({
    required int currentLevel,
    required int levelsCompletedSinceLastAd,
    required int lastAdTimestampMs,
  }) {
    if (config.mode == AdMode.disabled) return false;
    if (currentLevel < config.minLevelToEnableInterstitials) return false;
    if (levelsCompletedSinceLastAd <
        config.minCompletedLevelsBetweenInterstitials) {
      return false;
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final elapsedSec = (nowMs - lastAdTimestampMs) ~/ 1000;
    if (elapsedSec < config.minSecondsBetweenInterstitials) return false;
    return true;
  }

  @override
  Future<bool> showInterstitialIfEligible({
    required int currentLevel,
    required int levelsCompletedSinceLastAd,
    required int lastAdTimestampMs,
    void Function()? onAdDismissed,
  }) async {
    if (!isInterstitialEligible(
      currentLevel: currentLevel,
      levelsCompletedSinceLastAd: levelsCompletedSinceLastAd,
      lastAdTimestampMs: lastAdTimestampMs,
    )) {
      return false;
    }

    final ad = _interstitialAd;
    if (ad == null) {
      loadInterstitialAd();
      return false;
    }

    final completer = Completer<bool>();

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        loadInterstitialAd();
        onAdDismissed?.call();
        if (!completer.isCompleted) completer.complete(true);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
        loadInterstitialAd();
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    ad.show();
    return completer.future;
  }

  @override
  void dispose() {
    _rewardedAd?.dispose();
    _interstitialAd?.dispose();
    _rewardedAd = null;
    _interstitialAd = null;
  }
}
