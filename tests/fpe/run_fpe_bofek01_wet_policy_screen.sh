#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
MATERIALIZER=tests/rom/materialize_f_rom0_headcalc_stubs.py
SOURCE=tests/verification/test_bofek00_adaptive_wet_trajectory.f90
WORK="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-bofek01-screen-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$WORK"
trap 'rm -rf "$WORK"' EXIT
fail(){ echo "F_PE_BOFEK01_SCREEN_FAIL $*" >&2; exit 1; }

git fetch --no-tags origin integration/f-ci-canonical
LIVE="$(git rev-parse FETCH_HEAD)"
[[ "$LIVE" == "50ee9dc2acbc9847807d3fd98d0553f9862d428b" ]] || fail "canonical drift: $LIVE"

grep -Fq "if (numbit <= numbit_crit) dt = min(dt*fact_dt_increase,dtMax)" src/legacy/b1_10_fci11_port/timecontrol_part04.inc || fail "growth policy drift"
grep -Fq "if (numbit >= MaxIt)       dt = max(dt*fact_dt_decrease,dtMin)" src/legacy/b1_10_fci11_port/timecontrol_part04.inc || fail "accepted reduction policy drift"
grep -Fq "dt = dt / fact_dt_fldect" src/legacy/b1_10_fci11_port/timecontrol_part05.inc || fail "failure reduction policy drift"
grep -Fq "FMR_REFERENCE_BALANCE_FLOOR_DEPTH_CM = 2.8e-16_real64" src/runtime/mod_fmr_serialized_reference_backend.f90 || fail "BALTOL02 floor drift"

python3 - "$SOURCE" "$WORK" <<'PY'
from pathlib import Path
import re,sys
src=Path(sys.argv[1]).read_text()
out=Path(sys.argv[2])
candidates=[
("baseline",0.001,0.02,4,8,2.0,0.5,2.0),
("dtmax_half",0.001,0.01,4,8,2.0,0.5,2.0),
("dtmax_x2",0.001,0.04,4,8,2.0,0.5,2.0),
("dtmax_x4",0.001,0.08,4,8,2.0,0.5,2.0),
("numbit_2",0.001,0.02,2,8,2.0,0.5,2.0),
("numbit_6",0.001,0.02,6,8,2.0,0.5,2.0),
("inc_1p5",0.001,0.02,4,8,1.5,0.5,2.0),
("inc_3",0.001,0.02,4,8,3.0,0.5,2.0),
]
for name,dtmin,dtmax,numbit,maxit,inc,dec,fail in candidates:
    t=src
    t=re.sub(r"real\(real64\), parameter :: DTMIN=0\.001_real64, DTMAX=0\.02_real64",
             f"real(real64), parameter :: DTMIN={dtmin:.12g}_real64, DTMAX={dtmax:.12g}_real64",t)
    t=re.sub(r"real\(real64\), parameter :: FACT_INC=2\.0_real64, FACT_DEC=0\.5_real64, FACT_FAIL=2\.0_real64",
             f"real(real64), parameter :: FACT_INC={inc:.12g}_real64, FACT_DEC={dec:.12g}_real64, FACT_FAIL={fail:.12g}_real64",t)
    t=re.sub(r"integer, parameter :: NUMBIT_CRIT=4, MAXIT_POLICY=8, MAX_ATTEMPTS=256",
             f"integer, parameter :: NUMBIT_CRIT={numbit}, MAXIT_POLICY={maxit}, MAX_ATTEMPTS=256",t)
    Path(out/f"{name}.f90").write_text(t)
PY

run_one(){
  local name="$1"
  local build="$WORK/build-$name"
  local stub="$WORK/stub-$name.f90"
  python3 "$MATERIALIZER" --source tests/fsi/fsi04_real_headcalc_stubs.f90 --output "$stub" --nodes 16 --dz-cm 10
  python3 "$COMPILER" --root "$ROOT" --stub "$stub" --target "$WORK/$name.f90"     --external-source src/legacy/b1_10_port/headcalc.f90 --build "$build" --opt 2
  /usr/bin/time -f "%e" -o "$WORK/$name.time" env OMP_NUM_THREADS=1 OMP_DYNAMIC=false "$build/rom0_test" > "$WORK/$name.out" 2>&1
  grep -Fq "F_PE_BOFEK00_ADAPTIVE_TRAJECTORY=PASS" "$WORK/$name.out" || { cat "$WORK/$name.out" >&2; fail "$name"; }
}

for name in baseline dtmax_half dtmax_x2 dtmax_x4 numbit_2 numbit_6 inc_1p5 inc_3; do
  run_one "$name"
done

python3 - "$WORK" <<'PY'
from pathlib import Path
import json,statistics,sys
w=Path(sys.argv[1])
names=["baseline","dtmax_half","dtmax_x2","dtmax_x4","numbit_2","numbit_6","inc_1p5","inc_3"]

def parse(name):
    end=None; accepts=[]
    for line in (w/f"{name}.out").read_text().splitlines():
        if line.startswith("F_PE_BOFEK00_ADAPTIVE_ACCEPT|"):
            accepts.append(dict(x.split("=",1) for x in line.split("|")[1:]))
        elif line.startswith("F_PE_BOFEK00_ADAPTIVE_END|"):
            end=dict(x.split("=",1) for x in line.split("|")[1:])
    if not end: raise SystemExit(f"missing end {name}")
    return {
      "accepted":int(end["ACCEPTED"]),"rejected":int(end["REJECTED"]),
      "growths":int(end["GROWTHS"]),"reductions":int(end["REDUCTIONS"]),
      "nonlinear":int(end["TOTAL_NL"]),"backtracks":int(end["TOTAL_BACK"]),
      "runoff":float(end["CUM_RUNOFF"]),"top_h":float(end["TOP_H"]),"pond":float(end["POND"]),
      "ledger":float(end["MAX_ABS_LEDGER"]),
      "accepted_dt":[float(x["DT"]) for x in accepts],
      "wall_seconds":float((w/f"{name}.time").read_text().strip())
    }

rows={n:parse(n) for n in names}
b=rows["baseline"]
for n,r in rows.items():
    r["work_proxy"]=r["nonlinear"]+r["backtracks"]
    r["work_ratio"]=r["work_proxy"]/b["work_proxy"]
    r["runoff_abs_delta"]=abs(r["runoff"]-b["runoff"])
    r["top_h_abs_delta"]=abs(r["top_h"]-b["top_h"])
    r["pond_abs_delta"]=abs(r["pond"]-b["pond"])
    r["strict_smoke_pass"]=(r["ledger"]<=5e-8 and r["runoff_abs_delta"]<=1e-4 and
                            r["top_h_abs_delta"]<=1e-3 and r["pond_abs_delta"]<=1e-4 and
                            r["rejected"]<=max(1,2*b["rejected"]))
    print("F_PE_BOFEK01_SCREEN|"+n+"|"+json.dumps(r,sort_keys=True,separators=(",",":")))
print("F_PE_BOFEK01_SCREEN_JSON="+json.dumps(rows,sort_keys=True,separators=(",",":")))
print("F_PE_BOFEK01_SCREEN=PASS")
PY
