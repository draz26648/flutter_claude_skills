---
name: golden-tests
description: Conventions for Flutter golden tests as a design-fidelity guard — multi-device sets, theme and locale coverage, and the rule that regenerated goldens require visual review before commit. Use this whenever adding or modifying a widget, whenever a test fails with a golden mismatch, whenever asked to add tests for UI, and whenever a screen has just been verified against a design. Trigger it proactively after finishing UI work, because a screen that matches the design today drifts within weeks unless the match is frozen in a test.
---

# Golden Tests

Visual verification proves a screen matches today. Goldens are what stop it drifting
tomorrow. Every widget that renders something visible gets one.

## Structure

```
test/goldens/
├── flutter_test_config.dart      # font loading, once, for all golden tests
├── components/
│   ├── primary_button_test.dart
│   └── goldens/                   # generated PNGs, committed
└── screens/
    ├── login_screen_test.dart
    └── goldens/
```

## The matrix

Each golden test covers the axes that actually break layouts:

- **Devices** — one small phone (360x640), one large phone (430x932), one tablet if the
  app supports it
- **Themes** — light and dark
- **Text scale** — 1.0 and 2.0
- **Locale and direction** — LTR and RTL if the app ships Arabic or Hebrew

Full cross-product is too many images to review. Cover 1.0/light/LTR on every device,
then one variant each for dark, 2.0 text scale, and RTL. That catches the real failures
without generating sixty files nobody looks at.

## Writing one

```dart
void main() {
  testGoldens('PrimaryButton renders across states', (tester) async {
    final builder = DeviceBuilder()
      ..overrideDevicesForAllScenarios(devices: [Device.phone, Device.tabletPortrait])
      ..addScenario(widget: const PrimaryButton(label: 'Continue'), name: 'default')
      ..addScenario(widget: const PrimaryButton(label: 'Continue', isLoading: true), name: 'loading')
      ..addScenario(widget: const PrimaryButton(label: 'Continue', onPressed: null), name: 'disabled');

    await tester.pumpDeviceBuilder(builder, wrapper: materialAppWrapper(theme: AppTheme.light));
    await screenMatchesGolden(tester, 'primary_button_light');
  });
}
```

Load real fonts in `flutter_test_config.dart`. Without it every golden renders in
Ahem — solid black boxes — and the test verifies layout while proving nothing about
typography.

## The regeneration rule

```bash
flutter test --update-goldens
```

This command is how design drift enters a codebase. It always makes the tests pass,
which means a failing golden is only useful if someone looks at what changed.

Never run it as a reflex when a test fails. First determine whether the change was
intended. If it was, regenerate, then **open the changed PNGs and look at them** before
committing. If a golden changed and nobody can say why, that is a bug being committed,
not a test being updated.

In review, treat changed golden files as changed code.

## Common mistakes

- Wrapping every scenario in its own `MaterialApp` with an ad-hoc theme instead of a
  shared wrapper. The goldens then test the wrapper, not the widget.
- Goldens containing dates, timers, or random data. Freeze the clock and seed the data
  or the test fails on its own schedule.
- Not awaiting image loading. Network images render as blank space; use a fake image
  provider so the golden is deterministic.
- Committing goldens generated on a different platform. Font rasterization differs
  between macOS and Linux — generate them in CI, or pin the platform.
