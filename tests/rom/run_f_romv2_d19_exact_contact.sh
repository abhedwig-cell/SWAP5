#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

BASE=ab8d52a3b3ab39470a989a46dc19e3bd24a01906
PREREG=integration/f-rom/F-ROMV2_D19_PREREGISTRATION.json
PREREG_BLOB=6dcce48d78ad4ff66c3d8453b08acdb7bc0f4640
AUTH=integration/f-rom/F-ROMV2_D19_STAGE2_AUTHORIZATION.json
AUTH_BLOB=6f01743e3a42b1149334ef0f05ff840988b5ddfe
PREFLIGHT=tests/rom/preflight_f_romv2_d19_exact_contact_merge.py
TEST=tests/rom/test_f_romv2_d19_exact_contact_comparators.f90
ANALYZER=tests/rom/analyze_f_romv2_d19_exact_contact.py
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
MATERIALIZER=tests/rom/materialize_f_rom0_headcalc_stubs.py
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-romv2-d19-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${F_ROMV2_D19_EVIDENCE_DIR:-$ROOT/F-ROMV2-D19-EVIDENCE}"
mkdir -p "$BUILD" "$EVIDENCE"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_ROMV2_D19_GATE_FAIL $*" >&2; exit 1; }

git fetch --no-tags origin integration/f-ci-canonical
LIVE="$(git rev-parse FETCH_HEAD)"
[[ "$LIVE" == "$BASE" ]] || fail "canonical advanced after D19 Stage-2 authorization: $LIVE"
git merge-base --is-ancestor "$BASE" HEAD || fail "D19 candidate not descendant of Stage-2 base"
git diff --quiet "$BASE"...HEAD -- src reference || fail "D19 mutated src/reference"
[[ "$(git rev-parse HEAD:$PREREG)" == "$PREREG_BLOB" ]] || fail "D19 preregistration blob drift"
[[ "$(git rev-parse HEAD:$AUTH)" == "$AUTH_BLOB" ]] || fail "D19 Stage-2 authorization blob drift"

python3 - "$PREREG" "$AUTH" <<'PY'
import json,sys
p=json.load(open(sys.argv[1])); a=json.load(open(sys.argv[2]))
assert p["phase"]=="PREREGISTERED_BEFORE_INTERNAL_PREFLIGHT_AND_SWAP_TRAJECTORY_EXECUTION"
assert p["exact_contact_initial_state"]["slug_length_cm"]==5
assert "NO_CONTACT_GAP" in p["firewalls"]
assert a["phase"]=="STAGE2_AUTHORIZED_AFTER_IMMUTABLE_FMC_PREFLIGHT"
assert a["stage2"]["SWAP_trajectory_generation_authorized"] is True
assert a["stage1_preflight"]["decision"]=="D19_FMC_EXACT_CONTACT_MERGE_PREFLIGHT_PASS"
assert a["canonical_reconciliation"]["scientific_design_changed"] is False
print("F_ROMV2_D19_STAGE2_LOCK=PASS")
PY

python3 "$PREFLIGHT" --prereg "$PREREG" --output "$EVIDENCE/F-ROMV2_D19_PREFLIGHT_RESULT.json" | tee "$EVIDENCE/preflight.txt"
grep -Fq '"decision": "D19_FMC_EXACT_CONTACT_MERGE_PREFLIGHT_PASS"' "$EVIDENCE/F-ROMV2_D19_PREFLIGHT_RESULT.json" || fail "D19 preflight no-go"

for spec in "R16 16 10" "R2 2 80"; do
  read -r id n dz <<<"$spec"
  stub="$BUILD/stubs_n${n}.f90"
  python3 "$MATERIALIZER" --source tests/fsi/fsi04_real_headcalc_stubs.f90 --output "$stub" --nodes "$n" --dz-cm "$dz"
  for opt in 0 2; do
    outdir="$BUILD/${id}_o${opt}"
    python3 "$COMPILER" --root "$ROOT" --stub "$stub" --target "$TEST" \
      --external-source src/legacy/b1_10_port/headcalc.f90 --build "$outdir" --opt "$opt"
    "$outdir/rom0_test" > "$EVIDENCE/${id}_o${opt}.txt" 2>&1 || {
      tail -n 500 "$EVIDENCE/${id}_o${opt}.txt" >&2
      fail "${id} O${opt} execution"
    }
    grep -Fq 'F_ROMV2_D19_REF_EXECUTION_COMPLETE=PASS' "$EVIDENCE/${id}_o${opt}.txt" || fail "${id} missing completion O${opt}"
    [[ "$(grep -c 'F_ROMV2_D19_REF_STATE|' "$EVIDENCE/${id}_o${opt}.txt")" -eq 256 ]] || fail "${id} expected 256 states O${opt}"
  done
  cmp "$EVIDENCE/${id}_o0.txt" "$EVIDENCE/${id}_o2.txt" || fail "${id} O0/O2 drift"
  echo "F_ROMV2_D19_${id}_O0_O2_IDENTITY=PASS"
done

python3 "$ANALYZER" --r16 "$EVIDENCE/R16_o2.txt" --r2 "$EVIDENCE/R2_o2.txt" \
  --preflight "$EVIDENCE/F-ROMV2_D19_PREFLIGHT_RESULT.json" --prereg "$PREREG" --authorization "$AUTH" \
  --output "$EVIDENCE/F-ROMV2_D19_RESULT.json" | tee "$EVIDENCE/analyzer.txt"

sha256sum "$EVIDENCE"/R*_o*.txt "$EVIDENCE/F-ROMV2_D19_PREFLIGHT_RESULT.json" \
  "$EVIDENCE/F-ROMV2_D19_RESULT.json" "$EVIDENCE/preflight.txt" "$EVIDENCE/analyzer.txt" > "$EVIDENCE/sha256.txt"
echo "F_ROMV2_D19_EXACT_CONTACT_COMPARATOR=PASS"
