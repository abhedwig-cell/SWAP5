#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

CANONICAL_START=9bb73821bb78a04c759b763746b50a3f777cd416
P2_PREREG=integration/f-rom/LARE_RS1_GW_P2_PREREGISTRATION.json
P1_RESULT=integration/f-rom/LARE_RS1_GW_P1_RESULT.json
SELECTOR=tests/rom/prepare_lare_rs1_gw_p2_selection.py
TEST=tests/rom/test_lare_rs1_gw_p2_future_probe.f90
ANALYZER=tests/rom/analyze_lare_rs1_gw_p2_future_response.py
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
MATERIALIZER=tests/rom/materialize_f_rom0_headcalc_stubs.py

REFERENCE_FILE="${LARE_RS1_GW_REFERENCE_FILE:-}"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-lare-rs1-gw-p2-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${LARE_RS1_GW_P2_EVIDENCE_DIR:-$ROOT/LARE_RS1_GW_P2_EVIDENCE}"
mkdir -p "$BUILD" "$EVIDENCE"
trap 'rm -rf "$BUILD"' EXIT

fail(){ echo "LARE_RS1_GW_P2_FAIL $*" >&2; exit 1; }

[[ -f "$P1_RESULT" ]] || fail "formal P1 result missing"
[[ -n "$REFERENCE_FILE" && -f "$REFERENCE_FILE" ]] || fail "qualified Stage-A reference missing"
echo "7d92c4524d16836a25200851ce560b041971d05f65256785e8cf1ef59ae0b345  $REFERENCE_FILE" | sha256sum -c -

git merge-base --is-ancestor "$CANONICAL_START" HEAD || fail "canonical start not ancestor"
git diff --quiet "$CANONICAL_START"...HEAD -- src reference || fail "P2 changed src/reference"
echo 'LARE_RS1_GW_P2_SOURCE_FREEZE=PASS'

python3 "$SELECTOR"   --p1 "$P1_RESULT"   --p2-prereg "$P2_PREREG"   --starts "$BUILD/starts.txt"   --selection "$EVIDENCE/LARE_RS1_GW_P2_SELECTION.json"

python3 - "$P1_RESULT" "$P2_PREREG" "$EVIDENCE/LARE_RS1_GW_P2_SELECTION.json" <<'PY'
import json,sys
p1=json.load(open(sys.argv[1]))
p2=json.load(open(sys.argv[2]))
sel=json.load(open(sys.argv[3]))
assert p1["decision"]=="LARE_RS1_GW_P1_RESPONSE_BLIND_PARTITIONS_FROZEN"
assert p1["future_probe_response_used"] is False
assert p2["phase"]=="PREREGISTERED_BEFORE_FORMAL_P1_PAIR_FUTURE_RESPONSE_EXECUTION"
assert p2["pre_execution_comparator_clarification"]["before_first_formal_P2_response_execution"] is True
assert sel["response_used_for_selection"] is False
assert sel["pair_reselection"] is False
roles=sel["selection_rule_result"]
assert roles["D_AGGRESSIVE"]=="D2"
assert roles["D_STATE_SEPARATING"]=="D3"
assert roles["D_ROBUST_PLATEAU"]=="D4"
print("LARE_RS1_GW_P2_AUTHORITY_LOCK=PASS")
PY

python3 "$MATERIALIZER"   --source tests/fsi/fsi04_real_headcalc_stubs.f90   --output "$BUILD/stubs_n16.f90"   --nodes 16   --dz-cm 10

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  python3 "$COMPILER"     --root "$ROOT"     --stub "$BUILD/stubs_n16.f90"     --target "$TEST"     --external-source src/legacy/b1_10_port/headcalc.f90     --build "$OUT"     --opt "$opt"

  LARE_RS1_GW_P2_STARTS_FILE="$BUILD/starts.txt"     "$OUT/rom0_test" > "$EVIDENCE/o$opt.txt" 2>&1 || {
      tail -n 600 "$EVIDENCE/o$opt.txt" >&2
      fail "P2 Reference future-probe execution O$opt"
    }
  grep -Fq 'LAREGW2_EXECUTION_COMPLETE=PASS' "$EVIDENCE/o$opt.txt" ||
    fail "missing P2 completion marker O$opt"
done

python3 - "$EVIDENCE/LARE_RS1_GW_P2_SELECTION.json" "$EVIDENCE/o2.txt" <<'PY'
import json,sys
sel=json.load(open(sys.argv[1]))
raw=open(sys.argv[2]).read()
n=int(sel["unique_start_state_count"])
checks={
 "start_nodes":(raw.count("LAREGW2_START_NODE|"), n*16),
 "endpoints":(raw.count("LAREGW2_PROBE|"), n*7*4),
 "steps":(raw.count("LAREGW2_STEP|"), n*7*1250),
}
for name,(got,expected) in checks.items():
    if got!=expected:
        raise SystemExit(f"{name}: got {got}, expected {expected}")
print("LARE_RS1_GW_P2_STRUCTURE=PASS",n)
PY

cmp "$EVIDENCE/o0.txt" "$EVIDENCE/o2.txt" ||
  fail "P2 O0/O2 stdout drift"
echo 'LARE_RS1_GW_P2_O0_O2_IDENTITY=PASS'

python3 "$ANALYZER"   --input "$EVIDENCE/o2.txt"   --repeat "$EVIDENCE/o0.txt"   --reference "$REFERENCE_FILE"   --selection "$EVIDENCE/LARE_RS1_GW_P2_SELECTION.json"   --p2-prereg "$P2_PREREG"   --output "$EVIDENCE/LARE_RS1_GW_P2_RESULT.json" |
  tee "$EVIDENCE/analyzer.txt"

cat "$EVIDENCE/LARE_RS1_GW_P2_RESULT.json"
sha256sum   "$EVIDENCE/o0.txt"   "$EVIDENCE/o2.txt"   "$EVIDENCE/LARE_RS1_GW_P2_SELECTION.json"   "$EVIDENCE/LARE_RS1_GW_P2_RESULT.json"   "$EVIDENCE/analyzer.txt" > "$EVIDENCE/sha256.txt"

git diff --check "$CANONICAL_START"...HEAD
echo 'LARE_RS1_GW_P2_GATE=PASS'
