# Tagged releases

Push a `v*` tag (for example `v1.2.3`) to run the release workflow. GitHub
publishes the release after the Android APK, Linux GTK3 archive, GTK3 Flatpak,
Linux GTK4 archive, and GTK4 Flatpak all build successfully. Each download has
a SHA-256 checksum; the publishing job verifies the checksums before making
the draft public. Tags containing a hyphen are marked as prereleases.

The GTK4 job reuses the normal GTK4 build workflow and its pinned SDK/engine.
It is called by the release workflow for tags, avoiding a duplicate standalone
GTK4 tag build. Branch and pull request GTK4 checks continue independently.

Android signing requires the existing `ANDROID_KEYSTORE_BASE64`,
`ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`, and `ANDROID_STORE_PASSWORD`
repository secrets. GitHub publishing uses `GITHUB_TOKEN` with `contents: write`.
A failed required build leaves the GitHub release unpublished; rerun failed
jobs after resolving the problem. Generated release notes accompany the release.

The existing Gitea release flow remains separate and does not include GTK4.
