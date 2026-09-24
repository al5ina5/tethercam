import { invoke } from "@tauri-apps/api/core";
import { useCallback, useEffect, useRef, useState } from "react";

type Lens = "front" | "back";

interface Status {
  active: boolean;
  serial: string | null;
  lens: Lens;
  camera_id: string | null;
  video_ok: boolean;
  mic_ok: boolean;
  transport: "usb" | "wifi" | "off";
  endpoint: string | null;
}

const idle: Status = {
  active: false,
  serial: null,
  lens: "front",
  camera_id: null,
  video_ok: false,
  mic_ok: false,
  transport: "off",
  endpoint: null,
};

function LensButton({
  name,
  current,
  busy,
  onPick,
}: {
  name: Lens;
  current: Lens;
  busy: boolean;
  onPick: (l: Lens) => void;
}) {
  const on = current === name;
  return (
    <button
      disabled={busy}
      onClick={() => onPick(name)}
      className={`flex-1 py-2 text-sm font-semibold capitalize transition-colors first:rounded-l-full last:rounded-r-full disabled:opacity-60 ${
        on ? "bg-white text-ink shadow" : "text-sub hover:text-ink"
      }`}
    >
      {name}
    </button>
  );
}

export default function App() {
  const [status, setStatus] = useState<Status>(idle);
  const [frame, setFrame] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const timer = useRef<number | null>(null);

  const poll = useCallback(async () => {
    try {
      setStatus(await invoke<Status>("get_status"));
    } catch {
      /* backend starting */
    }
  }, []);

  useEffect(() => {
    poll();
    const s = window.setInterval(poll, 2000);
    return () => window.clearInterval(s);
  }, [poll]);

  useEffect(() => {
    if (!status.active) {
      setFrame(null);
      if (timer.current) window.clearInterval(timer.current);
      return;
    }
    const grab = async () => {
      try {
        const jpg = await invoke<string | null>("preview_frame");
        if (jpg) setFrame(jpg);
      } catch {
        /* offline moment */
      }
    };
    grab();
    timer.current = window.setInterval(grab, 300);
    return () => {
      if (timer.current) window.clearInterval(timer.current);
    };
  }, [status.active]);

  const pick = async (lens: Lens) => {
    if (busy || (status.lens === lens && status.active)) return;
    setBusy(true);
    try {
      await invoke("set_lens", { lens });
    } finally {
      window.setTimeout(() => {
        setBusy(false);
        poll();
      }, 2500);
    }
  };

  const [pairMsg, setPairMsg] = useState<string | null>(null);

  const pair = async () => {
    setBusy(true);
    setPairMsg("pairing over USB… keep the cable in");
    try {
      const ep = await invoke<string>("pair_wireless");
      setPairMsg(`paired ${ep} - you can unplug now`);
    } catch (e) {
      setPairMsg(typeof e === "string" ? e : "pairing failed");
    } finally {
      setBusy(false);
      poll();
    }
  };

  const unpair = async () => {
    await invoke("forget_wifi");
    setPairMsg(null);
    poll();
  };

  return (
    <div className="mx-auto flex min-h-full w-full max-w-[440px] flex-col items-center gap-3 px-4 py-4">
      <div className="flex flex-col items-center gap-0.5">
        <span
          className={`text-xs font-extrabold tracking-wide ${
            status.active ? "text-go" : "text-idle"
          }`}
        >
          ● {status.active ? "LIVE" : "OFF"}
        </span>
        <h1 className="text-[22px] font-extrabold leading-tight">TetherCam</h1>
        <p className="text-[13px] text-sub">
          {status.active
            ? `${status.serial ?? "phone"}  •  ${status.lens}  •  ${status.transport}  •  TetherCam + TetherMic`
            : "Plug in any Android."}
        </p>
      </div>

      <div className="aspect-video w-full overflow-hidden rounded-[14px] bg-[#101216]">
        {frame ? (
          <img src={frame} alt="phone camera" className="h-full w-full object-cover" />
        ) : (
          <div className="flex h-full items-center justify-center text-sm text-idle">
            {status.active ? "warming up…" : "no signal"}
          </div>
        )}
      </div>

      <div className="flex w-56 rounded-full bg-black/5 p-1">
        <LensButton name="front" current={status.lens} busy={busy} onPick={pick} />
        <LensButton name="back" current={status.lens} busy={busy} onPick={pick} />
      </div>

      <button
        disabled={busy || !status.serial || status.transport !== "usb"}
        onClick={pair}
        className="text-[13px] font-semibold text-cable disabled:opacity-40"
      >
        {status.transport === "wifi"
          ? `wireless • ${status.endpoint ?? ""}`
          : "enable wireless (needs USB now)"}
      </button>
      {status.transport === "wifi" && (
        <button onClick={unpair} className="text-xs text-sub underline">
          forget wireless, USB only
        </button>
      )}
      {pairMsg && <p className="text-xs text-sub">{pairMsg}</p>}

      {!status.video_ok && status.active && (
        <p className="text-xs text-stop">video node missing - replug the phone</p>
      )}
    </div>
  );
}
