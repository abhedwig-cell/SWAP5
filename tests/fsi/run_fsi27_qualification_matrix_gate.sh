#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BASE="6318f04bd4d7dd8f9a587f03decaaea63d4f5f36"
BUILD="${TMPDIR:-/tmp}/swap5-fsi27-matrix-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "FSI27_MATRIX_RUNNER_FAIL $*" >&2; exit 1; }

git cat-file -e "$BASE^{commit}" || fail 'canonical base missing'
git merge-base --is-ancestor "$BASE" HEAD || fail 'candidate does not descend from frozen canonical base'
changed_src="$(git diff --name-only "$BASE"...HEAD -- src | sort)"
[[ "$changed_src" == 'src/adapter/mod_reference_richards_legacy_binding.f90' ]] || fail "unexpected production delta: $changed_src"
[[ "$(git rev-parse HEAD:src/adapter/mod_reference_richards_legacy_binding.f90)" == '2cb1126397147b9e447634b131c93932c097177d' ]] || \
  fail 'adapter blob drift'
[[ "$(git rev-parse HEAD:src/legacy/b1_10_port/headcalc.f90)" == '55893f1f5ccba2052ad681743aa155b69f351246' ]] || \
  fail 'HeadCalc blob drift'

echo 'FSI27_MATRIX_SOURCE_LOCK=PASS'

FLAGS=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow -fopenmp)
SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  tests/fsi/test_fsi27_qualification_matrix.f90
)

compile_run() {
  local opt="$1" out="$BUILD/o$1"
  mkdir -p "$out"
  local objects=() src obj
  for src in "${SRC[@]}"; do
    obj="$out/$(basename "${src%.*}").o"
    gfortran "${FLAGS[@]}" -O"$opt" -J "$out" -I "$out" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${FLAGS[@]}" -O"$opt" "${objects[@]}" -o "$out/test"
  timeout 60s env OMP_NUM_THREADS=1 OMP_DYNAMIC=false "$out/test" > "$out/output.txt"
  grep -Fq 'FSI27_MATRIX_QBOT_SIGN_COVERAGE=PASS' "$out/output.txt"
  grep -Fq 'FSI27_MATRIX_ABA_REPLAY=PASS' "$out/output.txt"
  for n in 1 2 4 8; do grep -Fq "FSI27_MATRIX_SERIALIZED_WORKERS_${n}=PASS" "$out/output.txt"; done
  grep -Fq 'FSI27_MATRIX_REQUEST_IMMUTABILITY=PASS' "$out/output.txt"
  grep -Fq 'FSI27_MATRIX_GLOBAL_POISON=PASS' "$out/output.txt"
  grep -Fq 'FSI27_MATRIX_SCRATCH_POISON=PASS' "$out/output.txt"
  grep -Fq 'FSI27_MATRIX_UNSUPPORTED_BOTTOM_MODES=PASS' "$out/output.txt"
  grep -Fq 'FSI27_QUALIFICATION_MATRIX PASS' "$out/output.txt"
  cat "$out/output.txt"
  echo "FSI27_MATRIX_O${opt}=PASS"
}

compile_run 0
compile_run 2
cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || fail 'O0/O2 matrix output differs'
echo 'FSI27_MATRIX_O0_O2_IDENTITY=PASS'
echo 'FSI27_QUALIFICATION_MATRIX_RUNNER PASS'
