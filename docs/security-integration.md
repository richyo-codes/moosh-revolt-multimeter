# Fork security integration

The merge preserves all 26 original sorny commits through reviewed head
`db2b165d7bb26dca3bffcd70df1ec7fe6d7bb491`. Security fixes are separate
follow-up commits; the original contributor history is not rewritten.

| Review item | Integration status |
| --- | --- |
| MR-01 exporter lifecycle race | Fixed with serialized transitions, generation invalidation, stale-socket cleanup, and actual/transition UI state. Deterministic and real-socket regressions pass. |
| MR-02 metrics exposure | Intentional opt-in plaintext endpoint retained. Defaults remain disabled and loopback-only. Remote scraping needs deployment access controls as described in `prometheus.md`. |
| MR-03 CLI option matching | Fixed: exact names are preserved, and numeric equivalence requires successfully parsed finite numbers. Unknown options fail before a write. |
| MR-04 startup identity selection | The existing local exact-address/enabled-device fix is retained. Names do not select startup targets. Address equality is not cryptographic authentication. |
| MR-05 frame buffering | Inherited finding remains open: invalid leading node handling and explicit receive resource/time limits need separate protocol work. |
| MR-06 tree resource limits | Inherited finding remains open: bounded decompression, depth/node budgets, and complete-input validation need separate protocol work. |

The CLI regression fixture deliberately uses illustrative chooser names,
including `OFF`, `ONESHOT`, and `CONTINUOUS`. It is not presented as a captured
physical meter tree. `test/chooser_option_test.dart` also checks mode/analysis
names, numeric rates/ranges, descriptive errors, correct write indices, and no
writes for unresolved options. `tool/mooshimeter_log.dart` compiles as a pure
Dart executable. Physical meter configuration has not been verified here.

Mobile integration coverage includes portrait phones, landscape phones,
480-by-320 displays, tablet/desktop sizes, English/French readings, both themes,
enlarged text, and full-screen versus docked channel configuration. A Linux
release and an Android debug APK build successfully. macOS compilation,
Bluetooth hardware, deployed firewall behavior, and actual PDF opening remain
platform/hardware verification work.
