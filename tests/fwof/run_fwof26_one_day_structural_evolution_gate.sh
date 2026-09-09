#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fwof26-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

BASE=342096ca6d44a8d83458209eda2039424db0d2d5
EXPECTED_SRC=$'src/crop/mod_wofost_crop_owner_state.f90\nsrc/crop/mod_wofost_one_day_structural_evolution.f90'
changed_src="$(git diff --name-only "$BASE" -- src | sort)"
[[ "$changed_src" == "$EXPECTED_SRC" ]] || {
  echo 'FWOF26_UNEXPECTED_PRODUCTION_DELTA' >&2
  printf '%s\n' "$changed_src" >&2
  exit 1
}
echo 'FWOF26_PRODUCTION_DELTA_TWO_CROP_STATE_FILES=PASS'

check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git hash-object "$path")"
  [[ "$actual" == "$expected" ]] || {
    echo "FWOF26_BLOB_MISMATCH $path expected=$expected actual=$actual" >&2
    exit 1
  }
}

check_blob integration/f-wof/F-WOF25_STATUS.json 897ef8801a0588ae7d2bf5ce4497cc72461173f4
check_blob integration/f-wof/F-WOF25_READINESS_GATE.json 4ee7d89a50d9efb38b6f7cb5b41b74e2279f3006
echo 'FWOF26_FWO25_READINESS_LOCK=PASS'

python3 - <<'PY'
from pathlib import Path
import json, re

owner = Path('src/crop/mod_wofost_crop_owner_state.f90').read_text()
evolution = Path('src/crop/mod_wofost_one_day_structural_evolution.f90').read_text()
owner_code = '\n'.join(line.split('!', 1)[0] for line in owner.splitlines()).lower()
evolution_code = '\n'.join(line.split('!', 1)[0] for line in evolution.splitlines()).lower()

for required in [
    'type, public :: wofost_common_evolution_continuation_t',
    'real(real64) :: temperature_sum',
    'logical :: anthesis_reached',
    'integer :: minimum_temperature_history_count',
    'real(real64) :: minimum_temperature_history(7)',
    'type(wofost_common_evolution_continuation_t), allocatable :: evolution_continuation',
    'type(wofost_b110_reference_compatibility_t), allocatable :: b110_reference_compatibility'
]:
    assert required in owner_code, required

for required in [
    'subroutine prepare_wofost_one_day_candidate',
    'subroutine finalize_wofost_one_day_candidate',
    'type, public :: wofost_one_day_rate_packet_t',
    'type, public :: wofost_accepted_window_aggregates_t',
    'real(real64), parameter :: b110_nihil = 1.0e-10_real64',
    'laiexp_carryover_threshold = 6.0_real64'
]:
    assert required in evolution_code, required

for forbidden in [
    'use mod_meteo', 'use variables', 'use plant_interface', 'daynr', 't1900', 'cropstart', 'cropend',
    'mod_soil_water_solver', 'headcalc', 'reference_richards', 'modflow', '.swp'
]:
    assert forbidden not in evolution_code, forbidden

assert not re.search(r'\b(open|close|inquire|read|write)\s*\(', evolution_code)
assert 'type(wofost_one_day_rate_packet_t), allocatable' not in owner_code
assert 'wofost_rates' not in owner_code

contract = json.loads(Path('integration/f-wof/F-WOF26_WORK_UNIT_CONTRACT.json').read_text())
assert contract['base']['commit'] == '342096ca6d44a8d83458209eda2039424db0d2d5'
assert contract['admitted_profile']['sw_wofost'] == 1
assert contract['admitted_profile']['IDSL'] == [0, 1]
assert contract['production_scope']['full_rate_evaluator'] is False
assert contract['production_scope']['day_start_minimum_temperature_history_update'] is True
assert contract['production_scope']['accepted_IQROT_IPTRA_to_RELTR'] is True
assert contract['production_scope']['B110_GLAIEXP_carryover_sidecar'] is True

print('FWOF26_COMPACT_OPTIONAL_OWNER_EXTENSION_STATIC=PASS')
print('FWOF26_EVENT_LOCAL_RATE_PACKET_NOT_PERSISTED=PASS')
print('FWOF26_NO_CALENDAR_IO_SOLVER_DEPENDENCY_STATIC=PASS')
print('FWOF26_FULL_WOFOST_RATE_EVALUATOR_EXCLUDED=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -Wno-unused-variable -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
TX="$ROOT/src/transaction/mod_transaction_reference.f90"
CONTRACTS="$ROOT/src/runtime/mod_canonical_contracts.f90"
RUNTIME="$ROOT/src/runtime/mod_canonical_interval_runtime.f90"
KERNEL="$ROOT/src/kernel/mod_kernel_transactions.f90"
BIOMASS="$ROOT/src/crop/mod_wofost_actual_biomass_state.f90"
OWNER="$ROOT/src/crop/mod_wofost_crop_owner_state.f90"
EVOLUTION="$ROOT/src/crop/mod_wofost_one_day_structural_evolution.f90"
TEST="$ROOT/tests/fwof/test_fwof26_one_day_structural_evolution.f90"

for OPT in o0 o2; do
  FLAG=-O0
  [[ "$OPT" == "o2" ]] && FLAG=-O2
  gfortran "${COMMON[@]}" "$FLAG" -J "$BUILD/$OPT" \
    "$TX" "$CONTRACTS" "$RUNTIME" "$KERNEL" "$BIOMASS" "$OWNER" "$EVOLUTION" "$TEST" \
    -o "$BUILD/$OPT/test"
  "$BUILD/$OPT/test" > "$BUILD/$OPT/output.txt" 2>&1 || { cat "$BUILD/$OPT/output.txt" >&2; exit 1; }

  for marker in \
    'FWOF26_INACTIVE_ROUTE_NO_OPTIONAL_STATE_OR_FORCING_DEPENDENCY=PASS' \
    'FWOF26_ONLY_EXPLICIT_ONE_DAY_EVENT_ADMITTED=PASS' \
    'FWOF26_DAY_START_PREPARE_IS_CANDIDATE_LOCAL=PASS' \
    'FWOF26_ONE_DAY_STATE_UPDATE_ORDER_AND_ANTHESIS=PASS' \
    'FWOF26_EXACTLY_ONE_DAILY_LEAF_COHORT_SHIFT=PASS' \
    'FWOF26_GLAIEXP_THRESHOLD_CARRYOVER_CAPTURE=PASS' \
    'FWOF26_ACCEPTED_IQROT_IPTRA_RELTR_BINDING_FAILS_CLOSED=PASS' \
    'FWOF26_GLAIEXP_POST_THRESHOLD_USES_STORED_REFERENCE_MEMORY=PASS' \
    'FWOF26_ZERO_GROWTH_STILL_PRESERVES_DAILY_COHORT_CARDINALITY=PASS' \
    'FWOF26_POST_THRESHOLD_REFERENCE_WITHOUT_CARRYOVER_FAILS_CLOSED=PASS' \
    'FWOF26_FKT_CHECKPOINT_DISCARD_LEAVES_COMMITTED_STATE_UNCHANGED=PASS' \
    'FWOF26_SAME_CHECKPOINT_SAME_EVENT_REPLAY_BITWISE_IDENTITY=PASS' \
    'FWOF26_ONE_DAY_STRUCTURAL_EVOLUTION_TEST PASS'; do
    grep -Fq "$marker" "$BUILD/$OPT/output.txt"
  done
  echo "FWOF26_${OPT^^}=PASS"
done

cmp "$BUILD/o0/output.txt" "$BUILD/o2/output.txt"
echo 'FWOF26_O0_O2_OUTPUT_IDENTITY=PASS'
cat "$BUILD/o0/output.txt"
echo "FWOF26_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/output.txt" | cut -d' ' -f1)"
echo 'FWOF26_ONE_DAY_STRUCTURAL_EVOLUTION_GATE PASS'
