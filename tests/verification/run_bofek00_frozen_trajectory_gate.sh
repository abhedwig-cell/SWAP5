#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

AUTH=0b67e2af993f16e9d1678b70cacfe9b164954140
TARGET=tests/verification/test_bofek00_frozen_wet_trajectory.f90
COMPILER="$ROOT/tests/rom/compile_f_rom0_fortran_closure.py"
MATERIALIZER="$ROOT/tests/rom/materialize_f_rom0_headcalc_stubs.py"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-bofek00-frozen-${GITHUB_RUN_ID:-local}-$$"
OLD="$BUILD/old"
mkdir -p "$BUILD"
trap 'git worktree remove --force "$OLD" >/dev/null 2>&1 || true; rm -rf "$BUILD"' EXIT
fail(){ echo "F_PE_BOFEK00_FROZEN_GATE_FAIL $*" >&2; exit 1; }

git fetch --no-tags origin "$AUTH"
git merge-base --is-ancestor "$AUTH" HEAD || fail "candidate lost frozen reproduction ancestry"
git worktree add --detach "$OLD" "$AUTH" >/dev/null
mkdir -p "$OLD/tests/verification"
cp "$TARGET" "$OLD/$TARGET"

run_one(){
  local label="$1"
  local root="$2"
  local out="$BUILD/$label"
  mkdir -p "$out"
  python3 "$MATERIALIZER" --source "$root/tests/fsi/fsi04_real_headcalc_stubs.f90" --output "$out/stubs.f90" --nodes 16 --dz-cm 10
  # compiler paths are interpreted relative to --root, so place the generated stub under that root.
  cp "$out/stubs.f90" "$root/tests/verification/bofek00_generated_stubs.f90"
  python3 "$COMPILER" --root "$root"     --stub tests/verification/bofek00_generated_stubs.f90     --external-source src/legacy/b1_10_port/headcalc.f90     --target "$TARGET" --build "$out/compile" --opt 2
  "$out/compile/rom0_test" > "$out/result.txt" 2>&1 || { cat "$out/result.txt" >&2; fail "$label runtime"; }
  grep -Fq 'F_PE_BOFEK00_FROZEN_TRAJECTORY=PASS' "$out/result.txt" || fail "$label missing pass marker"
  rm -f "$root/tests/verification/bofek00_generated_stubs.f90"
}

run_one old "$OLD"
run_one corrected "$ROOT"

python3 - "$BUILD/old/result.txt" "$BUILD/corrected/result.txt" "$BUILD/summary.json" <<'PY'
import json,re,sys,math
from pathlib import Path

def parse(path):
    steps=[]
    heads=[]
    summary={}
    for line in Path(path).read_text().splitlines():
        if line.startswith("BOFEK00_FROZEN|"):
            row={}
            for item in line.split("|")[1:]:
                k,v=item.split("=",1)
                row[k]=float(v) if k not in {"STEP","NEWTON","BACKTRACK","RETRIES"} else int(float(v))
            steps.append(row)
        elif line.startswith("BOFEK00_HEADS,"):
            heads.append([float(x) for x in line.split(",")[1:]])
        elif line.startswith("BOFEK00_FROZEN_SUMMARY|"):
            for item in line.split("|")[1:]:
                k,v=item.split("=",1)
                summary[k]=float(v) if k!="STEPS" else int(float(v))
    assert len(steps)==24 and len(heads)==24
    return {"steps":steps,"heads":heads,"summary":summary}

old=parse(sys.argv[1]); new=parse(sys.argv[2])
def total(key,obj): return sum(x[key] for x in obj["steps"])
out={
 "work_unit":"F-PE-BOFEK00E",
 "timestep_sequence_days":[x["DT"] for x in old["steps"]],
 "same_timestep_sequence": [x["DT"] for x in old["steps"]]==[x["DT"] for x in new["steps"]],
 "old":{
   "cumulative_runoff_cm":old["summary"]["CUMRUNOFF"],
   "final_pond_cm":old["summary"]["FINAL_POND"],
   "newton_iterations":total("NEWTON",old),
   "backtracks":total("BACKTRACK",old),
   "internal_retries":total("RETRIES",old),
   "native_mass_diagnostic_finite":all(math.isfinite(x["MASS_NATIVE"]) for x in old["steps"]),
   "max_abs_native_mass_if_finite":max([abs(x["MASS_NATIVE"]) for x in old["steps"] if math.isfinite(x["MASS_NATIVE"])] or [0.0]),
   "max_abs_ledger":max(abs(x["LEDGER"]) for x in old["steps"])
 },
 "corrected":{
   "cumulative_runoff_cm":new["summary"]["CUMRUNOFF"],
   "final_pond_cm":new["summary"]["FINAL_POND"],
   "newton_iterations":total("NEWTON",new),
   "backtracks":total("BACKTRACK",new),
   "internal_retries":total("RETRIES",new),
   "native_mass_diagnostic_finite":all(math.isfinite(x["MASS_NATIVE"]) for x in new["steps"]),
   "max_abs_native_mass_if_finite":max([abs(x["MASS_NATIVE"]) for x in new["steps"] if math.isfinite(x["MASS_NATIVE"])] or [0.0]),
   "max_abs_ledger":max(abs(x["LEDGER"]) for x in new["steps"])
 },
 "trajectory":{
   "max_abs_head_difference_cm":max(abs(a-b) for ha,hb in zip(old["heads"],new["heads"]) for a,b in zip(ha,hb)),
   "max_abs_pond_difference_cm":max(abs(a["POND"]-b["POND"]) for a,b in zip(old["steps"],new["steps"])),
   "max_abs_runoff_step_difference_cm":max(abs(a["RUNOFF"]-b["RUNOFF"]) for a,b in zip(old["steps"],new["steps"])),
   "max_abs_qbot_difference_cm_per_day":max(abs(a["QBOT"]-b["QBOT"]) for a,b in zip(old["steps"],new["steps"]))
 }
}
Path(sys.argv[3]).write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
print(json.dumps(out,indent=2,sort_keys=True))
assert out["same_timestep_sequence"]
assert out["old"]["max_abs_ledger"] < 1e-8
assert out["corrected"]["max_abs_ledger"] < 1e-8
print("F_PE_BOFEK00_FROZEN_COMPARISON=PASS")
PY

cat "$BUILD/summary.json"
echo "F_PE_BOFEK00_FROZEN_GATE=PASS"
