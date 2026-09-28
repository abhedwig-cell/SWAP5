#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

AUTH=0b67e2af993f16e9d1678b70cacfe9b164954140
TARGET=tests/verification/test_bofek00_adaptive_wet_application.f90
COMPILER="$ROOT/tests/rom/compile_f_rom0_fortran_closure.py"
MATERIALIZER="$ROOT/tests/rom/materialize_f_rom0_headcalc_stubs.py"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-bofek00-ladder-${GITHUB_RUN_ID:-local}-$$"
OLD="$BUILD/old"
DURATIONS=(10 20 40 80 160 320)
mkdir -p "$BUILD"
trap 'git worktree remove --force "$OLD" >/dev/null 2>&1 || true; rm -rf "$BUILD"' EXIT
fail(){ echo "F_PE_BOFEK00_LADDER_FAIL $*" >&2; exit 1; }

git fetch --no-tags origin "$AUTH"
git merge-base --is-ancestor "$AUTH" HEAD || fail "candidate lost frozen reproduction ancestry"
git worktree add --detach "$OLD" "$AUTH" >/dev/null
mkdir -p "$OLD/tests/verification"
cp "$TARGET" "$OLD/$TARGET"

compile_one(){
  local label="$1"
  local root="$2"
  local out="$BUILD/$label"
  mkdir -p "$out"
  python3 "$MATERIALIZER" --source "$root/tests/fsi/fsi04_real_headcalc_stubs.f90" --output "$out/stubs.f90" --nodes 16 --dz-cm 10
  cp "$out/stubs.f90" "$root/tests/verification/bofek00_generated_stubs.f90"
  python3 "$COMPILER" --root "$root"     --stub tests/verification/bofek00_generated_stubs.f90     --external-source src/legacy/b1_10_port/headcalc.f90     --target "$TARGET" --build "$out/compile" --opt 2
  rm -f "$root/tests/verification/bofek00_generated_stubs.f90"
}

compile_one old "$OLD"
compile_one corrected "$ROOT"

for label in old corrected; do
  : > "$BUILD/$label/ladder.txt"
  for seconds in "${DURATIONS[@]}"; do
    set +e
    /usr/bin/time -f '%e' -o "$BUILD/$label/time.txt" "$BUILD/$label/compile/rom0_test" "$seconds"       > "$BUILD/$label/result.txt" 2>&1
    rc=$?
    set -e
    line="$(grep '^BOFEK00_ADAPTIVE|' "$BUILD/$label/result.txt" | tail -1 || true)"
    [[ -n "$line" ]] || { cat "$BUILD/$label/result.txt" >&2; fail "$label $seconds missing diagnostic"; }
    runtime="$(cat "$BUILD/$label/time.txt")"
    printf '%s|PROCESS_RC=%s|RUNTIME_SECONDS=%s\n' "$line" "$rc" "$runtime" >> "$BUILD/$label/ladder.txt"
  done
done

python3 - "$BUILD/old/ladder.txt" "$BUILD/corrected/ladder.txt" "$BUILD/summary.json" <<'PY'
import json,sys
from pathlib import Path

INTS={"KERNEL_STATUS","ACCEPTED_SUBSTEPS","SOLVER_ITERATIONS","NONLINEAR","INTERNAL_RETRIES",
      "HEADCALC_CALLS","JACOBIAN_BUILDS","LINEAR_SOLVES","BACKTRACK","ALT_SOLVER","PROCESS_RC"}

def parse(path):
    rows=[]
    for line in Path(path).read_text().splitlines():
        row={}
        for item in line.split("|")[1:]:
            k,v=item.split("=",1)
            if v in {"T","F"}:
                row[k]=(v=="T")
            elif k in INTS:
                row[k]=int(float(v))
            else:
                row[k]=float(v)
        rows.append(row)
    return rows

old=parse(sys.argv[1]); new=parse(sys.argv[2])
assert [r["DURATION_SECONDS"] for r in old] == [10.0,20.0,40.0,80.0,160.0,320.0]
assert [r["DURATION_SECONDS"] for r in new] == [10.0,20.0,40.0,80.0,160.0,320.0]

def classify(a,b):
    oa=bool(a.get("COMPLETED",False) and a.get("COMMITTED",False))
    nb=bool(b.get("COMPLETED",False) and b.get("COMMITTED",False))
    if oa and nb: return "BOTH_ACCEPT"
    if (not oa) and nb: return "CORRECTED_ONLY_ACCEPTS"
    if oa and (not nb): return "OLD_ONLY_ACCEPTS"
    return "BOTH_FAIL"

pairs=[]
for a,b in zip(old,new):
    pairs.append({
      "duration_seconds":a["DURATION_SECONDS"],
      "classification":classify(a,b),
      "old":a,
      "corrected":b,
      "delta":{
        "accepted_substeps":b["ACCEPTED_SUBSTEPS"]-a["ACCEPTED_SUBSTEPS"],
        "nonlinear_iterations":b["NONLINEAR"]-a["NONLINEAR"],
        "internal_retries":b["INTERNAL_RETRIES"]-a["INTERNAL_RETRIES"],
        "backtracks":b["BACKTRACK"]-a["BACKTRACK"],
        "runtime_seconds":b["RUNTIME_SECONDS"]-a["RUNTIME_SECONDS"]
      }
    })

old_accept=[p["duration_seconds"] for p in pairs if p["old"].get("COMPLETED",False) and p["old"].get("COMMITTED",False)]
new_accept=[p["duration_seconds"] for p in pairs if p["corrected"].get("COMPLETED",False) and p["corrected"].get("COMMITTED",False)]
out={
 "work_unit":"F-PE-BOFEK00F-LADDER",
 "policy_unchanged":True,
 "durations_seconds":[10,20,40,80,160,320],
 "old_max_accepted_seconds":max(old_accept) if old_accept else None,
 "corrected_max_accepted_seconds":max(new_accept) if new_accept else None,
 "pairs":pairs
}
Path(sys.argv[3]).write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
print(json.dumps(out,indent=2,sort_keys=True))
for p in pairs:
    for side in ("old","corrected"):
        r=p[side]
        if r.get("COMPLETED",False):
            assert r.get("MASS_COMPLETE",False)
            assert abs(r["MASS_RESIDUAL"]) <= 1e-8
print("F_PE_BOFEK00_ADAPTIVE_LADDER=PASS")
PY

cat "$BUILD/summary.json"
echo "F_PE_BOFEK00_ADAPTIVE_LADDER_GATE=PASS"
