//! TetherCam - Tauri shell. Stable Linux core, adapters for later OSes.
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

mod platform;

use platform::{LinuxBackend, PlatformBackend, PreviewCache, Status};
use std::sync::Mutex;
use tauri::State;

struct Backend(Mutex<LinuxBackend>);

fn lens_file() -> String {
    format!(
        "{}/.config/tethercam/lens",
        std::env::var("HOME").unwrap_or_else(|_| "/root".into())
    )
}

#[tauri::command]
fn get_status(be: State<Backend>) -> Status {
    be.0.lock().unwrap().status()
}

#[tauri::command]
fn set_lens(be: State<Backend>, lens: String) -> Status {
    be.0.lock().unwrap().apply_lens(&lens);
    // Return intent immediately; the camera needs seconds to re-init and the
    // UI polls. Never block the window on a backend restart.
    let mut st = be.0.lock().unwrap().status();
    st.lens = if lens == "back" {
        "back".into()
    } else {
        "front".into()
    };
    st
}

#[tauri::command]
fn pair_wireless(be: State<Backend>) -> Result<String, String> {
    be.0.lock().unwrap().pair_wireless()
}

#[tauri::command]
fn forget_wifi(be: State<Backend>) {
    be.0.lock().unwrap().forget_wifi()
}
#[tauri::command]
fn preview_frame(cache: State<PreviewCache>) -> Option<String> {
    cache
        .latest()
        .map(|jpg| format!("data:image/jpeg;base64,{}", base64::encode(jpg)))
}

#[tauri::command]
fn take_snapshot(be: State<Backend>) -> Option<String> {
    let path = format!(
        "{}/Pictures/tethercam-{}.jpg",
        std::env::var("HOME").unwrap_or_else(|_| "/tmp".into()),
        chrono_stamp()
    );
    if be.0.lock().unwrap().snapshot(&path) {
        Some(path)
    } else {
        None
    }
}

fn chrono_stamp() -> String {
    // No chrono dep for one timestamp: seconds since epoch is plenty.
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs().to_string())
        .unwrap_or_else(|_| "shot".into())
}

fn main() {
    // Lens default for fresh installs; existing choice is never overwritten.
    let lf = lens_file();
    if !std::path::Path::new(&lf).exists() {
        let _ = std::fs::create_dir_all(
            std::path::Path::new(&lf).parent().unwrap(),
        );
        let _ = std::fs::write(&lf, "front");
    }
    tauri::Builder::default()
        .manage(Backend(Mutex::new(LinuxBackend)))
        .manage(PreviewCache::new())
        .invoke_handler(tauri::generate_handler![
            get_status,
            set_lens,
            pair_wireless,
            forget_wifi,
            preview_frame,
            take_snapshot
        ])
        .run(tauri::generate_context!())
        .expect("TetherCam failed to start");
}
