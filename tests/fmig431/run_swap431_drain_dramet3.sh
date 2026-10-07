#!/usr/bin/env bash
set -euo pipefail
R="$(cd "$(dirname "$0")/../.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
for o in 0 2; do
  gfortran -O$o -std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace     "$R/src/process/mod_drainage_dramet3_response.f90"     "$R/tests/fmig431/test_swap431_drain_dramet3.f90" -o "$T/test$o"
  "$T/test$o" > "$T/out$o"
done
diff -u "$T/out0" "$T/out2"
cat "$T/out0"
