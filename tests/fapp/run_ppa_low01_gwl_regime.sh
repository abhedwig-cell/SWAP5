#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FC="${FC:-gfortran}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
for OPT in 0 2; do
  "$FC" -std=f2008 -Wall -Wextra -fcheck=all -ffpe-trap=invalid,zero,overflow "-O${OPT}" \
    -J "$TMP" "$ROOT/src/adapter/mod_ppa_low01_gwl_regime.f90" \
    "$ROOT/tests/fapp/test_ppa_low01_gwl_regime.f90" -o "$TMP/test-low01-regime-O${OPT}"
  "$TMP/test-low01-regime-O${OPT}" | tee "$TMP/out-O${OPT}"
done
diff -u "$TMP/out-O0" "$TMP/out-O2"
