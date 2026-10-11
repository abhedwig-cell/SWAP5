#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fci09-gate-$$"
trap 'rm -rf "$BUILD"' EXIT
mkdir -p "$BUILD/o0" "$BUILD/o2"

TX="$ROOT/src/transaction/mod_transaction_reference.f90"
CONTRACTS="$ROOT/src/runtime/mod_canonical_contracts.f90"
WATER="$ROOT/src/adapter/mod_b1_10_water_checkpoint.f90"
PROCESS="$ROOT/src/adapter/mod_b1_10_process_checkpoint.f90"
CAPSULE="$ROOT/src/adapter/mod_b1_10_legacy_trial_capsule.f90"
BINDING="$ROOT/src/adapter/mod_b1_10_transaction_binding.f90"
STUBS="$ROOT/tests/fci/fci08_process_state_stubs.f90"
TEST="$ROOT/tests/fci/test_fci09_transaction_binding.f90"
SWAPPART="$ROOT/src/legacy/b1_10_port/swap_part03.inc"

python - "$TX" "$WATER" "$PROCESS" "$CAPSULE" "$BINDING" "$SWAPPART" <<'PY'
from pathlib import Path
import re,subprocess,sys

tx,water,process,capsule,binding,swappart = [Path(x) for x in sys.argv[1:]]
expected={
 str(tx):'4a573316b77252b56bcb429fd519aa57123e9a06',
 str(water):'f8171d0263325b5103ac2df7cd353c443e27c925',
 str(process):'4084f979d86e0a97d2b7b570af38ad44d85dca6c',
 str(capsule):'46ebc5339e85f69c8a24ab99ba70987f559c817d',
 str(swappart):'14482290cfa4ef1daeb03813c1290b2c793b27a9',
}
for path,sha in expected.items():
    got=subprocess.check_output(['git','hash-object',path],text=True).strip()
    if got != sha:
        raise SystemExit(f'F-CI09 provenance pin mismatch: {path} {got} != {sha}')

b=binding.read_text().lower()
s=swappart.read_text().lower()
t=tx.read_text().lower()
checks={
 'extends_transaction_model':'extends(transaction_model_t)' in b,
 'extends_attempt_context':'extends(transaction_attempt_context_t)' in b,
 'process_capture_bound':'capture_b1_10_process_state' in b,
 'process_restore_bound':'restore_b1_10_process_state' in b,
 'capsule_capture_bound':'capture_b1_10_legacy_trial_capsule' in b,
 'capsule_restore_bound':'restore_b1_10_legacy_trial_capsule' in b,
 'generic_interval_locked':'generic_interval_advance = .false.' in b,
 'trial_mass_locked':'trial_mass_flux_contract = .false.' in b,
 'storage_locked':'mass_storage_contract = .false.' in b,
 'temporal_error_locked':'temporal_error_contract = .false.' in b,
 'reference_execution_capability_gate':'reference_execution_admitted' in b,
 'blocked_advance_no_swap_call':'call swap(' not in b,
 'binding_no_file_io':not re.search(r'\b(open|read|write)\s*\(',b),
 'legacy_dll_single_day_guard':'only single day allowed: tend must equal tstart' in s,
 'reference_core_full_trial':'call model%advance(full_state, t0, attempt_t1' in t,
 'reference_core_half_one':'call model%advance(half_state, t0, midpoint' in t,
 'reference_core_half_two':'call model%advance(half_state, midpoint, attempt_t1' in t,
}
failed=[k for k,v in checks.items() if not v]
print({'work_unit':'F-CI09','checks':checks,'failed':failed})
if failed:
    raise SystemExit(2)
PY

for opt in 0 2; do
  O="$BUILD/o$opt"
  FLAGS=(-O$opt -std=f2008 -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffree-line-length-none -J "$O" -I "$O")
  gfortran "${FLAGS[@]}" -c "$TX" -o "$O/transaction.o"
  gfortran "${FLAGS[@]}" -c "$CONTRACTS" -o "$O/contracts.o"
  gfortran "${FLAGS[@]}" -c "$STUBS" -o "$O/stubs.o"
  gfortran "${FLAGS[@]}" -c "$WATER" -o "$O/water.o"
  gfortran "${FLAGS[@]}" -c "$PROCESS" -o "$O/process.o"
  gfortran "${FLAGS[@]}" -c "$CAPSULE" -o "$O/capsule.o"
  gfortran "${FLAGS[@]}" -c "$BINDING" -o "$O/binding.o"
  gfortran "${FLAGS[@]}" -c "$TEST" -o "$O/test.o"
  gfortran -O$opt -o "$O/test_binding" "$O/transaction.o" "$O/contracts.o" "$O/stubs.o" "$O/water.o" "$O/process.o" "$O/capsule.o" "$O/binding.o" "$O/test.o"
  "$O/test_binding" > "$O/pass.log"
  grep -q 'FCI09_TRANSACTION_BINDING PASS' "$O/pass.log"
  if "$O/test_binding" storage-negative > "$O/storage-negative.log" 2>&1; then
    echo 'F-CI09 storage negative control unexpectedly succeeded' >&2
    exit 3
  fi
  grep -q 'mass storage contract not admitted' "$O/storage-negative.log"
done

cmp "$BUILD/o0/pass.log" "$BUILD/o2/pass.log"
echo FCI09_GATE_PASS
