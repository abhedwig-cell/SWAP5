#!/usr/bin/env bash
set -euo pipefail

CANONICAL=687ee32ca98a42368a2b6380ea78d33eb254dad9
ORIGINAL_BACKEND=3506b453ba6a00111d182f29db8cbfb288001854
I25_BACKEND=960ea116cad81e8c0db8a579982f4999b3d085ed
TOP_CARRIER=299717757082ff06e98bd3aaec2c0b8b3013ea21
I25_RUNTIME=cf3a231fdf439fe8de1cbaadb9759d1a8fcf7dea
I25_TEST=118af81cab0fd74920b48729a2658aa81ae0b1f3

git fetch origin integration/f-ci-canonical
test "$(git rev-parse origin/integration/f-ci-canonical)" = "$CANONICAL"
git merge-base --is-ancestor "$CANONICAL" HEAD

test "$(git rev-parse "$CANONICAL:src/runtime/mod_fmr_serialized_reference_backend.f90")" = "$ORIGINAL_BACKEND"
test "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_reference_backend.f90)" = "$I25_BACKEND"
test "$(git rev-parse HEAD:src/runtime/mod_fmr_top_sensible_boundary_carrier.f90)" = "$TOP_CARRIER"
test "$(git rev-parse HEAD:src/runtime/mod_eb_i25_multisubstep_sensible_boundary_runtime.f90)" = "$I25_RUNTIME"
test "$(git rev-parse HEAD:tests/eb/test_eb_i25_multisubstep_sensible_boundary_runtime.f90)" = "$I25_TEST"

declare -A LOCKS=(
  [src/runtime/mod_fmr_bottom_thermal_carrier.f90]=c371be3e22eaa6da70ca8cbb060bc42d1e0e0bfb
  [src/runtime/mod_fmr_serialized_multiswap_runtime.f90]=1aa2454048d0e480becaee34f596f20f1a7bd66e
  [src/runtime/mod_eb_i23_sensible_boundary_runtime.f90]=35dda86ca51bd91040af0672a43e2961c8db64fd
  [src/runtime/mod_eb_i24_top_liquid_sensible_inflow_runtime.f90]=5f27ff7a4fa67a3991c622d960a7133857dab1c2
  [src/process/mod_liquid_water_sensible_enthalpy.f90]=2247370ee34fac73a0e2d0b9fa15e171467aded3
  [src/process/mod_external_liquid_water_temperature.f90]=64b85363e764d2c6e2777f5f1258abb3ac9e5abf
  [src/process/mod_whole_column_sensible_energy_accounting.f90]=c00efd8cdb4de947de16e1d32ae4c9f4d0590850
  [src/process/mod_restricted_soil_temperature.f90]=fa4e1d7b48d3515e6569c9080d497178c25c4e85
  [src/process/mod_soil_temperature_contract.f90]=baa13df3975de2c699b0ec910477bcfa9b47f15e
)
for path in "${!LOCKS[@]}"; do
  test "$(git rev-parse "$CANONICAL:$path")" = "${LOCKS[$path]}"
  test "$(git rev-parse "HEAD:$path")" = "${LOCKS[$path]}"
done
echo 'EB_I25_LIVE_CANONICAL_LOCK=PASS'
echo 'EB_I25_INHERITED_AUTHORITY_BLOBS=PASS'

git diff --name-only "$CANONICAL" HEAD | sort > changed.txt
cat > allowed.txt <<'EOF'
.github/workflows/eb-i25-multisubstep-sensible-boundary.yml
src/runtime/mod_eb_i25_multisubstep_sensible_boundary_runtime.f90
src/runtime/mod_fmr_serialized_reference_backend.f90
src/runtime/mod_fmr_top_sensible_boundary_carrier.f90
tests/eb/EB-I25_CHECKPOINT.json
tests/eb/EB-I25_CONTRACT.md
tests/eb/run_eb_i25_multisubstep_sensible_boundary_gate.sh
tests/eb/test_eb_i25_multisubstep_sensible_boundary_runtime.f90
EOF
sort -o allowed.txt allowed.txt
diff -u allowed.txt changed.txt

test ! -e tools/eb_i25_patch_backend.py
test ! -e .github/workflows/eb-i25-backend-bootstrap.yml
grep -Fq 'type(fmr_top_sensible_boundary_carrier_t) :: top_sensible_boundary_carrier' src/runtime/mod_fmr_serialized_reference_backend.f90
grep -Fq 'call self%top_sensible_boundary_carrier%copy_to(typed%top_sensible_boundary_carrier)' src/runtime/mod_fmr_serialized_reference_backend.f90
grep -Fq 'call self%top_sensible_boundary_carrier%restore_from(typed%top_sensible_boundary_carrier)' src/runtime/mod_fmr_serialized_reference_backend.f90
grep -Fq 'record_top_sensible_boundary_sample' src/runtime/mod_fmr_serialized_reference_backend.f90
grep -Fq 'publication%carrier_sample_count_value /= output%accepted_substeps' src/runtime/mod_eb_i25_multisubstep_sensible_boundary_runtime.f90
grep -Fq 'sample%top_exchange_native > 0.0_real64' src/runtime/mod_eb_i25_multisubstep_sensible_boundary_runtime.f90
grep -Fq 'resolve_external_liquid_water_temperature' src/runtime/mod_eb_i25_multisubstep_sensible_boundary_runtime.f90
grep -Fq 'evaluate_liquid_water_sensible_transport' src/runtime/mod_eb_i25_multisubstep_sensible_boundary_runtime.f90
grep -Fq 'J_CM2_TO_J_M2 * boundary_energy_j_cm2' src/runtime/mod_eb_i25_multisubstep_sensible_boundary_runtime.f90
grep -Fq 'Preserve I24 exactly' src/runtime/mod_eb_i25_multisubstep_sensible_boundary_runtime.f90
grep -Fq 'does not publish a whole-column sensible-energy residual' tests/eb/EB-I25_CONTRACT.md
grep -Fq 'complete SWAP5 Energy Balance' tests/eb/EB-I25_CONTRACT.md
echo 'EB_I25_BOUNDED_DELTA=PASS'
echo 'EB_I25_STATIC_CONTRACT=PASS'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_transaction_reference.f90
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
  src/runtime/mod_fmr_drainage_response_binding.f90
  src/process/mod_soil_temperature_contract.f90
  src/process/mod_restricted_soil_temperature.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/process/mod_snow_process.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/process/mod_restricted_fixed_weir_surface_water.f90
  src/runtime/mod_fmr_bottom_thermal_carrier.f90
  src/runtime/mod_fmr_top_sensible_boundary_carrier.f90
  src/process/mod_liquid_water_sensible_enthalpy.f90
  src/runtime/mod_fmr_bottom_external_thermal_binding.f90
  src/runtime/mod_fmr_bottom_external_thermal_provider.f90
  src/runtime/mod_fmr_bottom_sensible_energy.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_accepted_commit_receipt.f90
  src/runtime/mod_fmr_owned_commit_receipt.f90
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
  src/process/mod_linear_mixture_sensible_storage.f90
  src/kernel/mod_energy_conservation_types.f90
  src/process/mod_whole_column_sensible_energy_accounting.f90
  src/runtime/mod_eb_i23_sensible_boundary_runtime.f90
  src/process/mod_external_liquid_water_temperature.f90
  src/runtime/mod_eb_i24_top_liquid_sensible_inflow_runtime.f90
  src/runtime/mod_eb_i25_multisubstep_sensible_boundary_runtime.f90
)

for opt in 0 2; do
  OUT="${RUNNER_TEMP:-/tmp}/eb-i25-o${opt}"
  rm -rf "$OUT"
  mkdir -p "$OUT"
  objects=()
  for source in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    -c tests/eb/test_eb_i25_multisubstep_sensible_boundary_runtime.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/output.txt" 2>&1
  grep -Fx 'EB_I25_TWO_HALF_ACCEPTED_AGGREGATION=PASS' "$OUT/output.txt"
  grep -Fx 'EB_I25_MISSING_TOP_DONOR_FAIL_CLOSED=PASS' "$OUT/output.txt"
  grep -Fx 'EB_I25_TOP_OUTFLOW_FAIL_CLOSED=PASS' "$OUT/output.txt"
  grep -Fx 'EB_I25_SINGLE_SUBSTEP_I24_EQUIVALENCE=PASS' "$OUT/output.txt"
  grep -Fx 'EB_I25_REJECTED_TRIAL_NO_PUBLICATION=PASS' "$OUT/output.txt"
  grep -Fx 'EB_I25_MULTISUBSTEP_SENSIBLE_BOUNDARY_GATE=PASS' "$OUT/output.txt"
  cat "$OUT/output.txt"
done
cmp -s "${RUNNER_TEMP:-/tmp}/eb-i25-o0/output.txt" "${RUNNER_TEMP:-/tmp}/eb-i25-o2/output.txt"
echo 'EB_I25_O0_O2_IDENTITY=PASS'
echo 'EB_I25_OWNER_QUALIFICATION=PASS'
