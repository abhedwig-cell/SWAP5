#!/usr/bin/env bash
set -euo pipefail
B="${TMPDIR:-/tmp}/wu05e-mobile-salt-$$"
mkdir -p "$B"
trap 'rm -rf "$B"' EXIT
for O in 0 2; do
  gfortran -std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -Wno-error=compare-reals \
    -fcheck=all -O"$O" -J"$B" -I"$B" \
    src/process/mod_solute_mobile_salt_state.f90 \
    tests/physics/test_mobile_salt_state.f90 -o "$B/salt-$O"
  "$B/salt-$O" | tee "$B/salt-output-$O"
  grep -Fq PPA_WU05E_MOBILE_SALT=PASS "$B/salt-output-$O"
  gfortran -std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -Wno-error=compare-reals \
    -fcheck=all -O"$O" -J"$B" -I"$B" \
    src/process/mod_root_salinity_response.f90 \
    tests/physics/test_root_salinity_response.f90 -o "$B/response-$O"
  "$B/response-$O" | tee "$B/response-output-$O"
  grep -Fq PPA_WU05E_ROOT_SALINITY_RESPONSE=PASS "$B/response-output-$O"
done
cmp "$B/salt-output-0" "$B/salt-output-2"
cmp "$B/response-output-0" "$B/response-output-2"
echo PPA_WU05E_MOBILE_SALT_O0_O2=PASS
