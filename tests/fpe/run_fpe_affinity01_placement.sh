#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-affinity01-${GITHUB_RUN_ID:-local}-$"
N="${AFFINITY01_N:-10000}"
REPS="${AFFINITY01_REPS:-5}"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "FPE_AFFINITY01_FAIL $*" >&2; exit 1; }

python3 - "$BUILD/multi04_nogate.sh" <<'PY'
from pathlib import Path
import sys
s=Path("tests/fpe/run_fpe_multi04_p1c_application_context_scaling.sh").read_text()
s=s.replace('if s2 < 1.5: raise SystemExit(f"2-worker frozen speed gate failed: {s2}")\n','')
s=s.replace('if s4 < 2.2: raise SystemExit(f"4-worker frozen speed gate failed: {s4}")\n','')
Path(sys.argv[1]).write_text(s)
PY
chmod +x "$BUILD/multi04_nogate.sh"

run_variant() {
  local tag="$1"
  local bind="$2"
  local places="$3"
  local out="$BUILD/$tag.txt"
  echo "AFFINITY01_VARIANT_BEGIN|TAG=$tag|BIND=$bind|PLACES=$places"
  if [[ "$tag" == "DEFAULT" ]]; then
    env -u OMP_PROC_BIND -u OMP_PLACES       MULTI04_P1C_N="$N" MULTI04_P1C_REPS="$REPS"       bash "$BUILD/multi04_nogate.sh" | tee "$out"
  else
    OMP_PROC_BIND="$bind" OMP_PLACES="$places" OMP_DYNAMIC=FALSE       MULTI04_P1C_N="$N" MULTI04_P1C_REPS="$REPS"       bash "$BUILD/multi04_nogate.sh" | tee "$out"
  fi
}

run_variant DEFAULT "" ""
run_variant SPREAD_THREADS spread threads
run_variant CLOSE_THREADS close threads
run_variant SPREAD_CORES spread cores
run_variant CLOSE_CORES close cores

python3 - "$BUILD" <<'PY'
import re,sys
from pathlib import Path
build=Path(sys.argv[1])
tags=["DEFAULT","SPREAD_THREADS","CLOSE_THREADS","SPREAD_CORES","CLOSE_CORES"]
rows={}
for tag in tags:
    txt=(build/f"{tag}.txt").read_text()
    m=re.search(
        r'MULTI04_P1C_SUMMARY\|N=(\d+)\|W1_SECONDS=([^|]+)\|W2_SECONDS=([^|]+)\|W4_SECONDS=([^|]+)\|'
        r'SPEEDUP2=([^|]+)\|SPEEDUP4=([^|]+)\|QSUM=([^|]+)\|TSUM=(.+)',txt)
    if not m:
        raise SystemExit(f"missing summary {tag}")
    rows[tag]=dict(n=int(m.group(1)),w1=float(m.group(2)),w4=float(m.group(4)),
                   q=float(m.group(7)),t=float(m.group(8)))

base=rows["DEFAULT"]
best=("DEFAULT",1.0,1.0)
for tag,row in rows.items():
    if row["n"]!=base["n"]:
        raise SystemExit(f"N mismatch {tag}")
    if row["q"]!=base["q"] or row["t"]!=base["t"]:
        raise SystemExit(f"semantic checksum mismatch {tag}")
    s1=base["w1"]/row["w1"]
    s4=base["w4"]/row["w4"]
    print(
        f"AFFINITY01_SUMMARY|TAG={tag}|N={row['n']}|W1_SECONDS={row['w1']:.12f}|"
        f"W4_SECONDS={row['w4']:.12f}|W1_VS_DEFAULT={s1:.6f}|W4_VS_DEFAULT={s4:.6f}|"
        f"QSUM={row['q']:.17e}|TSUM={row['t']:.17e}"
    )
    if tag!="DEFAULT" and s4>best[1]:
        best=(tag,s4,s1)

if best[1]>=1.05 and best[2]>=1/1.02:
    decision="SELECT_"+best[0]
else:
    decision="NO_AFFINITY_CANDIDATE"
print(f"AFFINITY01_DECISION|BEST={best[0]}|W4_SPEEDUP={best[1]:.6f}|W1_SPEEDUP={best[2]:.6f}|DECISION={decision}")
print("FPE_AFFINITY01=PASS")
PY
