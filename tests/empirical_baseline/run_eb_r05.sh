#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap431-eb-r05-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

FVQ28_REF=origin/qualification/f-vq28-richards-temporal-numeric-profile
FVQ28_FIXTURE=tests/fvq/test_fvq28_heldout_temporal_profile.f90
FVQ28_FIXTURE_BLOB=82e75725e8d8c159b20260cd6d68d25ee4a98823
FSI18_REF=origin/work/f-si18-reference-convergence-cliff
FSI18_GENERATOR=tests/fsi/fsi18_make_reference_tridag_stubs.py
FSI18_GENERATOR_BLOB=bf25c4c7fefaa59811255b0bc25c041522ab008e
CURRENT_BINDING=src/adapter/mod_reference_richards_legacy_binding.f90
CURRENT_BINDING_BLOB=03a64b6d09fd804242bcf76f7cb5277f59a6230a
CURRENT_HEADCALC=src/legacy/b1_10_port/headcalc.f90
CURRENT_HEADCALC_BLOB=3ff8d5cfd6963dfb7dafb33ec454fbc0df938a55

git cat-file -e "$FVQ28_REF^{commit}"
git cat-file -e "$FSI18_REF^{commit}"
test "$(git rev-parse "$FVQ28_REF:$FVQ28_FIXTURE")" = "$FVQ28_FIXTURE_BLOB"
test "$(git rev-parse "$FSI18_REF:$FSI18_GENERATOR")" = "$FSI18_GENERATOR_BLOB"
test "$(git hash-object "$CURRENT_BINDING")" = "$CURRENT_BINDING_BLOB"
test "$(git hash-object "$CURRENT_HEADCALC")" = "$CURRENT_HEADCALC_BLOB"
grep -Fq -- '-40.0_real64, -55.0_real64, -110.0_real64, -160.0_real64, -210.0_real64, -320.0_real64' <(git show "$FVQ28_REF:$FVQ28_FIXTURE")
grep -Fq 'head_jumps(nj) = [ -0.05_real64, -0.01_real64, 0.01_real64, 0.05_real64 ]' <(git show "$FVQ28_REF:$FVQ28_FIXTURE")
grep -Fq 'real(real64), parameter :: total_dt = 0.25_real64' <(git show "$FVQ28_REF:$FVQ28_FIXTURE")
echo 'EB_R05_FVQ28_HELDOUT_ORACLE_PINNED=PASS'
echo 'EB_R05_CURRENT_RICHARDS_BINDING_PINNED=PASS'
echo 'EB_R05_CURRENT_HEADCALC_PINNED=PASS'

git show "$FSI18_REF:$FSI18_GENERATOR" > "$BUILD/make_reference_tridag.py"
python3 "$BUILD/make_reference_tridag.py" tests/fsi/fsi04_real_headcalc_stubs.f90 "$BUILD/fsi04_reference_tridag_stubs.f90"
if grep -Fq 'solution(i) = 0.0d0' "$BUILD/fsi04_reference_tridag_stubs.f90"; then
  echo 'EB_R05_FAIL zero-correction TRIDAG survived reference replacement' >&2
  exit 1
fi
grep -Fq 'SWAP 4.3.1 tridag.f90' "$BUILD/fsi04_reference_tridag_stubs.f90"
echo 'EB_R05_REFERENCE_TRIDAG_CONTROL=PASS'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
  "$BUILD/fsi04_reference_tridag_stubs.f90"
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_process_hydraulic_view.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  tests/fmr/mod_fmr04_fixed_top_provider.f90
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  objects=()
  for source in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -Wno-error=compare-reals -Wno-error=unused-dummy-argument \
      -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -Wno-error=compare-reals -Wno-error=unused-dummy-argument \
    -O"$opt" -J "$OUT" -I "$OUT" -c tests/empirical_baseline/observe_transient_richards_response.f90 -o "$OUT/observer.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/observer.o" -o "$OUT/observer"
  timeout 120s "$OUT/observer" > "$OUT/output.txt" 2>&1 || { cat "$OUT/output.txt" >&2; exit 1; }
  grep -Fq 'EB_R05_TRANSIENT_STORAGE_RESPONSE_NONZERO=PASS' "$OUT/output.txt"
  grep -Fq 'EB_R05_TRAJECTORY_MASS_CLOSURE=PASS' "$OUT/output.txt"
  grep -Fq 'EB_R05_SAME_INPUT_REPLAY_IDENTITY=PASS' "$OUT/output.txt"
  grep -Fq 'EB_R05_CURRENT_CANONICAL_TRANSIENT_RICHARDS_OBSERVATION PASS' "$OUT/output.txt"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'EB_R05_O0_O2_OBSERVATION_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"
echo "EB_R05_OBSERVATION_SHA256=$(sha256sum "$BUILD/o0/output.txt" | cut -d' ' -f1)"
