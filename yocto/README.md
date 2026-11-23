# MooshRevolt for Yocto

This layer packages MooshRevolt for flutter-pi on Yocto Project 6.0
(Wrynose). It builds a release AOT bundle with the SDK and engine provided
by [meta-flutter](https://github.com/meta-flutter/meta-flutter). The tested
meta-flutter revision is `46ef6e3b1b5c92a283f6ae340438bf05b57c584d`
on its `wrynose` branch.

Add both layers to your build:

```sh
bitbake-layers add-layer /path/to/meta-flutter
bitbake-layers add-layer /path/to/moosh-revolt-multimeter/yocto
```

Select a matching Flutter SDK and engine in your build configuration:

```conf
INIT_MANAGER = "systemd"
DISTRO_FEATURES:append = " bluetooth opengl"
FLUTTER_SDK_TAG = "3.47.8"
PACKAGECONFIG:append:pn-flutter-engine = " release"
PREFERRED_VERSION_flutter-pi = "git%"
```

Run `bitbake moosh-revolt` to build the package. Add `moosh-revolt` to your
image's `IMAGE_INSTALL` to install it. Launch `moosh-revolt` from a target
console with DRM, input and BlueZ access. The board supplies the kernel,
display and Bluetooth controller support.

The recipe pins the tested app commit with `SRCREV`. Update that pin after
validating the new app revision with the selected Flutter SDK.

The layer metadata is [MIT licensed](COPYING.MIT). The package builds
[MooshRevolt under GPL-3.0-only](../LICENSE).
