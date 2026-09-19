#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

BASE=9bb73821bb78a04c759b763746b50a3f777cd416
PREREG=integration/f-rom/F-ROMV2_D2_PREREGISTRATION.json
PREREG_BLOB=e06f3a8d691c930befad8cc7a6d348a659f30ea2
TEST=tests/rom/test_f_romv2_d2_coarse_richards_trajectories.f90
ANALYZER=tests/rom/analyze_f_romv2_d2_coarse_richards.py
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
MATERIALIZER=tests/rom/materialize_f_rom0_headcalc_stubs.py
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-romv2-d2-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${F_ROMV2_D2_EVIDENCE_DIR:-$ROOT/F-ROMV2-D2-EVIDENCE}"
mkdir -p "$BUILD" "$EVIDENCE"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_ROMV2_D2_GATE_FAIL $*" >&2; exit 1; }

git fetch --no-tags origin integration/f-ci-canonical
LIVE="$(git rev-parse FETCH_HEAD)"
[[ "$LIVE" == "$BASE" ]] || fail "canonical advanced after D2 preregistration: $LIVE"
git merge-base --is-ancestor "$BASE" HEAD || fail "D2 candidate is not descendant of preregistered canonical"
git diff --quiet "$BASE"...HEAD -- src reference || fail "D2 mutated src/reference"
[[ "$(git rev-parse HEAD:$PREREG)" == "$PREREG_BLOB" ]] || fail "D2 preregistration blob drift"

python3 - "$PREREG" <<'PY'
import json,sys
p=json.load(open(sys.argv[1]))
assert p["phase"]=="PREREGISTERED_BEFORE_EXECUTION"
assert [(g["id"],g["nodes"],g["dz_cm"]) for g in p["geometries"]]==[
 ("R16",16,10),("R8",8,20),("R4",4,40),("R2",2,80)]
assert p["scientific_role"]["blind_confirmation"] is False
assert p["decisions"]["no_application_thresholds"] is True
assert "NO_C2_OOD_RETUNING" in p["firewalls"]
print("F_ROMV2_D2_PREREGISTRATION_LOCK=PASS")
PY

for spec in "R16 16 10" "R8 8 20" "R4 4 40" "R2 2 80"; do
  read -r id n dz <<<"$spec"
  stub="$BUILD/stubs_n${n}.f90"
  python3 "$MATERIALIZER" --source tests/fsi/fsi04_real_headcalc_stubs.f90 \
    --output "$stub" --nodes "$n" --dz-cm "$dz"
  for opt in 0 2; do
    outdir="$BUILD/${id}_o${opt}"
    python3 "$COMPILER" --root "$ROOT" --stub "$stub" --target "$TEST" \
      --external-source src/legacy/b1_10_port/headcalc.f90 --build "$outdir" --opt "$opt"
    "$outdir/rom0_test" > "$EVIDENCE/${id}_o${opt}.txt" 2>&1 || {
      tail -n 500 "$EVIDENCE/${id}_o${opt}.txt" >&2
      fail "${id} O${opt} execution"
    }
    grep -Fq 'F_ROMV2_D2_EXECUTION_COMPLETE=PASS' "$EVIDENCE/${id}_o${opt}.txt" || fail "${id} missing completion O${opt}"
    [[ "$(grep -c 'F_ROMV2_D2_STATE|' "$EVIDENCE/${id}_o${opt}.txt")" -eq 768 ]] || fail "${id} expected 768 states O${opt}"
  done
  cmp "$EVIDENCE/${id}_o0.txt" "$EVIDENCE/${id}_o2.txt" || fail "${id} O0/O2 drift"
  echo "F_ROMV2_D2_${id}_O0_O2_IDENTITY=PASS"
done

python3 "$ANALYZER" \
  --r16 "$EVIDENCE/R16_o2.txt" --r8 "$EVIDENCE/R8_o2.txt" \
  --r4 "$EVIDENCE/R4_o2.txt" --r2 "$EVIDENCE/R2_o2.txt" \
  --prereg "$PREREG" --output "$EVIDENCE/F-ROMV2_D2_RESULT.json" \
  | tee "$EVIDENCE/analyzer.txt"

sha256sum "$EVIDENCE"/R*_o*.txt "$EVIDENCE/F-ROMV2_D2_RESULT.json" "$EVIDENCE/analyzer.txt" > "$EVIDENCE/sha256.txt"
echo "F_ROMV2_D2_ARCHITECTURE_SCREEN=PASS"
