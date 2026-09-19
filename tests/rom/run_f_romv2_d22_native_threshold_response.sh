#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

BASE=435fee071f4045cea217b1cc0cef07c4d8c20427
PREREG=integration/f-rom/F-ROMV2_D22_PREREGISTRATION.json
PREREG_BLOB=bfac813721baf5638afc367936b99ab6dbad1275
TARGET=tests/rom/test_f_romv2_d22_swap_threshold_response.f90
ANALYZER=tests/rom/analyze_f_romv2_d22_native_threshold_response.py
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
MATERIALIZER=tests/rom/materialize_f_rom0_headcalc_stubs.py
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-romv2-d22-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${F_ROMV2_D22_EVIDENCE_DIR:-$ROOT/F-ROMV2-D22-EVIDENCE}"
mkdir -p "$BUILD" "$EVIDENCE"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_ROMV2_D22_GATE_FAIL $*" >&2; exit 1; }

git fetch --no-tags origin integration/f-ci-canonical
LIVE="$(git rev-parse FETCH_HEAD)"
[[ "$LIVE" == "$BASE" ]] || fail "canonical advanced after D22 preregistration: $LIVE"
git merge-base --is-ancestor "$BASE" HEAD || fail "D22 candidate not descendant of base"
git diff --quiet "$BASE"...HEAD -- src reference || fail "D22 mutated src/reference"
[[ "$(git rev-parse HEAD:$PREREG)" == "$PREREG_BLOB" ]] || fail "D22 preregistration blob drift"

python3 - "$PREREG" <<'PY'
import json,sys
p=json.load(open(sys.argv[1]))
assert p["phase"]=="PREREGISTERED_BEFORE_EXECUTION"
assert p["common_context"]["rainfall_factor_ladder_Ksat"]==[0.25,0.5,1,2,4,8,16]
assert p["scientific_role"]["Richards_trajectory_test"] is False
assert p["decision_logic"]["no_weighted_score"] is True
assert "NO_MATCHED_LABEL_SEARCH" in p["firewalls"]
assert "NO_RICHARDS_TRAJECTORY_GENERATION" in p["firewalls"]
print("F_ROMV2_D22_PREREGISTRATION_LOCK=PASS")
PY

stub="$BUILD/stubs_n16.f90"
python3 "$MATERIALIZER" --source tests/fsi/fsi04_real_headcalc_stubs.f90 --output "$stub" --nodes 16 --dz-cm 10
for opt in 0 2; do
  out="$BUILD/o$opt"
  python3 "$COMPILER" --root "$ROOT" --stub "$stub" --target "$TARGET" --build "$out" --opt "$opt"
  "$out/rom0_test" > "$EVIDENCE/swap_o$opt.txt" 2>&1 || {
    cat "$EVIDENCE/swap_o$opt.txt" >&2
    fail "SWAP native threshold response O$opt"
  }
  grep -Fq 'F_ROMV2_D22_SWAP_RESPONSE=PASS' "$EVIDENCE/swap_o$opt.txt" || fail "missing SWAP response pass O$opt"
done
cmp "$EVIDENCE/swap_o0.txt" "$EVIDENCE/swap_o2.txt" || fail "SWAP response O0/O2 drift"

python3 "$ANALYZER" --prereg "$PREREG" --swap "$EVIDENCE/swap_o2.txt" \
  --output "$EVIDENCE/F-ROMV2_D22_RESULT.json" | tee "$EVIDENCE/analyzer.txt"

sha256sum "$EVIDENCE/swap_o0.txt" "$EVIDENCE/swap_o2.txt" \
  "$EVIDENCE/F-ROMV2_D22_RESULT.json" "$EVIDENCE/analyzer.txt" > "$EVIDENCE/sha256.txt"
echo "F_ROMV2_D22_NATIVE_THRESHOLD_RESPONSE=PASS"
