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
| Appearance | Settings screen | Dark mode is available only under Settings → Appearance |

The test output itself is the machine-readable pass/fail report. Use
`flutter test --reporter expanded` when attaching an explicit test log to a
release or issue.

## Visual screenshot report

The integration test captures a deterministic alternator/under-hood scenario
in desktop dark, mobile light, and compact-landscape light layouts:

```sh
flutter test integration_test/marketing_screenshots_test.dart -d linux
```

Screenshots are written to `build/marketing_screenshots/` by default. Override
the output directory when collecting a release report:

```sh
flutter test integration_test/marketing_screenshots_test.dart -d linux \
  --dart-define=MARKETING_SCREENSHOT_DIR=build/ui-report
```

Review all generated PNGs before publishing screenshots or making broad visual
changes. They intentionally use simulated readings and do not need a physical
Mooshimeter.
