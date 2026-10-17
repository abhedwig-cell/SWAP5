#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../../.." && pwd)"
src="$root/tests/nut-sol/candidates"
prod="$root/src/process/mod_b111_pond_solute_exchange.f90"
if ! command -v gfortran >/dev/null; then echo 'gfortran unavailable' >&2; exit 2; fi
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
for opt in 0 2; do
  (
    cd "$tmp"
    gfortran -std=f2008 -Wall -Wextra -Werror -fcheck=all "-O$opt" \
      "$prod" "$src/mod_b111_surface_loss_budget.f90" \
      "$src/test_surface_loss_real_production.f90" -o "compare_O$opt"
    "./compare_O$opt"
  )
done
