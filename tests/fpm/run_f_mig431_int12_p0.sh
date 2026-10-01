#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="/tmp/swap5-int12-p0-$$"
mkdir -p "$BUILD"; trap 'rm -rf "$BUILD"' EXIT
SRC="$ROOT/src/runtime/mod_interception_source_window_runtime.f90"
TEST="$ROOT/tests/fpm/test_f_mig431_int12_p0.f90"
gfortran -std=f2008 -Wall -Wextra -Werror -O0 -J"$BUILD" "$SRC" "$TEST" -o "$BUILD/p0-o0"
"$BUILD/p0-o0" > "$BUILD/o0.txt"
gfortran -std=f2008 -Wall -Wextra -Werror -O2 -J"$BUILD" "$SRC" "$TEST" -o "$BUILD/p0-o2"
"$BUILD/p0-o2" > "$BUILD/o2.txt"
cmp "$BUILD/o0.txt" "$BUILD/o2.txt"
cat "$BUILD/o0.txt"
echo "F-MIG431-INT12-P0 O0/O2 IDENTITY PASS"
