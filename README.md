# TetherCam

**Turn any Android phone into a webcam and microphone for your Linux PC.**

No app on the phone. No account, no cloud, no watermark. Plug in USB (or pair
over WiFi) and pick **TetherCam** in your app - that is the whole setup.

[![release](https://img.shields.io/github/v/release/al5ina5/tethercam)](https://github.com/al5ina5/tethercam/releases)
[![license](https://img.shields.io/github/license/al5ina5/tethercam)](LICENSE)
![platform](https://img.shields.io/badge/platform-Linux-blue)

---

## Why TetherCam

- **Nothing to install on the phone.** No companion app, no Play Store, no
  root, no sign-up - just enable USB debugging.
- **Instant install.** A `.deb` for Mint and Ubuntu (double-click), or one
  `curl` line. No build step, no toolchain.
- **Zero configuration.** Plug in, run `tethercam`, choose "TetherCam".
- **Camera and microphone**, both as normal system devices, so any app works.
- **Switch front/back without dropping the mic** - the camera re-inits for a
  second or two.
- **USB or WiFi.** After a one-time `tethercam pair`, unplug and it fails over
  to WiFi on its own; USB wins whenever it is plugged in.
- **Free and open source** (MIT). No telemetry, no time limit.

> Replacing DroidCam, Iriun or a USB capture card? This is the zero-app option
> for Linux.

## Install

**Linux Mint / Ubuntu - `.deb` (double-click).** Download from
[Releases](https://github.com/al5ina5/tethercam/releases) and open the `.deb`,
or:

```bash
sudo apt install ./tethercam_*_amd64.deb
```

**One line (from source):**

```bash
curl -fsSL https://raw.githubusercontent.com/al5ina5/tethercam/main/packaging/install-online.sh | bash
```

**From a clone:** `./install.sh`

## Use it

1. On the phone: **Settings -> Developer options -> USB debugging -> on**.
2. Plug it in and accept the prompt on the phone.
3. Run `tethercam` on the computer - it starts the stream and opens the panel.
4. In your app, choose **TetherCam** for camera and microphone.

No phone app to pair, no server to run, no config file to edit.

## Works with

OBS Studio, Discord, Zoom, Google Meet, Microsoft Teams, Slack, Jitsi, Firefox
and Chromium - anything that can see a webcam and a microphone.

## Camera and microphone

| | Device | Notes |
|---|---|---|
| Camera | `TetherCam` (`/dev/video42`) | 1280x720 @ 30fps; needs Android 12+ (older phones mirror the screen) |
| Microphone | `TetherCam` | live phone mic |

The mic needs a helper sink (`TetherCam Sink`). Some audio apps (pavucontrol,
Cinnamon Sound, OBS's *Desktop Audio* dropdown) list it, but it is never the
default and the phone mic never routes through it - plumbing only.

## USB and WiFi

USB is the default and lowest-latency option. For WiFi, run `tethercam pair`
once while on USB; the endpoint is saved, and the daemon fails over on its own
and switches back to USB as soon as a cable appears.

## Commands

```
tethercam                    open the control panel (starts the stream)
tethercam front|back|auto    switch camera
tethercam start|stop         start/stop streaming
tethercam status             one-line status
tethercam doctor             diagnose anything that looks wrong
tethercam pair|forget        wireless ADB pairing
tethercam snapshot [path]    save a frame
tethercam version            print the version
```

## Requirements

Linux with **PipeWire** (Mint 22 / Ubuntu 24.04+), `adb`, `ffmpeg`, `zenity`
and `v4l2loopback`. The installer pulls what it can and reports what is
missing; scrcpy is downloaded automatically (checksum-pinned).

## Troubleshooting

- **No `TetherCam` in the app?** Run `tethercam doctor` - it checks the camera,
  mic, routing and service at once.
- **Phone not detected?** Ensure USB debugging is on and you accepted the
  on-phone prompt (`adb devices` should list it).
- **Black video?** Close any app using the phone camera, then re-init with
  `tethercam back` or `tethercam front`.
- **Mic silent in OBS?** Point *Desktop Audio* at your real output and select
  **TetherCam** for *Mic/Aux*.

## How it works

TetherCam drives the official [scrcpy](https://github.com/Genymobile/scrcpy)
client from your computer - no app is installed on the phone (scrcpy's server
is pushed over adb for the session). The camera becomes a `v4l2loopback` device
(`/dev/video42`, "TetherCam") and the mic a PipeWire source ("TetherCam"), so
any app can use them.

## Status

**0.1.1 alpha**, proven on SM-G990U (Android 15) and SM-G781U (Android 13).
Camera and mic are supervised independently - switching lenses never drops the
mic, and mic routing is re-asserted so it cannot leak into Desktop Audio.

## Development

```bash
packaging/deb/build-deb.sh   # build the .deb into dist/
bash tests/test-routing.sh   # regression tests (phone checks skip if unplugged)
```

Layout:

* `scripts/tethercam` - CLI and control panel
* `scripts/tethercam-daemon` - supervisor for camera + mic
* `tests/test-routing.sh` - regression tests
* `packaging/` - deb build, udev, modprobe, systemd, desktop entry
* `app/` - cross-platform GUI, not part of the Linux install yet

## Uninstall

```bash
sudo apt remove tethercam   # .deb install
./uninstall.sh              # clone install
```

## License

MIT - see [LICENSE](LICENSE). No phone code is bundled; scrcpy is downloaded
automatically (see [NOTICE](NOTICE)).
