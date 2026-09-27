#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
TMP="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-base01-p2-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$TMP"
trap 'rm -rf "$TMP"' EXIT

run_arm() {
  local name="$1"
  local specialized="$2"
  BASE01_P2_SPECIALIZED="$specialized"     bash tests/fpe/run_fpe_base01_p1b_outer.sh | tee "$TMP/$name.txt"
  grep -Fq 'FPE_BASE01_P1B=PASS' "$TMP/$name.txt"
}

# Alternate arm order by process parity to avoid systematic warm/cold bias.
if (( $$ % 2 == 0 )); then
  run_arm current 0
  run_arm specialized 1
else
  run_arm specialized 1
  run_arm current 0
fi

python3 - "$TMP/current.txt" "$TMP/specialized.txt" <<'PY'
import json,statistics,sys

def parse(path):
    rows={}
    agg=None
    for line in open(path):
        if line.startswith("BASE01_P1B_RAW|"):
            payload,tail=line.strip().split("|REGIME=",1)
            regime,rep=tail.split("|REP=",1)
            d=json.loads(payload.split("|",1)[1])
            key=(d["material"],float(d["h0"]),float(d["imbalance"]),regime,int(rep))
            rows[key]=d
        elif line.startswith("BASE01_P1B_AGG|"):
            vals={}
            for part in line.strip().split("|")[1:]:
                k,v=part.split("=",1)
                vals[k]=float(v)
            agg=vals
    if len(rows)!=60:
        raise SystemExit(f"{path}: expected 60 rows, got {len(rows)}")
    if agg is None:
        raise SystemExit(f"{path}: missing aggregate")
    return rows,agg

base,ba=parse(sys.argv[1])
cand,ca=parse(sys.argv[2])
if set(base)!=set(cand):
    raise SystemExit("P2 arm row-key mismatch")

diag=("transaction_calls","accepted_substeps","attempts","retries","solver_rejections",
      "temporal_rejections","nonlinear_iterations","backtracking_attempts")
max_q=0.0
for key in sorted(base):
    b=base[key]; c=cand[key]
    if b["heads"]!=c["heads"]:
        raise SystemExit(f"head sequence changed {key}")
    if tuple(int(b[k]) for k in diag)!=tuple(int(c[k]) for k in diag):
        raise SystemExit(f"discrete trajectory changed {key}")
    if len(b["q"])!=len(c["q"]):
        raise SystemExit(f"q size changed {key}")
    for x,y in zip(b["q"],c["q"]):
        d=abs(float(x)-float(y)); max_q=max(max_q,d)
        tol=128*2.220446049250313e-16*max(1.0,abs(float(x)),abs(float(y)))
        if d>tol:
            raise SystemExit(f"q drift {key}: {x} {y}")

def group_trial_sum(rows):
    groups={}
    for key,d in rows.items():
        g=key[:4]
        groups.setdefault(g,[]).append(float(d["swap_trial_ns"]))
    return sum(statistics.median(v) for v in groups.values())

bt=group_trial_sum(base)
ct=group_trial_sum(cand)
base_temporal=ba["TEMPORAL_NS"]; cand_temporal=ca["TEMPORAL_NS"]
base_backend=ba["BACKEND_NS"]; cand_backend=ca["BACKEND_NS"]

r_temporal=cand_temporal/base_temporal
r_backend=cand_backend/base_backend
r_trial=ct/bt
gain_temporal=1.0-r_temporal
gain_backend=1.0-r_backend
gain_trial=1.0-r_trial

qual=(gain_temporal>=0.15 and gain_backend>=0.03)
print(
  f"BASE01_P2_SUMMARY|CURRENT_TEMPORAL_NS={base_temporal:.3f}|SPECIALIZED_TEMPORAL_NS={cand_temporal:.3f}"
  f"|TEMPORAL_RATIO={r_temporal:.9f}|TEMPORAL_GAIN={gain_temporal:.9f}"
  f"|CURRENT_BACKEND_NS={base_backend:.3f}|SPECIALIZED_BACKEND_NS={cand_backend:.3f}"
  f"|BACKEND_RATIO={r_backend:.9f}|BACKEND_GAIN={gain_backend:.9f}"
  f"|CURRENT_TRIAL_NS={bt:.3f}|SPECIALIZED_TRIAL_NS={ct:.3f}"
  f"|TRIAL_RATIO={r_trial:.9f}|TRIAL_GAIN={gain_trial:.9f}"
  f"|MAX_ABS_Q_DIFF={max_q:.17e}|QUALIFIED={str(qual).upper()}"
)
if gain_temporal < 0.15:
    raise SystemExit(f"temporal runtime gate failed: {gain_temporal:.6f}")
if gain_backend < 0.03:
    raise SystemExit(f"backend runtime gate failed: {gain_backend:.6f}")
print("FPE_BASE01_P2=PASS")
PY
