#!/bin/bash
# TetherCam installer - Linux Mint / Ubuntu. No phone app needed.
set -euo pipefail
REPO="$(cd "$(dirname "$0")" && pwd)"
SCRCPY_VER=4.1
SCRCPY_URL="https://github.com/Genymobile/scrcpy/releases/download/v${SCRCPY_VER}/scrcpy-linux-x86_64-v${SCRCPY_VER}.tar.gz"
SCRCPY_SHA256="ad56ae8bfeedf41e824945c11dbf55fcb092b3e615b9b486f48a50e30d389635"
SCRCPY_DIR="$HOME/.local/share/scrcpy-4.1"

die() { echo "tethercam: $*" >&2; exit 1; }

# --- dependencies ------------------------------------------------------------
missing=()
need() { command -v "$1" >/dev/null 2>&1 || missing+=("$2"); }
need adb      android-tools-adb
need ffmpeg   ffmpeg
need zenity   zenity
need systemctl systemd
need pactl    pipewire-pulse
need pw-link  pipewire
need curl     curl
need tar      tar
need sha256sum coreutils
need sudo     sudo
if [ "${#missing[@]}" -gt 0 ]; then
  die "missing packages: ${missing[*]}
  install with: sudo apt install ${missing[*]}"
fi
pactl info 2>/dev/null | grep PipeWire >/dev/null \
  || die "TetherCam needs PipeWire (pipewire-pulse). This machine is not running PipeWire."
lsmod 2>/dev/null | grep '^v4l2loopback' >/dev/null \
  || die "missing kernel module v4l2loopback (sudo apt install v4l2loopback-dkms)"

# --- scrcpy (checksum-pinned official release, fetched once) -----------------
if [ ! -x "$SCRCPY_DIR/scrcpy" ]; then
  echo "fetching official scrcpy v$SCRCPY_VER ..."
  tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
  curl -fsSL -o "$tmp/scrcpy.tar.gz" "$SCRCPY_URL"
  echo "$SCRCPY_SHA256  $tmp/scrcpy.tar.gz" | sha256sum -c - || die "scrcpy checksum mismatch"
  mkdir -p "$SCRCPY_DIR"
  tar -xzf "$tmp/scrcpy.tar.gz" -C "$SCRCPY_DIR" --strip-components=1
fi

# --- scripts -----------------------------------------------------------------
mkdir -p "$HOME/.local/bin"
install -m755 "$REPO/scripts/tethercam"        "$HOME/.local/bin/tethercam"
install -m755 "$REPO/scripts/tethercam-daemon" "$HOME/.local/bin/tethercam-daemon"
# drop files from the previous multi-script layout
rm -f "$HOME/.local/bin/tethercam-ui" "$HOME/.local/bin/tethercam-app" \
      "$HOME/.local/bin/tethercam-pair" "$HOME/.local/bin/tethercam-front" \
      "$HOME/.local/bin/tethercam-back" "$HOME/.local/bin/tethercam-auto" \
      "$HOME/.local/bin/tethercam-stop"
for old in phoneCam phoneCam-ui phoneCam-front phoneCam-back phoneCam-auto phoneCam-stop; do
  rm -f "$HOME/.local/bin/$old"
done
rm -f "$HOME"/.local/bin/phoneCam*
mkdir -p "$HOME/.config/tethercam"
[ -f "$HOME/.config/tethercam/lens" ] || echo front > "$HOME/.config/tethercam/lens"

# --- systemd user service ----------------------------------------------------
mkdir -p "$HOME/.config/systemd/user"
install -m644 "$REPO/packaging/systemd/tethercam.service" "$HOME/.config/systemd/user/"
rm -f "$HOME/.config/systemd/user/tethercam-replug.service" \
      "$HOME/.config/systemd/user/phoneCam.service"

# --- udev + kernel module ----------------------------------------------------
sudo cp "$REPO/packaging/udev/99-tethercam.rules" /etc/udev/rules.d/
sudo cp "$REPO/packaging/modprobe/zz-tethercam.conf" /etc/modprobe.d/
sudo cp "$REPO/packaging/modules-load/tethercam.conf" /etc/modules-load.d/
sudo rm -f /etc/modprobe.d/phoneCam.conf /etc/modprobe.d/tethercam.conf
sudo udevadm control --reload-rules
if [ ! -e /dev/video42 ]; then
  sudo modprobe -r v4l2loopback 2>/dev/null || true
  sudo modprobe v4l2loopback
fi

# --- desktop entry -----------------------------------------------------------
mkdir -p "$HOME/.local/share/applications"
sed "s|Exec=tethercam|Exec=$HOME/.local/bin/tethercam|g" \
  "$REPO/packaging/desktop/tethercam.desktop" > "$HOME/.local/share/applications/tethercam.desktop"
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true

systemctl --user daemon-reload
systemctl --user enable tethercam.service
systemctl --user restart tethercam.service

echo
echo "done. Plug in a phone (USB debugging authorized), then run:  tethercam"
echo "In OBS: camera 'TetherCam'  /  mic 'TetherCam'"
