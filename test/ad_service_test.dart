import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_escape/src/config/ad_config.dart';
import 'package:parcel_escape/src/services/ad_service.dart';

void main() {
  group('AdConfig & Production Validation', () {
    test('Default mode is disabled', () {
      expect(AdConfig.disabledConfig.mode, AdMode.disabled);
    });

    test('Test config uses official Google test sample ad-unit IDs', () {
      expect(AdConfig.testConfig.mode, AdMode.test);
      expect(AdConfig.testConfig.androidAppId, AdConfig.testAndroidAppId);
      expect(AdConfig.testConfig.rewardedAdUnitId, AdConfig.testRewardedAdUnitId);
      expect(AdConfig.testConfig.interstitialAdUnitId, AdConfig.testInterstitialAdUnitId);
    });

    test('Production validation fails if live mode lacks audience review', () {
      const liveConfig = AdConfig(
        mode: AdMode.live,
        androidAppId: 'ca-app-pub-1234567890123456~1234567890',
        rewardedAdUnitId: 'ca-app-pub-1234567890123456/1111111111',
        interstitialAdUnitId: 'ca-app-pub-1234567890123456/2222222222',
      );

      expect(
        () => liveConfig.validateForProduction(
          audiencePolicyReviewed: false,
          privacyPolicyAccepted: true,
        ),
        throwsStateError,
      );
    });

    test('Production validation fails if live mode lacks privacy acceptance', () {
      const liveConfig = AdConfig(
        mode: AdMode.live,
        androidAppId: 'ca-app-pub-1234567890123456~1234567890',
        rewardedAdUnitId: 'ca-app-pub-1234567890123456/1111111111',
        interstitialAdUnitId: 'ca-app-pub-1234567890123456/2222222222',
      );

      expect(
        () => liveConfig.validateForProduction(
          audiencePolicyReviewed: true,
          privacyPolicyAccepted: false,
        ),
        throwsStateError,
      );
    });

    test('Production validation fails if test sample IDs are used in live mode', () {
      const liveWithTestIds = AdConfig(
        mode: AdMode.live,
        androidAppId: AdConfig.testAndroidAppId,
        rewardedAdUnitId: AdConfig.testRewardedAdUnitId,
        interstitialAdUnitId: AdConfig.testInterstitialAdUnitId,
      );

      expect(
        () => liveWithTestIds.validateForProduction(
          audiencePolicyReviewed: true,
          privacyPolicyAccepted: true,
        ),
        throwsStateError,
      );
    });
  });

  group('Interstitial Frequency & Cooldown Gating', () {
    late FakeAdService adService;

    setUp(() {
      adService = FakeAdService();
      adService.loadInterstitialAd();
    });

    test('Cannot show interstitial during tutorial levels (levels 1-3)', () {
      expect(
        adService.isInterstitialEligible(
          currentLevel: 1,
          levelsCompletedSinceLastAd: 10,
          lastAdTimestampMs: 0,
        ),
        isFalse,
      );
      expect(
        adService.isInterstitialEligible(
          currentLevel: 3,
          levelsCompletedSinceLastAd: 10,
          lastAdTimestampMs: 0,
        ),
        isFalse,
      );
    });

    test('Cannot show interstitial if fewer than 4 levels completed since last ad', () {
      expect(
        adService.isInterstitialEligible(
          currentLevel: 5,
          levelsCompletedSinceLastAd: 3,
          lastAdTimestampMs: 0,
        ),
        isFalse,
      );
    });

    test('Cannot show interstitial if 180s cooldown has not elapsed', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final recentAdTime = now - (60 * 1000); // 60 seconds ago

      expect(
        adService.isInterstitialEligible(
          currentLevel: 8,
          levelsCompletedSinceLastAd: 6,
          lastAdTimestampMs: recentAdTime,
        ),
        isFalse,
      );
    });

    test('Can show interstitial when level >= 4, >= 4 levels completed, and >= 180s elapsed', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final oldAdTime = now - (200 * 1000); // 200 seconds ago

      expect(
        adService.isInterstitialEligible(
          currentLevel: 8,
          levelsCompletedSinceLastAd: 5,
          lastAdTimestampMs: oldAdTime,
        ),
        isTrue,
      );

      final shown = await adService.showInterstitialIfEligible(
        currentLevel: 8,
        levelsCompletedSinceLastAd: 5,
        lastAdTimestampMs: oldAdTime,
      );

      expect(shown, isTrue);
      expect(adService.interstitialShownCount, 1);
    });

    test('DisabledAdService always returns false and never presents ads', () {
      final disabled = DisabledAdService();
      expect(
        disabled.isInterstitialEligible(
          currentLevel: 10,
          levelsCompletedSinceLastAd: 10,
          lastAdTimestampMs: 0,
        ),
        isFalse,
      );
    });
  });

  group('Rewarded Ad Callbacks and Safety', () {
    test('Reward is granted ONLY when onUserEarnedReward fires', () async {
      final adService = FakeAdService();
      adService.loadRewardedAd();

      bool rewardEarned = false;
      bool dismissed = false;

      // Case 1: Reward earned
      adService.shouldGrantReward = true;
      final result1 = await adService.showRewardedAd(
        onUserEarnedReward: () {
          rewardEarned = true;
        },
        onAdDismissed: () {
          dismissed = true;
        },
      );

      expect(result1, isTrue);
      expect(rewardEarned, isTrue);
      expect(dismissed, isTrue);

      // Case 2: Dismissed early without earning reward
      adService.loadRewardedAd();
      rewardEarned = false;
      dismissed = false;
      adService.shouldGrantReward = false;

      final result2 = await adService.showRewardedAd(
        onUserEarnedReward: () {
          rewardEarned = true;
        },
        onAdDismissed: () {
          dismissed = true;
        },
      );

      expect(result2, isTrue);
      expect(rewardEarned, isFalse, reason: 'Dismissing without earning reward must not grant reward');
      expect(dismissed, isTrue);
    });

    test('Ad load or presentation failure triggers error callback gracefully', () async {
      final adService = FakeAdService();
      // Not loaded
      adService.isRewardedAdAvailable = false;

      String? errorMsg;
      final shown = await adService.showRewardedAd(
        onUserEarnedReward: () {},
        onAdFailedToShow: (err) {
          errorMsg = err;
        },
      );

      expect(shown, isFalse);
      expect(errorMsg, isNotNull);
    });
  });
}
