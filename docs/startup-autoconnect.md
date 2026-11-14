# Startup autoconnect regression evidence

Affected code: `e37be6621f02fd6303f9ae67006a7e57f826f532` and the local
pre-fix `1ff8af9` tree. These are application startup-selection bugs, not
defects established in `universal_ble` or the Linux Bluetooth stack.

## Reproductions and expected behavior

1. Remember meter A with autoconnect enabled; advertise meter B with a name
   containing `mooshim`. The old scan accepts B by name. Startup must select
   only a remembered, enabled address, case-insensitively, regardless of name.
2. Mark a remembered device `autoConnect: false` and return it from system
   devices. The old system-device branch still connects. Disabled devices must
   never be selected automatically.
3. Disable autoconnect on every remembered device. The old
   `getFirstRemembered()` falls back to the first disabled entry. It must return
   `null` when no enabled entry exists.
4. Start discovery with no matching advertisements, or continuously advertise
   unrelated devices. The old `await for` has no five-second deadline. The scan
   must stop after one overall five-second window, release its subscription,
   and request platform scan cleanup. Unrelated events must not restart the
   deadline. System-device lookup and platform scan cleanup have their own
   bounded waits, so total startup time can exceed five seconds.

The startup scan listener is registered before calling `startScan`, so the first
advertisement is not lost. ScanScreen is mounted after startup discovery ends,
preventing its automatic scan from competing with that discovery. When multiple
remembered meters are enabled, an exact matching system device is preferred;
otherwise the first matching scan advertisement wins. Names never select a
startup target. Manual device selection remains available after discovery.

`test/startup_autoconnect_test.dart` reproduces the selection and deadline
cases using injected transport operations, with no real BLE hardware. It also
covers scan errors and a stalled platform `startScan` call.

## Existing report search

Public GitHub issue searches for this repository and autoconnect did not return
an equivalent report during this investigation. A direct `gh issue list`
attempt failed with HTTP 401, so the issue inventory could not be verified
completely. No issue was filed and no remote changes were made. These focused
application fixes and tests are suitable for submission to the app repository;
there is no dependency workaround to retain or upstream dependency fix to drop.
