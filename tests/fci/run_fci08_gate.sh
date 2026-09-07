#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fci08-gate-$$"
trap 'rm -rf "$BUILD"' EXIT
mkdir -p "$BUILD/o0" "$BUILD/o2"

TX="$ROOT/src/transaction/mod_transaction_reference.f90"
CONTRACTS="$ROOT/src/runtime/mod_canonical_contracts.f90"
WATER="$ROOT/src/adapter/mod_b1_10_water_checkpoint.f90"
PROCESS="$ROOT/src/adapter/mod_b1_10_process_checkpoint.f90"
CAPSULE="$ROOT/src/adapter/mod_b1_10_legacy_trial_capsule.f90"
STUBS="$ROOT/tests/fci/fci08_process_state_stubs.f90"
TXTEST="$ROOT/tests/transaction/test_transaction_attempt_context.f90"
PTEST="$ROOT/tests/fci/test_fci08_process_checkpoint.f90"
CTEST="$ROOT/tests/fci/test_fci08_legacy_trial_capsule.f90"

python - "$TX" "$PROCESS" "$CAPSULE" <<'PY'
from pathlib import Path
import re,sys

tx=Path(sys.argv[1]).read_text().lower()
process=Path(sys.argv[2]).read_text().lower()
capsule=Path(sys.argv[3]).read_text().lower()
checks={
 'attempt_context_type':'type, public :: transaction_attempt_context_t' in tx,
 'model_capture_hook':'procedure :: capture_attempt_context' in tx,
 'model_restore_hook':'procedure :: restore_attempt_context' in tx,
 'restore_before_full':'call model%restore_attempt_context(checkpoint_context)' in tx,
 'capture_half_context':'call model%capture_attempt_context(half_context)' in tx,
 'process_extends_water':'extends(b1_10_water_state_t)' in process,
 'optional_thermal':'allocatable :: thermal' in process and 'tsoil(1:numnod)' in process,
 'optional_solute':'allocatable :: solute' in process and 'state%solute%cml' in process and 'state%solute%cmsy' in process,
 'optional_age_tracer':'state%solute%ageml' in process,
 'optional_irrigation':'allocatable :: irrigation' in process and 'dayfix' in process and 'nirri' in process,
 'optional_crop':'allocatable :: crop' in process and 'state%crop%cumdens' in process and 'state%crop%lrv_node' in process,
 'optional_wofost':'allocatable :: wofost' in process and 'croptype(icrop) == 2' in process,
 'wofost_state_not_rates':'r_act' not in process and 'r_pot' not in process,
 'process_no_io':not re.search(r'\b(open|read|write)\s*\(', process),
 'process_no_forcing_cursors':all(x not in process for x in ('meteo_rec','rain_rec','ipos_qtop','ipos_tetop','ipos_tebot')),
 'process_no_accounting':all(x not in process for x in ('imdectot','imsqprec','imqsol','cgrai','cqbotdo')),
 'capsule_thermal_cursors':all(x in capsule for x in ('ipos_qtop','ipos_tetop','ipos_tebot')),
 'capsule_solute_accounting':all(x in capsule for x in ('imdectot','imsqprec','imqsol','sbaldev','samini','isqtop')),
 'capsule_not_persistent':not re.search(r'extends\((canonical_state_t|transaction_state_t)\)', capsule),
}
failed=[k for k,v in checks.items() if not v]
print({'work_unit':'F-CI08','checks':checks,'failed':failed})
if failed: raise SystemExit(2)
PY

for opt in 0 2; do
  O="$BUILD/o$opt"
  FLAGS=(-O$opt -std=f2008 -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffree-line-length-none -J "$O" -I "$O")

  gfortran "${FLAGS[@]}" -c "$TX" -o "$O/transaction.o"
  gfortran "${FLAGS[@]}" "$TX" "$TXTEST" -o "$O/test_context"
  "$O/test_context" > "$O/context.log"
  grep -q 'FCI08_TRANSACTION_ATTEMPT_CONTEXT PASS' "$O/context.log"

  gfortran "${FLAGS[@]}" -c "$CONTRACTS" -o "$O/contracts.o"
  gfortran "${FLAGS[@]}" -c "$STUBS" -o "$O/stubs.o"
  gfortran "${FLAGS[@]}" -c "$WATER" -o "$O/water.o"
  gfortran "${FLAGS[@]}" -c "$PROCESS" -o "$O/process.o"
  gfortran "${FLAGS[@]}" -c "$PTEST" -o "$O/process_test.o"
  gfortran -O$opt -o "$O/test_process" "$O/transaction.o" "$O/contracts.o" "$O/stubs.o" "$O/water.o" "$O/process.o" "$O/process_test.o"
  "$O/test_process" > "$O/process.log"
  grep -q 'FCI08_PROCESS_CHECKPOINT PASS' "$O/process.log"

  gfortran "${FLAGS[@]}" -c "$CAPSULE" -o "$O/capsule.o"
  gfortran "${FLAGS[@]}" -c "$CTEST" -o "$O/capsule_test.o"
  gfortran -O$opt -o "$O/test_capsule" "$O/stubs.o" "$O/capsule.o" "$O/capsule_test.o"
  "$O/test_capsule" > "$O/capsule.log"
  grep -q 'FCI08_LEGACY_TRIAL_CAPSULE PASS' "$O/capsule.log"

done

cmp "$BUILD/o0/context.log" "$BUILD/o2/context.log"
cmp "$BUILD/o0/process.log" "$BUILD/o2/process.log"
cmp "$BUILD/o0/capsule.log" "$BUILD/o2/capsule.log"
echo FCI08_GATE_PASS
