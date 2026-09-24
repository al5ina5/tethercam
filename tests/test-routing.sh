#!/bin/bash
# TetherCam regression tests.
#
# The bug this guards against: the phone-mic scrcpy stream was also played to
# the default sink, so OBS "Desktop Audio" captured the mic a second time.
# The invariant: the mic stream lives on TetherSink and never on the default.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

fails=0
ok()  { printf 'ok   - %s\n' "$1"; }
bad() { printf 'FAIL - %s\n' "$1"; fails=$((fails + 1)); }

# 1. scripts parse
for s in scripts/tethercam scripts/tethercam-daemon install.sh uninstall.sh; do
  if bash -n "$s" 2>/dev/null; then ok "$s parses"; else bad "$s has syntax errors"; fi
done

# 2. the mic is user-facing as "TetherCam"
desc=$(pactl list sources 2>/dev/null | awk '
  /Name: TetherMic/ { f=1 }
  f && /Description:/ { sub(/.*Description: /, ""); print; exit }')
if [ "$desc" = "TetherCam" ]; then ok "TetherMic displays as TetherCam"
elif [ -z "$desc" ]; then echo "skip - TetherMic not present"
else bad "TetherMic description is '$desc'"; fi

# 3. routing invariant
sid=$(pactl list sink-inputs 2>/dev/null | awk '
  /^Sink Input #/ { id=$3 }
  /node\.name = "scrcpy"/ { gsub(/#/, "", id); found=id }
  END { if (found) print found }')
if [ -z "$sid" ]; then
  echo "skip - no scrcpy mic stream (phone unplugged?)"
else
  want=$(pactl list short sinks 2>/dev/null | awk '$2=="TetherSink"{print $1; exit}')
  cur=$(pactl list short sink-inputs 2>/dev/null | awk -v s="$sid" '$1==s{print $2}')
  if [ -n "$want" ] && [ "$cur" = "$want" ]; then ok "mic stream on TetherSink"
  else bad "mic stream on sink '$cur' (want TetherSink '$want')"; fi

  def=$(pactl get-default-sink 2>/dev/null || true)
  if [ -n "$def" ] && pw-link -l 2>/dev/null | awk -v d="$def" '
      /^scrcpy:output/ { s=1; next }
      /^[^ ]/ { s=0 }
      s && index($0, d ":playback") { f=1 }
      END { exit(f ? 0 : 1) }'; then
    bad "scrcpy is linked to the default sink '$def' (Desktop Audio leak)"
  else
    ok "scrcpy is not linked to the default sink"
  fi
fi

echo
if [ "$fails" -eq 0 ]; then echo "PASS"; else echo "$fails failure(s)"; exit 1; fi
