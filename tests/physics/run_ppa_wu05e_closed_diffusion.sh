#!/usr/bin/env bash
set -euo pipefail
B="${TMPDIR:-/tmp}/wu05e-closed-diffusion-$$"
mkdir -p "$B"
trap 'rm -rf "$B"' EXIT
for O in 0 2; do
  gfortran -std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -Wno-error=compare-reals \
    -fcheck=all -ffpe-trap=invalid,zero,overflow -O"$O" -J"$B" -I"$B" \
    src/process/mod_solute_mobile_salt_state.f90 src/process/mod_solute_closed_mobile_diffusion.f90 \
    tests/physics/test_closed_mobile_diffusion.f90 -o "$B/diffusion-$O"
  "$B/diffusion-$O" | tee "$B/output-$O"
done
cmp "$B/output-0" "$B/output-2"
echo PPA_WU05E_CLOSED_DIFFUSION_O0_O2=PASS
