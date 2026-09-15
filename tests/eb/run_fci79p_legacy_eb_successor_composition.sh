#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
fail() { echo "FCI79P_LEGACY_EB_FAIL $*" >&2; exit 179; }

POSTIMAGE=b7c2e510c68e5799a138e881793d27037c482b8a
I25_BACKEND=960ea116cad81e8c0db8a579982f4999b3d085ed
I25_CARRIER=299717757082ff06e98bd3aaec2c0b8b3013ea21
I25_MODULE=fc88731c12c8af5136aad13bda2a7da3d768dc4c
OLD_BACKEND=3506b453ba6a00111d182f29db8cbfb288001854

# Only the serialized backend authority moved on the inherited I23/I24 dependency
# surface. The I25 successor adds a transaction-owned top-boundary carrier.
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_reference_backend.f90)" == "$I25_BACKEND" ]] || fail 'unexpected successor backend'
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_top_sensible_boundary_carrier.f90)" == "$I25_CARRIER" ]] || fail 'unexpected successor top carrier'
[[ "$(git rev-parse HEAD:src/runtime/mod_eb_i25_multisubstep_sensible_boundary_runtime.f90)" == "$I25_MODULE" ]] || fail 'unexpected I25 runtime'
[[ "$(git rev-parse "$POSTIMAGE:src/runtime/mod_fmr_serialized_reference_backend.f90")" == "$I25_BACKEND" ]] || fail 'postimage backend authority mismatch'
[[ "$I25_BACKEND" != "$OLD_BACKEND" ]] || fail 'successor composition did not exercise backend evolution'

declare -A PRESERVED=(
  [src/runtime/mod_eb_i23_sensible_boundary_runtime.f90]=35dda86ca51bd91040af0672a43e2961c8db64fd
  [tests/eb/test_eb_i23_sensible_boundary_runtime_materialization.f90]=e9fde2d51d2c8cb76ae2def4b7e4a3acaf356d4a
  [tests/eb/EB-I23_CONTRACT.md]=56bfd4f1350e569e6f651ca4ada13550af93f986
  [src/runtime/mod_eb_i24_top_liquid_sensible_inflow_runtime.f90]=5f27ff7a4fa67a3991c622d960a7133857dab1c2
  [src/process/mod_external_liquid_water_temperature.f90]=64b85363e764d2c6e2777f5f1258abb3ac9e5abf
  [tests/eb/test_eb_i24_top_liquid_sensible_inflow_runtime.f90]=acd53e6e38598264d172e17d2596bebfb024e7fe
  [tests/eb/EB-I24_CONTRACT.md]=b7a504860ed027e87dad04731af63c933f668984
  [src/runtime/mod_fmr_serialized_multiswap_runtime.f90]=1aa2454048d0e480becaee34f596f20f1a7bd66e
  [src/process/mod_liquid_water_sensible_enthalpy.f90]=2247370ee34fac73a0e2d0b9fa15e171467aded3
  [src/process/mod_whole_column_sensible_energy_accounting.f90]=c00efd8cdb4de947de16e1d32ae4c9f4d0590850
  [src/process/mod_restricted_soil_temperature.f90]=fa4e1d7b48d3515e6569c9080d497178c25c4e85
  [src/process/mod_soil_temperature_contract.f90]=baa13df3975de2c699b0ec910477bcfa9b47f15e
)
for path in "${!PRESERVED[@]}"; do
  [[ "$(git rev-parse "HEAD:$path")" == "${PRESERVED[$path]}" ]] || fail "preserved I23/I24 authority drift $path"
done
echo 'FCI79P_I23_I24_OWNED_AUTHORITIES_PRESERVED=PASS'

# The backend extension must retain checkpoint/restore and the pre-existing
# bottom-thermal transaction surface while adding the I25 top carrier.
BACKEND=src/runtime/mod_fmr_serialized_reference_backend.f90
grep -Fq 'type(fmr_bottom_thermal_carrier_t) :: bottom_thermal_carrier' "$BACKEND" || fail 'bottom carrier lost'
grep -Fq 'call self%bottom_thermal_carrier%copy_to(typed%bottom_thermal_carrier)' "$BACKEND" || fail 'bottom carrier checkpoint copy lost'
grep -Fq 'call self%bottom_thermal_carrier%restore_from(typed%bottom_thermal_carrier)' "$BACKEND" || fail 'bottom carrier rollback restore lost'
grep -Fq 'type(fmr_top_sensible_boundary_carrier_t) :: top_sensible_boundary_carrier' "$BACKEND" || fail 'I25 top carrier missing'
grep -Fq 'call self%top_sensible_boundary_carrier%copy_to(typed%top_sensible_boundary_carrier)' "$BACKEND" || fail 'I25 top checkpoint copy missing'
grep -Fq 'call self%top_sensible_boundary_carrier%restore_from(typed%top_sensible_boundary_carrier)' "$BACKEND" || fail 'I25 top rollback restore missing'
echo 'FCI79P_BACKEND_SUCCESSOR_STRUCTURAL_COMPOSITION=PASS'

TMP="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fci79p-legacy-eb-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$TMP"
trap 'rm -rf "$TMP"' EXIT

make_runtime_replay() {
  local owner_gate="$1" output="$2" kind="$3"
  if [[ "$kind" == i23 ]]; then
    {
      echo 'set -euo pipefail'
      echo 'ROOT="$(pwd)"'
      echo 'BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/fci79p-i23-${GITHUB_RUN_ID:-local}-$$"'
      echo 'mkdir -p "$BUILD"'
      echo 'MODULE="src/runtime/mod_eb_i23_sensible_boundary_runtime.f90"'
      echo 'TEST="tests/eb/test_eb_i23_sensible_boundary_runtime_materialization.f90"'
      echo 'fail() { echo "FCI79P_I23_RUNTIME_FAIL $*" >&2; exit 1; }'
      awk '/^COMMON=/{emit=1} emit && /^git diff "\$CANONICAL"/{exit} emit{print}' "$owner_gate"
    } > "$output"
  else
    {
      echo 'set -euo pipefail'
      awk '/^COMMON=/{emit=1} emit{print}' "$owner_gate"
    } > "$output"
  fi
  python3 - "$output" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text()
worker='  src/runtime/mod_a23bu_worker_execution_context.f90\n'
worker_deps=(
    '  src/solver/mod_soil_water_accepted_step_direction_contract.f90\n'
    '  src/transaction/mod_accepted_trajectory_directional_sensitivity.f90\n'
)
if s.count(worker)!=1:
    raise SystemExit('worker compile-order anchor mismatch')
s=s.replace(worker, worker_deps+worker)
backend='  src/runtime/mod_fmr_serialized_reference_backend.f90\n'
if s.count(backend)!=1:
    raise SystemExit('backend compile-order anchor mismatch')
s=s.replace(backend, '  src/runtime/mod_fmr_top_sensible_boundary_carrier.f90\n'+backend)
p.write_text(s)
PY
}

make_runtime_replay tests/eb/run_eb_i23_sensible_boundary_runtime_materialization_gate.sh "$TMP/i23.sh" i23
bash "$TMP/i23.sh" | tee "$TMP/i23.log"
grep -Fq 'EB_I23_ACCEPTED_SINGLE_SUBSTEP_PARTIAL_MATERIALIZATION=PASS' "$TMP/i23.log"
grep -Fq 'EB_I23_BOTTOM_ADVECTIVE_UNAVAILABLE_FAIL_CLOSED=PASS' "$TMP/i23.log"
grep -Fq 'EB_I23_REJECTED_TRIAL_NO_PUBLICATION=PASS' "$TMP/i23.log"
grep -Fq 'EB_I23_O0_O2_SEMANTIC_IDENTITY=PASS' "$TMP/i23.log"
echo 'FCI79P_I23_RUNTIME_ON_I25_BACKEND=PASS'

make_runtime_replay tests/eb/run_eb_i24_top_liquid_sensible_inflow_gate.sh "$TMP/i24.sh" i24
bash "$TMP/i24.sh" | tee "$TMP/i24.log"
grep -Fq 'EB_I24_ACCEPTED_INFLOW_COMPLETE_I22_BOUNDARY=PASS' "$TMP/i24.log"
grep -Fq 'EB_I24_MISSING_TOP_DONOR_FAIL_CLOSED=PASS' "$TMP/i24.log"
grep -Fq 'EB_I24_TOP_OUTFLOW_DONOR_DIRECTION_FAIL_CLOSED=PASS' "$TMP/i24.log"
grep -Fq 'EB_I24_REJECTED_TRIAL_NO_PUBLICATION=PASS' "$TMP/i24.log"
grep -Fq 'EB_I24_O0_O2_IDENTITY=PASS' "$TMP/i24.log"
echo 'FCI79P_I24_RUNTIME_ON_I25_BACKEND=PASS'

echo 'FCI79P_LEGACY_EB_SUCCESSOR_COMPOSITION=PASS'
