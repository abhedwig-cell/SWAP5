#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
build="${TMPDIR:-/tmp}/ppa-wu05e-macro-salt-oracle-$$"
mkdir -p "$build"
trap 'rm -rf "$build"' EXIT

for opt in 0 2; do
  mkdir -p "$build/o$opt"
  gfortran -std=f2008 -O"$opt" -Wall -Wextra -Werror -Wno-error=compare-reals -fcheck=all \
    -J "$build/o$opt" -I "$build/o$opt" \
    "$root/src/process/mod_solute_macropore_exchange.f90" \
    "$root/tests/physics/test_mobile_macropore_salt_exchange_oracle.f90" \
    -o "$build/o$opt/test_exchange"
  "$build/o$opt/test_exchange" > "$build/o$opt/result.txt"
done
cmp "$build/o0/result.txt" "$build/o2/result.txt"
cat "$build/o2/result.txt"
echo 'PPA_WU05E_MACROPORE_SALT_EXCHANGE_O0_O2=PASS'
