#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fsi20-rejection-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

FVQ27=1dc8219beda37fbcd6fd4232c964208fa0f17c8f
BACKEND_BLOB=6f39d60a87c1987ae95d7faec2f55f865af90a08

git diff --quiet "$FVQ27" -- src || { echo 'FSI20_REJECTION_PRODUCTION_IMMUTABILITY=FAIL'; exit 1; }
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_reference_backend.f90)" == "$BACKEND_BLOB" ]]
echo 'FSI20_REJECTION_PRODUCTION_IMMUTABILITY=PASS'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_transaction_reference.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/runtime/mod_fmr_runtime_core.f90
  src/runtime/mod_fmr_checkpoint_orchestrator.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_process_hydraulic_view.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/process/mod_snow_process.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_process_hydraulic_view_binding.f90
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
  src/process/mod_irrigation_process.f90
  tests/fmr/mod_fmr04_fixed_top_provider.f90
)

OUT="$BUILD/o0"; mkdir -p "$OUT"; objects=()
for src in "${MODULE_SRC[@]}"; do
  obj="$OUT/$(basename "${src%.*}").o"
  gfortran "${COMMON[@]}" -O0 -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
  objects+=("$obj")
done
gfortran "${COMMON[@]}" -O0 -J "$OUT" -I "$OUT" -c tests/fsi/test_fsi20_prescribed_head_temporal_characterization.f90 -o "$OUT/test.o"
gfortran -O0 "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
timeout 120s "$OUT/test" | tee "$OUT/output.txt"
grep -Fq 'FSI20_PRESCRIBED_HEAD_TEMPORAL_CHARACTERIZATION_DRIVER PASS' "$OUT/output.txt"
python3 - "$OUT/output.txt" <<'PY'
from pathlib import Path
import re,sys
lines=Path(sys.argv[1]).read_text().splitlines()
ends=[x for x in lines if x.startswith('FSI20_CASE_END=')]
if len(ends)!=3: raise SystemExit(f'expected 3 case ends, got {len(ends)}')
for line in ends:
    m=re.match(r'FSI20_CASE_END=(\d+):STATUS=(\d+):COMPLETED=([TF]):ATTEMPTS=(\d+):RETRIES=(\d+):SOLVER_REJECTIONS=(\d+):TEMPORAL_REJECTIONS=(\d+):MASS_REJECTIONS=(\d+):ACCEPTED_SUBSTEPS=(\d+)',line)
    if not m: raise SystemExit('bad case end '+line)
    case,status,completed,attempts,retries,solver,temporal,mass,accepted=m.groups()
    print(f'FSI20_REJECTION_CASE={case}:STATUS={status}:COMPLETED={completed}:ATTEMPTS={attempts}:RETRIES={retries}:SOLVER_REJECTIONS={solver}:TEMPORAL_REJECTIONS={temporal}:MASS_REJECTIONS={mass}:ACCEPTED_SUBSTEPS={accepted}')
    if case=='2':
        assert completed=='F'
        assert int(solver)==0
        assert int(mass)==0
        assert int(temporal)==int(attempts)
        assert int(accepted)==0
print('FSI20_FGC02_BASELINE_REJECTION_IS_TEMPORAL_ONLY=PASS')
PY

echo 'FSI20_REJECTION_CLASSIFICATION PASS'
