# TetherCam

**Plug in any Android. Get a webcam and a microphone.**

One-command Linux webcam + mic from any Android, over USB or WiFi. No phone
app, no account, no cloud. Plug a Droid in and it appears as:

* a standard webcam - `TetherCam` (`/dev/video42`)
* a standard microphone - `TetherCam`

for OBS, Discord, Meet, Zoom. Unplug and they are gone.

Built on official [scrcpy](https://github.com/Genymobile/scrcpy) (see NOTICE).
MIT licensed.

## Status: working alpha

Proven on SM-G990U (Android 15) and SM-G781U (Android 13). The app is two
buttons: **Front | Back**. Switching lenses never interrupts the microphone.
Mic is always on - no toggle, no beta label.

## Requirements

Linux with PipeWire (Mint/Ubuntu), `adb`, `ffmpeg`, `zenity`, `v4l2loopback`.
`install.sh` checks all of this and tells you exactly what is missing.

## Install

**Linux Mint / Ubuntu - `.deb` (double-click).** Download from
[Releases](https://github.com/al5ina5/tethercam/releases) and double-click the
`.deb`, or:

```bash
sudo apt install ./tethercam_0.1.0_amd64.deb
```

**One line (from source):**

```bash
curl -fsSL https://raw.githubusercontent.com/al5ina5/tethercam/main/packaging/install-online.sh | bash
```

**From a clone:**

```bash
./install.sh
```

Then plug in a phone (USB debugging authorized) and run `tethercam`.
In OBS: camera `TetherCam`, mic `TetherCam`.

## Commands

```
tethercam                    open the control panel
tethercam front|back|auto    switch camera
tethercam start|stop         start/stop streaming
tethercam status             one-line status
tethercam doctor             diagnose anything that looks wrong
tethercam pair|forget        wireless ADB pairing
tethercam snapshot [path]    save a frame
tethercam version            print the version
```

## Wireless (same pipeline)

`tethercam pair` while on USB: the phone pairs over WiFi (`adb tcpip`, endpoint
saved). Unplug whenever - the daemon fails over to WiFi on its own. USB wins
whenever a cable is present.

## Devices

Two user-facing devices: camera `TetherCam` and mic `TetherCam`. The mic needs
a small helper sink under the hood (`TetherCam Sink`); some audio apps
(pavucontrol, Cinnamon Sound, OBS's *Desktop Audio* dropdown) still list it.
It is never the default, and the phone mic never routes through it - it is
plumbing only.

## Layout

* `scripts/tethercam` - the CLI and control panel (one entry point)
* `scripts/tethercam-daemon` - the supervisor for camera + mic
* `tests/test-routing.sh` - regression tests
* `packaging/` - udev, modprobe, systemd, desktop entry
* `app/` - cross-platform GUI, not part of the Linux install yet

## Uninstall

```bash
./uninstall.sh
```
