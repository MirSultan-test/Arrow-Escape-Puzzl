# Privacy Notes & Audience Policy Disclosures

## Status: Unresolved Owner Decisions Flagged [ACTION REQUIRED]

> [!IMPORTANT]
> The target audience declaration for **Parcel Escape: Arrow Puzzle** has **NOT** been finalized.
> Because the game mechanics appeal across demographic age groups and casual players, the product must **not** be arbitrarily labeled 13+ or adult-only merely to ease ad monetization.
> Live advertising is strictly **DISABLED by default** in this build (`AdMode.disabled`) until the application owner officially reviews and signs off on the gates outlined below.

---

## 1. Audience Policy Scenarios & Gates

### Scenario A: Families / Child-Directed Audience (Under 13 or Mixed with Children)
If the owner chooses to target children (either exclusively or as part of a Families-targeted app):
1. **Google Play Families Policy Compliance**:
   - Only certified AdMob ad units participating in Google Play's Families Self-Certified Ads SDK Program may be requested.
   - AdMob request configuration must set `tagForChildDirectedTreatment = TagForChildDirectedTreatment.yes`.
   - Ad content rating must be restricted to `MaxAdContentRating.g`.
   - No interest-based advertising, behavioral remarketing, or personalized tracking identifiers (including Google Advertising ID / AAID) may be transmitted for child users.
2. **Neutral Age Screening**:
   - A neutral age screen must ask the user for their age or birth year using neutral numeric inputs without pre-selecting ages or nudging.
   - The app must not collect full date of birth, names, contacts, or geolocation.
   - If the user indicates an age under the digital consent threshold (under 13 in the US/COPPA, under 16 in parts of EEA/GDPR-K), ads must either remain completely disabled or serve strictly non-personalized context-only ads from family-certified networks.
3. **Parental Consent Warning**:
   - The Google User Messaging Platform (UMP) SDK manages cookie and consent strings for GDPR/CCPA, but **UMP does NOT constitute verified parental consent** under COPPA. Do not treat UMP completion as parental consent.

### Scenario B: General Audience (Mixed Audience)
If targeting both children and adults:
1. The app must implement the neutral age screen on initial launch prior to any ad initialization.
2. For players verified as adults, personalized or non-personalized ads may be served subject to regional consent (UMP).
3. For players under the age of consent or undeclared, ads remain disabled or strictly child-safe.

### Scenario C: Unmonetized / Ad-Free Release
- The app can be released with `AdConfig.disabledConfig`. In this mode, no ad requests are made, hints are provided with the free offline fallback, and no SDK tracking occurs.

---

## 2. Local vs. Third-Party Data Processing

### Locally Persisted Gameplay Data (Device Storage Only)
The game operates completely offline. The following items are stored exclusively on the user's device via `SharedPreferences`:
- Level completion status (levels 1-50).
- In-progress board state (active parcels and move history for resuming puzzles).
- User preferences: sound toggle, haptic feedback toggle, reduced motion toggle, selected theme.
- In-game hint balances.
- Privacy & age declarations.

> [!NOTE]
> Resetting gameplay progress in Settings strictly preserves the user's age category and privacy selections.

### Third-Party SDK Data Processing (When Ads Are Enabled)
Even though game state is strictly local, developers cannot truthfully state "No data collected" in the Google Play Data Safety form if an advertising SDK is active.
When Google Mobile Ads SDK is compiled and active:
- The SDK may process IP addresses (for geolocation routing and fraud prevention), device identifiers (AAID, Android ID), performance diagnostics, and app interaction telemetry.
- In `AdMode.disabled`, the SDK is not initialized, preventing network tracking.

---

## 3. Permissions Audit (Merged Manifest)

The application manifest (`android/app/src/main/AndroidManifest.xml`) does **NOT** request any dangerous or sensitive Android permissions:
- `android.permission.CAMERA`: **NOT REQUESTED**
- `android.permission.RECORD_AUDIO`: **NOT REQUESTED**
- `android.permission.ACCESS_FINE_LOCATION`: **NOT REQUESTED**
- `android.permission.ACCESS_COARSE_LOCATION`: **NOT REQUESTED**
- `android.permission.READ_CONTACTS`: **NOT REQUESTED**
- `android.permission.READ_EXTERNAL_STORAGE` / `WRITE_EXTERNAL_STORAGE`: **NOT REQUESTED**

Network permissions (`INTERNET`, `ACCESS_NETWORK_STATE`) are declared for optional offline/online connectivity checks and ad SDK operation.

---

## 4. Consent Flow & Privacy Options Entry Point

1. **User Messaging Platform (UMP)**:
   - When transitioning from `disabled` to `test` or `live`, the owner must configure their AdMob account privacy messages (GDPR, US State Privacy, IDFA).
2. **In-App Privacy Options Entry Point**:
   - A permanent privacy options entry point is available to players at any time via:
     `Home -> Settings -> Privacy Information & Choices` (opens [`PrivacySheet`](file:///e:/study%20File/Games/Arrow-Escape-Puzzl/lib/src/screens/privacy_sheet.dart)).
   - Allows users to review disclosures and re-declare or inspect their age tier.
