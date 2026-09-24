#!/bin/bash
# TetherCam uninstaller - removes everything install.sh put down.
set -uo pipefail

systemctl --user disable --now tethercam.service 2>/dev/null || true
systemctl --user disable --now phoneCam.service 2>/dev/null || true
pkill -f "^$HOME/.local/share/scrcpy-4.1/scrcpy .*v4l2-sink=/dev/video42" 2>/dev/null || true
pkill -f "^$HOME/.local/share/scrcpy-4.1/scrcpy .*--audio-source=mic" 2>/dev/null || true

# Remove the virtual mic/sink so no phantom devices are left behind.
if command -v pactl >/dev/null 2>&1; then
  pactl list modules 2>/dev/null | awk '
    /^Module #/ { i=$2 }
    /Argument:.*Tether(Sink|Mic)/ { gsub(/#/, "", i); print i }' |
    while read -r m; do pactl unload-module "$m" 2>/dev/null || true; done
fi

rm -f "$HOME/.local/bin/tethercam" "$HOME/.local/bin/tethercam-daemon" \
      "$HOME/.local/bin/tethercam-ui" "$HOME/.local/bin/tethercam-app" \
      "$HOME/.local/bin/tethercam-pair" "$HOME/.local/bin/tethercam-front" \
      "$HOME/.local/bin/tethercam-back" "$HOME/.local/bin/tethercam-auto" \
      "$HOME/.local/bin/tethercam-stop"
for old in phoneCam phoneCam-ui phoneCam-front phoneCam-back phoneCam-auto phoneCam-stop; do
  rm -f "$HOME/.local/bin/$old"
done
rm -f "$HOME"/.local/bin/phoneCam*

rm -f "$HOME/.config/systemd/user/tethercam.service" \
      "$HOME/.config/systemd/user/tethercam-audio.service" \
      "$HOME/.config/systemd/user/tethercam-replug.service" \
      "$HOME/.config/systemd/user/phoneCam.service"
rm -f "$HOME/.local/share/applications/tethercam.desktop" \
      "$HOME/.local/share/applications/phoneCam.desktop"

sudo rm -f /etc/udev/rules.d/99-tethercam.rules /etc/udev/rules.d/99-phoneCam.rules \
           /etc/modprobe.d/tethercam.conf /etc/modprobe.d/phoneCam.conf \
           /etc/modprobe.d/zz-tethercam.conf /etc/modules-load.d/tethercam.conf
sudo udevadm control --reload-rules 2>/dev/null || true
systemctl --user daemon-reload 2>/dev/null || true

echo "uninstalled: scripts, service, udev/modprobe rules, TetherSink + TetherMic removed."
echo "kept: ~/.config/tethercam (your lens/wifi choice) and ~/.local/share/scrcpy-4.1."
