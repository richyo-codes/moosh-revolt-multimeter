# Operator startup configuration

On Linux, MooshRevolt reads `/etc/moosh-revolt/config.json` at startup if it
exists. Set `MOOSHREVOLT_CONFIG` to read a different file, for example:

```sh
MOOSHREVOLT_CONFIG=/data/config/moosh-revolt/config.json /usr/bin/mooshrevolt
```

The configuration is read once, validated completely, and applied after saved
UI preferences. Omitted settings inherit saved preferences, then application
defaults. It does not modify the JSON file or write operator overrides to saved
preferences. Restart the app to reload changes.

An absent default file is optional. An explicitly selected file must exist and
be readable. Empty/whitespace-only `MOOSHREVOLT_CONFIG`, unreadable files,
malformed JSON, and validation errors abort startup before the app starts
discovery or connects to a meter. The app does not fall back to saved targets
after a configuration error. The service journal receives the startup error.

Other native platforms only read a file when `MOOSHREVOLT_CONFIG` is set. Web
builds do not read the appliance's filesystem or environment.

## Schema version 1

All fields are optional. Unknown fields, explicit `null`, incorrect types,
unsupported values, and duplicate device addresses are rejected. Settings use
JSON booleans and integers, not strings.

| Field | Accepted value | App default without saved preferences |
| --- | --- | --- |
| `schemaVersion` | Integer `1` | Version 1 |
| `autoConnect` | Boolean | `true` |
| `skipUpgrade` | Boolean | `false` |
| `sampleRateHz` | Integer: `125`, `250`, `500`, `1000`, `2000`, `4000`, `8000` | `125` |
| `graphMaxPoints` | Integer from `2` through `100000` | `300` |
| `darkMode` | Boolean (`true`: dark, `false`: light) | `false` |
| `showFloatingReadings` | Boolean | `false` |
| `rememberedDevices` | Array of device objects; replaces the saved list | Empty list |

`graphMaxPoints` bounds in-memory graph history in points per channel, not
seconds or persistent logs. `skipUpgrade` exposes the existing UI preference;
it does not add firmware upgrade execution or new channel configuration.

Each device requires `address` and `name`. The address must be six hexadecimal
octets separated by colons, such as `00:11:22:33:44:55`. Addresses are
case-insensitive and normalized to uppercase. Names must be nonempty after
trimming and are labels, never discovery selectors. Optional `autoConnect`
must be a boolean and defaults to `true`. No other device fields are accepted.

A safe initial appliance configuration is:

```json
{"schemaVersion": 1, "autoConnect": false, "rememberedDevices": []}
```

A preconfigured example (replace the illustrative address before enabling
global autoconnect):

```json
{
  "schemaVersion": 1,
  "autoConnect": false,
  "sampleRateHz": 125,
  "graphMaxPoints": 300,
  "darkMode": true,
  "showFloatingReadings": false,
  "rememberedDevices": [
    {
      "address": "00:11:22:33:44:55",
      "name": "Bench meter",
      "autoConnect": true
    }
  ]
}
```

## Session and storage behavior

When `rememberedDevices` is supplied, it replaces the entire effective list,
including when it is `[]`. Automatic remembering after a connection and UI
edits to that list remain session-only. Removing the operator file restores
the original saved list. This prevents a routine connection from persisting
operator targets or flags as user preferences.

UI edits to individual scalar settings still use their existing persistence
behavior. A configured value takes precedence again on the next launch; an
omitted value uses its saved UI preference. The configuration is startup
preconfiguration, not a locked policy or a complete channel/range preset.

The `/data` partition, its mount dependency, permissions, journald limits, and
service environment belong to the image integration. The config path alone
does not relocate user preferences, screenshots, CSV exports, or logs.
Linux preferences use `shared_preferences` via the XDG application-support
directory: set `XDG_DATA_HOME` under `/data/state/moosh-revolt` in the app
service environment; the plugin adds its application identifier or executable
subdirectory. Verify the resulting path with the selected image/plugin version.
CSV and screenshots use the XDG documents directory; configure that separately
if they must live on `/data`. Journald handles stdout/stderr independently.

## Validation

```sh
flutter analyze
flutter test
```

`test/startup_config_test.dart` covers precedence, validation, explicit-file
failures, unchanged saved preferences after automatic remembering, and normal
UI persistence without an operator device list.
