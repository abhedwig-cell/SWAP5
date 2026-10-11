#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

BASE=be2bffe2b3d1684e68f64862d530810ba2c6eb2e
PREREG=34de89ca70a7f4e6327b65812ccc9e17b230a536
PREREG_FILE=integration/f-rom/F-ROM1A_I0_PREREGISTRATION.json
TEST=tests/rom/test_f_rom1a_i0_reference_observation_seam.f90
ANALYZER=tests/rom/analyze_f_rom1a_i0_reference_observation_seam.py
COMPILER=tests/rom/compile_f_rom0_fortran_closure.py
MATERIALIZER=tests/rom/materialize_f_rom0_headcalc_stubs.py
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-rom1a-i0-${GITHUB_RUN_ID:-local}-$$"
EVIDENCE="${F_ROM1A_I0_EVIDENCE_DIR:-$ROOT/F-ROM1A-I0-EVIDENCE}"
mkdir -p "$BUILD" "$EVIDENCE"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_ROM1A_I0_GATE_FAIL $*" >&2; exit 1; }

git merge-base --is-ancestor "$PREREG" HEAD || fail "preregistration is not ancestor"
mapfile -t SRC_DELTA < <(git diff --name-only "$PREREG"...HEAD -- src | sort)
EXPECTED=$'src/kernel/mod_kernel_transactions.f90\nsrc/runtime/mod_fmr_serialized_reference_backend.f90'
[[ "$(printf '%s\n' "${SRC_DELTA[@]}")" == "$EXPECTED" ]] || {
  printf 'F_ROM1A_I0_SOURCE_DELTA=%s\n' "${SRC_DELTA[*]:-NONE}" >&2
  fail "source allowlist"
}
git diff --quiet "$PREREG"...HEAD -- reference || fail "reference tree changed"
git diff --quiet "$BASE"...HEAD --   src/solver src/transaction src/adapter src/runtime/mod_canonical_interval_runtime.f90   src/runtime/mod_canonical_contracts.f90 || fail "ordinary solver/transaction/runtime core changed"
echo "F_ROM1A_I0_SOURCE_SCOPE=PASS"
echo "F_ROM1A_I0_REFERENCE_TREE_IMMUTABLE=PASS"

python3 - "$PREREG_FILE" <<'PY'
import json,sys
p=json.load(open(sys.argv[1]))
assert p["phase"]=="PREREGISTERED_BEFORE_SOURCE_MUTATION"
assert p["canonical_base"]=="be2bffe2b3d1684e68f64862d530810ba2c6eb2e"
assert p["allowed_source_files"]==[
  "src/kernel/mod_kernel_transactions.f90",
  "src/runtime/mod_fmr_serialized_reference_backend.f90",
]
assert p["qualification_matrix"]["materials"]==["B01","B14"]
assert p["qualification_matrix"]["bottom_modes"]==[2,5]
assert p["qualification_matrix"]["sample_dt_day"]==0.0008
assert p["qualification_matrix"]["hard_mass_gate_cm"]==1e-12
assert p["production_application_admission"] is False
print("F_ROM1A_I0_PREREGISTRATION_LOCK=PASS")
PY

grep -Fq 'procedure, public :: sample_reference_floor_interval' src/kernel/mod_kernel_transactions.f90 || fail "kernel sample method absent"
grep -Fq 'procedure, public :: commit_reference_floor_candidate' src/kernel/mod_kernel_transactions.f90 || fail "kernel commit method absent"
grep -Fq 'procedure, public :: run_reference_floor_sample' src/runtime/mod_fmr_serialized_reference_backend.f90 || fail "FMR sample method absent"
grep -Fq '(parameters%bottom_mode /= 2 .and. parameters%bottom_mode /= 5)' src/runtime/mod_fmr_serialized_reference_backend.f90 || fail "mode 2/5 admission absent"

python3 "$MATERIALIZER" --source tests/fsi/fsi04_real_headcalc_stubs.f90   --output "$BUILD/stubs_n16.f90" --nodes 16 --dz-cm 10

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  python3 "$COMPILER" --root "$ROOT" --stub "$BUILD/stubs_n16.f90"     --target "$TEST" --external-source src/legacy/b1_10_port/headcalc.f90     --build "$OUT" --opt "$opt"
  "$OUT/rom0_test" >"$EVIDENCE/o$opt.txt" 2>&1 || {
    cat "$EVIDENCE/o$opt.txt" >&2
    fail "I0 executable O$opt"
  }
  cat "$EVIDENCE/o$opt.txt"
  grep -Fq 'F_ROM1A_I0_ROW|MATERIAL=B01|MODE=MODE2|STATUS=PASS' "$EVIDENCE/o$opt.txt" || fail "B01 mode2 O$opt"
  grep -Fq 'F_ROM1A_I0_ROW|MATERIAL=B01|MODE=MODE5|STATUS=PASS' "$EVIDENCE/o$opt.txt" || fail "B01 mode5 O$opt"
  grep -Fq 'F_ROM1A_I0_ROW|MATERIAL=B14|MODE=MODE2|STATUS=PASS' "$EVIDENCE/o$opt.txt" || fail "B14 mode2 O$opt"
  grep -Fq 'F_ROM1A_I0_ROW|MATERIAL=B14|MODE=MODE5|STATUS=PASS' "$EVIDENCE/o$opt.txt" || fail "B14 mode5 O$opt"
  grep -Fq 'F_ROM1A_I0_FAILCLOSED|STATUS=PASS' "$EVIDENCE/o$opt.txt" || fail "fail-closed control O$opt"
  grep -Fq 'F_ROM1A_I0_REFERENCE_OBSERVATION_SEAM_GATE=PASS' "$EVIDENCE/o$opt.txt" || fail "capability marker O$opt"
done

cmp "$EVIDENCE/o0.txt" "$EVIDENCE/o2.txt" || fail "O0/O2 output drift"
python3 "$ANALYZER" --o0 "$EVIDENCE/o0.txt" --o2 "$EVIDENCE/o2.txt"   --output "$EVIDENCE/F-ROM1A_I0_RESULT.json" | tee "$EVIDENCE/analyzer.txt"
cat "$EVIDENCE/F-ROM1A_I0_RESULT.json"

git diff --check "$PREREG"...HEAD
sha256sum "$EVIDENCE/o0.txt" "$EVIDENCE/o2.txt" "$EVIDENCE/F-ROM1A_I0_RESULT.json"   "$EVIDENCE/analyzer.txt" > "$EVIDENCE/sha256.txt"
echo "F_ROM1A_I0_CAPABILITY_GATE=PASS"
