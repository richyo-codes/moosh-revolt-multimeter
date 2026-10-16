# UX review

A review of MooshRevolt's interface and navigation, done on macOS at desktop
(1280 × 800) and phone (390 × 844) sizes in light and dark themes. Findings
are ordered by their likely impact on the user, not by the effort to fix
them. Each one lists the problem, why it matters, and the fix.

Status: **Fixed** issues are resolved in the code; **Open** issues are
proposals.

## Critical: wrong or missing information

### 1. Measurement modes did not configure the meter — Fixed

- **Problem:** Diode Drop, Auxiliary Voltage, the AC modes and Internal
  Temperature wrote hard-coded indices that selected the wrong input or none
  at all. Only one resistance range was ever used.
- **Why it matters:** The screen showed a mode name and plausible numbers
  that were not that measurement. For a multimeter, this is the worst
  possible failure.
- **Fix:** Modes, ranges and analysis are chosen by name from the meter's
  configuration tree, and the result was verified on a Mooshimeter V.1.

### 2. No overload state — Fixed

- **Problem:** A saturated input showed a number, for example 1265.95 Ω for
  open probes. "OUT OF RANGE" was based on fixed 10 A/600 V limits whatever
  the mode.
- **Why it matters:** The user read a clipped value as a measurement.
- **Fix:** Readings above 120% of the active range show **OL**, as on bench
  meters. They appear as gaps in the chart and as "OL" in CSV exports.

### 3. Readout claimed precision it did not have — Fixed

- **Problem:** Every value showed 5 decimals, and the SI prefix jumped with
  the value.
- **Why it matters:** False precision misleads, and moving digits are hard to
  read at a glance.
- **Fix:** The decimal point and prefix are fixed by the range. The digit
  count follows the ADC resolution at the current sample rate.

## High: friction in the main workflow

### 4. Fixed split between readings and chart — Fixed

- **Problem:** The readings took a fixed 40% of the screen, and on desktop
  each card was about 70% empty. The chart could not grow.
- **Why it matters:** The chart carries the most information. Users who
  watch a trend could not trade the readings' empty space for chart area.
- **Fix:** A draggable divider sits between the panes. It shows a resize
  cursor, can be nudged with the arrow keys, and resets on double-click. The
  split is saved, and the menu has **Maximize chart / Restore layout**.

### 5. The value did not use its card — Fixed

- **Problem:** A 36 px number sat in a 500 × 350 card, and phone cards used
  20 px.
- **Why it matters:** The primary affordance of a meter is a number you can
  read from across the bench.
- **Fix:** The value scales to fill the available space, in both the compact
  and the full card.

### 6. The chart had no time axis — Fixed

- **Problem:** The chart showed no time labels.
- **Why it matters:** Nobody could tell when an event happened or how much
  history was on screen.
- **Fix:** Wall-clock ticks are aligned to round times, with a step that
  adapts from seconds to 10 minutes.

### 7. Chart history depended on the sample rate — Fixed

- **Problem:** The chart kept "300 points", which covered about 2.5 minutes
  at 125 Hz but only about 9 s at high rates.
- **Why it matters:** The same setting meant different things. It also made
  the chart feel jumpy at high rates.
- **Fix:** A time window of 10 s to 1 h, saved as a preference. Long windows
  are drawn as a min/max envelope.

### 8. Range and auto-ranging were invisible — Fixed

- **Problem:** The active range was not shown anywhere, and the CH1 range
  control was a fake chip.
- **Why it matters:** A meter's range defines what a reading means.
- **Fix:** Each card shows a range chip, for example **Auto · 60 V**. Tapping
  it opens the channel configuration, which offers the meter's real ranges.

### 9. A hidden channel could not be shown again — Fixed

- **Problem:** The only control to show a channel lived on that channel's
  card, which disappeared when the channel was hidden.
- **Why it matters:** The user had no way back.
- **Fix:** The legend chips toggle each channel and are always visible.
  There are also explicit **Show CH1/CH2** buttons.

### 10. Preferences were lost on restart — Fixed

- **Problem:** Channel visibility, modes, units, graph style and continuity
  options reset on every launch.
- **Why it matters:** Users had to repeat their setup each session.
- **Fix:** All of these are saved and restored. Saved modes are applied
  before the meter connects.

### 11. Continuity tone lagged the display — Fixed

- **Problem:** The chart showed continuity before the beep started.
- **Why it matters:** Probing relies on immediate audio feedback.
- **Fix:** A native low-latency tone on macOS. The tone is evaluated per
  sample, and the range is held while the tone is on.

## Medium: unclear affordances and navigation

### 12. Overflow menu was an unordered list — Fixed

- **Problem:** Nine items mixed view, acquisition, files and connection,
  without icons, and Disconnect was the last item.
- **Why it matters:** Users scan the menu; without groups, everything has to
  be read.
- **Fix:** Items are grouped (chart and acquisition, files, app and link)
  with icons and dividers.

### 13. Graph View duplicated the chart as a frozen snapshot — Fixed

- **Problem:** Graph View opened a static copy of the chart with its own time
  buttons (30/60/300/All). Those conflicted with the chart history setting,
  and its colors broke dark mode.
- **Why it matters:** There were two charts with different rules, and the
  "full view" stopped updating.
- **Fix:** Graph View is removed and replaced by **Maximize chart**, which
  stays live.

### 14. One icon, two meanings — Fixed

- **Problem:** The same "tune" icon opened the meter settings (app bar) and
  the channel configuration (cards).
- **Why it matters:** Identical icons imply identical actions.
- **Fix:** Meter settings now uses a chip icon. "Tune" stays with the
  channels.

### 15. Channel sheet covered the reading being adjusted — Fixed

- **Problem:** The sheet was always 85% high, mostly empty, and hid the live
  value.
- **Why it matters:** Users changing a range or mode got no feedback.
- **Fix:** The sheet sizes to its content and shows the live reading in its
  header.

### 16. Saved files were hard to find — Fixed

- **Problem:** Snapshots went to the sandbox container, and the app reported
  them as a long path in a snackbar.
- **Why it matters:** A saved file the user cannot find is effectively not
  saved.
- **Fix:** Files are saved to `Downloads/MooshRevolt` on desktop, and the
  snackbar has a **Show** action that reveals the file in Finder or the file
  manager.

### 17. Settings only reachable from the scan screen — Fixed

- **Problem:** Settings, including the theme, could only be opened before
  connecting.
- **Why it matters:** Users had to disconnect to change the theme.
- **Fix:** Settings is in the meter screen's menu.

### 18. Platform-specific action shown everywhere — Fixed

- **Problem:** "Copy CSV logger command" appeared on macOS and Android,
  although the logger only runs on Linux with BlueZ.
- **Fix:** The action is shown on Linux only.

## Low: polish

### 19. Dead and broken settings — Fixed

- **Problem:** "Skip firmware check" controlled nothing, and tapping the BLE
  UUID row did nothing (it was a `TODO`).
- **Fix:** The dead switch is removed, and tapping the UUID copies it.

### 20. "…" buttons used for value pickers — Fixed

- **Problem:** The sample rate and chart history settings used "more" icons
  instead of showing their current value.
- **Fix:** Dropdowns that show the current value.

### 21. Theme could not follow the system — Fixed

- **Problem:** The theme was a light/dark switch only.
- **Fix:** **System / Light / Dark**, defaulting to System.

### 22. Footer counted samples but hid the acquisition rate — Fixed

- **Fix:** The footer shows "125 Hz · N samples".

### 23. Small hit targets in compact cards — Open

- **Problem:** The compact header icons are 28 px wide, below the 44–48 px
  touch guideline.
- **Fix:** Merge the unit and min/max controls into one 48 px menu button in
  compact cards.

### 24. Min/max has no reset or average — Open

- **Problem:** Tracking can only be turned off and on again to reset it.
- **Fix:** Add a reset action, and show the average alongside min/max.

### 25. Scan screen repeats its device count — Open

- **Problem:** The "Found 1 device(s)" banner and the "1 found" chip say the
  same thing, and the raw device UUID dominates each row.
- **Fix:** Drop the chip, and show the UUID in a smaller, secondary style.
