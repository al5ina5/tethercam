# TetherCam mic path (built 2026-09-09, revised for the supervisor daemon)

Verified live on SM-G781U: `TetherMic` carries real room audio
(mean -44.6dB, max -29.9dB - matches a direct `--record` capture).

How it works (see `scripts/tethercam-daemon`):

1. Null sink + remap source, stable names, created once:
   `module-null-sink sink_name=TetherSink`,
   `module-remap-source master=TetherSink.monitor source_name=TetherMic`.
   Both are (re)created only when the display name is stale, so app device
   selections survive upgrades.
2. Headless audio scrcpy alongside video:
   `scrcpy --no-video --no-window --audio-source=mic`.
3. Gotcha: SDL talks **PipeWire natively**, so `PULSE_SINK=` is silently
   ignored. SDL also plays to the *default* sink, which would make OBS
   "Desktop Audio" (monitor of the default sink) capture the phone mic a
   second time. The daemon fixes this by moving the scrcpy stream into
   TetherSink (`pactl move-sink-input`) and re-asserting that every second,
   so a stray re-route can never reintroduce the leak.

Two scrcpy servers (one camera, one mic) coexist fine. Debug with
`tethercam doctor`, `pw-link -o | grep scrcpy`, and `tests/test-routing.sh`.
