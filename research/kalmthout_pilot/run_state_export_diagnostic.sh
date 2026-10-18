#!/usr/bin/env bash
# Run only the existing 1700-hour Kalmthout diagnostic then validate accepted-state export.
# Requires a local checkout on research/kalmthout-sw5-state-export-20261018.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
test "$(git branch --show-current)" = "research/kalmthout-sw5-state-export-20261018" || {
  echo "wrong research branch" >&2; exit 2;
}
OUT="${1:-$ROOT/kalmthout-export-result}"
mkdir -p "$OUT"
KALMTHOUT_NEWTON_TRACE=1 KALMTHOUT_DRY_DIAG_ONLY=1   bash research/kalmthout_pilot/run_kalmthout_official.sh "$OUT" > "$OUT/run.log" 2>&1
python3 research/kalmthout_pilot/validate_state_dump.py "$OUT/dry_diagnostic.log"
echo "STATE_EXPORT_VERIFIED=PASS (diagnostic simulation may intentionally fail)"
