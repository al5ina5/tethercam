# Changelog

## 0.1.1 - 2026-09-23

- Fix: the `.deb` now downloads scrcpy on first run. In 0.1.0 a package-only
  install had no scrcpy and the service could not start.
- README corrected to match the real user experience.

## 0.1.0 - 2026-09-23

First public alpha.

- One command, one UI: `tethercam` (control panel plus `front` / `back` /
  `auto` / `start` / `stop` / `status` / `doctor` / `pair` / `forget` /
  `snapshot`). The old multi-script layout is gone.
- Supervisor daemon: camera and microphone run independently, so switching
  lenses never drops the mic.
- Mic routing is re-asserted continuously and self-heals if the PipeWire
  devices disappear, so the phone mic can never leak into Desktop Audio.
- `install.sh` checks PipeWire, the audio tools, `v4l2loopback` and its own
  download tools, with exact `apt install` hints.
- `uninstall.sh` stops the service and removes the `TetherSink` / `TetherMic`
  virtual devices so no phantom devices are left behind.
- Added `tethercam doctor` and `tests/test-routing.sh`.
- Fixed the `pkill -f` footgun that could kill the invoking shell.
