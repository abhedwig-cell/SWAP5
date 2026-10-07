#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
for opt in -O0 -O2; do
  gfortran "$opt" -std=f2008 -ffree-line-length-none -fcheck=all     "$root/src/runtime/mod_fmr_runtime_core.f90"     "$root/tests/fpm/test_swap431_sol01_layout_registry.f90"     -o "$work/test_sol01_layout"
  "$work/test_sol01_layout"
done
