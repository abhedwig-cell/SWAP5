#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fwof43a-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=4ebbbb6563132a80c26a22124d9261928fe2ffbf
changed_src="$(git diff --name-only "$BASE" -- src)"
[[ "$changed_src" == "src/crop/mod_crop_et_canopy_view_provider.f90" ]] || {
  echo "FWO43A_UNEXPECTED_PRODUCTION_DELTA" >&2
  printf '%s\n' "$changed_src" >&2
  exit 1
}
echo 'FWO43A_PRODUCTION_DELTA_SINGLE_CROP_PROVIDER=PASS'

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git hash-object "$path")"
  [[ "$actual" == "$expected" ]] || {
    echo "FWO43A_PROTECTED_BLOB_MISMATCH $path expected=$expected actual=$actual" >&2
    exit 1
  }
}

# F-WOF29-qualified AFGEN substrate. F-WOF43A reuses it rather than defining
# a second interpolation implementation.
check_blob src/crop/mod_wofost_rate_table.f90 5a0e8387157c5d1e1a6a94a24c19c7519c6bfcd5
echo 'FWO43A_AFGEN_SUBSTRATE_SOURCE_LOCK=PASS'

python3 - <<'PY'
from pathlib import Path
p = Path('src/crop/mod_crop_et_canopy_view_provider.f90').read_text()
low = p.lower()

for forbidden in [
    'headcalc', 'mod_process_hydraulic_view', 'mod_root_water_uptake_process',
    'mod_reference_et_demand_process', 'mod_kernel_transactions',
    'open(', 'read(', 'write(', 't1900', 'iyear', 'calendar',
    'jacobian', 'newton', 'file=', 'unit_'
]:
    assert forbidden not in low, forbidden

assert 'type, public :: crop_et_canopy_parameters_t' in p
assert 'type, public :: crop_et_canopy_state_view_t' in p
assert 'type, public :: crop_et_canopy_forcing_t' in p
assert 'type, public :: crop_et_canopy_view_t' in p
assert 'direct_extinction_coefficient' in p
assert 'diffuse_extinction_coefficient' in p
assert 'crop_factor_by_development_stage' in p
assert 'transpiration_factor_by_co2' in p
assert '1.0_real64 - exp(-optical_depth)' in p
assert 'crop_factor_by_development_stage%evaluate' in p
assert 'transpiration_factor_by_co2%evaluate' in p
assert 'view%co2_transpiration_factor = 1.0_real64' in p
assert 'if (.not. state%crop_emerged) then' in p
assert 'allocatable' not in low
assert '\nsave' not in low and ' save' not in low

print('FWO43A_PROVIDER_BOUNDARY_STATIC=PASS')
print('FWO43A_NO_IO_CALENDAR_HYDRAULIC_OR_RUNTIME_INTERNALS=PASS')
print('FWO43A_NO_PERSISTENT_DERIVED_VIEW_STATE=PASS')
print('FWO43A_SOURCE_FORMULAS_PRESENT=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)

for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    src/crop/mod_wofost_rate_table.f90 -o "$OUT/mod_wofost_rate_table.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    src/crop/mod_crop_et_canopy_view_provider.f90 -o "$OUT/mod_crop_et_canopy_view_provider.o"
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c \
    tests/fwof/test_fwof43a_crop_et_canopy_view_provider.f90 -o "$OUT/test_fwof43a_crop_et_canopy_view_provider.o"
  gfortran -O"$opt" \
    "$OUT/mod_wofost_rate_table.o" \
    "$OUT/mod_crop_et_canopy_view_provider.o" \
    "$OUT/test_fwof43a_crop_et_canopy_view_provider.o" \
    -o "$OUT/test_fwof43a_crop_et_canopy_view_provider"

  "$OUT/test_fwof43a_crop_et_canopy_view_provider" > "$OUT/output.txt" 2>&1 || {
    cat "$OUT/output.txt" >&2
    exit 1
  }

  for marker in \
    'FWO43A_B110_VCOVER_FORMULA=PASS' \
    'FWO43A_B110_CF_AFGEN=PASS' \
    'FWO43A_B110_FCO2TRA_AFGEN=PASS' \
    'FWO43A_NONEMERGED_NONZERO_VCOVER=PASS' \
    'FWO43A_INACTIVE_DEPENDENCIES_MINIMAL=PASS' \
    'FWO43A_CO2_DISABLED_FORCING_INDEPENDENCE=PASS' \
    'FWO43A_AFGEN_ENDPOINT_CLAMP=PASS' \
    'FWO43A_FAIL_CLOSED_ACTIVE_DOMAIN=PASS' \
    'FWO43A_STATELESS_A_B_A_IDENTITY=PASS' \
    'FWO43A_CROP_ET_CANOPY_VIEW_TEST PASS'; do
      grep -Fq "$marker" "$OUT/output.txt"
  done
  echo "FWO43A_CANDIDATE_O${opt}=PASS"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FWO43A_CANDIDATE_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"
echo "FWO43A_CANDIDATE_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | cut -d' ' -f1)"
echo 'FWO43A_CROP_ET_CANOPY_VIEW_PROVIDER_GATE PASS'
