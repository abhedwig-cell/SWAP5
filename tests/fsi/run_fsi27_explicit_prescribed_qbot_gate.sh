#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BASE="6318f04bd4d7dd8f9a587f03decaaea63d4f5f36"
BUILD="${TMPDIR:-/tmp}/swap5-fsi27-prescribed-qbot-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "FSI27_RUNNER_FAIL $*" >&2; exit 1; }

git cat-file -e "$BASE^{commit}" || fail "canonical base missing"
git merge-base --is-ancestor "$BASE" HEAD || fail "branch does not descend from pinned canonical base"

changed_src="$(git diff --name-only "$BASE"...HEAD -- src | sort)"
expected_src='src/adapter/mod_reference_richards_legacy_binding.f90'
[[ "$changed_src" == "$expected_src" ]] || {
  echo 'FSI27_RUNNER_FAIL unexpected production delta:' >&2
  printf '%s\n' "$changed_src" >&2
  exit 1
}

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git rev-parse "HEAD:$path")" || fail "missing $path"
  [[ "$actual" == "$expected" ]] || fail "blob drift $path expected=$expected actual=$actual"
}

check_blob src/solver/mod_soil_water_solver_contract.f90 dc7b14a06f64c8ab0af9747f707b3394a5f5cbe0
check_blob src/solver/mod_reference_richards_state_binding.f90 e68d88382c6502c571713cc97fddd4e18434e271
check_blob src/solver/mod_reference_richards_workspace.f90 59ef9d037c1875610d45ac83387ebab9e917e0fe
check_blob src/solver/mod_reference_linear_solver.f90 b292d284e5549049eac1c80df4cc30008154eb96
check_blob src/solver/mod_b110_default_mvg_provider.f90 97d67eb373073b183be6d1bf5b756ecb5125dde2
check_blob src/solver/mod_b110_source_sink_provider.f90 d6c57add72387e5c0022a44319fff08046194aac
check_blob src/solver/mod_fixed_flux_top_boundary_provider.f90 fb226f133bd48d8ab945f111c76897aeff49facf
check_blob src/legacy/b1_10_port/headcalc.f90 55893f1f5ccba2052ad681743aa155b69f351246
check_blob src/adapter/mod_reference_richards_legacy_binding.f90 ea94a4ffb6a79caf1fa8fd8531a6af2ea6bf680c

grep -Fq 'request%boundary%bottom_mode /= 5 .and. request%boundary%bottom_mode /= 2' \
  src/adapter/mod_reference_richards_legacy_binding.f90 || fail 'mode 2 admission guard missing'
grep -Fq 'request%boundary%bottom_flux = qbot' src/adapter/mod_reference_richards_legacy_binding.f90 || \
  fail 'legacy request qbot mapping missing'
grep -Fq 'result%bottom_flux = state_binding%qbot' src/adapter/mod_reference_richards_legacy_binding.f90 || \
  fail 'result qbot publication missing'
grep -Fq 'F(NN) = F(NN) - state%qbot' src/legacy/b1_10_port/headcalc.f90 || \
  fail 'native prescribed qbot residual missing'

echo 'FSI27_STATIC_SOURCE_LOCK=PASS'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow -fopenmp)
MODULE_SRC=(
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
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  tests/fsi/test_fsi27_explicit_prescribed_qbot.f90
)

compile_and_run() {
  local opt="$1" out="$BUILD/o$1"
  mkdir -p "$out"
  local objects=()
  local src obj
  for src in "${MODULE_SRC[@]}"; do
    [[ -f "$src" ]] || fail "compile dependency missing: $src"
    obj="$out/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" "${objects[@]}" -o "$out/test_fsi27"
  timeout 30s env OMP_NUM_THREADS=1 OMP_DYNAMIC=false "$out/test_fsi27" > "$out/output.txt"
  grep -Fq 'FSI27_EXPLICIT_PRESCRIBED_QBOT_GATE PASS' "$out/output.txt" || {
    cat "$out/output.txt" >&2
    fail "O${opt} gate marker missing"
  }
  grep -Fq 'FSI27_ROW:' "$out/output.txt" || fail "O${opt} diagnostic row missing"
  grep -Fq 'FSI27_SOLVER_MASS_RESIDUAL_FINITE=' "$out/output.txt" || fail "O${opt} solver mass observation missing"
  cat "$out/output.txt"
  echo "FSI27_O${opt}=PASS"
}

compile_and_run 0
compile_and_run 2
cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || fail 'O0/O2 observable output differs'
echo 'FSI27_O0_O2_IDENTITY=PASS'
echo 'FSI27_EXPLICIT_PRESCRIBED_QBOT_RUNNER PASS'
