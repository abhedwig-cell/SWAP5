#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

CANONICAL_START=9bb73821bb78a04c759b763746b50a3f777cd416
PREREG_COMMIT=dfba60141532063835a7985f6f8c1dc9517bc09f
PREREG=integration/f-rom/LARE_RS1_GW_PREREGISTRATION.json
TEST=tests/rom/test_lare_rs1_gw_library.f90
ANALYZER=tests/rom/analyze_lare_rs1_gw_library.py
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
MATERIALIZER=tests/rom/materialize_f_rom0_headcalc_stubs.py

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-lare-rs1-gw-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${LARE_RS1_GW_EVIDENCE_DIR:-$ROOT/LARE_RS1_GW_EVIDENCE}"
mkdir -p "$BUILD" "$EVIDENCE"
trap 'rm -rf "$BUILD"' EXIT

fail(){ echo "LARE_RS1_GW_GATE_FAIL $*" >&2; exit 1; }

git merge-base --is-ancestor "$CANONICAL_START" HEAD || fail "canonical start not ancestor"
git merge-base --is-ancestor "$PREREG_COMMIT" HEAD || fail "pre-execution preregistration amendment not ancestor"
git diff --quiet "$CANONICAL_START"...HEAD -- src reference || fail "RS1-GW changed src/reference"
echo 'LARE_RS1_GW_SOURCE_FREEZE=PASS'

python3 - "$PREREG" <<'PY'
import json,sys
p=json.load(open(sys.argv[1]))
assert p["phase"]=="PREREGISTERED_BEFORE_NEW_GW_LIBRARY_EXECUTION"
assert p["canonical_basis"]=="integration/f-ci-canonical@9bb73821bb78a04c759b763746b50a3f777cd416"
assert p["pre_execution_amendment"]["before_first_RS1_GW_execution"] is True
assert p["stage_A"]["maximum_steps_per_long_history"]==1024
assert len(p["stage_A"]["histories"])==6
assert all(h["steps"]==1024 for h in p["stage_A"]["histories"])
assert p["stage_A"]["histories"][0]["segments"]==[
    ["BOTTOM_HEAD_FALL",24],["BOTTOM_HEAD_RISE",40],["HOLD",960]
]
assert p["firewalls"][0]=="NO_LARE_DYNAMICS_IN_RS1_GW"
assert p["production_rom_authorized"] is False
print("LARE_RS1_GW_AUTHORITY_LOCK=PASS")
PY

python3 "$MATERIALIZER"   --source tests/fsi/fsi04_real_headcalc_stubs.f90   --output "$BUILD/stubs_n16.f90"   --nodes 16   --dz-cm 10

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  python3 "$COMPILER"     --root "$ROOT"     --stub "$BUILD/stubs_n16.f90"     --target "$TEST"     --external-source src/legacy/b1_10_port/headcalc.f90     --build "$OUT"     --opt "$opt"

  "$OUT/rom0_test" > "$EVIDENCE/o$opt.txt" 2>&1 || {
    tail -n 400 "$EVIDENCE/o$opt.txt" >&2
    fail "Reference library execution O$opt"
  }

  grep -Fq 'LAREGW1_EXECUTION_COMPLETE=PASS' "$EVIDENCE/o$opt.txt" ||
    fail "missing completion marker O$opt"
  [[ "$(grep -c 'LAREGW1_STATE|' "$EVIDENCE/o$opt.txt")" -eq 6144 ]] ||
    fail "expected 6144 accepted states O$opt"
  [[ "$(grep -c 'LAREGW1_NODE|' "$EVIDENCE/o$opt.txt")" -eq 98304 ]] ||
    fail "expected 98304 node records O$opt"
done

cmp "$EVIDENCE/o0.txt" "$EVIDENCE/o2.txt" ||
  fail "O0/O2 Reference-library stdout drift"
echo 'LARE_RS1_GW_O0_O2_IDENTITY=PASS'

python3 "$ANALYZER"   --input "$EVIDENCE/o2.txt"   --repeat "$EVIDENCE/o0.txt"   --prereg "$PREREG"   --output "$EVIDENCE/LARE_RS1_GW_STAGE_A_RESULT.json" |
  tee "$EVIDENCE/analyzer.txt"

cat "$EVIDENCE/LARE_RS1_GW_STAGE_A_RESULT.json"
sha256sum   "$EVIDENCE/o0.txt"   "$EVIDENCE/o2.txt"   "$EVIDENCE/LARE_RS1_GW_STAGE_A_RESULT.json"   "$EVIDENCE/analyzer.txt" > "$EVIDENCE/sha256.txt"

git diff --check "$CANONICAL_START"...HEAD
echo 'LARE_RS1_GW_REFERENCE_LIBRARY_GATE=PASS'
