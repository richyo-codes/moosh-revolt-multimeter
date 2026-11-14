# UI verification

MooshRevolt uses deterministic widget tests for the responsive meter workspace
and integration screenshots for visual review. The widget suite is run in CI;
the screenshot suite is intended for local review and release assets.

## Responsive widget report

Run the normal test suite to verify the following contract:

```sh
flutter test
```

| Scenario | Viewport | Assertions |
| --- | --- | --- |
| Phone portrait | 390 × 844 | Stacked readings, portrait workspace, MooshRevolt title |
| Landscape/tablet | 844 × 390 | Secondary actions remain in the overflow menu |
| Desktop | 1280 × 800 | Readings and dual-axis graph share one landscape row |
| Signal unavailable | 390 × 844 | RSSI is omitted while battery and sample status remain visible |
| Appearance | Settings screen | Theme offers System, Light and Dark under Settings → Appearance |
| Resizable layout | 1400 × 800 | Dragging the divider resizes, clamps to 15–70%, and double-click resets |
| Channel configuration | 1280 × 800 / 390 × 844 | Docks as a non-modal side panel that Esc closes; opens as a full-screen page on phones |

The test output itself is the machine-readable pass/fail report. Use
`flutter test --reporter expanded` when attaching an explicit test log to a
release or issue.

## Visual screenshot report

The integration test renders the real meter screen with simulated readings
in these scenarios, which also illustrate the README:

| File | Viewport | Shows |
| --- | --- | --- |
| `alternator-check-mobile-light.png` | 390 × 844 | Phone portrait, alternator check |
| `alternator-check-landscape-light.png` | 844 × 390 | Compact landscape cards |
| `meter-desktop-light.png` | 1280 × 800 | Desktop with the real-power math channel |
| `meter-desktop-dark-config.png` | 1280 × 800 | Dark theme, docked CH1 configuration |
| `waveform-desktop-dark.png` | 1280 × 800 | Waveform view of a 50 Hz mains capture |
| `meter-guide-light.png` | 1280 × 800 | Meter guide: jacks, ranges and recipes |

```sh
flutter test integration_test/marketing_screenshots_test.dart -d linux
```

Screenshots are written to `build/marketing_screenshots/` by default. Override
the output directory when collecting a release report:

```sh
flutter test integration_test/marketing_screenshots_test.dart -d linux \
  --dart-define=MARKETING_SCREENSHOT_DIR=build/ui-report
```

On macOS the test runs inside the sandboxed app, so point the output at the
app container and copy the files from there:

```sh
OUT=~/Library/Containers/ca.richyoung.mooshrevolt/Data/tmp/shots
flutter test integration_test/marketing_screenshots_test.dart -d macos \
  --dart-define=MARKETING_SCREENSHOT_DIR=$OUT
cp "$OUT"/*.png docs/images/
```

Review all generated PNGs before publishing screenshots or making broad visual
changes. They intentionally use simulated readings and do not need a physical
Mooshimeter.

The findings behind the current layout and navigation are recorded in
[UX review](ux-review.md).
