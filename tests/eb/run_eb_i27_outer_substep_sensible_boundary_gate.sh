#!/usr/bin/env bash
set -euo pipefail

BASE=9d202705d1d7063ae129166b1049f7555a7ad802
FKT22_CLOSE=4a01641ffed8a2260260909825c3887db2dff1ac
FKT22_CHECKPOINT=tests/fkt/F-KT22_RECOMPOSITION_CHECKPOINT.json
FKT22_CHECKPOINT_BLOB=a9205fbe5d359e8d8f710476e5fbd2084eaff9e8
OLD_BACKEND_BLOB=960ea116cad81e8c0db8a579982f4999b3d085ed
FKT22_BACKEND_BLOB=9b4d6f7d6b63d66fe2e46eb9c46d70d08e32db13

git fetch origin integration/f-ci-canonical
git merge-base --is-ancestor "$BASE" origin/integration/f-ci-canonical
git merge-base --is-ancestor "$FKT22_CLOSE" origin/integration/f-ci-canonical

declare -A STABLE_LOCKS=(
  [src/runtime/mod_eb_i25_multisubstep_sensible_boundary_runtime.f90]=fc88731c12c8af5136aad13bda2a7da3d768dc4c
  [src/runtime/mod_fmr_top_sensible_boundary_carrier.f90]=299717757082ff06e98bd3aaec2c0b8b3013ea21
  [src/runtime/mod_fmr_serialized_multiswap_runtime.f90]=1aa2454048d0e480becaee34f596f20f1a7bd66e
  [src/process/mod_whole_column_sensible_energy_accounting.f90]=c00efd8cdb4de947de16e1d32ae4c9f4d0590850
  [src/process/mod_liquid_water_sensible_enthalpy.f90]=2247370ee34fac73a0e2d0b9fa15e171467aded3
  [src/process/mod_external_liquid_water_temperature.f90]=64b85363e764d2c6e2777f5f1258abb3ac9e5abf
  [src/runtime/mod_eb_i24_top_liquid_sensible_inflow_runtime.f90]=5f27ff7a4fa67a3991c622d960a7133857dab1c2
  [src/runtime/mod_eb_i23_sensible_boundary_runtime.f90]=35dda86ca51bd91040af0672a43e2961c8db64fd
)
for path in "${!STABLE_LOCKS[@]}"; do
  test "$(git rev-parse "$BASE:$path")" = "${STABLE_LOCKS[$path]}"
  test "$(git rev-parse "origin/integration/f-ci-canonical:$path")" = "${STABLE_LOCKS[$path]}"
done

test "$(git rev-parse "$BASE:src/runtime/mod_fmr_serialized_reference_backend.f90")" = "$OLD_BACKEND_BLOB"
test "$(git rev-parse "origin/integration/f-ci-canonical:src/runtime/mod_fmr_serialized_reference_backend.f90")" = "$FKT22_BACKEND_BLOB"
test "$(git rev-parse "origin/integration/f-ci-canonical:$FKT22_CHECKPOINT")" = "$FKT22_CHECKPOINT_BLOB"
git show "origin/integration/f-ci-canonical:$FKT22_CHECKPOINT" | grep -Fq '"eb-i25-preservation": "PASS"'
git show "origin/integration/f-ci-canonical:$FKT22_CHECKPOINT" | grep -Fq '"admitted_production_identical_to_qualified_checkpoint": true'
git show "origin/integration/f-ci-canonical:$FKT22_CHECKPOINT" | grep -Fq '"verdict": "ADMITTED_CANONICAL_CLOSED"'
echo 'EB_I27_FKT22_BACKEND_RECONCILIATION=PASS'
echo 'EB_I27_INHERITED_AUTHORITY_LOCK=PASS'

git diff --name-only --no-renames "$BASE" HEAD | sort > changed.txt
cat > allowed.txt <<'EOF'
.github/workflows/eb-i27-outer-substep-sensible-boundary.yml
src/runtime/mod_eb_i27_outer_substep_sensible_boundary_aggregation.f90
tests/eb/EB-I27_CHECKPOINT.json
tests/eb/EB-I27_CONTRACT.md
tests/eb/run_eb_i27_outer_substep_sensible_boundary_gate.sh
tests/eb/test_eb_i27_outer_substep_sensible_boundary_aggregation.f90
.github/workflows/eb-i26-outer-substep-sensible-boundary.yml
src/runtime/mod_eb_i26_outer_substep_sensible_boundary_aggregation.f90
tests/eb/EB-I26_CHECKPOINT.json
tests/eb/EB-I26_CONTRACT.md
tests/eb/run_eb_i26_outer_substep_sensible_boundary_gate.sh
tests/eb/test_eb_i26_outer_substep_sensible_boundary_aggregation.f90
tests/eb/materialize_eb_i27_owner_assets.py
EOF
sort -o allowed.txt allowed.txt
comm -23 changed.txt allowed.txt > unexpected.txt
test ! -s unexpected.txt
test -f src/runtime/mod_eb_i27_outer_substep_sensible_boundary_aggregation.f90
test -f tests/eb/EB-I27_CONTRACT.md
test -f tests/eb/test_eb_i27_outer_substep_sensible_boundary_aggregation.f90
echo 'EB_I27_BOUNDED_DELTA=PASS'

! grep -Eq 'call[[:space:]]+fmr_execute|call[[:space:]]+run_trial|call[[:space:]]+execute_resolved_column' \
  src/runtime/mod_eb_i27_outer_substep_sensible_boundary_aggregation.f90
grep -Fq 'size(publications) < 2' src/runtime/mod_eb_i27_outer_substep_sensible_boundary_aggregation.f90
grep -Fq 'publications(i)%accepted_substeps() /= 1' src/runtime/mod_eb_i27_outer_substep_sensible_boundary_aggregation.f90
grep -Fq 'publications(i)%carrier_sample_count() /= 2' src/runtime/mod_eb_i27_outer_substep_sensible_boundary_aggregation.f90
grep -Fq 'publications(i)%origin_revision() /= previous_committed_revision' \
  src/runtime/mod_eb_i27_outer_substep_sensible_boundary_aggregation.f90
grep -Fq '.not. same_time(step_t0, previous_t1)' src/runtime/mod_eb_i27_outer_substep_sensible_boundary_aggregation.f90
grep -Fq 'EB_I27_INCOMPLETE_INPUT' src/runtime/mod_eb_i27_outer_substep_sensible_boundary_aggregation.f90
grep -Fq 'does not add a multi-transaction rollback guarantee' tests/eb/EB-I27_CONTRACT.md
grep -Fq 'complete SWAP5 Energy Balance' tests/eb/EB-I27_CONTRACT.md
echo 'EB_I27_STATIC_CONTRACT=PASS'

# F-KT10-derived hydrologic fixture is committed in the I27 owner test.
COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/solver/mod_soil_water_accepted_step_direction_contract.f90
  src/transaction/mod_accepted_trajectory_directional_sensitivity.f90
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
  src/runtime/mod_eb_i27_outer_substep_sensible_boundary_aggregation.f90
)

for opt in 0 2; do
  OUT="${RUNNER_TEMP:-/tmp}/eb-i27-o${opt}"
  rm -rf "$OUT"
  mkdir -p "$OUT"
  objects=()
  for source in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$source" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" \
    -c tests/eb/test_eb_i27_outer_substep_sensible_boundary_aggregation.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  if ! "$OUT/test" > "$OUT/output.txt" 2>&1; then
    cat "$OUT/output.txt"
    exit 1
  fi
  grep -Fx 'EB_I27_TWO_OUTER_FOUR_HALF_AGGREGATION=PASS' "$OUT/output.txt"
  grep -Fx 'EB_I27_SINGLE_OUTER_REJECTED=PASS' "$OUT/output.txt"
  grep -Fx 'EB_I27_REVERSED_SEQUENCE_REJECTED=PASS' "$OUT/output.txt"
  grep -Fx 'EB_I27_DUPLICATE_SEQUENCE_REJECTED=PASS' "$OUT/output.txt"
  grep -Fx 'EB_I27_INCOMPLETE_INPUT_FAIL_CLOSED=PASS' "$OUT/output.txt"
  grep -Fx 'EB_I27_OUTER_SUBSTEP_SENSIBLE_BOUNDARY_GATE=PASS' "$OUT/output.txt"
  cat "$OUT/output.txt"
done
cmp -s "${RUNNER_TEMP:-/tmp}/eb-i27-o0/output.txt" "${RUNNER_TEMP:-/tmp}/eb-i27-o2/output.txt"
echo 'EB_I27_O0_O2_IDENTITY=PASS'
echo 'EB_I27_OWNER_QUALIFICATION=PASS'
