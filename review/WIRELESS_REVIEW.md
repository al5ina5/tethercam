# Wireless webcam performance review — 2026-09-09

The current wireless implementation fails the requested steady 30–60 FPS goal. A live observation of the existing virtual webcam reproduced the reported pattern: brief frame delivery followed by approximately eleven seconds without a frame. There are concrete implementation problems, and the active ADB/TCP connection also exhibits long transport outages. This review establishes where the stalls occur; it does not establish why the phone or network stops acknowledging traffic.

The running daemon matches `scripts/tethercam-daemon.sh` byte for byte. The observed phone was a Samsung SM-G990U on Android 15, using camera 1, H.264, 1280×720, requested 30 FPS, 1.5 Mbps, a configured 0.5-second keyframe interval, and an 800 ms V4L2 buffer. The microphone ran in its separate scrcpy process. Application settings and services were not changed.

**Live measurements**

A temporary FFmpeg reader opened the existing `/dev/video42`, computed frame checksums and timestamps, and discarded the images. Output synchronization was set to passthrough. Simultaneous `ss` snapshots sampled the existing ADB TCP connection every five seconds. The observation ran for approximately 35 seconds; process shutdown and TCP sampling brought total harness time to 35.89 seconds.

| Measurement | Observed |
| --- | --- |
| V4L2 advertised mode | 1280×720, 30 FPS |
| Frames observed | 206 |
| Consecutive checksum changes | 205 |
| FFmpeg reported delivery rate | 5.9 FPS |
| First long frame gap | 11.296 seconds |
| Second long frame gap | 11.617 seconds |
| ADB data silence at one TCP snapshot | 13.206 seconds |
| TCP retransmission timeout during stalls | 6.880 seconds |
| Ordinary TCP RTT before a stall | About 14–20 ms |

The two long frame gaps occurred at approximately 4.04–15.33 seconds and 19.93–31.55 seconds into the observation. Around the recovery, frames arrived in bursts, including 46 frames in one one-second bucket. A whole-recording average or a configured FPS value therefore hides the actual experience.

In the earlier wireless session with server PID 2354, the journal contains 259 `Camera capture failed` messages in 20 bursts across 315.52 seconds. The median interval between bursts is 16.42 seconds. That session eventually logged a device disconnect; the ADB log recorded a connection timeout. These are camera callback failures, not counts of successful frames or proof of a particular hardware fault.

Timing/checksum measurements establish delivery stalls, not glass-to-glass latency or image quality. FFmpeg's null output reported repeated DTS values during bursts; measurements use frame arrival before that output stage. No USB comparison, IP-camera comparison, 60 FPS test, or long-duration thermal test was performed in this review.

**Prioritized findings**

1. **P1 — The wireless stream has no application-level response to a live-but-stalled transport.** `scripts/tethercam-daemon.sh:59–64` launches a fixed profile and waits for scrcpy to exit. There is no fresh-frame deadline, stalled-stream recovery, or feedback-driven rate adjustment. During the measured freezes, the TCP connection remained established and the service remained active. The phone-side scrcpy encoder writes the encoded packet before releasing its MediaCodec output buffer. If the socket blocks long enough, that can back up encoding and camera capture. This mechanism is consistent with the observed transport stalls and camera failures, but proving the complete causal chain requires phone-side timing. Decouple encoder draining from network delivery, bound queued media by age/bytes, and monitor actual frame progress. For compressed-frame drops, recover at a valid keyframe with codec configuration; arbitrarily deleting reference frames will corrupt decoding. [Encoder implementation](https://github.com/Genymobile/scrcpy/blob/v4.1/server/src/main/java/com/genymobile/scrcpy/video/SurfaceEncoder.java#L229), [packet writes](https://github.com/Genymobile/scrcpy/blob/v4.1/server/src/main/java/com/genymobile/scrcpy/device/Streamer.java#L61).

2. **P1 — The configuration deliberately adds 800 ms of video latency.** `scripts/tethercam-daemon.sh:64` sets `--v4l2-buffer=800`; USB also adds 200 ms at line 66. This option adds playout delay, rather than limiting queue size. Even with an otherwise healthy link, this prevents a responsive webcam experience. It cannot cover the measured eleven-second delivery outages. Establish a baseline with zero added buffering, then add only a small measured jitter allowance, initially testing 30–80 ms. This is a latency correction; it is not by itself a fix for the transport stalls. [Upstream buffer semantics](https://github.com/Genymobile/scrcpy/blob/v4.1/doc/v4l2.md#buffering).

3. **P1 — Every wireless restart deliberately waits for an absent USB device.** `scripts/tethercam-daemon.sh:15–28` performs fifteen one-second USB waits before trying Wi-Fi, then adds a two-second sleep. Line 42 waits another four seconds for audio before video setup. With `RestartSec=3` in `packaging/systemd/tethercam.service:10`, a disconnect incurs at least 24 seconds of explicit waits before camera enumeration and startup, plus unbounded ADB command time. In an already paired wireless session, check USB once and try the saved wireless transport immediately; use bounded calls and device/readiness events. Keep microphone initialization off the critical video-start path. This explains long recovery after disconnects; the observed eleven-second within-session freezes also occur without such restarts.

4. **P2 — The Tauri preview cannot display 30 FPS.** `app/ui/src/App.tsx:79–88` retrieves one JPEG every 300 ms, limiting display updates to approximately 3.3 FPS. Null results are ignored, so a stale image may remain visible indefinitely while the service is active. Use a continuous video presentation path or a paced, bounded latest-frame handoff with frame IDs and expiry. The preview should independently meet the intended display cadence. Because the user also sees freezes in other camera apps, this is an additional defect rather than the source of the shared outage.

5. **P1 — The installer does not install or update the service's actual entry point.** `install.sh:23–26` copies the legacy launcher/UI, and lines 50–53 install/start a unit that executes `~/.local/bin/tethercam-daemon`. The installer never copies that daemon, the pairing helper, or `tethercam-replug.service`. A fresh install is incomplete, and an existing install can continue running old performance settings after reinstalling. Install the complete current pipeline and expose its version/effective settings so performance changes can be reproduced. The running daemon happened to match the reviewed source in this session.

Further gaps directly relevant to the target:

- Both camera profiles hardcode `--camera-fps=30`. There is no capability-checked 60 FPS mode. Stabilize 30 FPS first, then expose and verify supported resolution/FPS combinations. [scrcpy camera FPS documentation](https://github.com/Genymobile/scrcpy/blob/v4.1/doc/camera.md#frame-rate).
- `LinuxBackend::status()` uses service activity and device-node existence as health signals (`app/src-tauri/src/platform.rs:37–53,222–224`). Neither demonstrates fresh video. Transport is inferred from the first ADB device rather than the daemon's selected stream. Publish selected transport, last fresh frame age, delivered FPS, frame-gap percentiles, and restart reason from the running pipeline.
- `--stay-awake` applies while the device is plugged in, according to the installed scrcpy manual. A single wake key event at `scripts/tethercam-daemon.sh:63` does not establish sustained screen/CPU/Wi-Fi behavior on battery. Measure screen-on/off and battery/charging separately; do not assume this flag keeps an unplugged phone awake. This review did not establish power management as the cause.
- The README describes HEVC at 3 Mbps with a 150 ms buffer, while the running/source command uses H.264 at 1.5 Mbps and 800 ms. Its approximately eight-second throughput comparison cannot substantiate continuous responsiveness, and no supporting benchmark artifacts are included in the app source.

**What the transport evidence means**

ADB multiplexes its logical streams over one transport. Here, video, microphone, and command traffic use the phone's ADB TCP connection. TCP retransmits lost data and exposes an ordered byte stream, so a later keyframe cannot bypass an earlier delivery gap. The README's explanation that a lost Wi-Fi packet directly corrupts subsequent P-frames is not a sufficient explanation for this transport. Decoder errors need separate investigation of capture/encoder/session handling. Increasing keyframe frequency may help decoder recovery, but it does not remove TCP stalls. [ADB architecture](https://android.googlesource.com/platform/packages/modules/adb/%2B/HEAD/docs/dev/internals.md), [TCP semantics](https://www.rfc-editor.org/rfc/rfc9293.html#section-2.2).

Upstream scrcpy already replaces pending frames at its V4L2 sink. Adding another latest-frame cache after decoding cannot recover video that has not arrived. Queue controls must address the source and transport as well. [V4L2 sink implementation](https://github.com/Genymobile/scrcpy/blob/v4.1/app/src/v4l2_sink.c#L291).

**Recommended implementation sequence**

1. Make installation reproducible, expose stream-health metrics, and remove the fixed startup waits. Establish matched USB and wireless measurements at the same resolution, codec, FPS, lens, lighting, and microphone setting. Log the selected encoder and actual keyframes. Measure received packet timing, decoded-frame timing, and V4L2 delivery separately.
2. Test a low-buffer scrcpy profile with microphone enabled and disabled, then compare direct IP-camera streaming on the same phone and Wi-Fi path. Test battery/screen state and available hardware encoders. These experiments distinguish ADB-specific behavior, encoder/camera failures, and link/power behavior before committing to a replacement transport. Preserve the real camera output dimensions if resolution adaptation is added so consumers do not lose their webcam format.
3. If the ADB media path continues to stall, use direct phone-to-PC real-time media transport for wireless. A concrete candidate is hardware H.264 plus WebRTC media over UDP, with congestion control, pacing, a small jitter buffer, bounded queues, and keyframe recovery. Retain ADB for setup/control and the working USB path. This requires phone-side sender work; a desktop-only flag change cannot implement it. A direct TCP comparison is still useful because it removes ADB multiplexing without simultaneously changing reliability semantics. Interactive media needs a deadline-aware approach to late data. [Real-time media requirements](https://www.rfc-editor.org/rfc/rfc8836.html#section-2).
4. Replace the 300 ms JPEG preview polling and add capability-checked 60 FPS after the 30 FPS path meets its targets. Test microphone synchronization too: independent audio and video buffering can make lips and speech diverge.

**Proposed acceptance targets, not measured achievements**

At 720p30, run at least 30 minutes with motion and the microphone enabled: at least 29 fresh frames per second over sustained windows, no unprovoked multi-second freezes, 99th-percentile inter-frame gap below 100 ms, and no continuously growing delay. Measure glass-to-glass latency against USB, initially targeting wireless p95 below 150 ms and no more than 75 ms above the same USB pipeline. Verify image quality at motion; lowering bitrate alone is not success. Exercise congestion and reconnection separately, checking return to fresh live video rather than playback of a backlog. Repeat at 60 FPS on supported hardware, targeting at least 58 fresh FPS and tighter frame pacing. Validate both `/dev/video42` consumers and the app preview.

The live measurement provides a failing baseline. The exact origin of the repeated TCP outages and successful USB-like wireless performance remain to be demonstrated.
