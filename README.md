# Parcel Escape: Arrow Puzzle

**Parcel Escape: Arrow Puzzle** is a polished, offline-first 2D casual mobile puzzle game built with Flutter and Dart. Players clear warehouse parcels from a rectangular grid by tapping arrow-marked boxes in the correct order to guide them off the board edge.

---

## Game Overview & Rules

- **Grid Coordinates**: Row 0 is at the top edge; Column 0 is at the left edge.
- **Exit Ray**: When a parcel is tapped, the puzzle engine projects a discrete ray through every cell in the parcel's arrow direction (Up, Down, Left, or Right) towards the edge of the board.
- **Clear Exit**: If the exit ray contains no other parcels, the parcel animates straight out of the board and is removed from the active grid.
- **Blocked Bump**: If ANY parcel blocks the ray, a gentle bump animation plays in the arrow direction without moving either parcel or mutating the board state.
- **Empty Cells**: Empty cells are completely passable. Parcels do not slide into empty gaps and stop; they either exit completely or remain in place.
- **Solvability Invariant**: Successful moves only remove blockers for other parcels. Any legal move on a solvable board preserves solvability. There is no penalty or deadlock caused by choosing one valid removal order over another.
- **Input Serialization**: Touch inputs are strictly serialized during exit animations, preventing double taps, duplicate rewards, or race conditions.
- **Level Completion**: A level is complete when all parcels have been routed off the board.

---

## Architecture & Technology Stack

```
lib/
  main.dart                           # Application entry point & theme initialization
  src/
    config/
      ad_config.dart                  # Centralized AdMob config (disabled/test/live modes)
    models/
      direction.dart                  # Direction enum (up, down, left, right) & angles
      grid_position.dart              # Immutable (row, col) coordinates
      parcel.dart                     # Immutable parcel model (id, pos, dir, colorType)
      game_move.dart                  # Move record for undo stack & replay
      level_data.dart                 # Versioned level definition with integrity validation
      save_data.dart                  # Local save state with corrupted-file recovery
      board_theme.dart                # Theme definitions (Classic, Air Express, Eco Cargo)
    engine/
      board_matrix.dart               # Fast 2D spatial indexing matrix
      ray_cast.dart                   # Deterministic discrete ray-casting
      puzzle_engine.dart              # Pure puzzle engine decoupled from rendering
      puzzle_solver.dart              # Independent greedy & branch solver
      level_generator.dart            # Seeded reverse-insertion level generator
    controllers/
      game_controller.dart            # Central game controller (ChangeNotifier)
      audio_controller.dart           # Sound effects & haptics with lifecycle pause/resume
    services/
      storage_service.dart            # SharedPreferences local persistence
      ad_service.dart                 # AdService abstraction (Disabled, Fake, AdMob)
      level_repository.dart           # Level loader with bundle & memory caching
    rendering/
      arrow_path_builder.dart         # Procedural vector arrow Path generator
      parcel_painter.dart             # CustomPainter for delivery parcel boxes
      board_painter.dart              # CustomPainter for board tray and cell depressions
      particle_effect.dart            # Celebration confetti overlay (reduced motion aware)
    screens/
      home_screen.dart                # Title, logo, stats summary, Play button
      gameplay_screen.dart            # Main gameplay board, HUD, Hint/Undo/Restart
      level_select_screen.dart        # 50-level grid with completed/locked states
      settings_screen.dart            # Sound/haptics/theme toggles & pause menu
      tutorial_overlay.dart           # Contextual onboarding banners (Levels 1-3)
      level_complete_dialog.dart      # Win celebration, Next Level, Replay, Home
      privacy_sheet.dart              # Privacy transparency & neutral age screening
```

### Why Each Dependency Is Needed

1. **`shared_preferences: ^2.2.2`**:
   Provides robust, local, cross-platform key-value persistence for game saves, completed levels, undo history, theme selection, and privacy declarations.
2. **`audioplayers: ^5.2.1`**:
   Lightweight audio playback for the 4 procedurally generated local sound effects (`tap.wav`, `exit.wav`, `bump.wav`, `win.wav`), with full background pause/resume lifecycle control.
3. **`google_mobile_ads: ^4.0.0`**:
   Official Google Mobile Ads plugin implementing AdMob monetization with explicit Disabled, Test, and Live modes, frequency capping, and rewarded hint callbacks.

---

## Setup, Run, and Test Commands

### 1. Prerequisites
- **Flutter SDK**: 3.16.x or newer
- **Dart SDK**: 3.2.x or newer
- **Android SDK**: API 34 (compileSdkVersion 34, targetSdkVersion 34, minSdkVersion 21)
- **Java**: JDK 17

### 2. Dependency Resolution
```powershell
flutter pub get
```

### 3. Static Analysis
Run static analysis to verify zero errors, warnings, or lint issues:
```powershell
flutter analyze
```

### 4. Running the Test Suite
Run all 41 unit, engine, solver, generation, ad service, and widget navigation tests:
```powershell
flutter test
```

### 5. Running Shipped Level Generation & Verification Tools
- Regenerate and validate the 50 shipped levels in `assets/levels/levels.json`:
  ```powershell
  dart run tool/generate_shipped_levels.dart
  ```
- Regenerate the 4 procedural PCM WAV audio files in `assets/audio/`:
  ```powershell
  dart run tool/generate_audio.dart
  ```
- Run the 1,000-seed procedural generator test:
  ```powershell
  flutter test test/level_generation_test.dart
  ```

### 6. Building for Android
- **Debug APK**:
  ```powershell
  flutter build apk --debug
  ```
- **Release App Bundle (Google Play)**:
  ```powershell
  flutter build appbundle --release
  ```

---

## Replacing Branding, Package ID, Icons & Ad IDs

### 1. App Name
- **Android Display Name**: Change `android:label` in [`android/app/src/main/AndroidManifest.xml`](file:///e:/study%20File/Games/Arrow-Escape-Puzzl/android/app/src/main/AndroidManifest.xml).
- **In-App Name**: Change title in [`lib/main.dart`](file:///e:/study%20File/Games/Arrow-Escape-Puzzl/lib/main.dart) and [`lib/src/screens/home_screen.dart`](file:///e:/study%20File/Games/Arrow-Escape-Puzzl/lib/src/screens/home_screen.dart).

### 2. Package / Application ID
Update the package ID in:
- [`android/app/build.gradle`](file:///e:/study%20File/Games/Arrow-Escape-Puzzl/android/app/build.gradle): `applicationId "your.package.name"` and `namespace "your.package.name"`.
- [`android/app/src/main/kotlin/.../MainActivity.kt`](file:///e:/study%20File/Games/Arrow-Escape-Puzzl/android/app/src/main/kotlin/com/parcellogic/arrowpuzzle/parcel_escape/MainActivity.kt): update package declaration.

### 3. App Launcher Icons
Replace PNGs in `android/app/src/main/res/mipmap-*/ic_launcher.png` or use the `flutter_launcher_icons` tool.

### 4. AdMob Configuration & IDs
- Replace the sample Application ID in [`android/app/src/main/AndroidManifest.xml`](file:///e:/study%20File/Games/Arrow-Escape-Puzzl/android/app/src/main/AndroidManifest.xml):
  ```xml
  <meta-data
      android:name="com.google.android.gms.ads.APPLICATION_ID"
      android:value="ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX"/>
  ```
- Replace the ad unit IDs in [`lib/src/config/ad_config.dart`](file:///e:/study%20File/Games/Arrow-Escape-Puzzl/lib/src/config/ad_config.dart).
- Switch the ad mode in [`lib/main.dart`](file:///e:/study%20File/Games/Arrow-Escape-Puzzl/lib/main.dart) from `DisabledAdService` to `AdMobAdService` only after completing audience and privacy reviews.

---

## Release Signing Configuration

To sign release builds for Google Play without checking secrets into version control:

1. Generate a keystore:
   ```powershell
   keytool -genkey -v -keystore release-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias parcel_escape_key
   ```
2. Create `android/key.properties` (this file is excluded from Git via `.gitignore`):
   ```properties
   storePassword=<KEYSTORE_PASSWORD>
   keyPassword=<KEY_PASSWORD>
   keyAlias=parcel_escape_key
   storeFile=../release-keystore.jks
   ```
3. `android/app/build.gradle` automatically loads `key.properties` when present, signing with the release key, and falling back safely to debug signing if not configured.

---

## Documentation Links

- [`PRIVACY_NOTES.md`](file:///e:/study%20File/Games/Arrow-Escape-Puzzl/PRIVACY_NOTES.md): Audience policies, COPPA/Families gates, local data handling, and third-party SDK transparency.
- [`RELEASE_CHECKLIST.md`](file:///e:/study%20File/Games/Arrow-Escape-Puzzl/RELEASE_CHECKLIST.md): Launch checklist and owner decision gates.
- [`ASSET_LICENSES.md`](file:///e:/study%20File/Games/Arrow-Escape-Puzzl/ASSET_LICENSES.md): Provenance of all vector paths and procedural sound effects.
