#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BASE="6318f04bd4d7dd8f9a587f03decaaea63d4f5f36"
FSI13_RECORD_HEAD="485d702c720cd9532addf9cba8cf2c5bd3b3ee43"
FSI16_RECORD_HEAD="6591b2f481e1760f844514e63ef873e8deda301f"
BUILD="${TMPDIR:-/tmp}/swap5-fsi27-preservation-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "FSI27_PRESERVATION_RUNNER_FAIL $*" >&2; exit 1; }

git cat-file -e "$BASE^{commit}" || fail 'frozen canonical base missing'
git merge-base --is-ancestor "$BASE" HEAD || fail 'candidate lineage does not descend from frozen canonical base'
changed_src="$(git diff --name-only "$BASE"...HEAD -- src | sort)"
[[ "$changed_src" == 'src/adapter/mod_reference_richards_legacy_binding.f90' ]] || fail "unexpected production delta: $changed_src"
[[ "$(git rev-parse HEAD:src/adapter/mod_reference_richards_legacy_binding.f90)" == '2cb1126397147b9e447634b131c93932c097177d' ]] || fail 'adapter blob drift'
[[ "$(git rev-parse HEAD:src/legacy/b1_10_port/headcalc.f90)" == '55893f1f5ccba2052ad681743aa155b69f351246' ]] || fail 'HeadCalc blob drift'

# Pin the corrected qualification records themselves, not moving branch names.
git cat-file -e "$FSI13_RECORD_HEAD^{commit}" || fail 'F-SI13 record head missing'
git cat-file -e "$FSI16_RECORD_HEAD^{commit}" || fail 'F-SI16 record head missing'
[[ "$(git rev-parse "$FSI13_RECORD_HEAD:integration/f-si/F-SI13_QUALIFICATION.json")" == 'f9a1dda7819f6b769e8b7cd9ac0319af436e0499' ]] || fail 'F-SI13 qualification record blob drift'
[[ "$(git rev-parse "$FSI16_RECORD_HEAD:integration/f-si/F-SI16_QUALIFICATION.json")" == '73d6b78ee244fd94f5891e26c44b5147020a9034' ]] || fail 'F-SI16 qualification record blob drift'
git show "$FSI13_RECORD_HEAD:integration/f-si/F-SI13_QUALIFICATION.json" | grep -Fq 'QUALIFIED_EXPLICIT_BOTTOM_MODE_FREE_DRAINAGE' || fail 'F-SI13 decision mismatch'
git show "$FSI16_RECORD_HEAD:integration/f-si/F-SI16_QUALIFICATION.json" | grep -Fq 'QUALIFIED_EXPLICIT_PRESCRIBED_BOTTOM_HEAD_BOUNDARY_SWBOTB5' || fail 'F-SI16 decision mismatch'
echo 'FSI27_PINNED_FSI13_FSI16_RECORDS=PASS'

FLAGS=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow -fopenmp)
SOURCES=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  tests/fsi/mod_fsi27_b110_oracle_fixture.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  tests/fsi/test_fsi27_fsi13_fsi16_preservation.F90
)

compile_run() {
  local opt="$1" out="$BUILD/o$1" src obj
  local objects=()
  mkdir -p "$out"
  for src in "${SOURCES[@]}"; do
    obj="$out/$(basename "${src%.*}").o"
    gfortran "${FLAGS[@]}" -O"$opt" -J "$out" -I "$out" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${FLAGS[@]}" -O"$opt" "${objects[@]}" -o "$out/test"
  timeout 60s env OMP_NUM_THREADS=1 OMP_DYNAMIC=false "$out/test" > "$out/output.txt"
  grep -Fq 'FSI27_FSI13_FREE_DRAINAGE_CURRENT_SOURCE=PASS' "$out/output.txt"
  grep -Fq 'FSI27_FSI16_PRESCRIBED_HEAD_CURRENT_SOURCE=PASS' "$out/output.txt"
  grep -Fq 'FSI27_FSI13_FSI16_PRESERVATION PASS' "$out/output.txt"
  cat "$out/output.txt"
  echo "FSI27_FSI13_FSI16_PRESERVATION_O${opt}=PASS"
}

compile_run 0
compile_run 2
cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || fail 'O0/O2 preservation output drift'
echo 'FSI27_FSI13_FSI16_PRESERVATION_O0_O2=PASS'
echo 'FSI27_PINNED_REGRESSION_GATE PASS'
