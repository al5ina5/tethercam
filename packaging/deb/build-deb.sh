#!/bin/bash
# Build a Debian package for TetherCam.
#   packaging/deb/build-deb.sh            -> dist/tethercam_<ver>_amd64.deb
set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
VERSION="$(tr -d ' \n' < "$REPO/VERSION")"
ARCH=amd64
PKG=tethercam
OUT="$REPO/dist"
ROOT="$OUT/${PKG}_${VERSION}_${ARCH}"

command -v dpkg-deb >/dev/null || { echo "dpkg-deb not found" >&2; exit 1; }

rm -rf "$ROOT"
mkdir -p "$ROOT/DEBIAN" \
         "$ROOT/usr/bin" \
         "$ROOT/usr/lib/systemd/user" \
         "$ROOT/usr/lib/udev/rules.d" \
         "$ROOT/usr/share/applications" \
         "$ROOT/usr/share/doc/$PKG" \
         "$ROOT/etc/modprobe.d" \
         "$ROOT/etc/modules-load.d"

# payload
install -m755 "$REPO/scripts/tethercam"        "$ROOT/usr/bin/tethercam"
install -m755 "$REPO/scripts/tethercam-daemon" "$ROOT/usr/bin/tethercam-daemon"
sed 's|%h/.local/bin/tethercam-daemon|/usr/bin/tethercam-daemon|' \
  "$REPO/packaging/systemd/tethercam.service" > "$ROOT/usr/lib/systemd/user/tethercam.service"
chmod 644 "$ROOT/usr/lib/systemd/user/tethercam.service"
install -m644 "$REPO/packaging/desktop/tethercam.desktop" "$ROOT/usr/share/applications/tethercam.desktop"
install -m644 "$REPO/packaging/udev/99-tethercam.rules"   "$ROOT/usr/lib/udev/rules.d/99-tethercam.rules"
install -m644 "$REPO/packaging/modprobe/zz-tethercam.conf"     "$ROOT/etc/modprobe.d/zz-tethercam.conf"
install -m644 "$REPO/packaging/modules-load/tethercam.conf"    "$ROOT/etc/modules-load.d/tethercam.conf"
install -m644 "$REPO/LICENSE" "$ROOT/usr/share/doc/$PKG/copyright"

# debian changelog (required by policy)
{
  printf '%s (%s) unstable; urgency=medium\n\n' "$PKG" "$VERSION"
  printf '  * Release %s.\n\n' "$VERSION"
  printf ' -- al5ina5 <al5ina5@users.noreply.github.com>  %s\n' \
    "$(date -R)"
} | gzip -9n > "$ROOT/usr/share/doc/$PKG/changelog.Debian.gz"

# control
cat > "$ROOT/DEBIAN/control" <<EOF
Package: $PKG
Version: $VERSION
Section: video
Priority: optional
Architecture: $ARCH
Depends: android-tools-adb, ffmpeg, zenity, pipewire-pulse | pulseaudio, pipewire-bin, pulseaudio-utils, v4l2loopback-dkms, curl, ca-certificates
Recommends: android-sdk-platform-tools-common
Maintainer: al5ina5 <al5ina5@users.noreply.github.com>
Homepage: https://github.com/al5ina5/tethercam
Description: Use any Android as a webcam and microphone
 TetherCam turns any Android phone into a standard webcam (/dev/video42,
 "TetherCam") and microphone ("TetherCam") for OBS, Discord, Meet and Zoom,
 over USB or WiFi. No phone app, no account, no cloud.
EOF

# maintainer scripts
cat > "$ROOT/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e
if command -v udevadm >/dev/null 2>&1; then udevadm control --reload-rules || true; fi
if command -v modprobe >/dev/null 2>&1 && ! lsmod | grep -q '^v4l2loopback'; then
  modprobe v4l2loopback 2>/dev/null || true
fi
# Enable the per-user service for everyone; the udev rule starts it on plug.
if [ -d /run/systemd/system ] && command -v systemctl >/dev/null 2>&1; then
  systemctl --global enable tethercam.service >/dev/null 2>&1 || true
fi
exit 0
EOF

cat > "$ROOT/DEBIAN/prerm" <<'EOF'
#!/bin/sh
set -e
if [ -d /run/systemd/system ] && command -v systemctl >/dev/null 2>&1; then
  systemctl --global disable tethercam.service >/dev/null 2>&1 || true
fi
exit 0
EOF

cat > "$ROOT/DEBIAN/postrm" <<'EOF'
#!/bin/sh
set -e
if command -v udevadm >/dev/null 2>&1; then udevadm control --reload-rules || true; fi
exit 0
EOF

chmod 755 "$ROOT/DEBIAN/postinst" "$ROOT/DEBIAN/prerm" "$ROOT/DEBIAN/postrm"

dpkg-deb --build --root-owner-group "$ROOT" "$OUT/${PKG}_${VERSION}_${ARCH}.deb" >/dev/null
echo "built: $OUT/${PKG}_${VERSION}_${ARCH}.deb"
