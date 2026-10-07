#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/mc-irr01-avail-source-${GITHUB_RUN_ID:-local}-$$"
rm -rf "$BUILD"; mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
BUNDLE=integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64
base64 -d "$BUNDLE" > "$BUILD/authority.tar.gz"
tar -xzf "$BUILD/authority.tar.gz" -C "$BUILD"
SRC="$(find "$BUILD" -type f -path '*/SWAP/irrigation.f90' -print -quit)"
test -n "$SRC"
test "$(sha256sum "$SRC" | awk '{print $1}')" = "65830c1e030be8030995547729d9298e6352778f132e5195af2962baa38a3bf1"

echo 'MC_IRR01_AVAIL_TRACE_BEGIN'
grep -Rni --include='*.f90' --include='*.F90' --include='*.f' --include='*.F' -E 'F_IRR_AVAIL|f_irr_avail|TASK[[:space:]]*=[[:space:]]*4' "$BUILD" || true
echo 'MC_IRR01_AVAIL_TRACE_END'

COUNT="$(grep -Ril --include='*.f90' --include='*.F90' --include='*.f' --include='*.F' -E 'F_IRR_AVAIL|f_irr_avail' "$BUILD" | wc -l | tr -d ' ')"
echo "MC_IRR01_AVAIL_SOURCE_FILE_COUNT=$COUNT"
grep -Fq 'gird = gird * f_irr_avail' "$SRC"
grep -Fq 'if (irr_rate > 0.0d0) dt_irr_event = dt_irr_event * f_irr_avail' "$SRC"
echo 'MC_IRR01_AVAIL_SOURCE_TRACE=PASS'
