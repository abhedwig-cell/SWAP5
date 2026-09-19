#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

CANONICAL_START=9bb73821bb78a04c759b763746b50a3f777cd416
PAIR_PREREG_COMMIT=9bbd3662904ca20bffe427753dac882487e02069
PAIR_PREREG=integration/f-rom/LARE_RS1_GW_PAIR_PREREGISTRATION.json
TEST=tests/rom/test_lare_rs1_gw_future_probe.f90
ANALYZER=tests/rom/analyze_lare_rs1_gw_future_probe.py
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
MATERIALIZER=tests/rom/materialize_f_rom0_headcalc_stubs.py

REFERENCE_FILE="${LARE_RS1_GW_REFERENCE_FILE:-}"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-lare-rs1-gw-probe-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${LARE_RS1_GW_PROBE_EVIDENCE_DIR:-$ROOT/LARE_RS1_GW_PROBE_EVIDENCE}"
mkdir -p "$BUILD" "$EVIDENCE"
trap 'rm -rf "$BUILD"' EXIT

fail(){ echo "LARE_RS1_GW_PROBE_FAIL $*" >&2; exit 1; }

[[ -n "$REFERENCE_FILE" && -f "$REFERENCE_FILE" ]] || fail "qualified Stage-A reference file missing"
echo "7d92c4524d16836a25200851ce560b041971d05f65256785e8cf1ef59ae0b345  $REFERENCE_FILE" | sha256sum -c -

git merge-base --is-ancestor "$CANONICAL_START" HEAD || fail "canonical start not ancestor"
git merge-base --is-ancestor "$PAIR_PREREG_COMMIT" HEAD || fail "pair preregistration not ancestor"
git diff --quiet "$CANONICAL_START"...HEAD -- src reference || fail "future-probe work changed src/reference"
echo 'LARE_RS1_GW_PROBE_SOURCE_FREEZE=PASS'

python3 - "$PAIR_PREREG" "$BUILD/starts.txt" <<'PY'
import json,sys
p=json.load(open(sys.argv[1]))
assert p["phase"]=="FROZEN_BEFORE_FUTURE_PROBE_EXECUTION"
assert p["collision_search"]["future_outputs_used_for_selection"] is False
assert len(p["frozen_collision_pairs"])==4
assert p["future_probes"]["horizon_steps"]==[4,64,256,1024]
assert len(p["future_probes"]["probe_definitions"])==7
assert p["future_probes"]["identical_future_forcing_for_pair_members"] is True
assert p["acceptance_status"]["hydrological_thresholds"]=="NOT_FROZEN_IN_THIS_PAIR_SELECTION_UNIT"
starts=set()
for pair in p["frozen_collision_pairs"]:
    for side in ("a","b"):
        starts.add((int(pair[side]["history_index"]),int(pair[side]["step"])))
with open(sys.argv[2],"w") as f:
    for ih,step in sorted(starts):
        f.write(f"{ih} {step}\n")
assert len(starts)==8
print("LARE_RS1_GW_PAIR_AUTHORITY_LOCK=PASS")
PY

python3 "$MATERIALIZER"   --source tests/fsi/fsi04_real_headcalc_stubs.f90   --output "$BUILD/stubs_n16.f90"   --nodes 16   --dz-cm 10

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  python3 "$COMPILER"     --root "$ROOT"     --stub "$BUILD/stubs_n16.f90"     --target "$TEST"     --external-source src/legacy/b1_10_port/headcalc.f90     --build "$OUT"     --opt "$opt"

  LARE_RS1_GW_STARTS_FILE="$BUILD/starts.txt"     "$OUT/rom0_test" > "$EVIDENCE/o$opt.txt" 2>&1 || {
      tail -n 500 "$EVIDENCE/o$opt.txt" >&2
      fail "future-probe execution O$opt"
    }

  grep -Fq 'LAREGW1P_EXECUTION_COMPLETE=PASS' "$EVIDENCE/o$opt.txt" ||
    fail "missing completion marker O$opt"
  [[ "$(grep -c 'LAREGW1P_START_NODE|' "$EVIDENCE/o$opt.txt")" -eq 128 ]] ||
    fail "expected 128 start-node rows O$opt"
  [[ "$(grep -c 'LAREGW1P_PROBE|' "$EVIDENCE/o$opt.txt")" -eq 224 ]] ||
    fail "expected 224 endpoint rows O$opt"
  [[ "$(grep -c 'LAREGW1P_STEP|' "$EVIDENCE/o$opt.txt")" -eq 57344 ]] ||
    fail "expected 57344 step rows O$opt"
done

cmp "$EVIDENCE/o0.txt" "$EVIDENCE/o2.txt" ||
  fail "O0/O2 future-probe stdout drift"
echo 'LARE_RS1_GW_PROBE_O0_O2_IDENTITY=PASS'

python3 "$ANALYZER"   --input "$EVIDENCE/o2.txt"   --repeat "$EVIDENCE/o0.txt"   --reference "$REFERENCE_FILE"   --prereg "$PAIR_PREREG"   --output "$EVIDENCE/LARE_RS1_GW_FUTURE_PROBE_RESULT.json" |
  tee "$EVIDENCE/analyzer.txt"

cat "$EVIDENCE/LARE_RS1_GW_FUTURE_PROBE_RESULT.json"
sha256sum   "$EVIDENCE/o0.txt"   "$EVIDENCE/o2.txt"   "$EVIDENCE/LARE_RS1_GW_FUTURE_PROBE_RESULT.json"   "$EVIDENCE/analyzer.txt" > "$EVIDENCE/sha256.txt"

git diff --check "$CANONICAL_START"...HEAD
echo 'LARE_RS1_GW_FUTURE_PROBE_GATE=PASS'
