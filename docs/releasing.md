# Releases and CI/CD

GitHub Actions and Gitea Actions use the shared workflows in
[`../.github/workflows`](../.github/workflows). They install Flutter 3.47.1
through `subosito/flutter-action@v2`, avoiding a dependency on a third-party
Flutter container tag while satisfying this project's `^3.12.2` Dart SDK
constraint.

Pushes and pull requests resolve dependencies, analyze and test the app,
compile the CSV logger, and build Linux plus Android debug artifacts. On
GitHub, CI also builds an unsigned macOS app bundle; Gitea skips that job
because its Docker-based runner has no macOS host. A `v*`
tag publishes a Linux bundle and signed Android APK with SHA-256 checksums.

For Gitea, enable repository Actions and register an Act Runner with Docker
access. Configure a `GITEA_TOKEN` repository secret with release-creation
permission.

On GitHub, tagged releases also attach `MooshRevolt-<version>-macos.dmg`,
built by [`tools/build_dmg.sh`](../tools/build_dmg.sh). The image is signed
and notarized when these optional secrets are set; without them it carries
an ad-hoc signature and users allow it once in System Settings:

- `MACOS_CERTIFICATE_P12_BASE64` and `MACOS_CERTIFICATE_PASSWORD`: a
  "Developer ID Application" certificate exported as `.p12`
- `APPLE_ID`, `APPLE_TEAM_ID` and `APPLE_APP_PASSWORD` (an app-specific
  password) for notarization

## App icon

Every platform icon is rendered from
[`assets/branding/mooshrevolt_icon.svg`](../assets/branding/mooshrevolt_icon.svg),
which shows the Mooshimeter's translucent body, board and copper jacks. After
changing it, regenerate the macOS, Linux/Flatpak, Android, web and Windows
icons. The logo inside the app is drawn in code
(`lib/widgets/mooshrevolt_mark.dart`) without the tile, in the theme's
colors, so keep the two in step:

```sh
DYLD_FALLBACK_LIBRARY_PATH=/opt/homebrew/lib \
  uv run --with cairosvg --with pillow tools/generate_icons.py
```

The script needs the Cairo library (`brew install cairo`, or `libcairo2` on
Debian/Ubuntu).

## Android signing

Tagged Android releases require these repository secrets:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`
- `ANDROID_STORE_PASSWORD`

The release workflow reconstructs its temporary keystore and
`android/key.properties` at runtime. Both local signing files are ignored by
Git and must never be committed.
