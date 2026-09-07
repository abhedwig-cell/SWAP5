#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fci10-gate-$$"
trap 'rm -rf "$BUILD"' EXIT
mkdir -p "$BUILD/o0" "$BUILD/o2"

TX="$ROOT/src/transaction/mod_transaction_reference.f90"
CONTRACTS="$ROOT/src/runtime/mod_canonical_contracts.f90"
WATER="$ROOT/src/adapter/mod_b1_10_water_checkpoint.f90"
PROCESS="$ROOT/src/adapter/mod_b1_10_process_checkpoint.f90"
TRIAL="$ROOT/src/adapter/mod_b1_10_trial_mass.f90"
MASS="$ROOT/src/adapter/mod_b1_10_mass_seam.f90"
BINDING="$ROOT/src/adapter/mod_b1_10_transaction_binding.f90"
STUBS="$ROOT/tests/fci/fci10_mass_state_stubs.f90"
TEST="$ROOT/tests/fci/test_fci10_mass_seam.f90"
CONTRACT="$ROOT/integration/f-ci/F-CI10_TIME_MASS_SEAM.json"
EVIDENCE="$ROOT/integration/f-ci/evidence/F-CI10_LOCAL_HUPSEL_MASS_CANDIDATE.json"

python - "$TRIAL" "$MASS" "$BINDING" "$CONTRACT" "$EVIDENCE" <<'PY'
from pathlib import Path
import json,re,sys
trial=Path(sys.argv[1]).read_text().lower()
mass=Path(sys.argv[2]).read_text().lower()
binding=Path(sys.argv[3]).read_text().lower()
contract=json.loads(Path(sys.argv[4]).read_text())
evidence=json.loads(Path(sys.argv[5]).read_text())
checks={
 'trial_mass_worker_local_type':'type, public :: b1_10_trial_mass_t' in trial,
 'trial_mass_not_persistent':not re.search(r'extends\((canonical_state_t|transaction_state_t)\)',trial),
 'trial_mass_no_save':'save ::' not in trial,
 'trial_mass_no_io':not re.search(r'\b(open|read|write)\s*\(',trial),
 'storage_uses_soil_and_pond':'state%volact + state%pond' in mass,
 'storage_includes_interception':'state%crop%sicact' in mass,
 'snow_fail_closed':'swsnow /= 0' in mass,
 'macropore_fail_closed':'swmacro /= 0' in mass,
 'canonical_complete_requires_trial_complete':'trial_mass%active .and. trial_mass%complete' in mass,
 'canonical_residual_unrounded':'accounting%storage_end - accounting%storage_start' in mass and 'trial_mass%total_in - trial_mass%total_out' in mass,
 'fci09_reference_execution_still_locked':'generic_interval_advance = .false.' in binding and 'trial_mass_flux_contract = .false.' in binding,
 'timecontrol_hash_pinned':contract['source_identity']['timecontrol_f90_sha256']=='6d2a62db0ff1e3ea00693f7b39bdb36e1811ba79011f15feef5a656ddf3181b8',
 'integral_hash_pinned':contract['source_identity']['integral_f90_sha256']=='bd37ebe5014f14ab2ff961a336cfa284266102d510617feef1c00f6616c64174',
 'generic_subday_not_admitted':contract['time_seam_findings']['generic_subday_advance_admitted'] is False,
 'candidate_not_production':evidence['production_integration_status']=='NOT_YET_MATERIALIZED',
 'candidate_mass_pass':evidence['result']=='PASS_CANDIDATE_MASS_FORMULATION',
 'hard_mass_bound':evidence['max_abs_residual_cm'] <= evidence['hard_mass_limit_cm'],
 'candidate_o0_o2_identity':evidence['o0_o2_identity'] is True,
}
failed=[k for k,v in checks.items() if not v]
print({'work_unit':'F-CI10','checks':checks,'failed':failed})
if failed: raise SystemExit(2)
PY

for opt in 0 2; do
  O="$BUILD/o$opt"
  FLAGS=(-O$opt -std=f2008 -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffree-line-length-none -J "$O" -I "$O")
  gfortran "${FLAGS[@]}" -c "$TX" -o "$O/transaction.o"
  gfortran "${FLAGS[@]}" -c "$CONTRACTS" -o "$O/contracts.o"
  gfortran "${FLAGS[@]}" -c "$STUBS" -o "$O/stubs.o"
  gfortran "${FLAGS[@]}" -c "$WATER" -o "$O/water.o"
  gfortran "${FLAGS[@]}" -c "$PROCESS" -o "$O/process.o"
  gfortran "${FLAGS[@]}" -c "$TRIAL" -o "$O/trial.o"
  gfortran "${FLAGS[@]}" -c "$MASS" -o "$O/mass.o"
  gfortran "${FLAGS[@]}" -c "$TEST" -o "$O/test.o"
  gfortran -O$opt -o "$O/test_mass" "$O/transaction.o" "$O/contracts.o" "$O/stubs.o" "$O/water.o" "$O/process.o" "$O/trial.o" "$O/mass.o" "$O/test.o"
  "$O/test_mass" > "$O/mass.log"
  grep -q 'FCI10_MASS_SEAM PASS' "$O/mass.log"
done

cmp "$BUILD/o0/mass.log" "$BUILD/o2/mass.log"
echo FCI10_GATE_PASS
