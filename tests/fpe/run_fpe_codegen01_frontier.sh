#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-codegen01-${GITHUB_RUN_ID:-local}-$$"
N="${CODEGEN01_N:-10000}"
REPS="${CODEGEN01_REPS:-5}"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "FPE_CODEGEN01_FAIL $*" >&2; exit 1; }

BASE_SCRIPT="tests/fpe/run_fpe_multi04_p1c_application_context_scaling.sh"

run_variant() {
  local tag="$1"
  local flags="$2"
  local out="$BUILD/$tag.txt"
  local runner="$BUILD/$tag.sh"

  python3 - "$BASE_SCRIPT" "$runner" "$flags" <<'PY'
from pathlib import Path
import sys
src=Path(sys.argv[1]).read_text()
out=Path(sys.argv[2])
flags=sys.argv[3]

src=src.replace("swap5-multi04-p1c-","swap5-codegen01-"+out.stem+"-",1)
src=src.replace(
    'gfortran "${COMMON[@]}" -O2 -J "$OUT" -I "$OUT" -c "$source" -o "$obj"',
    f'gfortran "${{COMMON[@]}}" {flags} -J "$OUT" -I "$OUT" -c "$source" -o "$obj"')
src=src.replace(
    'gfortran -shared -fopenmp -O2 "${objects[@]}" -o "$OUT/libmulti04.so"',
    f'gfortran -shared -fopenmp {flags} "${{objects[@]}}" -o "$OUT/libmulti04.so"')
if "-O2" in src:
    raise SystemExit("unpatched -O2 remains in generated runner")
out.write_text(src)
PY
  chmod +x "$runner"
  echo "CODEGEN01_VARIANT_BEGIN|TAG=$tag|FLAGS=$flags"
  MULTI04_P1C_N="$N" MULTI04_P1C_REPS="$REPS" bash "$runner" | tee "$out"
  echo "CODEGEN01_VARIANT_END|TAG=$tag"
}

run_variant BASE_O2 "-O2"
run_variant O3 "-O3"
run_variant O3_NATIVE "-O3 -march=native"
run_variant O3_NATIVE_LTO "-O3 -march=native -flto"

python3 - "$BUILD" <<'PY'
import re,sys
from pathlib import Path
build=Path(sys.argv[1])
tags=["BASE_O2","O3","O3_NATIVE","O3_NATIVE_LTO"]
rows={}
for tag in tags:
    txt=(build/f"{tag}.txt").read_text()
    m=re.search(
        r'MULTI04_P1C_SUMMARY\|N=(\d+)\|W1_SECONDS=([^|]+)\|W2_SECONDS=([^|]+)\|W4_SECONDS=([^|]+)\|'
        r'SPEEDUP2=([^|]+)\|SPEEDUP4=([^|]+)\|QSUM=([^|]+)\|TSUM=(.+)',txt)
    if not m:
        raise SystemExit(f"missing summary {tag}")
    rows[tag]={
        "n":int(m.group(1)),
        "w1":float(m.group(2)),
        "w2":float(m.group(3)),
        "w4":float(m.group(4)),
        "s2":float(m.group(5)),
        "s4":float(m.group(6)),
        "q":float(m.group(7)),
        "t":float(m.group(8)),
    }

base=rows["BASE_O2"]
for tag,row in rows.items():
    if row["n"] != base["n"]:
        raise SystemExit(f"N mismatch {tag}")
    if row["q"] != base["q"] or row["t"] != base["t"]:
        raise SystemExit(f"semantic checksum mismatch {tag}")
    speed1=base["w1"]/row["w1"]
    speed4=base["w4"]/row["w4"]
    print(
        f"CODEGEN01_SUMMARY|TAG={tag}|N={row['n']}|W1_SECONDS={row['w1']:.12f}|"
        f"W4_SECONDS={row['w4']:.12f}|W1_VS_O2={speed1:.6f}|W4_VS_O2={speed4:.6f}|"
        f"INTERNAL_SPEEDUP4={row['s4']:.6f}|QSUM={row['q']:.17e}|TSUM={row['t']:.17e}"
    )

candidates=[]
for tag in tags[1:]:
    row=rows[tag]
    speed1=base["w1"]/row["w1"]
    speed4=base["w4"]/row["w4"]
    if speed4 >= 1.05 and speed1 >= 1/1.02:
        candidates.append((tag,speed4,speed1))

if not candidates:
    decision="NO_CODEGEN_CANDIDATE"
else:
    best=max(candidates,key=lambda x:x[1])
    if best[0]=="O3":
        decision="SELECT_O3"
    elif best[0]=="O3_NATIVE":
        o3=next((x for x in candidates if x[0]=="O3"),None)
        if o3 and best[1] < o3[1]*1.03:
            decision="SELECT_O3"
        else:
            decision="SELECT_NATIVE_RESEARCH"
    else:
        non_lto=max((x for x in candidates if x[0]!="O3_NATIVE_LTO"),default=None,key=lambda x:x[1])
        if non_lto and best[1] < non_lto[1]*1.03:
            decision="SELECT_"+non_lto[0]
        else:
            decision="SELECT_LTO_RESEARCH"
print(f"CODEGEN01_DECISION|DECISION={decision}")
print("FPE_CODEGEN01=PASS")
PY
