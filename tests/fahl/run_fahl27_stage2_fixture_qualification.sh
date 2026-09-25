#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fahl27-fixture-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -fopenmp -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/solver/mod_soil_water_accepted_step_direction_contract.f90
  src/transaction/mod_accepted_trajectory_directional_sensitivity.f90
  src/transaction/mod_accepted_trajectory_directional_publication.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_transaction_reference.f90
  src/transaction/mod_fkt_temporal_indicator_history.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/runtime/mod_fmr_runtime_core.f90
  src/runtime/mod_fmr_bottom_thermal_carrier.f90
  src/runtime/mod_fmr_top_sensible_boundary_carrier.f90
  src/runtime/mod_fmr_checkpoint_orchestrator.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_process_hydraulic_view.f90
  src/solver/mod_b110_smooth_freatic_projection.f90
  src/process/mod_drainage_process.f90
  src/process/mod_drainage_tabulated_response.f90
  src/process/mod_drainage_hooghoudt_equivalent_depth.f90
  src/process/mod_drainage_hooghoudt_ipos1_response.f90
  src/process/mod_drainage_hooghoudt_ipos23_response.f90
  src/process/mod_drainage_ernst_ipos45_preparation.f90
  src/process/mod_drainage_ernst_ipos45_response.f90
  src/process/mod_drainage_empirical_interflow_response.f90
  src/process/mod_drainage_multilevel_aggregation.f90
  src/process/mod_drainage_extended_exchange.f90
  src/runtime/mod_fmr_drainage_response_binding.f90
  src/runtime/mod_fmr_drainage_qbot_directional_binding.f90
  src/process/mod_soil_temperature_contract.f90
  src/process/mod_restricted_soil_temperature.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_adaptive_hydraulic_builder.f90
  src/solver/mod_b110_adaptive_hydraulic_cache.f90
  src/solver/mod_b110_adaptive_hydraulic_provider.f90
  src/solver/mod_b110_default_mvg_directional_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/process/mod_restricted_surface_evaporation.f90
  src/solver/mod_b110_dynamic_top_boundary_provider.f90
  src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90
  src/adapter/mod_b110_dynamic_top_boundary_directional_adapter.f90
  src/solver/mod_b110_root_sink_provider.f90
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
  src/runtime/mod_fmr_accepted_commit_receipt.f90
  src/runtime/mod_fmr_owned_commit_receipt.f90
  src/runtime/mod_fmr_bottom_external_thermal_binding.f90
  src/runtime/mod_fmr_bottom_external_thermal_provider.f90
  src/process/mod_liquid_water_sensible_enthalpy.f90
  src/runtime/mod_fmr_bottom_sensible_energy.f90
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
)


OUT="$BUILD/o2"
mkdir -p "$OUT"
objects=()
for source in "${MODULE_SRC[@]}"; do
  obj="$OUT/$(basename "${source%.*}").o"
  gfortran "${COMMON[@]}" -O2 -J "$OUT" -I "$OUT" -c "$source" -o "$obj"
  objects+=("$obj")
done
gfortran "${COMMON[@]}" -O2 -J "$OUT" -I "$OUT" \
  -c tests/fahl/test_fahl27_stage2_fixture_qualification.f90 -o "$OUT/test.o"
gfortran -fopenmp -O2 "${objects[@]}" "$OUT/test.o" -o "$OUT/test"

RESULT=/tmp/fahl27_stage2_fixture_qualification.txt
: > "$RESULT"
"$OUT/test" H74_D001  -74.0  0.01 | tee -a "$RESULT"
"$OUT/test" H725_D001 -72.5 0.01 | tee -a "$RESULT"
"$OUT/test" H70_D001  -70.0  0.01 | tee -a "$RESULT"
"$OUT/test" H74_D005  -74.0  0.05 | tee -a "$RESULT"
"$OUT/test" H725_D005 -72.5 0.05 | tee -a "$RESULT"

python3 - "$RESULT" <<'PY'
import json,re,sys
path=sys.argv[1]
order=["H74_D001","H725_D001","H70_D001","H74_D005","H725_D005"]
pat=re.compile(
 r"FAHL27_FIXTURE\s+(\S+)\s+HBOT=\s*([0-9.Ee+\-]+)\s+DT=\s*([0-9.Ee+\-]+)\s+"
 r"COMPLETED=([TF])\s+COMMITTED=([TF])\s+KERNEL=([0-9]+)\s+SUBSTEPS=([0-9]+)\s+"
 r"MASS=\s*([0-9.Ee+\-]+)\s+RETRIES=([0-9]+)\s+REJECTED=([0-9]+)"
)
rows={}
for line in open(path):
    m=pat.search(line)
    if m:
        rows[m.group(1)]={
          "id":m.group(1),"bottom_head_cm":float(m.group(2)),"duration_day":float(m.group(3)),
          "completed":m.group(4)=="T","committed":m.group(5)=="T","kernel_status":int(m.group(6)),
          "accepted_substeps":int(m.group(7)),"mass_residual_abs_cm":float(m.group(8)),
          "retries":int(m.group(9)),"rejected":int(m.group(10))
        }
missing=[x for x in order if x not in rows]
if missing:
    raise SystemExit("missing fixture rows: "+",".join(missing))
selected=None
for case_id in order:
    r=rows[case_id]
    if r["completed"] and r["committed"] and r["accepted_substeps"]>=1 and r["mass_residual_abs_cm"]<=1e-12:
        selected=r
        break
out={"work_unit":"F-AHL27_STAGE2_FIXTURE","candidates":[rows[x] for x in order],"selected":selected,
     "selection_rule":"first valid candidate in preregistered order"}
open("/tmp/fahl27_stage2_fixture_selected.json","w").write(json.dumps(out,indent=2)+"\n")
print(json.dumps(out,indent=2))
if selected is None:
    raise SystemExit("FAHL27_STAGE2_FIXTURE=BLOCKED_NO_VALID_CASE")
print("FAHL27_STAGE2_SELECTED_FIXTURE",selected["id"])
print("FAHL27_STAGE2_FIXTURE_QUALIFICATION=PASS")
PY
