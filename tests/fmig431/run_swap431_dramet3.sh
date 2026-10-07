#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"; B="$(mktemp -d)"; trap 'rm -rf "$B"' EXIT
for opt in 0 2; do
 D="$B/o$opt";mkdir -p "$D"
 gfortran -std=f2008 -ffree-line-length-none -fcheck=all -ffpe-trap=invalid,zero,overflow -O"$opt" -J"$D" -I"$D"   "$ROOT/src/solver/mod_soil_water_solver_contract.f90"   "$ROOT/src/solver/mod_process_hydraulic_view.f90"   "$ROOT/src/process/mod_drainage_dramet3_response.f90"   "$ROOT/tests/fmig431/test_swap431_dramet3.f90" -o "$D/test"
 "$D/test" > "$D/out.txt"
done
diff -u "$B/o0/out.txt" "$B/o2/out.txt"
for m in SW431_DRAIN_DRAMET3_OWL_RESOLUTION=PASS SW431_DRAIN_ALLOCATION=PASS SW431_DRAIN_INF_LIMIT=PASS SW431_DRAIN_DRAMET3_SIGNED_RESISTANCE=PASS; do grep -Fx "$m" "$B/o0/out.txt"; done
echo SW431_DRAIN_DRAMET3_QUALIFICATION=PASS
