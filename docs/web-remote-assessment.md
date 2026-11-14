# Web/WASM and appliance remote access assessment

## Build evidence

The app builds successfully with Flutter 3.44.9 / Dart 3.12.2 using:

```sh
flutter build web --wasm --no-pub --output=/tmp/moosh-revolt-web-assessment
```

This is compilation evidence, not verification of browser runtime behavior,
hardware communication, or remote operation. The pinned `universal_ble` 2.3.0
and `flutter_web_bluetooth` 1.1.0 dependencies compile in this configuration.
Flutter's [WASM documentation](https://docs.flutter.dev/platform-integration/web/wasm)
describes the build target and browser/dependency compatibility requirements.

## Current runtime boundaries

- Operator config is a native startup feature. The conditional web loader is
  a no-op; a browser cannot read `/etc`, `/data`, or the service environment.
- `ContinuityTone` calls `Platform.isAndroid` and `Platform.isLinux` directly.
  In particular, the device screen invokes `stop()` on disposal, which contains
  an unguarded platform check. Web needs conditional audio implementations or
  safe no-op behavior before this path is usable reliably.
- Screenshot, CSV, and continuity WAV code use `File`, `Directory`, native
  document directories, or processes. Web needs browser download/audio paths
  or disabled actions. Successful compilation does not make these APIs work.
- The current web BLE implementation uses `requestDevice()` inside `startScan`.
  Startup discovery cannot assume that a browser will allow an unattended
  device chooser. Web Bluetooth requires secure-context and user-interaction
  handling; see [Chrome's Bluetooth API documentation](https://developer.chrome.com/docs/capabilities/bluetooth).
  Browser device identifiers also must not be treated as Linux MAC addresses.

## Ownership of the Bluetooth connection

A web app opened on a laptop or phone uses that browser's Bluetooth adapter.
It does not obtain access to the appliance's BlueZ connection by being served
from the appliance. For independently laid-out local and remote UIs sharing
the appliance's meter, one native owner must hold the BLE connection and expose
readings, device state, and controlled commands through an authenticated API.
The existing protocol package and provider boundaries are potential reuse
points; introducing such an API is separate work, not part of startup config.

WayVNC can instead expose the existing native application's display and input
without another BLE backend. It shares the same session and UI, including the
480-by-320 layout; it does not provide an independently responsive remote
dashboard. Its documented target is a compatible wlroots-based compositor;
verify the image's actual compositor rather than assuming Weston or direct
DRM embeddings are supported. Browser access also needs a VNC web client and
appropriate transport/authentication integration. See the
[WayVNC project](https://github.com/any1/wayvnc).

The near-term integration option is the native app plus compatible remote
session access. An independent WASM dashboard is feasible follow-up work after
native-only UI services are separated and connection ownership is defined.
No backend rewrite or remote access service is implemented by these changes.
