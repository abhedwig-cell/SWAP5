#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"
for opt in 0 2; do
 "${FC:-gfortran}" -std=f2008 -ffree-line-length-none -fcheck=all -O"$opt" -J"$BUILD" -I"$BUILD" \
 src/process/macropore/mod_ppa_wu05a6_saturated_exchange_rate.f90 \
 src/process/macropore/mod_rfm_endpoint_release.f90 \
 tests/fpm/test_ppa_wu05a27_reverse_exchange.f90 -o "$BUILD/test"
 "$BUILD/test" > "$BUILD/o$opt.csv"
done
cmp "$BUILD/o0.csv" "$BUILD/o2.csv"
cat "$BUILD/o2.csv"
