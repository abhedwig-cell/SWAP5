#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-ftab02e-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

python3 - <<'PY'
from pathlib import Path
for p in [
    "integration/f-tab/F-TAB02_D_QUALIFICATION.json",
    "tests/fsi/test_ftab02e_provider_richards_performance.f90",
    "tests/fsi/test_ftab02e_serialized_runtime_performance.f90",
]:
    assert Path(p).exists(), p
for p in [
    "tests/fsi/test_ftab02e_provider_richards_performance.f90",
    "tests/fsi/test_ftab02e_serialized_runtime_performance.f90",
]:
    s=Path(p).read_text()
    assert "DELTA_PCT" in s
    assert "F_TAB02_E_GATE_FAIL" in s
print("F_TAB02_E_D_PREREQUISITE_RECORD_PRESENT=PASS")
print("F_TAB02_E_TIMING_IS_CHARACTERIZATION_NOT_SPEED_GATE=PASS")
PY

COMMON=(-std=f2018 -ffree-line-length-none -O3 -fopenmp -fbacktrace)
MODULES=(
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
  src/runtime/mod_fmr_accepted_commit_receipt.f90
  src/runtime/mod_fmr_owned_commit_receipt.f90
  src/runtime/mod_fmr_runtime_core.f90
  src/runtime/mod_fmr_bottom_thermal_carrier.f90
  src/process/mod_liquid_water_sensible_enthalpy.f90
  src/runtime/mod_fmr_bottom_external_thermal_binding.f90
  src/runtime/mod_fmr_bottom_external_thermal_provider.f90
  src/runtime/mod_fmr_bottom_sensible_energy.f90
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
  src/solver/mod_b110_generated_mvg_tspack.f90
  src/solver/mod_b110_generated_mvg_table_state.f90
  src/solver/mod_b110_generated_mvg_provider.f90
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
)

objs=()
for source in "${MODULES[@]}"; do
  obj="$BUILD/$(basename "${source%.*}").o"
  gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c "$source" -o "$obj"
  objs+=("$obj")
done

gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD"   -c tests/fsi/test_ftab02e_provider_richards_performance.f90 -o "$BUILD/provider-richards.o"
gfortran -O3 -fopenmp "${objs[@]}" "$BUILD/provider-richards.o" -o "$BUILD/provider-richards"

gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD"   -c tests/fsi/test_ftab02e_serialized_runtime_performance.f90 -o "$BUILD/serialized.o"
gfortran -O3 -fopenmp "${objs[@]}" "$BUILD/serialized.o" -o "$BUILD/serialized"

export OMP_NUM_THREADS=1
export OMP_DYNAMIC=false
"$BUILD/provider-richards" tests/fsi/fixtures/ftab02_staring1994_mvg.dat > "$BUILD/provider-richards.txt"
"$BUILD/serialized" > "$BUILD/serialized.txt"
cat "$BUILD/provider-richards.txt"
cat "$BUILD/serialized.txt"

grep -Fq 'F-TAB02-E PROVIDER AND REFERENCE-RICHARDS PERFORMANCE CHARACTERIZATION PASS' "$BUILD/provider-richards.txt"
grep -Fq 'F_TAB02_E_PROVIDER_TIMING_CAPTURED=PASS' "$BUILD/provider-richards.txt"
test "$(grep -c '^F_TAB02_E_RICHARDS_TIMING_CAPTURED=PASS' "$BUILD/provider-richards.txt")" -eq 3
grep -Fq 'F-TAB02-E SERIALIZED RUNTIME PERFORMANCE CHARACTERIZATION PASS' "$BUILD/serialized.txt"
test "$(grep -c '^F_TAB02_E_SERIALIZED_TIMING_CAPTURED=PASS' "$BUILD/serialized.txt")" -eq 3

python3 - "$BUILD/provider-richards.txt" "$BUILD/serialized.txt" "$BUILD/F-TAB02-E_SUMMARY.tsv" <<'PY'
from pathlib import Path
import math,sys
provider=Path(sys.argv[1]).read_text().splitlines()
serialized=Path(sys.argv[2]).read_text().splitlines()
lines=["source\tmetric\tvalue"]
for source,rows in [("provider-richards",provider),("serialized",serialized)]:
    for line in rows:
        if not line.startswith("F_TAB02_E_") or "=" not in line:
            continue
        k,v=line.split("=",1)
        try:
            x=float(v)
        except ValueError:
            lines.append(f"{source}\t{k}\t{v}")
            continue
        if not math.isfinite(x):
            raise SystemExit(f"non-finite E metric: {k}={v}")
        lines.append(f"{source}\t{k}\t{v}")
Path(sys.argv[3]).write_text("\n".join(lines)+"\n")
print(Path(sys.argv[3]).read_text(),end="")
PY

cp "$BUILD/provider-richards.txt" F-TAB02-E_PROVIDER_RICHARDS.log
cp "$BUILD/serialized.txt" F-TAB02-E_SERIALIZED.log
cp "$BUILD/F-TAB02-E_SUMMARY.tsv" F-TAB02-E_SUMMARY.tsv

git diff --check --   tests/fsi/test_ftab02e_provider_richards_performance.f90   tests/fsi/test_ftab02e_serialized_runtime_performance.f90   tests/fsi/run_ftab02e_generated_provider_performance.sh

echo "F_TAB02_E_CORRECTNESS_BEFORE_TIMING=PASS"
echo "F_TAB02_E_PAIRED_TIMING_CAPTURE=PASS"
echo "F-TAB02-E OWNER QUALIFICATION PASS"
