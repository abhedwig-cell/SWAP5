#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-int13-capacity-event-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

for opt in 0 2; do
  mkdir -p "$BUILD/o$opt"
  gfortran -std=f2008 -Wall -Wextra -Werror -O"$opt" -J"$BUILD/o$opt" -I"$BUILD/o$opt" \
    "$ROOT/src/process/mod_rutter_interception_process.f90" \
    "$ROOT/tests/fpm/test_f_mig431_int13_capacity_event.f90" \
    -o "$BUILD/o$opt/test"
  "$BUILD/o$opt/test" > "$BUILD/o$opt/output.txt"
done
cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
cat "$BUILD/o0/output.txt"
echo F_MIG431_INT13_CAPACITY_EVENT_O0_O2_IDENTITY=PASS
