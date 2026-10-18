#!/usr/bin/env bash
# Explicit research candidate; no canonical/hydraulic-owner admission implied.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RAW="$(realpath "${1:?original artifact weather.csv required}")"
ENDPOINT="$(realpath "${2:?2026-10-02 endpoint JSON required}")"
OUT="$(realpath -m "${3:?fresh output directory required}")"
mkdir -p "$OUT"
cd "$ROOT"
python3 research/kalmthout_pilot/align_existing_forcing.py "$RAW" "$ENDPOINT" "$OUT/weather_aligned.csv" > "$OUT/alignment_audit.json"
python3 research/kalmthout_pilot/swap431/prepare_reference_forcing.py "$OUT/weather_aligned.csv" "$OUT/swap431-case" > "$OUT/swap431_inputs.json"
python3 research/kalmthout_pilot/build_local.py "$OUT/build-O2" -O2 research/kalmthout_pilot/matched200_context.f90 continuous > "$OUT/build.log" 2>&1
"$OUT/build-O2/pilot" "$OUT/weather_aligned.csv" "$OUT/swap5.csv" 0 1.0 32 40 matched200 > "$OUT/swap5.log" 2>&1
python3 research/kalmthout_pilot/validate_completed_run.py "$OUT/swap5.csv"
if [[ -n "${SWAP431_EXE:-}" ]]; then
  EXE="$(realpath "$SWAP431_EXE")"
  set +e
  (cd "$OUT/swap431-case" && "$EXE" > stdout.log 2> stderr.log)
  rc=$?
  set -e
  test "$rc" -eq 100
  grep -Fq 'Swap simulation okay!' "$OUT/swap431-case/swap.log"
fi
