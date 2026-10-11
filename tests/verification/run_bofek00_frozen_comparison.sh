#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BASE=1759caebb7ca3bd62bbee65d9319f5d71d3e73f5
TARGET=tests/verification/test_bofek00_frozen_wet_trajectory.f90
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
MATERIALIZER=tests/rom/materialize_f_rom0_headcalc_stubs.py
WORK="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-bofek00-frozen-${GITHUB_RUN_ID:-local}-$$"
BASEWT="$WORK/base"
BUILD="$WORK/build"
mkdir -p "$WORK" "$BUILD"
trap 'git worktree remove --force "$BASEWT" >/dev/null 2>&1 || true; rm -rf "$WORK"' EXIT
fail(){ echo "F_PE_BOFEK00_FROZEN_GATE_FAIL $*" >&2; exit 1; }

git fetch --no-tags origin integration/f-ci-canonical
LIVE="$(git rev-parse FETCH_HEAD)"
[[ "$LIVE" == "$BASE" ]] || fail "canonical advanced after preregistration: $LIVE"
git worktree add --detach "$BASEWT" "$BASE" >/dev/null
mkdir -p "$BASEWT/tests/verification"
cp "$TARGET" "$BASEWT/$TARGET"

build_one(){
  local root="$1" label="$2" out="$BUILD/$2"
  local stubrel="tests/verification/.bofek00_stub_${label}.f90"
  python3 "$MATERIALIZER" --source "$root/tests/fsi/fsi04_real_headcalc_stubs.f90" --output "$root/$stubrel" --nodes 16 --dz-cm 10
  python3 "$COMPILER" --root "$root" --stub "$stubrel" --target "$TARGET" \
    --external-source src/legacy/b1_10_port/headcalc.f90 --build "$out" --opt 2
  set +e
  OMP_NUM_THREADS=1 OMP_DYNAMIC=false "$out/rom0_test" > "$BUILD/${label}.txt" 2>&1
  local rc=$?
  set -e
  echo "$rc" > "$BUILD/${label}.rc"
}

build_one "$BASEWT" baseline
build_one "$ROOT" corrected

echo "=== BASELINE ==="; cat "$BUILD/baseline.txt"
echo "=== CORRECTED ==="; cat "$BUILD/corrected.txt"
BASE_RC="$(cat "$BUILD/baseline.rc")"; CORR_RC="$(cat "$BUILD/corrected.rc")"
[[ "$CORR_RC" == 0 ]] || fail "corrected frozen trajectory failed rc=$CORR_RC"
[[ "$BASE_RC" == 0 ]] || fail "baseline frozen trajectory failed rc=$BASE_RC"
grep -Fq "F_PE_BOFEK00_FROZEN_TRAJECTORY=PASS" "$BUILD/baseline.txt" || fail "baseline PASS marker absent"
grep -Fq "F_PE_BOFEK00_FROZEN_TRAJECTORY=PASS" "$BUILD/corrected.txt" || fail "corrected PASS marker absent"

python3 - "$BUILD/baseline.txt" "$BUILD/corrected.txt" <<'PY'
import json,re,sys
def parse(path):
    steps=[]; accepts=[]; end=None
    for line in open(path):
        line=line.strip()
        if line.startswith("F_PE_BOFEK00_STEP|"):
            d=dict(x.split("=",1) for x in line.split("|")[1:])
            steps.append({k:float(v) if k in {"MAXRES","MASS_NATIVE"} else int(v) for k,v in d.items()})
        elif line.startswith("F_PE_BOFEK00_ACCEPT|"):
            d=dict(x.split("=",1) for x in line.split("|")[1:])
            accepts.append(d)
        elif line.startswith("F_PE_BOFEK00_FROZEN_END|"):
            end=dict(x.split("=",1) for x in line.split("|")[1:])
    return steps,accepts,end
b,a,be=parse(sys.argv[1]); c,ca,ce=parse(sys.argv[2])
assert len(b)==len(c)==24 and len(a)==len(ca)==24
out={
 "baseline":{"nonlinear_iterations":sum(x["NL"] for x in b),"backtracks":sum(x["BACK"] for x in b),"cum_runoff":float(be["CUM_RUNOFF"]),"top_h":float(be["TOP_H"]),"pond":float(be["POND"])},
 "corrected":{"nonlinear_iterations":sum(x["NL"] for x in c),"backtracks":sum(x["BACK"] for x in c),"cum_runoff":float(ce["CUM_RUNOFF"]),"top_h":float(ce["TOP_H"]),"pond":float(ce["POND"])},
 "max_abs_ledger_baseline":max(abs(float(x["LEDGER"])) for x in a),
 "max_abs_ledger_corrected":max(abs(float(x["LEDGER"])) for x in ca),
 "final_head_delta":float(ce["TOP_H"])-float(be["TOP_H"]),
 "runoff_delta":float(ce["CUM_RUNOFF"])-float(be["CUM_RUNOFF"]),
}
print("F_PE_BOFEK00_FROZEN_COMPARISON="+json.dumps(out,sort_keys=True,separators=(",",":")))
PY
echo "F_PE_BOFEK00_FROZEN_COMPARISON_GATE=PASS"
