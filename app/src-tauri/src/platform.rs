//! Platform adapters: one trait, one impl per OS.
//! Linux is the only stable backend today. macOS/Windows keep the same
//! contract later (virtual-cam sink + audio sink + device watcher each).

use serde::Serialize;
use std::process::Command;

#[derive(Serialize, Clone)]
pub struct Status {
    pub active: bool,
    pub serial: Option<String>,
    pub lens: String,
    pub camera_id: Option<String>,
    pub video_ok: bool,
    pub mic_ok: bool,
    pub transport: String,
    pub endpoint: Option<String>,
}

pub trait PlatformBackend: Send + Sync {
    fn id(&self) -> &'static str;
    fn service_active(&self) -> bool;
    fn adb_serial(&self) -> Option<String>;
    fn saved_lens(&self) -> String;
    fn last_camera(&self) -> Option<String>;
    fn video_node_ok(&self) -> bool;
    fn mic_ok(&self) -> bool;
    fn apply_lens(&self, lens: &str);
    fn preview_jpeg(&self) -> Option<Vec<u8>>;
    fn snapshot(&self, path: &str) -> bool;
    fn paired_endpoint(&self) -> Option<String>;
    /// One-time pairing over USB. Returns the endpoint or a human error.
    fn pair_wireless(&self) -> Result<String, String>;
    /// Drop WiFi pairing, back to USB only.
    fn forget_wifi(&self);

    fn status(&self) -> Status {
        let serial = self.adb_serial();
        let transport = match &serial {
            None => "off".to_string(),
            Some(s) if s.contains(':') => "wifi".to_string(),
            Some(_) => "usb".to_string(),
        };
        Status {
            active: self.service_active(),
            serial,
            lens: self.saved_lens(),
            camera_id: self.last_camera(),
            video_ok: self.video_node_ok(),
            mic_ok: self.mic_ok(),
            transport,
            endpoint: self.paired_endpoint(),
        }
    }
}

fn run(prog: &str, args: &[&str]) -> Option<String> {
    Command::new(prog)
        .args(args)
        .output()
        .ok()
        .and_then(|o| String::from_utf8(o.stdout).ok())
}

/// Live preview cache: one persistent ffmpeg MJPEG pipe, latest frame kept
/// in memory. Polling commands grab from here instead of spawning ffmpeg
/// per call (that capped the old UI at ~1.4fps).
pub struct PreviewCache {
    frame: std::sync::Arc<
        std::sync::Mutex<Option<(std::time::Instant, Vec<u8>)>>,
    >,
    started: std::sync::OnceLock<()>,
}

impl PreviewCache {
    pub fn new() -> Self {
        Self {
            frame: std::sync::Arc::new(std::sync::Mutex::new(None)),
            started: std::sync::OnceLock::new(),
        }
    }

    pub fn latest(&self) -> Option<Vec<u8>> {
        self.started.get_or_init(|| {
            let frame = self.frame.clone();
            std::thread::spawn(move || Self::pump(frame));
        });
        let g = self.frame.lock().ok()?;
        let (t, jpg) = g.as_ref()?;
        if t.elapsed().as_secs() < 3 {
            Some(jpg.clone())
        } else {
            None
        }
    }

    fn pump(
        frame: std::sync::Arc<
            std::sync::Mutex<Option<(std::time::Instant, Vec<u8>)>>,
        >,
    ) {
        use std::io::Read;
        loop {
            if !std::path::Path::new(SINK).exists() {
                std::thread::sleep(std::time::Duration::from_secs(1));
                continue;
            }
            let mut child = match Command::new("ffmpeg")
                .args([
                    "-loglevel", "error", "-f", "v4l2", "-i", SINK,
                    "-f", "mjpeg", "-q:v", "8", "-s", "640x360", "-",
                ])
                .stdout(std::process::Stdio::piped())
                .stderr(std::process::Stdio::null())
                .spawn()
            {
                Ok(c) => c,
                Err(_) => {
                    std::thread::sleep(std::time::Duration::from_secs(1));
                    continue;
                }
            };
            let mut buf = Vec::with_capacity(1 << 20);
            let mut tmp = [0u8; 65536];
            let mut nframes: u64 = 0;
            let mut nbytes: u64 = 0;
            let out = child.stdout.take();
            if let Some(mut pipe) = out {
                loop {
                    match pipe.read(&mut tmp) {
                        Ok(0) | Err(_) => break,
                        Ok(n) => {
                            buf.extend_from_slice(&tmp[..n]);
                            nbytes += n as u64;
                            while let Some(jpg) = take_jpeg(&mut buf) {
                                nframes += 1;
                                if nframes == 1 || nframes % 600 == 0 {
                                    eprintln!(
                                        "[preview] frames={} bytes={}",
                                        nframes, nbytes
                                    );
                                }
                                if let Ok(mut g) = frame.lock() {
                                    *g = Some((std::time::Instant::now(), jpg));
                                }
                            }
                            if buf.len() > (1 << 21) {
                                buf.clear();
                            }
                        }
                    }
                }
            }
            let _ = child.kill();
            std::thread::sleep(std::time::Duration::from_millis(500));
        }
    }
}

fn take_jpeg(buf: &mut Vec<u8>) -> Option<Vec<u8>> {
    let s = buf.windows(2).position(|w| w == [0xFF, 0xD8])?;
    let e = buf.windows(2).position(|w| w == [0xFF, 0xD9])?;
    if e < s {
        buf.drain(..s);
        return None;
    }
    let jpg = buf[s..e + 2].to_vec();
    buf.drain(..e + 2);
    Some(jpg)
}

pub struct LinuxBackend;
const SVC: &str = "tethercam.service";
const SINK: &str = "/dev/video42";
const LENS_FILE: &str = ".config/tethercam/lens";

fn home() -> String {
    std::env::var("HOME").unwrap_or_else(|_| "/root".into())
}

impl PlatformBackend for LinuxBackend {
    fn id(&self) -> &'static str {
        "linux"
    }

    fn service_active(&self) -> bool {
        run("systemctl", &["--user", "is-active", SVC])
            .map(|s| s.trim() == "active")
            .unwrap_or(false)
    }

    fn adb_serial(&self) -> Option<String> {
        run("adb", &["devices"]).and_then(|out| {
            out.lines().skip(1).find_map(|l| {
                let mut p = l.split_whitespace();
                match (p.next(), p.next()) {
                    (Some(s), Some("device")) => Some(s.to_string()),
                    _ => None,
                }
            })
        })
    }

    fn saved_lens(&self) -> String {
        std::fs::read_to_string(format!("{}/{}", home(), LENS_FILE))
            .map(|s| s.trim().to_string())
            .ok()
            .filter(|s: &String| s == "front" || s == "back")
            .unwrap_or_else(|| "front".into())
    }

    fn last_camera(&self) -> Option<String> {
        run("journalctl", &["--user", "-u", SVC, "-n", "80"]).and_then(|out| {
            let mut last = None;
            for caps in regex_lite(out) {
                last = Some(caps);
            }
            last
        })
    }

    fn video_node_ok(&self) -> bool {
        std::path::Path::new(SINK).exists()
    }

    fn mic_ok(&self) -> bool {
        run("pactl", &["list", "sources", "short"])
            .map(|s| s.lines().any(|l| l.contains("TetherMic")))
            .unwrap_or(false)
    }

    fn apply_lens(&self, lens: &str) {
        let lens = if lens == "back" { "back" } else { "front" };
        let path = format!("{}/{}", home(), LENS_FILE);
        let _ = std::fs::create_dir_all(
            std::path::Path::new(&path).parent().unwrap(),
        );
        let _ = std::fs::write(&path, lens);
        // The daemon watches this file and restarts only the camera, so the
        // mic never drops. Just make sure the service is up.
        let _ = Command::new("systemctl")
            .args(["--user", "start", SVC])
            .output();
    }

    fn preview_jpeg(&self) -> Option<Vec<u8>> {
        if !self.service_active() || !self.video_node_ok() {
            return None;
        }
        let out = Command::new("ffmpeg")
            .args([
                "-loglevel", "error", "-f", "v4l2", "-i", SINK,
                "-frames:v", "1", "-s", "640x360", "-q:v", "8",
                "-f", "mjpeg", "-",
            ])
            .output()
            .ok()?;
        if out.status.success() && out.stdout.len() > 1000 {
            Some(out.stdout)
        } else {
            None
        }
    }

    fn snapshot(&self, path: &str) -> bool {
        Command::new("ffmpeg")
            .args([
                "-y", "-loglevel", "error", "-f", "v4l2", "-i", SINK,
                "-frames:v", "1", path,
            ])
            .output()
            .map(|o| o.status.success())
            .unwrap_or(false)
    }

    fn paired_endpoint(&self) -> Option<String> {
        std::fs::read_to_string(format!("{}/.config/tethercam/endpoint", home()))
            .map(|s| s.trim().to_string())
            .ok()
            .filter(|s| !s.is_empty())
    }

    fn pair_wireless(&self) -> Result<String, String> {
        let bin = format!("{}/.local/bin/tethercam", home());
        match Command::new(&bin).arg("pair").output() {
            Ok(o) if o.status.success() => self
                .paired_endpoint()
                .ok_or_else(|| "paired but no endpoint saved".into()),
            Ok(o) => Err(String::from_utf8_lossy(&o.stderr)
                .lines()
                .last()
                .unwrap_or("pairing failed")
                .to_string()),
            Err(e) => Err(format!("pair helper missing: {e}")),
        }
    }

    fn forget_wifi(&self) {
        let bin = format!("{}/.local/bin/tethercam", home());
        let _ = Command::new(&bin).arg("forget").output();
    }
}

fn regex_lite(out: String) -> Vec<String> {
    // Finds "using --camera-id=N" without pulling in the regex crate.
    const MARK: &str = "using --camera-id=";
    let mut ids = Vec::new();
    let mut rest = out.as_str();
    while let Some(i) = rest.find(MARK) {
        let digits: String = rest[i + MARK.len()..]
            .chars()
            .take_while(|c| c.is_ascii_digit())
            .collect();
        if !digits.is_empty() {
            ids.push(digits);
        }
        rest = &rest[i + MARK.len()..];
    }
    ids
}

// --- Future platforms keep this exact contract ---
// pub struct MacBackend;   // TODO: CoreMediaIO sink + launchd watcher
// pub struct WindowsBackend; // TODO: OBS virtual-cam sink + scheduled task
