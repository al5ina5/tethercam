# TetherCam

**Turn any Android phone into a webcam and microphone for your Linux PC.**

No app to install on the phone. No account. No cloud. No watermark. Plug in a
USB cable (or pair over WiFi), pick **TetherCam** in OBS, Discord, Zoom, Meet,
Teams or any browser, and you are live.

Your phone shows up as a completely standard webcam and microphone, so every
app that already works with a webcam just works with your phone.

[![release](https://img.shields.io/github/v/release/al5ina5/tethercam)](https://github.com/al5ina5/tethercam/releases)
[![license](https://img.shields.io/github/license/al5ina5/tethercam)](LICENSE)
![platform](https://img.shields.io/badge/platform-Linux-blue)

---

## Why TetherCam

- **Nothing to install on the phone.** No companion app, no Play Store, no
  root, no sign-up. Just enable USB debugging.
- **Instant install.** A `.deb` for Mint and Ubuntu (double-click), or one
  `curl` line. No build step, no toolchain.
- **Zero configuration.** Plug in, run `tethercam`, choose "TetherCam". That is
  the entire setup.
- **Camera *and* microphone.** Both arrive as normal devices, not a special
  protocol your app has to understand.
- **Switch front/back without dropping the microphone.** The camera re-inits
  for a second or two; the mic keeps running the whole time.
- **USB or WiFi.** After a one-time `tethercam pair`, pull the cable and it
  fails over to WiFi on its own; USB wins whenever it is plugged in.
- **Works everywhere a webcam works** - OBS, Discord, Zoom, Google Meet,
  Microsoft Teams, Slack, Jitsi, browsers.
- **Free and open source** (MIT). No account, no telemetry, no cloud, no
  watermark, no time limit.

> Replacing DroidCam, Iriun or a USB capture card? TetherCam is the
> zero-app, zero-config option for Linux.

## Install

**Linux Mint / Ubuntu - `.deb` (double-click).** Download from
[Releases](https://github.com/al5ina5/tethercam/releases), double-click the
`.deb`, and install. Or:

```bash
sudo apt install ./tethercam_*_amd64.deb
```

**One line (from source):**

```bash
curl -fsSL https://raw.githubusercontent.com/al5ina5/tethercam/main/packaging/install-online.sh | bash
```

**From a clone:**

```bash
./install.sh
```

## Use it

1. On the phone: **Settings -> Developer options -> USB debugging -> on**.
2. Plug the phone in and accept the prompt on the phone.
3. On the computer, run `tethercam` - it starts the stream and opens the
   control panel.
4. In your app, choose **TetherCam** for the camera and **TetherCam** for the
   microphone.

That is the whole setup. There is no phone app to pair, no server to run, and
no configuration file to edit.

## Works with

OBS Studio, Discord, Zoom, Google Meet, Microsoft Teams, Slack, Jitsi, Firefox
and Chromium - anything that can see a webcam and a microphone.

## Camera and microphone

| | Device | Notes |
|---|---|---|
| Camera | `TetherCam` (`/dev/video42`) | 1280x720 @ 30fps by default |
| Microphone | `TetherCam` | live phone mic, always on |

The camera source needs **Android 12 or newer**. On older phones TetherCam
mirrors the screen instead (still usable as a "camera").

The mic needs a small helper sink under the hood (`TetherCam Sink`). Some audio
apps (pavucontrol, Cinnamon Sound, OBS's *Desktop Audio* dropdown) will list
it - it is never the default and the phone mic never routes through it, it is
plumbing only.

## USB and WiFi

- **USB** is the default and the lowest-latency option. Plug in and go.
- **WiFi:** run `tethercam pair` once while on USB. The phone pairs over the
  network and the endpoint is saved. Unplug whenever - the daemon fails over to
  WiFi on its own, and switches back to USB as soon as a cable appears.

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

## Requirements

Linux with **PipeWire** (Linux Mint 22 / Ubuntu 24.04 and newer), `adb`,
`ffmpeg`, `zenity` and the `v4l2loopback` kernel module. The installer pulls
what it can and tells you exactly what is missing. scrcpy itself is downloaded
automatically (checksum-pinned) - at install for the source installer, or on
first run for the `.deb`.

## Troubleshooting

- **The app does not list `TetherCam`?** Run `tethercam doctor` - it checks the
  camera node, the microphone, the routing and the service in one shot.
- **Phone not detected?** Make sure USB debugging is on and you accepted the
  prompt on the phone. `adb devices` should list it.
- **Black video / no frames?** Make sure no other app on the phone is using the
  camera, then re-init with `tethercam back` or `tethercam front`.
- **Mic silent?** In OBS, set *Desktop Audio* to your real output and use
  **TetherCam** for *Mic/Aux*.

## How it works

TetherCam drives the official [scrcpy](https://github.com/Genymobile/scrcpy)
client from your computer. No app is installed on the phone: scrcpy's server is
pushed over adb for the session and removed when it stops. The camera stream is
written to a `v4l2loopback` device (`/dev/video42`, "TetherCam") and the mic is
exposed as a PipeWire source ("TetherCam"). Because both are standard system
devices, any app can use them.

## Status

**0.1.1 alpha.** Proven on SM-G990U (Android 15) and SM-G781U (Android 13).
The camera and microphone are supervised independently, so switching lenses
never drops the mic, and the mic routing is re-asserted continuously so it can
never leak into Desktop Audio.

## Development

```bash
packaging/deb/build-deb.sh   # build the .deb into dist/
bash tests/test-routing.sh   # regression tests (phone checks skip if unplugged)
```

Layout:

* `scripts/tethercam` - the CLI and control panel (one entry point)
* `scripts/tethercam-daemon` - the supervisor for camera + mic
* `tests/test-routing.sh` - regression tests
* `packaging/` - deb build, udev, modprobe, systemd, desktop entry
* `app/` - cross-platform GUI, not part of the Linux install yet

## Uninstall

```bash
sudo apt remove tethercam   # if you installed the .deb
./uninstall.sh              # if you installed from a clone
```

## License

MIT - see [LICENSE](LICENSE). No phone code is bundled; scrcpy is downloaded
automatically and used at runtime (see [NOTICE](NOTICE)).
