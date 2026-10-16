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

Tagged Android releases require these repository secrets:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`
- `ANDROID_STORE_PASSWORD`

The release workflow reconstructs its temporary keystore and
`android/key.properties` at runtime. Both local signing files are ignored by
Git and must never be committed.
