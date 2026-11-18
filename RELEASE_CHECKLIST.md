# Production Release Checklist & Owner Decision Gates

This checklist details every required operational, legal, policy, and technical gate before deploying **Parcel Escape: Arrow Puzzle** to Google Play or external distribution channels.

---

## 1. Unresolved Owner Decisions [MANDATORY SIGN-OFF REQUIRED]

| Item | Decision Needed | Default Shipped Value | Status |
| :--- | :--- | :--- | :--- |
| **Target Audience** | Choose either: (A) Families / Under 13, (B) Mixed Audience with neutral age gate, or (C) 13+ General Audience. | `AdMode.disabled` / Neutral age screening structure ready | **[PENDING OWNER DECISION]** |
| **Monetization Policy** | Decide whether to release completely ad-free, with rewarded hints only, or with level-transition interstitials. | Disabled (Free hints offline fallback) | **[PENDING OWNER DECISION]** |
| **Production AdMob IDs** | Create production AdMob App ID and Ad Unit IDs in AdMob console. Replace test IDs. | Official Google Test Sample IDs | **[PENDING OWNER DECISION]** |
| **Production Privacy Policy URL** | Host public privacy policy on owner's domain covering local storage and third-party ad SDKs. | None (placeholder documented) | **[PENDING OWNER DECISION]** |
| **Support Contact & Entity** | Provide verified support email and legal entity name for Play Store listing. | Unassigned | **[PENDING OWNER DECISION]** |
| **App Branding & Trademark** | Verify and finalize working title "Parcel Escape: Arrow Puzzle" as registered mark or cleared name. | Working Title | **[PENDING OWNER DECISION]** |

---

## 2. Google Play Families & Child Safety Gates

If **Families / Children** audience is selected:
- [ ] Confirm Google Mobile Ads SDK version conforms to Google Play Families Self-Certified Ads SDK Program.
- [ ] Ensure `TagForChildDirectedTreatment.yes` and `MaxAdContentRating.g` are set in AdMob configuration.
- [ ] Confirm no transmission of Google Advertising ID (AAID) for users under the digital age of consent.
- [ ] Review Google Play Families Policy: [Google Play Families Policy](https://support.google.com/googleplay/android-developer/answer/9893335).

---

## 3. Google Play Store Console Configuration

- [ ] **Data Safety Form**:
  - Disclose local device storage for puzzle state and preferences.
  - Disclose AdMob SDK data collection (IP address, device identifiers, diagnostic metrics) if ads are active.
  - If ads remain disabled, declare zero third-party data collection.
- [ ] **Target API / SDK Level**:
  - Verified `compileSdkVersion 34` and `targetSdkVersion 34` in `android/app/build.gradle` (meets current Google Play requirements).
  - Minimum SDK set to `minSdkVersion 21`.
- [ ] **Content Rating Questionnaire**:
  - Complete IARC questionnaire in Play Console (game contains no violence, sexual content, gambling, or offensive language).
- [ ] **Privacy Policy URL**:
  - Enter production privacy URL in Play Console App Content section.

---

## 4. Release Keystore & App Signing Setup

Do not publish or distribute debug-signed APKs.
1. Generate an upload keystore:
   ```powershell
   keytool -genkey -v -keystore release-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias parcel_escape_key
   ```
2. Create `android/key.properties` in the project root (excluded from Git via `.gitignore`):
   ```properties
   storePassword=<YOUR_STORE_PASSWORD>
   keyPassword=<YOUR_KEY_PASSWORD>
   keyAlias=parcel_escape_key
   storeFile=../release-keystore.jks
   ```
3. Build the production Android App Bundle:
   ```powershell
   flutter build appbundle --release
   ```

---

## 5. Technical Pre-Release Verification Matrix

- [x] All 50 levels verified 100% solvable via independent solver test (`test/level_generation_test.dart`).
- [x] Invariant verified: Any legal removal choice preserves board solvability without deadlocks.
- [x] 1,000 seeded procedural levels generated and verified without failure.
- [x] All 41 automated unit, engine, ad service, and widget navigation tests passing cleanly.
- [x] Static analysis clean (`flutter analyze`: 0 issues found).
- [x] Responsive layout tested for compact screens (320px logical width) without clipping or overflow.
- [x] Offline-first: Full gameplay tested with zero network dependency.
- [x] Audio and haptics responsive to settings toggles with background pause/resume.
- [x] Save data integrity verified with corrupted-data fallback and privacy choice preservation.
