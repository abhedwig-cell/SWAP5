#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
fail(){ echo "M1_C3_INDEPENDENT_FAIL $*" >&2; exit 1; }

python3 - <<'PY'
from pathlib import Path
import re
p=Path('src/solver/mod_b110_dynamic_top_boundary_provider.f90').read_text()
a=Path('src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90').read_text()
t=Path('src/adapter/mod_b110_production_soil_water_task2.f90').read_text()

# The low-level carrier is opt-in and has no legacy/global/file dependency.
assert 'fixed_top_node_conductivity_cm_per_day = -1.0_real64' in p
assert 'fixed_top_node_conductivity = -1.0_real64' in a
for text in (p,a):
    assert 'MOD_' not in text
    assert not re.search(r'(?im)^\s*(open|read|write|inquire)\s*\(', text)

# The legacy compatibility semantics are composed only at the existing Task2 adapter.
for needle in (
    'enable_ksatexm_extension=m1_profile',
    'bind_b110_root_sink_provider(root_sink, root_copy)',
    'fmr_resolve_legacy_bottom_boundary(swbotb, legacy_bottom, bottom_status)',
    'fixed_top_node_conductivity=k(1)',
):
    assert needle in t, needle
assert 'call HeadCalc' not in t and 'call headcalc' not in t.lower()
assert 'swbotb == 6' in t
assert 'swkimpl == 0' in t
assert 'swsophy == 0' in t

# Defaults remain untouched outside the bounded profile.
assert 'm1_profile = m1_b111_legacy_application_profile_active()' in t
assert 'enable_ksatexm_extension=m1_profile' in t
assert 'root_provider_active = m1_profile .and.' in t
assert 'if (m1_profile .and. swbotb == 6) then' in t
assert 'if (m1_profile) then' in t and 'fixed_top_node_conductivity=k(1)' in t
print('M1_C3_INDEPENDENT_ARCHITECTURE_BOUNDARY=PASS')
print('M1_C3_INDEPENDENT_DEFAULTS_FAIL_CLOSED=PASS')
PY

BUILD="${RUNNER_TEMP:-/tmp}/m1-c3-independent-${GITHUB_RUN_ID:-local}-$$"
rm -rf "$BUILD"; mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
FLAGS=(-std=f2008 -pedantic-errors -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
for opt in 0 2; do
  OUT="$BUILD/o$opt"; mkdir -p "$OUT"
  gfortran "${FLAGS[@]}" -Wno-error=unused-dummy-argument -O"$opt" -J "$OUT" -I "$OUT" -c src/solver/mod_soil_water_solver_contract.f90 -o "$OUT/contract.o"
  gfortran "${FLAGS[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/solver/mod_b110_default_mvg_provider.f90 -o "$OUT/mvg.o"
  gfortran "${FLAGS[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/process/mod_restricted_surface_evaporation.f90 -o "$OUT/evap.o"
  gfortran "${FLAGS[@]}" -Wno-error=compare-reals -O"$opt" -J "$OUT" -I "$OUT" -c src/solver/mod_b110_dynamic_top_boundary_provider.f90 -o "$OUT/top.o"
  gfortran "${FLAGS[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/m1/test_m1_c3_fixed_top_conductivity.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "$OUT/contract.o" "$OUT/mvg.o" "$OUT/evap.o" "$OUT/top.o" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/output.txt"
  grep -Fq 'M1_C3_FIXED_TOP_DEFAULT_DYNAMIC=PASS' "$OUT/output.txt" || fail "default dynamic O$opt"
  grep -Fq 'M1_C3_FIXED_TOP_OVERRIDE_STABLE=PASS' "$OUT/output.txt" || fail "fixed override O$opt"
  grep -Fq 'M1_C3_FIXED_TOP_ORIGIN_IDENTITY=PASS' "$OUT/output.txt" || fail "origin identity O$opt"
done
cmp -s "$BUILD/o0/output.txt" "$BUILD/o2/output.txt" || fail 'O0/O2 output drift'
cat "$BUILD/o0/output.txt"

# Independent source-lineage checks for reused admitted semantics.
[[ "$(git rev-parse HEAD:src/solver/mod_b110_default_mvg_provider.f90)" == 90183cbe0f3f0b349e40fa6b0c65b2223ca8a739 ]] || fail 'F-SI39 provider authority drift'
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_legacy_bottom_boundary_application_binding.f90)" == 456c87437e83d1d362d41fbf9820e70d96353ff9 ]] || fail 'F-APP02 bottom binding authority drift'
[[ "$(git rev-parse HEAD:src/solver/mod_b110_root_sink_provider.f90)" == ef2d2fd883d116c314b98e8f0f14330150b4778a ]] || fail 'root-sink provider authority drift'
echo 'M1_C3_INDEPENDENT_REUSED_AUTHORITIES=PASS'
echo 'M1_C3_INDEPENDENT_QUALIFICATION=PASS'
