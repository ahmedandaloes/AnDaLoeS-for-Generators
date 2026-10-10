# Google Maps Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `flutter_map` + OpenStreetMap tiles with `google_maps_flutter` for a premium, familiar Google Maps experience.

**Architecture:** Swap the `FlutterMap` widget in `map_screen.dart` for `GoogleMap`. Keep the same governorate-center coordinate lookup (`_govCoords`) — no DB migration needed. Add the API key to AndroidManifest and AppDelegate.swift. Remove `flutter_map` and `latlong2` packages after migration.

**Tech Stack:** Flutter 3.44.3, `google_maps_flutter ^2.9.0`, Supabase Flutter v2, Riverpod v2

## Global Constraints

- Working directory for flutter commands: `app/`
- `flutter analyze --no-fatal-infos` must report zero errors before commit
- `withValues(alpha:)` not deprecated `.withOpacity()`
- File max 800 lines
- Commit format: `feat(map): <description>`
- Every new user-facing string → both `app/lib/l10n/app_en.arb` AND `app/lib/l10n/app_ar.arb`
- NEVER commit `app/lib/l10n/app_localizations*.dart` (gitignored)
- No service_role key anywhere — anon/publishable key only
- API key goes in AndroidManifest.xml and AppDelegate.swift, NOT in Dart code

---

### Task 0: Get Google Maps API Key (user action — no code)

**Files:** None (user action in Google Cloud Console)

**Interfaces:**
- Produces: `GOOGLE_MAPS_API_KEY` string used in Task 1 and Task 2

- [ ] **Step 1: Create API key**

Go to https://console.cloud.google.com/apis/credentials  
Create a new API key.

- [ ] **Step 2: Enable required APIs**

In Google Cloud Console → APIs & Services → Library, enable:
- **Maps SDK for Android**
- **Maps SDK for iOS**

- [ ] **Step 3: Restrict the key (recommended)**

Under the API key settings, restrict by:
- Application restrictions: Android apps + iOS apps
- API restrictions: Maps SDK for Android + Maps SDK for iOS

Copy the key value — you'll need it in Tasks 1 and 2.

---

### Task 1: Add package + Android API key

**Files:**
- Modify: `app/pubspec.yaml`
- Modify: `app/android/app/src/main/AndroidManifest.xml`

**Interfaces:**
- Consumes: `GOOGLE_MAPS_API_KEY` from Task 0
- Produces: `GoogleMap` widget available to import as `package:google_maps_flutter/google_maps_flutter.dart`

- [ ] **Step 1: Write a test that imports google_maps_flutter**

Create `app/test/core/google_maps_import_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() {
  test('google_maps_flutter LatLng type exists', () {
    const point = LatLng(30.0444, 31.2357);
    expect(point.latitude, closeTo(30.0444, 0.0001));
  });
}
```

- [ ] **Step 2: Run test — expect FAIL**

```bash
cd app && flutter test test/core/google_maps_import_test.dart
```
Expected: `FAILED` — "Target of URI doesn't exist: 'package:google_maps_flutter/google_maps_flutter.dart'"

- [ ] **Step 3: Add google_maps_flutter to pubspec.yaml**

In `app/pubspec.yaml`, under `dependencies:`, add after `cached_network_image`:
```yaml
  google_maps_flutter: ^2.9.0
```

Then run:
```bash
cd app && flutter pub get
```
Expected: `Process finished with exit code 0` — package downloaded.

- [ ] **Step 4: Run test — expect PASS**

```bash
cd app && flutter test test/core/google_maps_import_test.dart
```
Expected: `PASSED`

- [ ] **Step 5: Add API key to AndroidManifest.xml**

In `app/android/app/src/main/AndroidManifest.xml`, inside `<application ...>` (before the `<activity>` tag), add:
```xml
        <!-- Google Maps API key — replace YOUR_KEY_HERE with actual key -->
        <meta-data
            android:name="com.google.android.geo.API_KEY"
            android:value="YOUR_GOOGLE_MAPS_API_KEY_HERE"/>
```

Replace `YOUR_GOOGLE_MAPS_API_KEY_HERE` with the actual key from Task 0.

- [ ] **Step 6: Verify flutter analyze is clean**

```bash
cd app && flutter analyze --no-fatal-infos
```
Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
cd /Users/andaloes/AnDaLoeS-for-Generators && git add app/pubspec.yaml app/android/app/src/main/AndroidManifest.xml app/test/core/google_maps_import_test.dart && git commit -m "feat(map): add google_maps_flutter package + Android API key"
```

---

### Task 2: Add iOS API key in AppDelegate.swift

**Files:**
- Modify: `app/ios/Runner/AppDelegate.swift`

**Interfaces:**
- Consumes: `GOOGLE_MAPS_API_KEY` from Task 0
- Produces: Google Maps SDK initialized on iOS at app launch

- [ ] **Step 1: Write a test for AppDelegate configuration**

This is a platform file — we verify it compiles clean instead of unit-testing it.
```bash
cd app && flutter build ios --no-codesign --no-pub 2>&1 | tail -5
```
Before the change, this should succeed without error (or fail with a different error, not related to GMSServices).

- [ ] **Step 2: Read AppDelegate.swift**

```bash
cat app/ios/Runner/AppDelegate.swift
```

- [ ] **Step 3: Add GMSServices initialization**

The file will look like:
```swift
import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

Change it to:
```swift
import UIKit
import Flutter
import GoogleMaps

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_API_KEY_HERE")
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

Replace `YOUR_GOOGLE_MAPS_API_KEY_HERE` with the actual key from Task 0.

- [ ] **Step 4: Run pod install**

```bash
cd app/ios && pod install --repo-update 2>&1 | tail -5
```
Expected: `Pod installation complete!`

- [ ] **Step 5: Add ios/Runner/AppDelegate.swift to .gitignore exception**

In `app/.gitignore`, add after `!ios/Runner/Info.plist`:
```
!ios/Runner/AppDelegate.swift
```

- [ ] **Step 6: Commit**

```bash
cd /Users/andaloes/AnDaLoeS-for-Generators && git add -f app/ios/Runner/AppDelegate.swift app/app/.gitignore 2>/dev/null; git add -f app/ios/Runner/AppDelegate.swift app/.gitignore && git commit -m "feat(map): add Google Maps iOS API key in AppDelegate"
```

---

### Task 3: Rewrite map_screen.dart with GoogleMap widget

**Files:**
- Modify: `app/lib/features/generators/presentation/screens/map_screen.dart`
- Test: `app/test/features/generators/map_screen_test.dart`

**Interfaces:**
- Consumes: `google_maps_flutter` (Task 1), `generatorRepositoryProvider` (existing), `_govCoords` map (kept from existing file), `AppLocalizations` (existing)
- Produces: `MapScreen` widget — same route `/map`, same `GoRoute` registration in `app_router.dart`, same `_GeneratorMapCard` bottom sheet on marker tap

- [ ] **Step 1: Write failing widget test**

Create `app/test/features/generators/map_screen_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:andaloes/features/generators/presentation/screens/map_screen.dart';

void main() {
  testWidgets('MapScreen renders without crashing', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: MapScreen()),
      ),
    );
    // Shows loading or map — either is valid
    expect(find.byType(MapScreen), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test — expect FAIL**

```bash
cd app && flutter test test/features/generators/map_screen_test.dart
```
Expected: FAIL (import errors or GoogleMap platform channel issues in test env — acceptable for platform widget)

- [ ] **Step 3: Rewrite map_screen.dart**

Replace the full content of `app/lib/features/generators/presentation/screens/map_screen.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../data/repositories/generator_repository.dart';

// Approximate center coordinates for Egyptian governorates
const _govCoords = <String, LatLng>{
  'Cairo': LatLng(30.0444, 31.2357),
  'Giza': LatLng(30.0131, 31.2089),
  'Alexandria': LatLng(31.2001, 29.9187),
  'Sharqia': LatLng(30.7374, 31.7217),
  'Dakahlia': LatLng(31.1656, 31.4913),
  'Beheira': LatLng(30.8480, 30.3436),
  'Qalyubia': LatLng(30.3292, 31.2169),
  'Monufia': LatLng(30.5966, 30.9876),
  'Gharbia': LatLng(30.8754, 31.0344),
  'Kafr el-Sheikh': LatLng(31.1107, 30.9388),
  'Damietta': LatLng(31.4165, 31.8133),
  'Ismailia': LatLng(30.5965, 32.2715),
  'Port Said': LatLng(31.2653, 32.3019),
  'Suez': LatLng(29.9668, 32.5498),
  'North Sinai': LatLng(30.2832, 33.6116),
  'South Sinai': LatLng(28.9590, 33.5938),
  'Red Sea': LatLng(27.2579, 33.8116),
  'Matrouh': LatLng(31.3543, 27.2373),
  'Fayyum': LatLng(29.3084, 30.8428),
  'Beni Suef': LatLng(29.0661, 31.0994),
  'Minya': LatLng(28.1099, 30.7503),
  'Asyut': LatLng(27.1809, 31.1837),
  'Sohag': LatLng(26.5591, 31.6957),
  'Qena': LatLng(26.1551, 32.7160),
  'Luxor': LatLng(25.6872, 32.6396),
  'Aswan': LatLng(24.0889, 32.8998),
  'New Valley': LatLng(25.4481, 29.2077),
};

final _mapGeneratorsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.read(generatorRepositoryProvider).fetchForMap();
});

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  GoogleMapController? _mapController;
  Map<String, dynamic>? _selected;

  static const _egypt = LatLng(26.8206, 30.8025);
  static const _initialZoom = 6.0;

  LatLng _coordsFor(Map<String, dynamic> gen) {
    final gov = gen['governorate']?.toString() ?? '';
    final city = gen['city']?.toString() ?? '';
    return _govCoords[gov] ?? _govCoords[city] ?? const LatLng(30.0444, 31.2357);
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Set<Marker> _buildMarkers(
      List<Map<String, dynamic>> generators, ColorScheme cs) {
    return generators.map((g) {
      final id = g['id']?.toString() ?? g.hashCode.toString();
      final coords = _coordsFor(g);
      final isSelected = _selected?['id'] == g['id'];
      return Marker(
        markerId: MarkerId(id),
        position: coords,
        icon: isSelected
            ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure)
            : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selected = g);
          _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(coords, 10.0),
          );
        },
      );
    }).toSet();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context)!;
    final generatorsAsync = ref.watch(_mapGeneratorsProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(l.generatorMap),
        backgroundColor: cs.surface.withValues(alpha: 0.92),
        elevation: 0,
      ),
      body: generatorsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const AppErrorState(),
        data: (generators) => Stack(
          children: [
            GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: _egypt,
                zoom: _initialZoom,
              ),
              onMapCreated: (ctrl) => _mapController = ctrl,
              markers: _buildMarkers(generators, cs),
              onTap: (_, [__]) {
                if (_ is LatLng) setState(() => _selected = null);
              },
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
            ),

            // Count badge bottom-left
            Positioned(
              bottom: _selected != null ? 200 : 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: cs.surface.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: cs.shadow.withValues(alpha: 0.1),
                        blurRadius: 8),
                  ],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.bolt, size: 14, color: cs.primary),
                  const SizedBox(width: 4),
                  Text(
                    '${generators.length} generators',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface),
                  ),
                ]),
              ),
            ),

            // Re-center button
            Positioned(
              bottom: _selected != null ? 200 : 16,
              right: 16,
              child: FloatingActionButton.small(
                heroTag: 'recenter',
                backgroundColor: cs.surface,
                foregroundColor: cs.primary,
                onPressed: () => _mapController?.animateCamera(
                  CameraUpdate.newLatLngZoom(_egypt, _initialZoom),
                ),
                child: const Icon(Icons.my_location_outlined),
              ),
            ),

            // Selected generator card
            if (_selected != null)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _GeneratorMapCard(
                  generator: _selected!,
                  cs: cs,
                  onClose: () => setState(() => _selected = null),
                  onView: () => context.push(
                      AppRoutes.generatorDetail(_selected!['id'].toString())),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GeneratorMapCard extends StatelessWidget {
  const _GeneratorMapCard({
    required this.generator,
    required this.cs,
    required this.onClose,
    required this.onView,
  });
  final Map<String, dynamic> generator;
  final ColorScheme cs;
  final VoidCallback onClose;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final photo = (generator['photos'] as List?)?.isNotEmpty == true
        ? generator['photos'][0].toString()
        : null;
    final score =
        (generator['avg_score'] as num?)?.toStringAsFixed(1) ?? '–';
    final location = [
      generator['city']?.toString(),
      generator['governorate']?.toString(),
    ].where((v) => v != null && v.isNotEmpty).join(', ');

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: cs.shadow.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, -4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: cs.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: photo != null
                    ? CachedNetworkImage(
                        imageUrl: photo,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _placeholder(cs))
                    : _placeholder(cs),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      generator['title']?.toString() ?? 'Generator',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(Icons.location_on_outlined,
                          size: 13, color: cs.onSurfaceVariant),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(location,
                            style: TextStyle(
                                fontSize: 12, color: cs.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${generator['capacity_kva']} KVA',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: cs.primary),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.star_rounded,
                          size: 14, color: Colors.amber.shade600),
                      const SizedBox(width: 2),
                      Text(score,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text(
                        'EGP ${generator['price_per_day']}/day',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: cs.primary),
                      ),
                    ]),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onClose,
                tooltip: l.close,
                icon: const Icon(Icons.close),
                iconSize: 18,
                style: IconButton.styleFrom(
                  backgroundColor: cs.surfaceContainerHighest,
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: FilledButton.icon(
              onPressed: onView,
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: Text(l.viewDetails),
              style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder(ColorScheme cs) {
    return Container(
      width: 72,
      height: 72,
      color: cs.primaryContainer,
      child: Icon(Icons.bolt, size: 32, color: cs.primary),
    );
  }
}
```

- [ ] **Step 4: Remove flutter_map and latlong2 from pubspec.yaml**

In `app/pubspec.yaml`, delete these two lines:
```yaml
  flutter_map: ^7.0.2
  latlong2: ^0.9.0
```

Run:
```bash
cd app && flutter pub get
```

- [ ] **Step 5: Run flutter analyze**

```bash
cd app && flutter analyze --no-fatal-infos
```
Expected: `No issues found!`

If errors: any remaining `flutter_map`/`latlong2` imports will surface — remove them.

- [ ] **Step 6: Run tests**

```bash
cd app && flutter test --no-pub
```
Expected: all tests pass (the new map test may skip as a platform test — that's acceptable).

- [ ] **Step 7: Build APK to verify end-to-end compilation**

```bash
cd app && flutter build apk --debug --no-pub 2>&1 | tail -3
```
Expected: `✓ Built build/app/outputs/flutter-apk/app-debug.apk`

- [ ] **Step 8: Commit**

```bash
cd /Users/andaloes/AnDaLoeS-for-Generators && git add app/pubspec.yaml app/lib/features/generators/presentation/screens/map_screen.dart app/test/features/generators/map_screen_test.dart && git commit -m "feat(map): replace flutter_map with google_maps_flutter"
```

---

## Self-Review

**Spec coverage:**
- ✅ Package added (Task 1)
- ✅ Android API key (Task 1)
- ✅ iOS API key (Task 2)
- ✅ Map screen rewritten (Task 3)
- ✅ Old packages removed (Task 3)
- ✅ Same bottom card UX preserved
- ✅ Same marker tap → detail navigation

**Placeholder scan:** None found.

**Type consistency:** `LatLng` from `google_maps_flutter` used consistently throughout. `GoogleMapController` not `MapController`. `CameraUpdate.newLatLngZoom` not `_mapController.move`.

**Note:** `GoogleMap.onTap` callback signature is `(LatLng)`, not `(_, __)`. The implementation uses a checked cast — verify during compile step.
