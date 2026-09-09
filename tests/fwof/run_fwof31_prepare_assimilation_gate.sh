#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fwof31-$$"
mkdir -p "$BUILD/prepare-o0" "$BUILD/prepare-o2" "$BUILD/fwof30-o0" "$BUILD/fwof30-o2"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=ba8a2bda14671488a5800c7791abdfc80e8219c5
NEW_SRC=src/crop/mod_wofost_prepare_assimilation.f90
changed_src="$(git diff --name-only "$BASE" -- src)"
[[ "$changed_src" == "$NEW_SRC" ]] || {
  echo 'FWOF31_UNEXPECTED_PRODUCTION_DELTA' >&2
  printf '%s\n' "$changed_src" >&2
  exit 1
}
echo 'FWOF31_PRODUCTION_DELTA_SINGLE_PREPARE_ASSIMILATION_MODULE=PASS'

python3 - <<'PY'
from pathlib import Path
import json, re

text = Path('src/crop/mod_wofost_prepare_assimilation.f90').read_text()
code = '\n'.join(line.split('!', 1)[0] for line in text.splitlines()).lower()
contract = json.loads(Path('integration/f-wof/F-WOF31_WORK_UNIT_CONTRACT.json').read_text())
status30 = json.loads(Path('integration/f-wof/F-WOF30_STATUS.json').read_text())
evidence30 = json.loads(Path('integration/f-wof/F-WOF30_QUALIFICATION_EVIDENCE.json').read_text())

assert contract['base']['commit'] == 'ba8a2bda14671488a5800c7791abdfc80e8219c5'
assert status30['status'] == 'QUALIFIED_RESTRICTED_SHARED_IMMUTABLE_WOFOST_RATE_PARAMETER_BUNDLE'
assert evidence30['tested_candidate'] == 'eb0d3c52e216c0310417f2e774ff7c4fe7a325a4'
assert contract['production_scope']['state_mutation'] is False
assert contract['production_scope']['persistent_rate_workspace'] is False
assert contract['production_scope']['calendar_dependency'] is False
assert contract['production_scope']['file_IO_dependency'] is False
assert contract['production_scope']['soil_solver_dependency'] is False

for required in [
    'type, public :: wofost_prepare_assimilation_forcing_t',
    'type, public :: wofost_prepare_assimilation_result_t',
    'public :: prepare_wofost_actual_assimilation',
    'effc = forcing%co2_efficiency_factor * scalars%initial_light_use_efficiency',
    'amax = forcing%co2_amax_factor * amax_dvs * temperature_factor',
    'dtga = dtga * minimum_temperature_factor',
    '(0.4_real64 / scalars%co2_to_dry_matter_fraction) / 44.0_real64',
    'result%actual_pgass = result%actual_pgass * scalars%attainable_yield_multiplier',
    'real(real64), parameter :: xgauss(3)',
    'real(real64), parameter :: wgauss(3)',
    'if (forcing%daily_effective_solar_height <= 0.0_real64) return',
    'if (eff <= 0.0_real64) then'
]:
    assert required in code, required

# Phase A may read the generic view validator, DVS and LAI only.
state_refs = set(re.findall(r'state_view%([a-z0-9_]+)', code))
assert state_refs == {'validate', 'development_stage', 'actual_leaf_area_index'}, state_refs

for forbidden in [
    'use atmosphere_interface', 'use plant_interface', 'use mod_meteo',
    'use variables', 'use parameters', 'astro(', 'daynr', 't1900',
    'iqrot', 'iptra', 'headcalc', 'modflow', '.swp', 'mod_integral'
]:
    assert forbidden not in code, forbidden
assert not re.search(r'\b(open|close|inquire|read|write)\s*\(', code)

assert contract['new_source_bound_discrepancy']['id'] == 'F-WOF31-EFF-ZERO-DIRECT-BEAM-SINGULARITY'
assert '0..5e6' in ' '.join(contract['fail_closed_rules'])
assert '0..2' in ' '.join(contract['fail_closed_rules'])

print('FWOF31_FWO30_CLOSEOUT_AND_PARAMETER_BOUNDARY_LOCK=PASS')
print('FWOF31_EXACT_PHASE_A_STATE_PARAMETER_FORCING_BOUNDARY_STATIC=PASS')
print('FWOF31_B110_FORMULA_AND_GAUSS_TRANSCRIPT_STATIC=PASS')
print('FWOF31_HIDDEN_RAD_KDIF_GLOBALS_REMOVED_STATIC=PASS')
print('FWOF31_NO_CALENDAR_IO_SOLVER_OR_ACCEPTED_AGGREGATE_DEPENDENCY=PASS')
print('FWOF31_EFF_ZERO_DIRECT_BEAM_DISCREPANCY_PERSISTED=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
TX="$ROOT/src/transaction/mod_transaction_reference.f90"
BIOMASS="$ROOT/src/crop/mod_wofost_actual_biomass_state.f90"
OWNER="$ROOT/src/crop/mod_wofost_crop_owner_state.f90"
VIEW="$ROOT/src/crop/mod_wofost_one_day_rate_state_view.f90"
TABLE="$ROOT/src/crop/mod_wofost_rate_table.f90"
PARAMS="$ROOT/src/crop/mod_wofost_rate_parameters.f90"
PREPARE="$ROOT/src/crop/mod_wofost_prepare_assimilation.f90"
PREPARE_TEST="$ROOT/tests/fwof/test_fwof31_prepare_assimilation.f90"
FWO30_TEST="$ROOT/tests/fwof/test_fwof30_rate_parameter_bundle.f90"

for OPT in o0 o2; do
  FLAG=-O0
  [[ "$OPT" == "o2" ]] && FLAG=-O2
  gfortran "${COMMON[@]}" "$FLAG" -J "$BUILD/prepare-$OPT" \
    "$TX" "$BIOMASS" "$OWNER" "$VIEW" "$TABLE" "$PARAMS" "$PREPARE" "$PREPARE_TEST" \
    -o "$BUILD/prepare-$OPT/test"
  "$BUILD/prepare-$OPT/test" > "$BUILD/prepare-$OPT/output.txt" 2>&1 || {
    cat "$BUILD/prepare-$OPT/output.txt" >&2
    exit 1
  }
  for marker in \
    'FWOF31_B110_ACTUAL_PGASS_BITWISE_TRANSCRIPT_EQUIVALENCE=PASS' \
    'FWOF31_STATE_AND_PARAMETERS_READ_ONLY=PASS' \
    'FWOF31_ZERO_ASSIMILATION_SHORT_CIRCUITS=PASS' \
    'FWOF31_ACTIVE_SOLAR_DENOMINATORS_FAIL_CLOSED=PASS' \
    'FWOF31_ZERO_EFFC_DIRECT_BEAM_FAILS_CLOSED=PASS' \
    'FWOF31_SOURCE_BOUND_FORCING_AND_TABLE_RANGES=PASS' \
    'FWOF31_NONFINITE_STATE_FAILS_CLOSED_WITHOUT_ARITHMETIC=PASS' \
    'FWOF31_PREPARE_ASSIMILATION_TEST PASS'; do
    grep -Fq "$marker" "$BUILD/prepare-$OPT/output.txt"
  done
  echo "FWOF31_${OPT^^}=PASS"
done

cmp "$BUILD/prepare-o0/output.txt" "$BUILD/prepare-o2/output.txt"
echo 'FWOF31_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/prepare-o0/output.txt"
echo "FWOF31_OUTPUT_SHA256=$(sha256sum "$BUILD/prepare-o0/output.txt" | cut -d' ' -f1)"

for OPT in o0 o2; do
  FLAG=-O0
  [[ "$OPT" == "o2" ]] && FLAG=-O2
  gfortran "${COMMON[@]}" "$FLAG" -J "$BUILD/fwof30-$OPT" \
    "$TABLE" "$PARAMS" "$FWO30_TEST" -o "$BUILD/fwof30-$OPT/test"
  "$BUILD/fwof30-$OPT/test" > "$BUILD/fwof30-$OPT/output.txt" 2>&1 || {
    cat "$BUILD/fwof30-$OPT/output.txt" >&2
    exit 1
  }
done
cmp "$BUILD/fwof30-o0/output.txt" "$BUILD/fwof30-o2/output.txt"
FWO30_SHA="$(sha256sum "$BUILD/fwof30-o0/output.txt" | cut -d' ' -f1)"
[[ "$FWO30_SHA" == '16827a9cf83541accd0c5e659d59a0d8c13a8aa55bfcbed3993798ddc2da0cec' ]] || {
  echo "FWOF31_FWO30_REGRESSION_SHA_MISMATCH actual=$FWO30_SHA" >&2
  exit 1
}
grep -Fq 'FWOF30_RATE_PARAMETER_BUNDLE_TEST PASS' "$BUILD/fwof30-o0/output.txt"
echo 'FWOF31_FWO30_PARAMETER_BUNDLE_EXACT_REGRESSION=PASS'

echo 'FWOF31_PREPARE_ASSIMILATION_GATE PASS'
