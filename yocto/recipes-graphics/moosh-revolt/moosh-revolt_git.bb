# SPDX-License-Identifier: MIT
SUMMARY = "MooshRevolt Mooshimeter Bluetooth multimeter client for flutter-pi"
HOMEPAGE = "https://github.com/richyo-codes/moosh-revolt-multimeter"
LICENSE = "GPL-3.0-only"
LIC_FILES_CHKSUM = "file://LICENSE;md5=75d892af193fd5a298f724c4377d8f62"

SRC_URI = "git://github.com/richyo-codes/moosh-revolt-multimeter.git;protocol=https;branch=main"
SRCREV = "e37be6621f02fd6303f9ae67006a7e57f826f532"
PV = "1.0.0+git"

# Builds the app, path dependency packages/mooshimeter_ble, and Dart plugin
# registrant against the same Flutter revision as flutter-engine. Do not use
# the independent prebuilt flutter-pi-engine recipe with this app.
inherit flutter-app features_check

PUBSPEC_APPNAME = "moosh_revolt"
FLUTTER_APPLICATION_PATH = ""
FLUTTER_APP_RUNTIME_MODES = "release"
PUBSPEC_IGNORE_LOCKFILE = "0"
REQUIRED_DISTRO_FEATURES = "bluetooth opengl systemd"
COMPATIBLE_HOST = "(aarch64|x86_64).*-linux"

# VM testing uses the upstream mock meter provider. Both compilation stages
# must receive the define: meta-flutter regenerates kernel IR before AOT.
MOOSHREVOLT_MOCK ?= "0"
FLUTTER_BUILD_ARGS:append = " ${@'--dart-define=MOOSHREVOLT_MOCK=true' if d.getVar('MOOSHREVOLT_MOCK') == '1' else ''}"
APP_AOT_EXTRA:append = " ${@'-DMOOSHREVOLT_MOCK=true' if d.getVar('MOOSHREVOLT_MOCK') == '1' else ''}"

RDEPENDS:${PN} += "flutter-pi bluez5 dbus liberation-fonts"

# meta-flutter's flutter-pi is built with FILESYSTEM_LAYOUT=meta-flutter and
# consumes the versioned data/ and lib/ bundle produced by flutter-app.
do_install:append() {
    install -d ${D}${bindir}
    cat > ${D}${bindir}/moosh-revolt <<EOF
#!/bin/sh
exec ${bindir}/flutter-pi --release ${FLUTTER_INSTALL_DIR}/${FLUTTER_SDK_VERSION}/release "\$@"
EOF
    chmod 0755 ${D}${bindir}/moosh-revolt
}
