#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fsi07-provider-concurrency-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

STUBS="$ROOT/tests/fsi/fsi04_real_headcalc_stubs.f90"
WORKER="$ROOT/src/runtime/mod_a23bu_worker_execution_context.f90"
CONTRACT="$ROOT/src/solver/mod_soil_water_solver_contract.f90"
WORKSPACE="$ROOT/src/solver/mod_reference_richards_workspace.f90"
STATE="$ROOT/src/solver/mod_reference_richards_state_binding.f90"
PROVIDER="$ROOT/tests/fsi/mod_fsi07_top_provider.f90"
HEADCALC="$ROOT/src/legacy/b1_10_port/headcalc.f90"
DRIVER="$ROOT/tests/fsi/test_fsi07_real_concurrency_provider.F90"

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -fopenmp)
for opt in 0 2; do
  out="$BUILD/o$opt"; mkdir -p "$out"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$STUBS" -o "$out/stubs.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$WORKER" -o "$out/worker.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$CONTRACT" -o "$out/contract.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$WORKSPACE" -o "$out/workspace.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$STATE" -o "$out/state.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$PROVIDER" -o "$out/provider.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$HEADCALC" -o "$out/headcalc.o"
  gfortran "${COMMON[@]}" -O"$opt" -cpp -J "$out" -I "$out" -c "$DRIVER" -o "$out/driver.o"
  gfortran "${COMMON[@]}" -O"$opt" "$out/driver.o" "$out/headcalc.o" "$out/provider.o" "$out/state.o" \
    "$out/workspace.o" "$out/contract.o" "$out/worker.o" "$out/stubs.o" -o "$out/gate"
  for threads in 1 2 4 8; do
    timeout 30s env OMP_NUM_THREADS="$threads" OMP_DYNAMIC=false "$out/gate" > "$out/t${threads}.txt"
    grep -Fq "F-SI07_REAL_HEADCALC_${threads} PASS" "$out/t${threads}.txt"
  done
  echo "F-SI07_PROVIDER_CONCURRENCY_O${opt}_1_2_4_8 PASS"
done

echo 'F-SI07_PROVIDER_CONCURRENCY_GATE PASS'
