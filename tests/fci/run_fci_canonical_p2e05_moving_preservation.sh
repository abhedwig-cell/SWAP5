#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

AUTH=50346642bd565f79134ea17d5462e544b354998c
FROSS12_AUTH=786fe5bf59e616dcfa9a86b16b58c67ac0b3b97d
TX=src/transaction/mod_transaction_reference.f90
TX_BLOB=d5a71a526efaebd82054580c3186f8e3545db331
SW=src/solver/mod_soil_water_solver_contract.f90
REF_ADAPTER=src/adapter/mod_reference_richards_legacy_binding.f90
ROSS_ADAPTER=src/solver/mod_rossfast_d3r_soil_water_solver.f90
SW_P2E05=40a1ddc05fb8e2c1822763de645fd07a094568a3
REF_ADAPTER_P2E05=4b545c6fb260e81cd6c8f4d2d65f2beee7281e53
ROSS_ADAPTER_P2E05=dbb441f3529be179d64fb57f9c44336d3d20c540

fail() { echo "FCI_CANONICAL_P2E05_PRESERVATION_FAIL $*" >&2; exit 1; }

git merge-base --is-ancestor "$AUTH" HEAD || fail 'Status-A authority not ancestor'
git merge-base --is-ancestor "$FROSS12_AUTH" HEAD || fail 'F-ROSS12 authority not ancestor'
test "$(git rev-parse "HEAD:$TX")" = "$TX_BLOB" || fail "admitted F-KT18 transaction postimage drift: $TX"
echo 'FCI57P_MOVING_TRANSACTION_REFERENCE_POSTIMAGE=PASS'

# All pre-P2E05 dependencies remain byte-identical to the Status-A authority.
# The two common Reference-side P2E05 blobs are checked separately below.
dependency_surface=(
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_fkt_temporal_indicator_history.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/runtime/mod_fmr_runtime_core.f90
  src/runtime/mod_fmr_checkpoint_orchestrator.f90
  src/runtime/mod_fmr_accepted_commit_receipt.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/solver/mod_surface_evaporation_capacity_contract.f90
  src/solver/mod_b110_surface_evaporation_capacity_provider.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/process/mod_snow_process.f90
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
  src/process/mod_liquid_water_sensible_enthalpy.f90
  src/runtime/mod_fmr_bottom_thermal_carrier.f90
  src/runtime/mod_fmr_bottom_external_thermal_binding.f90
  src/runtime/mod_fmr_bottom_external_thermal_provider.f90
  src/runtime/mod_fmr_bottom_sensible_energy.f90
  src/kernel/mod_energy_conservation_types.f90
  src/runtime/mod_energy_conservation_ledger.f90
  src/runtime/mod_fmr_owned_commit_receipt.f90
  src/runtime/mod_fmr_parallel_physical_scheduler.f90
  src/runtime/mod_fmr_parallel_worker_pool.f90
  src/runtime/mod_fmr_parallel_root_uptake_pool.f90
  src/runtime/mod_fmr_committed_restart.f90
  src/runtime/mod_fmr_restart_state_contract.f90
  src/runtime/mod_fmr_reference_et_root_uptake_composition.f90
  src/solver/mod_process_hydraulic_view.f90
  src/process/mod_drainage_spatial_distribution.f90
  src/process/mod_drainage_empirical_interflow_response.f90
  src/process/mod_drainage_ernst_ipos45_preparation.f90
  src/process/mod_drainage_ernst_ipos45_response.f90
  src/process/mod_drainage_hooghoudt_equivalent_depth.f90
  src/process/mod_drainage_hooghoudt_ipos1_response.f90
  src/process/mod_drainage_hooghoudt_ipos23_response.f90
  src/process/mod_drainage_multilevel_aggregation.f90
  src/process/mod_drainage_process.f90
  src/process/mod_drainage_tabulated_response.f90
  src/runtime/mod_fmr_drainage_response_binding.f90
  src/runtime/mod_fmr_divdra_runtime_binding.f90
  src/runtime/mod_fmr_divdra_serialized_composition.f90
  src/runtime/mod_fmr_divdra_serialized_runtime.f90
  src/process/mod_restricted_surface_evaporation.f90
  src/runtime/mod_fmr_surface_evaporation_runtime_materialization.f90
  src/runtime/mod_fmr_surface_evaporation_accepted_publication.f90
  src/runtime/mod_fmr_process_hydraulic_view_binding.f90
  src/process/mod_soil_temperature_contract.f90
  src/process/mod_restricted_soil_temperature.f90
  src/runtime/mod_coupling_application_accuracy_contract.f90
  src/runtime/mod_coupling_application_accuracy_adapter.f90
  src/runtime/mod_groundwater_coupling_contract.f90
  src/runtime/mod_groundwater_coupling_policy.f90
  src/runtime/mod_groundwater_exchange_service_contract.f90
  src/runtime/mod_groundwater_interface_mass_ledger.f90
  src/runtime/mod_groundwater_coupled_restart.f90
)
for path in "${dependency_surface[@]}"; do
  test "$(git rev-parse "HEAD:$path")" = "$(git rev-parse "$AUTH:$path")" || fail "admitted dependency drift: $path"
done

# P2E05 typed-diagnostic successors are exact, not wildcard exceptions.
test "$(git rev-parse HEAD:$SW)" = "$SW_P2E05" || fail 'typed solver contract is not the qualified P2E05 blob'
test "$(git rev-parse HEAD:$REF_ADAPTER)" = "$REF_ADAPTER_P2E05" || fail 'Reference adapter is not the qualified P2E05 blob'

# F-ROSS12 backend and selection stay byte-identical; only its result adapter
# is the exact P2E05 typed-diagnostic successor.
fross12_frozen_surface=(
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_rossfast_solver_selection_binding.f90
)
for path in "${fross12_frozen_surface[@]}"; do
  test "$(git rev-parse "HEAD:$path")" = "$(git rev-parse "$FROSS12_AUTH:$path")" || fail "admitted F-ROSS12 successor drift: $path"
done
test "$(git rev-parse HEAD:$ROSS_ADAPTER)" = "$ROSS_ADAPTER_P2E05" || fail 'RossFast adapter is not the qualified P2E05 blob'

# Reuse the stronger exact-scope + semantic-replay gate. This proves the three
# successor blobs together without weakening any historical authority.
bash tests/fci/run_fci96_p2e05_semantic_successor_preservation.sh

echo 'FCI34_MOVING_ROOT_ATTRIBUTION_PRESERVATION=PASS'
echo 'FCI35_MOVING_PARALLEL_RESTART_DEPENDENCY_PRESERVATION=PASS'
echo 'FCI36_MOVING_DIVDRA_ACTIVE_RUNTIME_PRESERVATION=PASS'
echo 'FCI37_MOVING_PARALLEL_ROOT_UPTAKE_PRESERVATION=PASS'
echo 'FCI39_MOVING_SURFACE_EVAPORATION_CAPACITY_PRESERVATION=PASS'
echo 'FCI40_MOVING_EFFECTIVE_FORCING_EXECUTOR_PRESERVATION=PASS'
echo 'FCI41_MOVING_SURFACE_EVAPORATION_RUNTIME_PRESERVATION=PASS'
echo 'FCI42_MOVING_SURFACE_EVAPORATION_ALLOCATION_PRESERVATION=PASS'
echo 'FCI43_MOVING_SOIL_TEMPERATURE_PROCESS_PRESERVATION=PASS'
echo 'FCI44_MOVING_APPLICATION_ACCURACY_CONTRACT_PRESERVATION=PASS'
echo 'FCI45_MOVING_SOIL_TEMPERATURE_RUNTIME_PRESERVATION=PASS'
echo 'FCI46_MOVING_EXTERNAL_ACCURACY_ADAPTER_PRESERVATION=PASS'
echo 'FCI47_MOVING_PRESERVATION_AUTHORITY_RECONCILED=PASS'
echo 'FCI48_MOVING_TYPED_OPTIONAL_STATE_LAYOUT_PRESERVATION=PASS'
echo 'FCI49_MOVING_FKT15_SOLVER_SERVICE_TRANSACTION_COMPOSITION_PRESERVATION=PASS'
echo 'FCI50_MOVING_FGC17_TYPED_GROUNDWATER_INTERFACE_PRESERVATION=PASS'
echo 'FCI52_MOVING_PM08D7_FIXED_WEIR_TRANSACTIONAL_RUNTIME_PRESERVATION=PASS'
echo 'FCI57_MOVING_FAIL_CLOSED_MASS_COMPLETENESS_PRESERVATION=PASS'
echo 'FCI59_MOVING_ATOMIC_SURFACE_PUBLICATION_PRESERVATION=PASS'
echo 'FCI61_MOVING_DRAINAGE_RESPONSE_RUNTIME_PRESERVATION=PASS'
echo 'FCI62_MOVING_PRESCRIBED_QBOT_TEMPORAL_RUNTIME_PRESERVATION=PASS'
echo 'FCI63_MOVING_BOTTOM_ENERGY_PUBLICATION_PRESERVATION=PASS'
echo 'FCI64_MOVING_ENERGY_LEDGER_OWNED_RECEIPT_PRESERVATION=PASS'
echo 'FCI65_MOVING_FGC24_COUPLED_RESTART_PRESERVATION=PASS'
echo 'FCI96_MOVING_FROSS12_SUCCESSOR_PRESERVATION=PASS'
echo 'FCI_CANONICAL_MOVING_PRESERVATION_NO_HISTORICAL_DELTA_ASSUMPTION=PASS'
echo 'FCI_CANONICAL_LINEAGE_AWARE_GATE PASS'
