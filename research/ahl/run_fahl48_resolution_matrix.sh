#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fahl48-resolution-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
COMMON=(-std=f2008 -ffree-line-length-none -O2 -fcheck=all -fbacktrace)
SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/transaction/mod_transaction_reference.f90
  src/solver/mod_soil_water_accepted_step_direction_contract.f90
  src/transaction/mod_accepted_trajectory_directional_sensitivity.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_accepted_trajectory_directional_publication.f90
  src/transaction/mod_fkt_temporal_indicator_history.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/runtime/mod_fmr_runtime_core.f90
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
  src/process/mod_drainage_extended_exchange.f90
  src/runtime/mod_fmr_drainage_response_binding.f90
  src/process/mod_soil_temperature_contract.f90
  src/process/mod_restricted_soil_temperature.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_b110_default_mvg_provider.f90
  research/ahl/mod_ahl47_direct_retention_provider.f90
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
  src/runtime/mod_rossfast_d3r_execution_policy.f90
  src/runtime/mod_rossfast_d3r_model_binding.f90
)
objects=()
for source in "${SRC[@]}"; do
  obj="$BUILD/$(basename "${source%.*}").o"
  gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c "$source" -o "$obj"
  objects+=("$obj")
done
gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c research/ahl/test_fahl48_resolution_matrix.f90 -o "$BUILD/test.o"
gfortran -O2 "${objects[@]}" "$BUILD/test.o" -o "$BUILD/test"

RESULT="$BUILD/result.txt"
: > "$RESULT"
for res in 64 128 256; do
  for material in B01 B12 O05 O14; do
    for spec in "wet -10 -7.5" "mid -75 -50" "dry -500 -400"; do
      read -r regime h0 hbot <<< "$spec"
      "$BUILD/test" "$res" "$material" "$regime" "$h0" "$hbot" | tee -a "$RESULT"
    done
  done
done
test "$(grep -c 'FAHL48_MATRIX .* PASS' "$RESULT")" -eq 36
python3 - "$RESULT" <<'PY'
import re,sys,collections
rows=collections.defaultdict(list)
for line in open(sys.argv[1]):
    m=re.search(r'FAHL48_MATRIX_METRIC\|CASE=([^|]+)\|RES=(\d+)\|MAX_DH_CM=([^|]+)\|MAX_DTHETA=([^|]+).*\|MASS=([^|]+)\|ITER_DELTA=(\d+)\|BACKTRACK_DELTA=(\d+)',line)
    if m:
        rows[int(m.group(2))].append({
            "case":m.group(1),"dh":float(m.group(3)),"dt":float(m.group(4)),
            "mass":float(m.group(5)),"di":int(m.group(6)),"db":int(m.group(7))
        })
for res in (64,128,256):
    rr=rows[res]
    if len(rr)!=12: raise SystemExit(f'res {res}: expected 12 metrics got {len(rr)}')
    print(f'FAHL48_SUMMARY|RES={res}|CASES={len(rr)}|MAX_DH={max(x["dh"] for x in rr):.17e}|MAX_DTHETA={max(x["dt"] for x in rr):.17e}|MAX_MASS={max(x["mass"] for x in rr):.17e}|PATH_DRIFT={sum(x["di"] or x["db"] for x in rr)}')
print('FAHL48_RESOLUTION_MATRIX=PASS')
PY
