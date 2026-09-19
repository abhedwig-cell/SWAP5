#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-hydro-memory-dyn02-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/modflow-bin" "$BUILD/downloads" "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "HYDRO_MEMORY_DYN02_FAIL $*" >&2; exit 72; }

BASE=52b4608fdf548b89b154f19caeb97c1a5effe3de
git merge-base --is-ancestor "$BASE" HEAD || fail "branch is not descended from canonical prescribed-root tangent authority"
git diff --quiet "$BASE"..HEAD -- src || fail "ACC02-F1 changed production source"
git diff --quiet "$BASE"..HEAD -- reference || fail "ACC02-F1 changed reference source"

[[ "$(git rev-parse HEAD:docs/publication/HYDRO_MEMORY_STAGE0_ACCURACY_GOVERNANCE_V1.md)" == "09bf6a63d50986794332c672aa89801249d6ef9f" ]] || fail "ACC01 governance source drift"
[[ "$(git rev-parse HEAD:docs/publication/HYDRO_MEMORY_STAGE0_INTERFACE_ACCURACY_GOVERNANCE_V1.md)" == "62841616e83ae9209cd33566929866a7e54d87d6" ]] || fail "ACC02 governance source drift"
grep -Fq '"decision": "ACC01_F1_PASS_GOVERNED_TEMPORAL_ROUTE"' integration/research/HYDRO_MEMORY_ACC01_F1_RESULT.json || fail "ACC01 F1 authority missing"
grep -Fq '"decision": "ACC02_GOVERNANCE_QUALIFIED"' integration/research/HYDRO_MEMORY_ACC02_RESULT.json || fail "ACC02 authority missing"
grep -Fq '"decision": "ACC02_F2_PASS_FOUR_CONSECUTIVE_LIVE_ROOT_ACTIVE_WINDOWS"' integration/research/HYDRO_MEMORY_ACC02_F2_RESULT.json || fail "ACC02-F2 authority missing"
grep -Fq '"decision": "DYN01_PASS_FORCING_AND_ACCEPTED_STATE_DEPENDENT_FEDDES_COMPOSITION"' integration/research/HYDRO_MEMORY_DYN01_RESULT.json || fail "DYN01 authority missing"
grep -Fq '"decision": "QUALIFIED_RESTRICTED_PRESCRIBED_ROOT_TANGENT_COVERAGE"' integration/audits/PPA_ROOT_HYD02_RESULT.json || fail "PPA-ROOT-HYD02 canonical authority missing"
echo 'HYDRO_MEMORY_DYN02_AUTHORITY_LOCK=PASS'

BRIDGE=tests/research/support/mod_hydro_memory_dyn02_bridge.f90
grep -Fq 'ROOT_TOTAL=2.0e-2_real64' "$BRIDGE" || fail "root total drift"
grep -Fq 'H_APP_CM=4.0e-1_real64' "$BRIDGE" || fail "H_app drift"
grep -Fq 'A_TEMPORAL=2.5e-1_real64' "$BRIDGE" || fail "temporal allocation drift"
grep -Fq 'A_INTERFACE=2.5e-1_real64' "$BRIDGE" || fail "interface allocation drift"
grep -Fq 'p%root_extraction_active=.true.' "$BRIDGE" || fail "root extraction inactive"
grep -Fq 'datum,.false.,.true.,.false.,.false.,endpoint,status' "$BRIDGE" || fail "root-active tangent endpoint binding missing"
echo 'HYDRO_MEMORY_DYN02_FROZEN_FIXTURE=PASS'

python3 - <<PY
from pathlib import Path
from flopy.utils.get_modflow import run_main
bindir=Path("$BUILD/modflow-bin")
downloads=Path("$BUILD/downloads")
run_main(bindir,owner="MODFLOW-ORG",repo="modflow6",release_id="6.8.0",
         subset={"mf6","libmf6.so"},downloads_dir=downloads,force=True,quiet=False)
PY
ARCHIVE="$BUILD/downloads/modflow6-6.8.0-linux.zip"
echo "33edf988b672a9f282d6773304c079d0f180541f6fe0c6555265d9c71841256e  $ARCHIVE" | sha256sum -c - || fail "MODFLOW asset hash"
test -f "$BUILD/modflow-bin/libmf6.so" || fail "missing libmf6.so"

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fPIC -fopenmp)
MODULE_SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/solver/mod_soil_water_accepted_step_direction_contract.f90
  src/transaction/mod_accepted_trajectory_directional_sensitivity.f90
  src/transaction/mod_accepted_trajectory_directional_publication.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_transaction_reference.f90
  src/transaction/mod_fkt_temporal_indicator_history.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_coupling_application_accuracy_contract.f90
  src/runtime/mod_groundwater_coupling_policy.f90
  src/runtime/mod_groundwater_accuracy_binding.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/runtime/mod_fmr_runtime_core.f90
  src/runtime/mod_fmr_bottom_thermal_carrier.f90
  src/runtime/mod_fmr_top_sensible_boundary_carrier.f90
  src/runtime/mod_fmr_checkpoint_orchestrator.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_process_hydraulic_view.f90
  src/process/mod_drainage_process.f90
  src/process/mod_drainage_tabulated_response.f90
  src/process/mod_drainage_hooghoudt_equivalent_depth.f90
  src/process/mod_drainage_hooghoudt_ipos1_response.f90
  src/process/mod_drainage_hooghoudt_ipos23_response.f90
  src/process/mod_drainage_ernst_ipos45_preparation.f90
  src/process/mod_drainage_ernst_ipos45_response.f90
  src/process/mod_drainage_empirical_interflow_response.f90
  src/process/mod_drainage_multilevel_aggregation.f90
  src/runtime/mod_fmr_drainage_response_binding.f90
  src/solver/mod_b110_smooth_freatic_projection.f90
  src/runtime/mod_fmr_drainage_qbot_directional_binding.f90
  src/process/mod_soil_temperature_contract.f90
  src/process/mod_restricted_soil_temperature.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_default_mvg_directional_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/process/mod_restricted_surface_evaporation.f90
  src/solver/mod_b110_dynamic_top_boundary_provider.f90
  src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90
  src/adapter/mod_b110_dynamic_top_boundary_directional_adapter.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/adapter/mod_reference_richards_accepted_step_directional_service.f90
  src/process/mod_snow_process.f90
  src/process/mod_restricted_fixed_weir_surface_water.f90
  src/runtime/mod_fmr_soil_water_application_host.f90
  src/runtime/mod_rossfast_d3r_execution_policy.f90
  src/runtime/mod_rossfast_d3r_model_binding.f90
  src/solver/mod_rossfast_d3r_table_kernel.f90
  src/solver/mod_rossfast_d3r_table_provider.f90
  src/solver/mod_rossfast_d3r_soil_water_solver.f90
  src/runtime/mod_fmr_rossfast_solver_selection_binding.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_process_hydraulic_view_binding.f90
  src/process/mod_root_water_uptake_process.f90
  src/runtime/mod_fmr_root_uptake_process_binding.f90
  src/crop/mod_crop_root_uptake_input_contract.f90
  src/runtime/mod_fmr_crop_root_uptake_input_adapter.f90
  src/process/mod_reference_et_demand_process.f90
  src/runtime/mod_fmr_reference_et_demand_binding.f90
  src/runtime/mod_fmr_reference_et_ptra_root_input_binding.f90
  src/runtime/mod_fmr_reference_et_root_uptake_composition.f90
  src/adapter/mod_ppa_wu03_common_forcing_adapter.f90
  src/runtime/mod_groundwater_coupling_contract.f90
  src/runtime/mod_groundwater_swap_forcing_adapter.f90
  src/runtime/mod_groundwater_swap_transaction_participant.f90
  src/runtime/mod_fmr_groundwater_head_forcing_adapter.f90
  src/runtime/mod_fmr_groundwater_swap_participant.f90
  src/runtime/mod_groundwater_interface_mass_ledger.f90
  src/runtime/mod_groundwater_tile_aggregation.f90
  src/runtime/mod_groundwater_multiswap_types.f90
  src/runtime/mod_modflow6_swap_predictor_response.f90
  src/runtime/mod_modflow6_swap_prescribed_qbot_bottom_face.f90
  src/runtime/mod_modflow6_swap_predictor_tangent_adapter.f90
  src/runtime/mod_modflow6_swap_predictor_origin.f90
  src/runtime/mod_modflow6_swap_predictor_candidate_assembler.f90
  src/runtime/mod_modflow6_multiswap_cell_response.f90
  src/runtime/mod_modflow6_linear_response_backend.f90
  src/runtime/mod_modflow6_api_binding.f90
  src/adapter/mod_modflow6_fgc34_c_bridge.f90
  tests/research/support/mod_hydro_memory_dyn02_bridge.f90
)

build_bridge(){
  local opt="$1" out="$BUILD/o$1"
  local objects=()
  for source in "${MODULE_SRC[@]}"; do
    obj="$out/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$out" -I "$out" -c "$source" -o "$obj" || fail "compile O$opt $source"
    objects+=("$obj")
  done
  gfortran -shared -fopenmp -O"$opt" "${objects[@]}" -o "$out/libhydro_memory_dyn02.so" || fail "link O$opt bridge"
  nm -D "$out/libhydro_memory_dyn02.so" | grep -q 'fgc44_swap_initialize_c' || fail "missing SWAP ABI O$opt"
  nm -D "$out/libhydro_memory_dyn02.so" | grep -q 'hydro_memory_acc02_head_policy_c' || fail "missing governed policy ABI O$opt"
  nm -D "$out/libhydro_memory_dyn02.so" | grep -q 'hydro_memory_dyn02_begin_next_window_c' || fail "missing next-window ABI O$opt"
  nm -D "$out/libhydro_memory_dyn02.so" | grep -q 'hydro_memory_dyn02_window_diagnostics_c' || fail "missing DYN02 forcing diagnostics ABI O$opt"
}
build_bridge 0
build_bridge 2

for opt in 0 2; do
  LIBMF6="$BUILD/modflow-bin/libmf6.so"   FGC44_SWAP_LIB="$BUILD/o$opt/libhydro_memory_dyn02.so"   python3 tests/research/test_hydro_memory_dyn02_live_recomposition.py > "$BUILD/o$opt/live.txt" 2>&1 || {
    cat "$BUILD/o$opt/live.txt" >&2
    fail "live runtime O$opt"
  }
  for marker in \
    HYDRO_MEMORY_DYN02_PERSISTENT_SWAPP_STATE=PASS \
    HYDRO_MEMORY_DYN02_DYNAMIC_PREDICTOR_ORIGIN=PASS \
    HYDRO_MEMORY_DYN02_REVISION_TIME_LEDGER_SEQUENCE=PASS \
    HYDRO_MEMORY_DYN02_GOVERNED_ACCURACY=PASS \
    HYDRO_MEMORY_DYN02_LIVE_MODFLOW680=PASS \
    HYDRO_MEMORY_DYN02_EXACT_ONCE_PUBLICATION=PASS \
    HYDRO_MEMORY_DYN02_WINDOW_FORCING_IMMUTABLE=PASS \
    HYDRO_MEMORY_DYN02_ACCEPTED_STATE_RECOMPOSITION=PASS \
    HYDRO_MEMORY_DYN02_DROUGHT_RECOVERY_FORCING_SEQUENCE=PASS \
    HYDRO_MEMORY_DYN02_GATE=PASS; do
    grep -Fxq "$marker" "$BUILD/o$opt/live.txt" || { cat "$BUILD/o$opt/live.txt" >&2; fail "missing O$opt marker $marker"; }
  done
done

python3 - "$BUILD/o0/live.txt" "$BUILD/o2/live.txt" <<'PY'
import sys,math
paths=sys.argv[1:]
num_keys=[
"HYDRO_MEMORY_DYN02_H_APP_CM",
"HYDRO_MEMORY_DYN02_TEMPORAL_BUDGET_CM",
"HYDRO_MEMORY_DYN02_INTERFACE_TOLERANCE_M",
"HYDRO_MEMORY_DYN02_INITIAL_ACTUAL_UPTAKE_CM_PER_DAY",
"HYDRO_MEMORY_DYN02_MAX_TEMPORAL_INDICATOR",
"HYDRO_MEMORY_DYN02_MAX_HEAD_RESIDUAL_M",
"HYDRO_MEMORY_DYN02_MAX_FLUX_RESIDUAL",
"HYDRO_MEMORY_DYN02_FINAL_REVISION",
"HYDRO_MEMORY_DYN02_FINAL_TIME_DAY",
"HYDRO_MEMORY_DYN02_FINAL_LEDGER_EXCHANGE_M",
]
seq_keys=[
"HYDRO_MEMORY_DYN02_PTRA_SEQUENCE",
"HYDRO_MEMORY_DYN02_ACTUAL_UPTAKE_SEQUENCE",
"HYDRO_MEMORY_DYN02_TOP_FLUX_SEQUENCE",
]
def parse(path):
    nums={}; seqs={}
    for line in open(path,encoding="utf-8",errors="replace"):
        line=line.strip()
        for key in num_keys:
            prefix=key+"="
            if line.startswith(prefix): nums[key]=float(line[len(prefix):])
        for key in seq_keys:
            prefix=key+"="
            if line.startswith(prefix): seqs[key]=[float(x) for x in line[len(prefix):].split(",")]
    missing=[k for k in num_keys if k not in nums]+[k for k in seq_keys if k not in seqs]
    if missing: raise SystemExit("missing optimization metrics "+repr(missing))
    return nums,seqs
(a,sa),(b,sb)=map(parse,paths)
for k in num_keys:
    if k=="HYDRO_MEMORY_DYN02_FINAL_REVISION":
        if a[k]!=b[k]: raise SystemExit(f"O0/O2 revision drift {a[k]} {b[k]}")
    else:
        scale=max(1.0,abs(a[k]),abs(b[k]))
        if abs(a[k]-b[k])>1e-12*scale:
            raise SystemExit(f"O0/O2 numeric drift {k}: {a[k]} {b[k]}")
for k in seq_keys:
    if len(sa[k])!=len(sb[k]): raise SystemExit(f"O0/O2 sequence length drift {k}")
    for i,(x,y) in enumerate(zip(sa[k],sb[k]),1):
        if abs(x-y)>1e-12*max(1.0,abs(x),abs(y)):
            raise SystemExit(f"O0/O2 sequence drift {k}[{i}]: {x} {y}")
print("HYDRO_MEMORY_DYN02_O0_O2_BEHAVIOR=PASS")
PYcat "$BUILD/o2/live.txt"
echo 'HYDRO_MEMORY_DYN02_MODFLOW_ASSET_HASH=PASS'
echo 'HYDRO_MEMORY_DYN02_QUALIFICATION=PASS'
