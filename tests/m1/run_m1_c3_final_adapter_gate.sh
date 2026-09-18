#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/m1-c3-final-${GITHUB_RUN_ID:-local}-$$"
rm -rf "$BUILD"; mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "M1_C3_FINAL_GATE_FAIL $*" >&2; exit 1; }

python3 - <<'PY'
from pathlib import Path
p=Path('src/solver/mod_b110_dynamic_top_boundary_provider.f90').read_text()
a=Path('src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90').read_text()
t=Path('src/adapter/mod_b110_production_soil_water_task2.f90').read_text()
assert 'fixed_top_node_conductivity_cm_per_day = -1.0_real64' in p
assert 'if (request%fixed_top_node_conductivity_cm_per_day >= 0.0_real64) then' in p
assert 'fixed_top_node_conductivity = -1.0_real64' in a
assert 'intent(in), optional :: fixed_top_node_conductivity' in a
assert 'b110_request%fixed_top_node_conductivity_cm_per_day = self%fixed_top_node_conductivity' in a
for token in [
  'use mod_b110_root_sink_provider',
  'use mod_fmr_legacy_bottom_boundary_application_binding',
  'enable_ksatexm_extension=m1_profile',
  'fixed_top_node_conductivity=k(1)',
  'fmr_resolve_legacy_bottom_boundary',
  'request%evaluation%root_sink => root_sink',
  'logical function m1_b111_legacy_application_profile_active()'
]:
    assert token in t, token
assert t.count('fixed_top_node_conductivity=k(1)') == 1
assert 'swbotb == 6 .and. m1_b111_legacy_application_profile_active()' in t
assert 'any(abs(qrot(1:numnod)) > 0.0_real64) .and. .not. m1_b111_legacy_application_profile_active()' in t
for path in [
  'src/solver/mod_b110_dynamic_top_boundary_provider.f90',
  'src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90',
  'src/adapter/mod_b110_production_soil_water_task2.f90'
]:
    low=Path(path).read_text().lower()
    for forbidden in ('open(', 'file=', 'unit=', 'read('):
        assert forbidden not in low, (path, forbidden)
print('M1C3_NO_FILE_PARSER_SEMANTICS_IN_TYPED_SEAM=PASS')
print('M1C3_BOUNDED_PROFILE_SOURCE_GUARDS=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
for opt in 0 2; do
  OUT="$BUILD/o$opt"; mkdir -p "$OUT"
  gfortran "${COMMON[@]}" -O"$opt" -J"$OUT" -I"$OUT" -c src/solver/mod_soil_water_solver_contract.f90 -o "$OUT/contract.o"
  gfortran "${COMMON[@]}" -O"$opt" -J"$OUT" -I"$OUT" -c src/process/mod_restricted_surface_evaporation.f90 -o "$OUT/evap.o"
  gfortran "${COMMON[@]}" -O"$opt" -J"$OUT" -I"$OUT" -c src/solver/mod_b110_default_mvg_provider.f90 -o "$OUT/mvg.o"
  gfortran "${COMMON[@]}" -O"$opt" -J"$OUT" -I"$OUT" -c src/solver/mod_b110_dynamic_top_boundary_provider.f90 -o "$OUT/dyn.o"
  gfortran "${COMMON[@]}" -O"$opt" -J"$OUT" -I"$OUT" -c src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90 -o "$OUT/dyn_adapter.o"
  gfortran "${COMMON[@]}" -Wno-error=compare-reals -O"$opt" -J"$OUT" -I"$OUT" -c tests/m1/test_m1_c3_fixed_top_conductivity.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "$OUT/contract.o" "$OUT/evap.o" "$OUT/mvg.o" "$OUT/dyn.o" "$OUT/dyn_adapter.o" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/m1.txt"
  grep -Fq 'M1C3_FIXED_TOP_DEFAULT_PRESERVATION=PASS' "$OUT/m1.txt" || fail "default preservation O$opt"
  grep -Fq 'M1C3_FIXED_TOP_LEGACY_SEMANTIC=PASS' "$OUT/m1.txt" || fail "legacy fixed top O$opt"

  gfortran "${COMMON[@]}" -Wno-error=compare-reals -O"$opt" -J"$OUT" -I"$OUT" -c tests/fsi/test_fsi39_b110_ksatexm.f90 -o "$OUT/fsi39.o"
  gfortran -O"$opt" "$OUT/contract.o" "$OUT/mvg.o" "$OUT/fsi39.o" -o "$OUT/fsi39"
  "$OUT/fsi39" > "$OUT/fsi39.txt"
  for mark in F_SI39_DEFAULT_DISABLED_PRESERVATION=PASS F_SI39_HUPSEL_SATURATED_KSATEXM=PASS F_SI39_HUPSEL_NEAR_SATURATED_INTERPOLATION=PASS F_SI39_BELOW_THRESHOLD_NOOP=PASS; do
    grep -Fq "$mark" "$OUT/fsi39.txt" || fail "F-SI39 O$opt missing $mark"
  done
done
cmp "$BUILD/o0/m1.txt" "$BUILD/o2/m1.txt" || fail 'M1 fixed-top O0/O2 drift'
cmp "$BUILD/o0/fsi39.txt" "$BUILD/o2/fsi39.txt" || fail 'F-SI39 O0/O2 drift'
cat "$BUILD/o0/m1.txt"
echo 'M1C3_FSI39_DEFAULT_PRESERVATION=PASS'
echo 'M1C3_FINAL_TYPED_ADAPTER_GATE=PASS'
