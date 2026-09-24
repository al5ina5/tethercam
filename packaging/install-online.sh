#!/bin/bash
# TetherCam one-line installer.
#
#   curl -fsSL https://raw.githubusercontent.com/al5ina5/tethercam/main/packaging/install-online.sh | bash
#
# Override the ref (branch or tag) with TETHERCAM_REF:
#   curl -fsSL .../install-online.sh | TETHERCAM_REF=v0.1.0 bash
set -euo pipefail
REF="${TETHERCAM_REF:-main}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
echo "tethercam: fetching $REF ..."
curl -fsSL "https://github.com/al5ina5/tethercam/archive/${REF}.tar.gz" \
  | tar -xz -C "$tmp" --strip-components=1
exec "$tmp/install.sh"
