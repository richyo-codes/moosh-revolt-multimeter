# Releases and CI/CD

GitHub Actions and Gitea Actions use the shared workflows in
[`../.github/workflows`](../.github/workflows). They install Flutter 3.47.1
through `subosito/flutter-action@v2`, avoiding a dependency on a third-party
Flutter container tag while satisfying this project's `^3.12.2` Dart SDK
constraint.

Pushes and pull requests resolve dependencies, analyze and test the app,
compile the CSV logger, and build Linux plus Android debug artifacts. A `v*`
tag creates a draft GitHub release with a Linux bundle and signed Android APK
with SHA-256 checksums.

Flatpak packaging runs in a separate optional job. It downloads the archived
Linux bundle from the build job and uses `tools/build_flatpak.sh --skip-build`,
so it needs no Flutter installation or recompilation. A successful tagged
Flatpak job attaches its bundle and checksum to the existing release. A failed
Flatpak job does not block Linux/Android artifacts or release creation.
The Flatpak runner still needs permission to create Bubblewrap namespaces.

For Gitea, enable repository Actions and register an Act Runner with Docker
access. Configure a `GITEA_TOKEN` repository secret with release-creation
permission.

Tagged Android releases require these repository secrets:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`
- `ANDROID_STORE_PASSWORD`

The release workflow reconstructs its temporary keystore and
`android/key.properties` at runtime. Both local signing files are ignored by
Git and must never be committed.
