/// Explicit operating modes for ad monetization.
enum AdMode {
  /// All ads completely disabled. Hints use free offline fallback.
  disabled,

  /// Uses official Google Mobile Ads test sample IDs.
  test,

  /// Production live ads. Requires explicit verification of audience,
  /// privacy policies, store disclosures, and valid production IDs.
  live,
}

/// Centralized configuration for Google Mobile Ads integration.
class AdConfig {
  final AdMode mode;
  final String androidAppId;
  final String rewardedAdUnitId;
  final String interstitialAdUnitId;

  // Interstitial frequency gating rules
  final int minCompletedLevelsBetweenInterstitials;
  final int minSecondsBetweenInterstitials;
  final int minLevelToEnableInterstitials;

  const AdConfig({
    required this.mode,
    required this.androidAppId,
    required this.rewardedAdUnitId,
    required this.interstitialAdUnitId,
    this.minCompletedLevelsBetweenInterstitials = 4,
    this.minSecondsBetweenInterstitials = 180,
    this.minLevelToEnableInterstitials = 4, // Never during tutorial (levels 1-3)
  });

  /// Official Google Mobile Ads Android sample IDs for safe testing.
  static const String testAndroidAppId =
      'ca-app-pub-3940256099942544~3347511713';
  static const String testRewardedAdUnitId =
      'ca-app-pub-3940256099942544/5224354917';
  static const String testInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712';

  /// Default safe configuration: completely disabled.
  static const AdConfig disabledConfig = AdConfig(
    mode: AdMode.disabled,
    androidAppId: testAndroidAppId,
    rewardedAdUnitId: '',
    interstitialAdUnitId: '',
  );

  /// Safe test configuration using Google's official test sample ad units.
  static const AdConfig testConfig = AdConfig(
    mode: AdMode.test,
    androidAppId: testAndroidAppId,
    rewardedAdUnitId: testRewardedAdUnitId,
    interstitialAdUnitId: testInterstitialAdUnitId,
  );

  /// Validates production configuration.
  /// Throws [StateError] if live mode is enabled without production IDs or audience verification.
  void validateForProduction({
    required bool audiencePolicyReviewed,
    required bool privacyPolicyAccepted,
  }) {
    if (mode == AdMode.live) {
      if (!audiencePolicyReviewed) {
        throw StateError(
          'Production ads cannot be enabled: Audience policy has not been finalized and reviewed.',
        );
      }
      if (!privacyPolicyAccepted) {
        throw StateError(
          'Production ads cannot be enabled: Privacy disclosures and consent requirements have not been accepted.',
        );
      }
      if (rewardedAdUnitId == testRewardedAdUnitId ||
          interstitialAdUnitId == testInterstitialAdUnitId ||
          rewardedAdUnitId.isEmpty ||
          interstitialAdUnitId.isEmpty) {
        throw StateError(
          'Production ads cannot use Google sample test ad units.',
        );
      }
    }
  }
}
