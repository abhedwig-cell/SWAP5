#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-pub-gc-e6a-${GITHUB_RUN_ID:-local}-$$"
OUT="${PUB_GC_E6A_RESULT_DIR:-$BUILD/results}"
mkdir -p "$BUILD" "$OUT"
trap 'rm -rf "$BUILD"' EXIT

FGC44_BUILD_DIR="$BUILD/fgc44" FGC44_SKIP_E2E=1 \
  bash tests/fgc/run_fgc44_real_swap_modflow_end_to_end.sh

SWAPLIB="$BUILD/fgc44/bridge/libfgc44_swap.so"
H0S=(-150 -75 -25 -10)
QBOTS=(1e-6 1e-4 1e-2 1e-1 1e0)

: > "$OUT/cases.jsonl"
: > "$OUT/case-output.txt"

for h0 in "${H0S[@]}"; do
  for q in "${QBOTS[@]}"; do
    echo "PUB_GC_E6A_CASE H0=$h0 QBOT=$q" | tee -a "$OUT/case-output.txt"
    CASE_OUT="$(
      FGC44_SWAP_LIB="$SWAPLIB" \
      E6A_WINDOW_DAY="1e-3" \
      E6A_H0_CM="$h0" \
      E6A_QBOT_CM_PER_DAY="$q" \
      python3 tests/publication/test_pub_gc_e6a_state_case.py
    )"
    printf '%s\n' "$CASE_OUT" | tee -a "$OUT/case-output.txt"
    JSON_LINE="$(printf '%s\n' "$CASE_OUT" | sed -n 's/^E6A_JSON=//p' | tail -n 1)"
    test -n "$JSON_LINE" || { echo "missing E6A JSON H0=$h0 q=$q" >&2; exit 1; }
    printf '%s\n' "$JSON_LINE" >> "$OUT/cases.jsonl"
  done
done

python3 - "$OUT" <<'PY'
from __future__ import annotations
import csv,json,math,sys
from pathlib import Path

out=Path(sys.argv[1])
records=[json.loads(x) for x in (out/"cases.jsonl").read_text().splitlines() if x.strip()]
if len(records)!=20:
    raise SystemExit(f"expected 20 E6A cases, got {len(records)}")

keys={(float(r["initial_h0_cm"]),float(r["predictor_qbot_cm_per_day"])) for r in records}
if len(keys)!=20:
    raise SystemExit("duplicate/missing E6A keys")

anchor=next(r for r in records if r["initial_h0_cm"]==-75.0 and r["predictor_qbot_cm_per_day"]==1e-4)
if not anchor["predictor_ready"]:
    raise SystemExit(f"E6A B3 predictor anchor regressed: {anchor}")

def probe_ready(r,delta):
    for p in r.get("probes",[]):
        if abs(float(p["delta_h_m"])-delta)<=1e-16:
            return bool(p["ready"])
    return False

candidates=[]
summary=[]
for r in sorted(records,key=lambda x:(x["initial_h0_cm"],x["predictor_qbot_cm_per_day"])):
    pair_ready=(
        r["predictor_ready"]
        and probe_ready(r,-1e-4)
        and probe_ready(r,+1e-4)
        and bool(r.get("predictor_mass_complete",False))
        and math.isfinite(float(r.get("predictor_mass_residual_native",math.nan)))
        and list(r.get("authority_state_after",[0,0.0,0,0.0]))==[0,0.0,0,0.0]
    )
    max_sym=None
    for d in (1e-6,1e-5,1e-4,1e-3):
        if probe_ready(r,-d) and probe_ready(r,+d):
            max_sym=d
    row={
        "initial_h0_cm":r["initial_h0_cm"],
        "predictor_qbot_cm_per_day":r["predictor_qbot_cm_per_day"],
        "predictor_status":r["predictor_status"],
        "predictor_ready":r["predictor_ready"],
        "reference_head_m":r.get("reference_head_m"),
        "predictor_u":r.get("predictor_u"),
        "predictor_q_u_cm_per_day":r.get("predictor_q_u_cm_per_day"),
        "predictor_storage_change_native":r.get("predictor_storage_change_native"),
        "predictor_mass_residual_native":r.get("predictor_mass_residual_native"),
        "max_symmetric_ready_delta_h_m":max_sym,
        "qualifies_for_e6b":pair_ready,
    }
    summary.append(row)
    if pair_ready:
        candidates.append(row)

if candidates:
    candidates.sort(key=lambda r:(float(r["predictor_qbot_cm_per_day"]),float(r["initial_h0_cm"])),reverse=True)
    selected=candidates[0]
else:
    selected=None

expanded=selected is not None and float(selected["predictor_qbot_cm_per_day"])>1e-4
status="EXPANDED_STATE_DOMAIN" if expanded else ("PREDICTOR_ONLY_OR_NO_USEFUL_EXPANSION")

payload={
    "schema":"pub-gc-e6a-result-v1",
    "case_count":len(records),
    "window_day":1e-3,
    "status":status,
    "qualifying_candidate_count":len(candidates),
    "selected_e6b_candidate":selected if expanded else None,
    "summary":summary,
    "records":records,
}
(out/"PUB_GC_E6A_RESULT.json").write_text(json.dumps(payload,indent=2,sort_keys=True)+"\n")

fields=sorted({k for row in summary for k in row})
with (out/"PUB_GC_E6A_SUMMARY.csv").open("w",newline="") as fh:
    w=csv.DictWriter(fh,fieldnames=fields)
    w.writeheader(); w.writerows(summary)

print(json.dumps({k:v for k,v in payload.items() if k!="records" and k!="summary"},indent=2,sort_keys=True))
print("PUB_GC_E6A_STATE_SCREEN_COMPLETE=PASS")
PY
