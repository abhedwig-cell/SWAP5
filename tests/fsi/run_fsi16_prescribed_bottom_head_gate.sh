#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FSI15_HEAD="fe5e55d5d5ebff42e8212cba8df15652e5f1a52b"
BUILD="${TMPDIR:-/tmp}/swap5-fsi16-prescribed-head-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

[[ "$(git merge-base "$FSI15_HEAD" HEAD)" == "$FSI15_HEAD" ]] || {
  echo 'F-SI16_PRESCRIBED_HEAD FAIL lineage' >&2; exit 1; }

changed_src="$(git diff --name-only "$FSI15_HEAD"...HEAD -- src | sort)"
expected_src=$'src/adapter/mod_reference_richards_legacy_binding.f90\nsrc/legacy/b1_10_port/headcalc.f90'
[[ "$changed_src" == "$expected_src" ]] || {
  echo 'F-SI16_PRESCRIBED_HEAD FAIL unexpected production delta:' >&2
  printf '%s\n' "$changed_src" >&2
  exit 1
}

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git rev-parse "HEAD:$path")"
  [[ "$actual" == "$expected" ]] || {
    echo "F-SI16_PRESCRIBED_HEAD FAIL blob $path expected=$expected actual=$actual" >&2; exit 1; }
}
check_blob src/solver/mod_soil_water_solver_contract.f90 4271372085d800fd5da969a2ed073b00422d79c6
check_blob src/solver/mod_reference_richards_state_binding.f90 e68d88382c6502c571713cc97fddd4e18434e271
check_blob src/legacy/b1_10_port/headcalc.f90 d92f77963329d61ab3feb988f912252c0161436c

grep -Fq 'size(request%parameters%node_distance) /= n) return' src/solver/mod_soil_water_solver_contract.f90
grep -Fq 'grid_disnod = 0.5d0*parameter_set%dz(numnod)' src/legacy/b1_10_port/headcalc.f90
grep -Fq 'request%boundary%bottom_mode /= 5' src/adapter/mod_reference_richards_legacy_binding.f90
if grep -Fq "route = 'bottom-distance-required'" src/adapter/mod_reference_richards_legacy_binding.f90; then
  echo 'F-SI16_PRESCRIBED_HEAD FAIL stale explicit lower-face parameter guard' >&2; exit 1
fi
grep -Fq 'call materialize_prescribed_head_bottom_flux(request, ws%richards, state_binding)' src/adapter/mod_reference_richards_legacy_binding.f90
grep -Fq 'state%qbot = state%qtop' src/adapter/mod_reference_richards_legacy_binding.f90
grep -Fq 'richards%sink(node) - richards%source(node) + richards%provider_root_sink(node)' src/adapter/mod_reference_richards_legacy_binding.f90
if grep -Fqi 'call fluxes' src/adapter/mod_reference_richards_legacy_binding.f90; then
  echo 'F-SI16_PRESCRIBED_HEAD FAIL common adapter calls legacy fluxes' >&2
  exit 1
fi

echo 'F-SI16_STATIC_MINIMAL_PRODUCTION_SEAM PASS'

FLAGS=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow -fopenmp)
compile_gate() {
  local opt="$1" out="$2"
  mkdir -p "$out"
  gfortran "${FLAGS[@]}" -O"$opt" -J "$out" -I "$out" -c tests/fsi/fsi04_real_headcalc_stubs.f90 -o "$out/stubs.o"
  gfortran "${FLAGS[@]}" -O"$opt" -J "$out" -I "$out" -c src/runtime/mod_a23bu_worker_execution_context.f90 -o "$out/worker.o"
  gfortran "${FLAGS[@]}" -Werror -O"$opt" -J "$out" -I "$out" -c src/solver/mod_soil_water_solver_contract.f90 -o "$out/contract.o"
  gfortran "${FLAGS[@]}" -O"$opt" -J "$out" -I "$out" -c src/solver/mod_reference_richards_workspace.f90 -o "$out/workspace.o"
  gfortran "${FLAGS[@]}" -O"$opt" -J "$out" -I "$out" -c src/solver/mod_reference_richards_state_binding.f90 -o "$out/state.o"
  gfortran "${FLAGS[@]}" -O"$opt" -J "$out" -I "$out" -c tests/fsi/mod_fsi07_top_provider.f90 -o "$out/top.o"
  gfortran "${FLAGS[@]}" -Werror -O"$opt" -J "$out" -I "$out" -c src/solver/mod_b110_default_mvg_provider.f90 -o "$out/mvg.o"
  gfortran "${FLAGS[@]}" -Werror -O"$opt" -J "$out" -I "$out" -c src/solver/mod_b110_source_sink_provider.f90 -o "$out/process.o"
  gfortran "${FLAGS[@]}" -Werror -O"$opt" -J "$out" -I "$out" -c src/solver/mod_b110_root_sink_provider.f90 -o "$out/root.o"
  gfortran "${FLAGS[@]}" -O"$opt" -J "$out" -I "$out" -c src/legacy/b1_10_port/headcalc.f90 -o "$out/headcalc.o"
  gfortran "${FLAGS[@]}" -O"$opt" -J "$out" -I "$out" -c src/adapter/mod_reference_richards_legacy_binding.f90 -o "$out/adapter.o"
  gfortran "${FLAGS[@]}" -Werror -O"$opt" -J "$out" -I "$out" -c tests/fsi/test_fsi16_prescribed_bottom_head.F90 -o "$out/driver.o"
  gfortran "${FLAGS[@]}" -O"$opt" "$out/driver.o" "$out/adapter.o" "$out/headcalc.o" "$out/root.o" \
    "$out/process.o" "$out/mvg.o" "$out/top.o" "$out/state.o" "$out/workspace.o" "$out/contract.o" \
    "$out/worker.o" "$out/stubs.o" -o "$out/test"
}

for opt in 0 2; do
  out="$BUILD/o$opt"
  compile_gate "$opt" "$out"
  timeout 30s env OMP_NUM_THREADS=1 OMP_DYNAMIC=false "$out/test" > "$out/output.txt"
  grep -Fq 'F-SI16_BOTTOM_FLUX_SEED_INDEPENDENCE PASS' "$out/output.txt"
  grep -Fq 'F-SI16_BOTTOM_HEAD_RESPONSE PASS' "$out/output.txt"
  grep -Fq 'F-SI16_LEGACY_BOTTOM_GLOBAL_POISON PASS' "$out/output.txt"
  grep -Fq 'F-SI16_CONTINUITY_QBOT_IDENTITY PASS' "$out/output.txt"
  grep -Fq 'F-SI16_UNOWNED_BOTTOM_MODES_FAIL_CLOSED PASS' "$out/output.txt"
  grep -Fq 'F-SI16_DERIVED_BOTTOM_DISTANCE PASS' "$out/output.txt"
  grep -Fq 'F-SI16_PRESCRIBED_BOTTOM_HEAD_GATE PASS' "$out/output.txt"
  echo "F-SI16_PRESCRIBED_BOTTOM_HEAD_O${opt} PASS"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'F-SI16_PRESCRIBED_BOTTOM_HEAD_O0_O2_IDENTITY PASS'

# The new common-route admission is guarded away from direct legacy execution.
bash tests/fsi/run_fsi13_legacy_direct_identity_gate.sh >/dev/null
echo 'F-SI16_LEGACY_DIRECT_IDENTITY_REGRESSION PASS'

echo 'F-SI16_PRESCRIBED_BOTTOM_HEAD_GATE PASS'
