#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

python "$ROOT/tools/fci/fci07_legacy_trial_capsule_gate.py"

for opt in 0 2; do
  BUILD="$ROOT/.fci07-capsule-o$opt"
  rm -rf "$BUILD"; mkdir -p "$BUILD"
  FLAGS=(-O$opt -std=f2008 -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffree-line-length-none -J "$BUILD" -I "$BUILD")
  gfortran "${FLAGS[@]}" -c "$ROOT/tests/fci/fci07_legacy_capsule_stubs.f90" -o "$BUILD/stubs.o"
  gfortran "${FLAGS[@]}" -c "$ROOT/src/adapter/mod_b1_10_legacy_trial_capsule.f90" -o "$BUILD/capsule.o"
  gfortran "${FLAGS[@]}" -c "$ROOT/tests/fci/test_fci07_legacy_trial_capsule.f90" -o "$BUILD/test.o"
  gfortran -O$opt -o "$BUILD/test" "$BUILD/stubs.o" "$BUILD/capsule.o" "$BUILD/test.o"
  "$BUILD/test" > "$BUILD/gate.log"
  grep -q 'FCI07_LEGACY_TRIAL_CAPSULE PASS' "$BUILD/gate.log"
done

cmp "$ROOT/.fci07-capsule-o0/gate.log" "$ROOT/.fci07-capsule-o2/gate.log"
echo FCI07_GATE_PASS
