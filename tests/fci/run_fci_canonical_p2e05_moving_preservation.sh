#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

AUTH=50346642bd565f79134ea17d5462e544b354998c
FCI110_ADMISSION=a0fd7822ea5d7ecc0bb409fd9f0439c8fd1dca6a
DIR01_ADMISSION=b95ce4b9a27144eb400fae25de69dd5d927667a8
REPAIR01_ADMISSION=c64737c89953888c311e005a2a0077964f358498
BALTOL02_ADMISSION=0ac76e68a35dda95c753d255927f1dc432f7b42e
FPERF_B1_ADMISSION=ffb08380054ddec9e940fc0e4056758d30a1d7da
FROSS12_AUTH=786fe5bf59e616dcfa9a86b16b58c67ac0b3b97d
FROSS13_PRODUCTION=0fdba1a603ffd54eff7ee92a3cd7001f2b802678
FGC31_RECONCILED=49a4685474a2d8df53c77c45e87a6c243316a97c
FGC44_PRODUCTION=04e5db63356e48256997fad9daea9e77040c29e6
FSI39_PRODUCTION=20d34024cfe4b981b6c00d5042bdf366f8aae830
BOFEK00_ADMISSION=f670e012ab028cc1e74bb9b7aa1b8655b545619c
BOFEK00_HEADCALC=3310e5f89109592134e715edd73154479e2ae157
BOFEK00_SW=f67cbe5b4612e8f4230f58f81cbffd3d44336c0d
BOFEK00_DYNAMIC_TOP=7586cc2db6aafba053fff31ccecb178335fb37aa
BOFEK00_DYNAMIC_TOP_ADAPTER=1bd89321dc19e3438ec71a7581bab14948886ab7
TEMPORAL11_ADMISSION=0928019bf826d6377d5f9324144496334bf4b0d6
TEMPORAL11_TEMPORAL_INDICATOR=7239ec1b8572e97a624515fe7dd2ff25de648baa
F_ROM1A_PRODUCTION=5db312c3845ccb0a00372b3ccf3e6a45f0be9a2b
PPA_LOW02_ADMISSION=6c63b8d0e340669d9722bc5e3d947d42d2b467a5
PPA_LOW02_QUALIFIED=8d238bb46c9d4d77e38802e75458d99f59794d11
PPA_ROOT_HYD01_ADMISSION=308a619c91d2cc3dae7f7aa143cfbe97c780c635
PPA_ROOT_HYD01_QUALIFIED=b7803c1cf0818677651a0eecaed4bd84ffb3059a
PPA_WU04A_ADMISSION=50e7d1dece5b75d0103459d5c118d03a2665eea3
PPA_WU04A_QUALIFIED=f1fd0fa5633cea1fa5f3870eb2aa7b236d40a938
PPA_WU04B_ADMISSION=4d40b8d4b6a1df06ff97fab55497542778431290
PPA_WU04B_QUALIFIED=eb0e635975b77ec92084e1416038b1bc1f8232bc
PPA_WU05B_QUALIFIED=a2b9227e43c6f705942dc4959a579c011b857ae0
PPA_WU05B_BACKEND=c093919f070af2cf1616328cf3bd50df84e0a5f0
PPA_WU05B_MERGE_BACKEND=d375e621a88e6e026e99702cd99b59a17e498536
PPA_WU05B_EFFECT=2c8adba7986e7d85749c4c36d26530748fbbab9e
PPA_WU05B_PROVIDER=08492a7272860629c9ffee34968c9cc29952bd58
TEMPORAL_INDICATOR=src/solver/mod_reference_richards_temporal_indicator.f90
PPA_ROOT_HYD01_TEMPORAL_INDICATOR=2068215a57edb1d2a59c36d6b32f519ebdc09ebd
FCI110_TEMPORAL_INDICATOR=81a0305958e108e92224a48862358d79c765cd0a
TX=src/transaction/mod_transaction_reference.f90
TX_BLOB=d5a71a526efaebd82054580c3186f8e3545db331
FPERF_B1_TX_BLOB=97d8ef1fae91e174ab6daefb42ffa6a85da9380e
SW=src/solver/mod_soil_water_solver_contract.f90
REF_ADAPTER=src/adapter/mod_reference_richards_legacy_binding.f90
ROSS_ADAPTER=src/solver/mod_rossfast_d3r_soil_water_solver.f90
BACKEND=src/runtime/mod_fmr_serialized_reference_backend.f90
RUNTIME_CORE=src/runtime/mod_fmr_runtime_core.f90
RESTART_STATE=src/runtime/mod_fmr_restart_state_contract.f90
SURFACE_EVAP=src/process/mod_restricted_surface_evaporation.f90
SELECTION=src/runtime/mod_fmr_rossfast_solver_selection_binding.f90
FROSS13_MODEL=src/runtime/mod_rossfast_d3r_model_binding.f90
FROSS13_PROVIDER=src/solver/mod_rossfast_d3r_table_provider.f90
FROSS17_KERNEL=src/solver/mod_rossfast_d3r_table_kernel.f90
FROSS13_MODEL_POSTIMAGE=5442fd7e7a2f392c9b796cd17c76b17977259f22
FROSS13_PROVIDER_POSTIMAGE=ac997bf06c56a37080d1c8db69b6d4208f4b75ca
FROSS17_CACHE_KERNEL=2ad2a680e62744451d6763de48585f1bd45d3067
FROSS22_TIERED_KERNEL=438ee46e012e9eb183b8f2532437e2fe56aa18ed
FROSS22_TIERED_SOLVER=2b134c36097aed2a44a56bfe8e2194b15aa063aa
SW_P2E05=40a1ddc05fb8e2c1822763de645fd07a094568a3
FCI110_SW=45cb74e00ae5fe09a220e630d84507cde543070b
REF_ADAPTER_P2E05=4b545c6fb260e81cd6c8f4d2d65f2beee7281e53
FCI110_REF_ADAPTER=6d1ca6edfd2f71a4b2d7c3c54efa448986f4b09b
REPAIR01_REF_ADAPTER=dab224d42792a71525960895d26b419c9589ce33
ROSS_ADAPTER_P2E05=dbb441f3529be179d64fb57f9c44336d3d20c540
BACKEND_FROSS12=19d07cac9285142d14a6e9c53706fb73d016d5ad
BACKEND_FGC31=4e5491c997ed0752a4db9abd09b5ad3daf394db2
BACKEND_FGC44=4597c833e7f45beaef04ffcc592ca6a4fcbd0395
FSI39_PROVIDER=90183cbe0f3f0b349e40fa6b0c65b2223ca8a739
FCI110_PROVIDER=b9042b4a41ddbf940888821aea4b258e37ed290e
DIR01_PROVIDER=7af945e2f596d7c93ce0ea21a211d76a69213283
FSI39_BACKEND=556ed83dee4d5b159f1de7ae797af7106a0abe2e
F_ROM1A_KERNEL=c28cb8246aaf087da92538e58b1aa2da5d1b5b11
FCI110_KERNEL_TRANSACTIONS=9cb522c1486ba015a3c4fe86d6706e884806c4cf
F_ROM1A_BACKEND=5d63f91b37443952b4a96292925f645aae0b22d1
PPA_LOW02_BACKEND=80c7ca618ea228e31ac43ae493f16dd6eccc5991
PPA_WU04A_RUNTIME_CORE=29cff34a37c13143ce069486251bc0b858cadf48
PPA_WU04A_RESTART_STATE=665d90cb82485dec485be68694f77e0fcd03145c
PPA_WU04A_SURFACE_EVAP=a7b9f5271ac0582420e883a62c6e13672dc190e9
PPA_WU04A_BACKEND=b1ba0549ef9149c4261b8a595c8782be01726c43
PPA_WU04B_RUNTIME_CORE=dc1dbffab96542ee09be5f923cea65628864d87b
FCI110_RUNTIME_CORE=0783af04474752a47f7b3a0304a84dd379cff7d6
PPA_WU04B_RESTART_STATE=ddcb880dbdbf1d6b41c8721f931df9a2c8bc121a
PPA_WU04B_SURFACE_EVAP=1f795f0baaa3ed86272a1feabc3f1a6463b3ce77
PPA_WU04B_BACKEND=9bd344a83afd5e10b96178933362dbb7eeea4f30
FCI110_BACKEND=27df1d7ef2cec91501af3a0f0b3fb45e869c30f3
DIR01_BACKEND=37a2381a6f124648969ca9c1bf7e5ee1f4072c72
BALTOL02_BACKEND=a5d472636f50a715cf64016ad9d500b401b0ebb1
SELECTION_FROSS12=cca61af52bde3eed12b756547277cc2776589648

fail() { echo "FCI_CANONICAL_P2E05_PRESERVATION_FAIL $*" >&2; exit 1; }

git merge-base --is-ancestor "$AUTH" HEAD || fail 'Status-A authority not ancestor'
git merge-base --is-ancestor "$FROSS12_AUTH" HEAD || fail 'F-ROSS12 authority not ancestor'
if git merge-base --is-ancestor "$FPERF_B1_ADMISSION" HEAD; then
  # The canonical branch has a later transaction postimage than the original
  # F-PERF-CANON01-B1 blob. Preserve the exact target-branch transaction
  # source in a PR merge, while retaining the old exact pin when it is still
  # the current target postimage.
  canonical_tx_authority="$(git rev-parse "HEAD^1:$TX")"
  if [[ "$canonical_tx_authority" == "$FPERF_B1_TX_BLOB" ]]; then
    test "$(git rev-parse "HEAD:$TX")" = "$FPERF_B1_TX_BLOB" || \
      fail "admitted F-PERF-CANON01-B1 transaction successor drift: $TX"
    echo 'FCI_CANONICAL_FPERF_B1_TRANSACTION_SUCCESSOR=PASS'
  else
    test "$(git rev-parse "HEAD:$TX")" = "$canonical_tx_authority" || \
      fail "current canonical F-PERF-CANON01-B1 transaction successor drift: $TX"
    echo "FCI_CANONICAL_FPERF_B1_CURRENT_TARGET_TRANSACTION_SUCCESSOR=$canonical_tx_authority"
  fi
else
  test "$(git rev-parse "HEAD:$TX")" = "$TX_BLOB" || \
    fail "admitted F-KT18 transaction postimage drift: $TX"
  echo 'FCI57P_MOVING_TRANSACTION_REFERENCE_POSTIMAGE=PASS'
fi

# Preserve the exact target-canonical postimages for the shared dependency
# surface. Several dependencies have later admitted/current successors since
# the historical Status-A and F-CI110 pins. The focused postimage checks below
# still enforce their independently qualified semantic successors.
dependency_surface=(
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_fkt_temporal_indicator_history.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/runtime/mod_fmr_checkpoint_orchestrator.f90
  src/runtime/mod_fmr_accepted_commit_receipt.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_surface_evaporation_capacity_contract.f90
  src/solver/mod_b110_surface_evaporation_capacity_provider.f90
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
dependency_authority="$(git rev-parse HEAD^1)"
echo "FCI_CANONICAL_CURRENT_TARGET_DEPENDENCY_BASELINE=$dependency_authority"
for path in "${dependency_surface[@]}"; do
  test "$(git rev-parse "HEAD:$path")" = "$(git rev-parse "$dependency_authority:$path")" || \
    fail "candidate changed current canonical dependency from $dependency_authority: $path"
done

# BOFEK00 is a later independently qualified successor for wet
# dynamic-top behavior. Canonical has since advanced beyond its original exact
# blobs. Preserve the exact current target-tree postimages in this PR merge;
# focused BOFEK00 semantic gates remain the authority for those behaviors.
if git merge-base --is-ancestor "$BOFEK00_ADMISSION" HEAD; then
  for path in \
    src/legacy/b1_10_port/headcalc.f90 \
    src/solver/mod_b110_dynamic_top_boundary_provider.f90 \
    src/adapter/mod_b110_dynamic_top_boundary_solver_adapter.f90; do
    test "$(git rev-parse "HEAD:$path")" = "$(git rev-parse "$dependency_authority:$path")" || \
      fail "candidate changed current BOFEK00 target postimage: $path"
  done
  echo 'FCI_CANONICAL_BOFEK00_CURRENT_TARGET_POSTIMAGES=PASS'
else
  test "$(git rev-parse HEAD:src/legacy/b1_10_port/headcalc.f90)" = \
       "$(git rev-parse "$dependency_authority:src/legacy/b1_10_port/headcalc.f90")" || \
    fail 'pre-BOFEK00 HeadCalc drift'
fi

# PPA-WU04-A/B are later, independently qualified exact successors for
# stateful evaporation continuation. Keep them lineage-aware and exact rather
# than weakening the moving gate with wildcard drift allowances.
if git merge-base --is-ancestor "$PPA_WU04B_ADMISSION" HEAD; then
  git merge-base --is-ancestor "$PPA_WU04B_QUALIFIED" "$PPA_WU04B_ADMISSION" || \
    fail 'PPA-WU04-B qualified head is not contained by canonical admission'
  # Preserve the accepted current-canonical continuation and restart postimages.
  # Their exact historical pins predate later canonical advances; the PR must
  # leave the current target versions byte-identical.
  for path in "$RUNTIME_CORE" "$RESTART_STATE" "$SURFACE_EVAP"; do
    test "$(git rev-parse "HEAD:$path")" = "$(git rev-parse "$dependency_authority:$path")" || \
      fail "candidate changed current stateful-evaporation target postimage: $path"
  done
  echo 'FCI_CANONICAL_PPA_WU04B_STATEFUL_EVAPORATION_SUCCESSOR=PASS'
elif git merge-base --is-ancestor "$PPA_WU04A_ADMISSION" HEAD; then
  git merge-base --is-ancestor "$PPA_WU04A_QUALIFIED" "$PPA_WU04A_ADMISSION" || \
    fail 'PPA-WU04-A qualified head is not contained by canonical admission'
  test "$(git rev-parse "HEAD:$RUNTIME_CORE")" = "$PPA_WU04A_RUNTIME_CORE" || \
    fail 'admitted PPA-WU04-A runtime-core successor drift'
  test "$(git rev-parse "HEAD:$RESTART_STATE")" = "$PPA_WU04A_RESTART_STATE" || \
    fail 'admitted PPA-WU04-A restart-state successor drift'
  test "$(git rev-parse "HEAD:$SURFACE_EVAP")" = "$PPA_WU04A_SURFACE_EVAP" || \
    fail 'admitted PPA-WU04-A surface-evaporation successor drift'
  echo 'FCI_CANONICAL_PPA_WU04A_STATEFUL_EVAPORATION_SUCCESSOR=PASS'
else
  test "$(git rev-parse "HEAD:$RUNTIME_CORE")" = "$(git rev-parse "$AUTH:$RUNTIME_CORE")" || \
    fail 'pre-PPA-WU04 runtime-core drift'
  test "$(git rev-parse "HEAD:$RESTART_STATE")" = "$(git rev-parse "$AUTH:$RESTART_STATE")" || \
    fail 'pre-PPA-WU04 restart-state drift'
  test "$(git rev-parse "HEAD:$SURFACE_EVAP")" = "$(git rev-parse "$AUTH:$SURFACE_EVAP")" || \
    fail 'pre-PPA-WU04 surface-evaporation drift'
fi

# PPA-ROOT-HYD01 is a later, independently qualified exact successor of the
# Reference Richards temporal-indicator provider. Keep the historical Status-A
# blob before its admission and accept only the exact admitted successor after
# that point. This is canonical preservation authority, not new solver physics.
if git merge-base --is-ancestor "$PPA_ROOT_HYD01_ADMISSION" HEAD; then
  git merge-base --is-ancestor "$PPA_ROOT_HYD01_QUALIFIED" "$PPA_ROOT_HYD01_ADMISSION" || \
    fail 'PPA-ROOT-HYD01 qualified head is not contained by canonical admission'
  test "$(git rev-parse "HEAD:$TEMPORAL_INDICATOR")" = "$(git rev-parse "$dependency_authority:$TEMPORAL_INDICATOR")" || \
    fail 'candidate changed current temporal-indicator target postimage'
  echo 'FCI_CANONICAL_PPA_ROOT_HYD01_TEMPORAL_INDICATOR_SUCCESSOR=PASS'
else
  test "$(git rev-parse "HEAD:$TEMPORAL_INDICATOR")" = "$(git rev-parse "$AUTH:$TEMPORAL_INDICATOR")" || \
    fail 'pre-PPA-ROOT-HYD01 temporal-indicator drift'
fi

# The current canonical has one later, explicitly qualified two-file research
# observation successor. It is not a wildcard exception: only the exact
# admitted F-ROM1A production postimage is accepted when that admission is in
# the lineage. Before that admission, kernel_transactions remains byte-equal
# to the Status-A authority.
if git merge-base --is-ancestor "$F_ROM1A_PRODUCTION" HEAD; then
  test "$(git rev-parse HEAD:src/kernel/mod_kernel_transactions.f90)" = \
       "$(git rev-parse "$dependency_authority:src/kernel/mod_kernel_transactions.f90")" || \
    fail 'candidate changed current kernel-transaction target postimage'
  echo 'FCI_CANONICAL_F_ROM1A_KERNEL_SUCCESSOR=PASS'
else
  test "$(git rev-parse HEAD:src/kernel/mod_kernel_transactions.f90)" =     "$(git rev-parse "$AUTH:src/kernel/mod_kernel_transactions.f90")" ||     fail 'pre-F-ROM1A kernel transaction drift'
fi

# P2E05 typed-diagnostic successors remain exact. Later admitted successors
# are selected only when their admission is in the current lineage.
# Preserve the current admitted solver contract and Reference/RossFast adapters.
# Their semantic lineage authorities above remain required; these source
# postimages may have advanced on current canonical since historical exact pins.
for path in "$SW" "$REF_ADAPTER" "$ROSS_ADAPTER"; do
  test "$(git rev-parse "HEAD:$path")" = "$(git rev-parse "$dependency_authority:$path")" || \
    fail "candidate changed current solver-contract/adapter target postimage: $path"
done
echo 'FCI_CANONICAL_CURRENT_SOLVER_ADAPTER_POSTIMAGES=PASS'

# B19/MICRO current-target preservation with explicit qualified MC-ROOT01 source exceptions.
# Root uptake process exception is restricted to the Feddes oxygen candidate
# and must be accompanied by exact-head empirical oxygen qualification.
# All unchanged source paths retain the exact canonical first-parent blob.
# This bounded exception is NOT proof of scientific preservation for modified paths.
check_b19_micro_root_recomposition() {
  local crop_lifecycle_changed=0
  local crop_physical_restart_changed=0
  local crop_hydraulic_provenance_changed=0
  local candidate_path
  while IFS= read -r candidate_path; do
    case "$candidate_path" in
      src/crop/mod_crop_adaptive_root_profile_owner.f90 ) ;;
      src/crop/mod_crop_root_anaerobic_extension_gate.f90 ) ;;
      src/crop/mod_crop_root_depth_biomass.f90 ) ;;
      src/crop/mod_crop_root_depth_rate_owner.f90 ) ;;
      src/crop/mod_crop_root_extension_supply_limit.f90 ) ;;
      src/crop/mod_wofost_crop_owner_state.f90 ) ;;
      src/crop/mod_wofost_finalize_rates.f90 ) ;;
      src/crop/mod_wofost_one_day_structural_evolution.f90 ) ;;
      src/crop/mod_wofost_potential_shadow_daily.f90 ) ;;
      src/crop/mod_wofost_potential_shadow_state.f90 ) ;;
      src/crop/mod_wofost_prepare_assimilation.f90 ) ;;
      src/crop/mod_wofost_two_phase_crop_window.f90 ) ;;
      src/runtime/mod_fmr_biomass_root_depth_binding.f90 ) ;;
      src/runtime/mod_fmr_root_depth_rate_daily_binding.f90 ) ;;
      src/runtime/mod_fmr_root_depth_supply_composition.f90 ) ;;
      src/runtime/mod_fmr_wofost_accepted_window_lineage.f90 ) ;;
      src/runtime/mod_fmr_wofost_crop_transaction.f90 ) ;;
      src/process/mod_root_water_uptake_process.f90 ) ;;
      src/crop/mod_crop_root_length_density_constant.f90 ) ;;
      src/crop/mod_crop_rotation_calendar.f90 ) ;;
      src/crop/mod_crop_rotation_transition.f90 ) ;;
      src/crop/mod_crop_rotation_lifecycle_preflight.f90 ) ;;
      src/crop/mod_crop_preparation_sowing_preflight.f90 ) ;;
      src/crop/mod_crop_germination_preflight.f90 ) ;;
      src/crop/mod_crop_lifecycle_daily_composition.f90 ) ;;
      src/crop/mod_crop_lifecycle_continuation.f90 ) crop_lifecycle_changed=1 ;;
      src/crop/mod_crop_previous_day_emergence_gate.f90 ) crop_lifecycle_changed=1 ;;
      src/runtime/mod_fmr_crop_rotation_receipt_binding.f90 ) ;;
      src/runtime/mod_fmr_crop_physical_calendar_restart_coherence.f90 ) crop_physical_restart_changed=1 ;;
      src/runtime/mod_fmr_crop_accepted_hydraulic_provenance.f90 ) crop_hydraulic_provenance_changed=1 ;;
      src/runtime/mod_fmr_micro_constant_lrv_binding.f90 ) ;;
      *) fail "B19+MICRO unqualified source change: $candidate_path" ;;
    esac
  done < <(git diff --name-only "$dependency_authority" HEAD -- src)
  if (( crop_lifecycle_changed )); then
    # This source is admitted to the restricted B19/MICRO candidate surface
    # ONLY after its full exact-head F-KT O0/O2 plus actual MICRO02/03/05/06
    # and B19 current-source O0/O2 cross-preservation gate has succeeded.
    # No unconditional source allowlisting or modification of frozen physics.
    test -f tests/fmig431/run_crop_lifecycle_b19_micro_cross_preservation.sh || \
      fail 'missing qualified lifecycle B19/MICRO cross-preservation gate'
    bash tests/fmig431/run_crop_lifecycle_b19_micro_cross_preservation.sh || \
      fail 'lifecycle B19/MICRO cross-preservation failed'
  fi
  if (( crop_hydraulic_provenance_changed )); then
    # Fail closed unless the exact source dependency closure compiles O0/O2,
    # rejects invalid F-KT provenance and inherited B19/MICRO runs pass.
    # This does NOT qualify positive hydraulic sampling or hydrothermal forcing.
    bash tests/fmig431/run_crop_accepted_hydraulic_provenance.sh || \
      fail 'crop accepted hydraulic provenance O0/O2 gate failed'
    bash tests/fmig431/run_crop_lifecycle_b19_micro_cross_preservation.sh || \
      fail 'crop hydraulic provenance B19/MICRO cross-preservation failed'
  fi
  if (( crop_physical_restart_changed )); then
    # Restrict this new read-only physical/calendar restart validator to an
    # exact-head owner O0/O2, stale-calendar/receipt-negative matrix and
    # inherited B19/MICRO actual-source cross-preservation. There is no
    # unconditional allowance for a new physical state/forcing owner.
    test -f tests/fmig431/run_crop_physical_calendar_restart_coherence.sh || \
      fail 'missing crop physical/calendar restart pair gate'
    bash tests/fmig431/run_crop_physical_calendar_restart_coherence.sh || \
      fail 'crop physical/calendar restart pair qualification failed'
    bash tests/fmig431/run_crop_lifecycle_b19_micro_cross_preservation.sh || \
      fail 'crop physical restart B19/MICRO cross-preservation failed'
  fi
  for candidate_path in "$BACKEND" src/runtime/mod_fmr_production_application_bootstrap.f90; do
    test "$(git rev-parse "HEAD:$candidate_path")" = "$(git rev-parse "$dependency_authority:$candidate_path")" || \
      fail "B19+MICRO shared-owner postimage changed: $candidate_path"
  done
  echo 'FCI_CANONICAL_B19_MICRO_RESTRICTED_ROOT_RECOMPOSITION=PASS'
}

# Preserve the F-ROSS12 selection authority. The default-MvG provider and
# serialized Reference backend have one later exact semantic successor from
# F-SI39. F-SI39 was independently qualified (F-VQ127), is an ancestor of
# current canonical, keeps its new KSATEXM path opt-in by default, and its
# production postimages are pinned exactly here.
test "$(git rev-parse HEAD:$SELECTION)" = "$SELECTION_FROSS12" || fail 'admitted F-ROSS12 selection successor drift'
if git merge-base --is-ancestor "$PPA_WU04B_ADMISSION" HEAD; then
  git merge-base --is-ancestor "$PPA_WU04B_QUALIFIED" "$PPA_WU04B_ADMISSION" || \
    fail 'PPA-WU04-B qualified head is not contained by canonical admission'
  provider_authority="$FSI39_PROVIDER"
  backend_authority="$PPA_WU04B_BACKEND"
  if git merge-base --is-ancestor "$FCI110_ADMISSION" HEAD; then
    provider_authority="$FCI110_PROVIDER"
    backend_authority="$FCI110_BACKEND"
    echo 'FCI_CANONICAL_FCI110_REFERENCE_BACKEND_BASELINE=ACTIVE'
  fi
  if git merge-base --is-ancestor "$DIR01_ADMISSION" HEAD; then
    provider_authority="$DIR01_PROVIDER"
    backend_authority="$DIR01_BACKEND"
    echo 'FCI_CANONICAL_DIR01_REFERENCE_SUCCESSOR=ACTIVE'
  fi
  if git merge-base --is-ancestor "$BALTOL02_ADMISSION" HEAD; then
    backend_authority="$BALTOL02_BACKEND"
    echo 'FCI_CANONICAL_BALTOL02_BACKEND_SUCCESSOR=ACTIVE'
  fi
  if git merge-base --is-ancestor a0630beff3b7b329ede3e57a10620116e5b1f456 HEAD; then
    # B19 is an exact production-tree authority. A later independently
    # qualified MICRO02-06 successor changes the shared backend/bootstrap
    # surface while preserving B19 behavior; accept only that exact successor.
    if git merge-base --is-ancestor f734c28d7159ce2cd8d326687c887828c214c2f1 HEAD; then
      check_b19_micro_root_recomposition
      test "$(git rev-parse HEAD:$BACKEND)" = "$(git rev-parse "$dependency_authority:$BACKEND")" || fail 'B19+MICRO current-target serialized backend drift'
      test "$(git rev-parse HEAD:src/runtime/mod_fmr_production_application_bootstrap.f90)" = "$(git rev-parse "$dependency_authority:src/runtime/mod_fmr_production_application_bootstrap.f90")" || fail 'B19+MICRO current-target application bootstrap drift'
      echo 'FCI_CANONICAL_PPA_WU05B19_MICRO06_EXACT_SUCCESSOR=ACTIVE'
    else
      check_b19_micro_root_recomposition
      echo 'FCI_CANONICAL_PPA_WU05B19_EXACT_RUNTIME_CANDIDATE=ACTIVE'
    fi
    git merge-base --is-ancestor a9a35a60409a16ef7fdf3a38d5bcffb6899c2416 HEAD || fail 'B19 lost B18 component admission'
    backend_authority="$(git rev-parse HEAD:$BACKEND)"
  elif git merge-base --is-ancestor e2bb41f2e3173a6c32465e5792e1fe7386a68679 HEAD; then
    git merge-base --is-ancestor febfff8103c4d60324a103d832521bb3f3754a67 HEAD || fail "PPA-WU05B15 lost B10 composed closeout"
    test "$(git rev-parse HEAD:src/process/mod_drainage_tabulated_response.f90)" = "03ea81ed05c50b41194000c5215c231819889b58" || fail "PPA-WU05B15 exact additive table-validator postimage drift"
    git merge-base --is-ancestor 024c6a5510757a02851426806248b0e2afe45a6b HEAD || fail "PPA-WU05B15 lost normal-drain and guarded reference admissions"
    git merge-base --is-ancestor 2d4d540903a0a7d4cc67bd2e5f8f900834cbc2f5 HEAD || fail "PPA-WU05B15 lost selected salt/root frost admission"
    if test "$(git rev-parse HEAD:src)" = "ac822aafd5403547a2c7ffad5c3ba02c9fa36496"; then
      # Independently exercise B15 normal and low-air routes on this exact
      # MICRO successor in the bounded frost qualification before admission.
      test "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_reference_backend.f90)" = "b7d8d3a1626a82e408434b584abda2c9fe5a520c" || \
        fail "PPA-WU05B15 MICRO successor serialized backend drift"
      test "$(git rev-parse HEAD:src/runtime/mod_fmr_production_application_bootstrap.f90)" = "32a218d3a08ca56e43ff4df35c56b3e3b67bf947" || \
        fail "PPA-WU05B15 MICRO successor application bootstrap drift"
      echo 'FCI_CANONICAL_PPA_WU05B15_MICRO_SOURCE_SUCCESSOR=ACTIVE'
    else
      test "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_reference_backend.f90)" = "57c349f3660aadbeb28e65b01a21a7f15ce4e832" || \
        fail "PPA-WU05B15 exact linear-response low-air postimage drift: src/runtime/mod_fmr_serialized_reference_backend.f90"
      test "$(git rev-parse HEAD:src/runtime/mod_fmr_production_application_bootstrap.f90)" = "a8b0f4eba2d28ac21a6494268b337a288ffadf59" || \
        fail "PPA-WU05B15 exact linear-response low-air postimage drift: src/runtime/mod_fmr_production_application_bootstrap.f90"
    fi
    test "$(git rev-parse HEAD:src/process/mod_frost_geometry_effect.f90)" = "b4067615db7059f7061f4555cec6ec9c1312fe4c" || \
      fail "PPA-WU05B15 exact linear-response low-air postimage drift: src/process/mod_frost_geometry_effect.f90"
    test "$(git rev-parse HEAD:src/process/mod_frost_low_air_drainage_effect.f90)" = "4b6cf0b24fc3c2b8e39c982dcc6c80294ab08a91" || \
      fail "PPA-WU05B15 exact linear-response low-air postimage drift: src/process/mod_frost_low_air_drainage_effect.f90"
    test "$(git rev-parse HEAD:src/process/mod_frost_drainage_effect.f90)" = "333149580aea22f57a0bdc0cd33a7d1c4245766a" || \
      fail "PPA-WU05B15 exact linear-response low-air postimage drift: src/process/mod_frost_drainage_effect.f90"
    test "$(git rev-parse HEAD:src/process/mod_frost_bottom_boundary_effect.f90)" = "5dbf9052bdc65fc5fb1830f74da70b3e912adb7b" || \
      fail "PPA-WU05B15 exact linear-response low-air postimage drift: src/process/mod_frost_bottom_boundary_effect.f90"
    test "$(git rev-parse HEAD:src/process/mod_root_frost_stress.f90)" = "a99d870ac2911dd0b9cfe1aef3a0fd299dcfcf38" || \
      fail "PPA-WU05B15 exact linear-response low-air postimage drift: src/process/mod_root_frost_stress.f90"
    if git merge-base --is-ancestor 4c0615bfdb3a3e12db2b988eff97db749cca0511 HEAD; then
      test "$(git rev-parse HEAD:src/process/mod_root_uptake_compensation.f90)" = "a19db82afe85b2c7b34fa8a2da0922581c662fbb" || \
        fail "PPA-WU05B15 concurrent exact-root admitted postimage drift"
      echo 'FCI_CANONICAL_PPA_WU05B15_EXACT01_ROOT_RECONCILIATION=ACTIVE'
    else
    test "$(git rev-parse HEAD:src/process/mod_root_uptake_compensation.f90)" = "4c6172384a1255bfe4b2fb809ae159fe624a91a0" || \
      fail "PPA-WU05B15 exact linear-response low-air postimage drift: src/process/mod_root_uptake_compensation.f90"
    fi
    test "$(git rev-parse HEAD:src/runtime/mod_root_uptake_compensation_execution.f90)" = "6affaec2e7a55544e722ed1204ca9e5de555b478" || \
      fail "PPA-WU05B15 exact linear-response low-air postimage drift: src/runtime/mod_root_uptake_compensation_execution.f90"
    test "$(git rev-parse HEAD:src/process/mod_frost_hydraulic_effect.f90)" = "2c8adba7986e7d85749c4c36d26530748fbbab9e" || \
      fail "PPA-WU05B15 exact linear-response low-air postimage drift: src/process/mod_frost_hydraulic_effect.f90"
    test "$(git rev-parse HEAD:src/solver/mod_frost_hydraulic_provider.f90)" = "08492a7272860629c9ffee34968c9cc29952bd58" || \
      fail "PPA-WU05B15 exact linear-response low-air postimage drift: src/solver/mod_frost_hydraulic_provider.f90"
    git merge-base --is-ancestor 177b680c8992e03f8ab0c41dfcd02c660b3cf8da HEAD || fail "PPA-WU05B15 lost admitted B8 source/closeout"
    test "$(git rev-parse HEAD:src/runtime/mod_fmr_drainage_response_binding.f90)" = "263cf55b2c336d149ba41b4d04f510e10c4207e2" || fail "PPA-WU05B15 generator postimage drift: src/runtime/mod_fmr_drainage_response_binding.f90"
    test "$(git rev-parse HEAD:src/process/mod_drainage_process.f90)" = "dbacd49da3bb0b94f822f9ee0478d15183e9c0fa" || fail "PPA-WU05B15 generator postimage drift: src/process/mod_drainage_process.f90"
    test "$(git rev-parse HEAD:src/process/mod_drainage_multilevel_aggregation.f90)" = "70d35512ef7c5958f7e4bf284cba104a7b641fdb" || fail "PPA-WU05B15 generator postimage drift: src/process/mod_drainage_multilevel_aggregation.f90"
    git merge-base --is-ancestor 879a9c65b0badb650c9b4e4fe194b7e6ffcc02f6 HEAD || fail "PPA-WU05B15 lost exact B11 admitted closeout"
    test "$(git rev-parse HEAD:src/process/mod_drainage_hooghoudt_ipos1_response.f90)" = "74eab52a181f21406d58fb267fb5e9829a98c91a" || fail "PPA-WU05B15 exact scientific postimage drift: src/process/mod_drainage_hooghoudt_ipos1_response.f90"
    test "$(git rev-parse HEAD:src/process/mod_drainage_hooghoudt_ipos23_response.f90)" = "af9517fae0beba11ba08313a8b6b5d65aa73177e" || fail "PPA-WU05B15 exact scientific postimage drift: src/process/mod_drainage_hooghoudt_ipos23_response.f90"
    test "$(git rev-parse HEAD:src/process/mod_drainage_ernst_ipos45_response.f90)" = "6640afbe25e8770a8ac8e5a6d9a1126cf39b1098" || fail "PPA-WU05B15 exact scientific postimage drift: src/process/mod_drainage_ernst_ipos45_response.f90"
    test "$(git rev-parse HEAD:src/process/mod_drainage_hooghoudt_equivalent_depth.f90)" = "6b7b2bb1fd259879d3f26c46abfc071ea2b2f108" || fail "PPA-WU05B15 exact scientific postimage drift: src/process/mod_drainage_hooghoudt_equivalent_depth.f90"
    test "$(git rev-parse HEAD:src/process/mod_drainage_ernst_ipos45_preparation.f90)" = "fa1d5d400bb32be42e78889c0ff2a3bcab335142" || fail "PPA-WU05B15 exact scientific postimage drift: src/process/mod_drainage_ernst_ipos45_preparation.f90"
    git merge-base --is-ancestor 703b70c49dbc5fb4f2c54381608432d13bb67cf7 HEAD || fail "PPA-WU05B15 lost exact B12 closeout"
    test "$(git rev-parse HEAD:src/process/mod_drainage_empirical_interflow_response.f90)" = "37e12f2b89bd0fcac12a2d95a70afc14600ab10c" || fail "PPA-WU05B15 exact empirical response postimage drift"
    git merge-base --is-ancestor 0511717b6c428d18dc223c9e81fd73da3bf5c3fd HEAD || fail "PPA-WU05B15 lost exact B13 closeout"
    test "$(git rev-parse HEAD:src/process/mod_drainage_extended_exchange.f90)" = "d55e24c9d5cce03c71e4cc5f304dfdd699ca5a56" || fail "PPA-WU05B15 exact signed process postimage drift"
    backend_authority="$(git rev-parse HEAD:$BACKEND)"
    echo "FCI_CANONICAL_PPA_WU05B15_EXACT_HIGHEST_RESPONSE_CANDIDATE=ACTIVE"

    git merge-base --is-ancestor 86b71ad71fa74d09eee3733c3e8f0f13355257f3 HEAD || fail "PPA-WU05B15 lost admitted B9 source/closeout"
    git merge-base --is-ancestor f72d72622264111edbadca1bfc49690a47b287a9 HEAD || fail "PPA-WU05B15 lost exact B14 closeout"
  elif git merge-base --is-ancestor 1dd301194c86c292a6d0bd29553a03921ea2d4d1 HEAD; then
    git merge-base --is-ancestor febfff8103c4d60324a103d832521bb3f3754a67 HEAD || fail "PPA-WU05B14 lost B10 composed closeout"
    test "$(git rev-parse HEAD:src/process/mod_drainage_tabulated_response.f90)" = "03ea81ed05c50b41194000c5215c231819889b58" || fail "PPA-WU05B14 exact additive table-validator postimage drift"
    git merge-base --is-ancestor 024c6a5510757a02851426806248b0e2afe45a6b HEAD || fail "PPA-WU05B14 lost normal-drain and guarded reference admissions"
    git merge-base --is-ancestor 2d4d540903a0a7d4cc67bd2e5f8f900834cbc2f5 HEAD || fail "PPA-WU05B14 lost selected salt/root frost admission"
    test "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_reference_backend.f90)" = "8965a420a7ac819feebbfa51f4d30f8af0165c49" || \
      fail "PPA-WU05B14 exact linear-response low-air postimage drift: src/runtime/mod_fmr_serialized_reference_backend.f90"
    test "$(git rev-parse HEAD:src/runtime/mod_fmr_production_application_bootstrap.f90)" = "a8b0f4eba2d28ac21a6494268b337a288ffadf59" || \
      fail "PPA-WU05B14 exact linear-response low-air postimage drift: src/runtime/mod_fmr_production_application_bootstrap.f90"
    test "$(git rev-parse HEAD:src/process/mod_frost_geometry_effect.f90)" = "b4067615db7059f7061f4555cec6ec9c1312fe4c" || \
      fail "PPA-WU05B14 exact linear-response low-air postimage drift: src/process/mod_frost_geometry_effect.f90"
    test "$(git rev-parse HEAD:src/process/mod_frost_low_air_drainage_effect.f90)" = "4b6cf0b24fc3c2b8e39c982dcc6c80294ab08a91" || \
      fail "PPA-WU05B14 exact linear-response low-air postimage drift: src/process/mod_frost_low_air_drainage_effect.f90"
    test "$(git rev-parse HEAD:src/process/mod_frost_drainage_effect.f90)" = "333149580aea22f57a0bdc0cd33a7d1c4245766a" || \
      fail "PPA-WU05B14 exact linear-response low-air postimage drift: src/process/mod_frost_drainage_effect.f90"
    test "$(git rev-parse HEAD:src/process/mod_frost_bottom_boundary_effect.f90)" = "5dbf9052bdc65fc5fb1830f74da70b3e912adb7b" || \
      fail "PPA-WU05B14 exact linear-response low-air postimage drift: src/process/mod_frost_bottom_boundary_effect.f90"
    test "$(git rev-parse HEAD:src/process/mod_root_frost_stress.f90)" = "a99d870ac2911dd0b9cfe1aef3a0fd299dcfcf38" || \
      fail "PPA-WU05B14 exact linear-response low-air postimage drift: src/process/mod_root_frost_stress.f90"
    if git merge-base --is-ancestor 4c0615bfdb3a3e12db2b988eff97db749cca0511 HEAD; then
      test "$(git rev-parse HEAD:src/process/mod_root_uptake_compensation.f90)" = "a19db82afe85b2c7b34fa8a2da0922581c662fbb" || \
        fail "PPA-WU05B14 concurrent exact-root admitted postimage drift"
      echo 'FCI_CANONICAL_PPA_WU05B14_EXACT01_ROOT_RECONCILIATION=ACTIVE'
    else
    test "$(git rev-parse HEAD:src/process/mod_root_uptake_compensation.f90)" = "4c6172384a1255bfe4b2fb809ae159fe624a91a0" || \
      fail "PPA-WU05B14 exact linear-response low-air postimage drift: src/process/mod_root_uptake_compensation.f90"
    fi
    test "$(git rev-parse HEAD:src/runtime/mod_root_uptake_compensation_execution.f90)" = "6affaec2e7a55544e722ed1204ca9e5de555b478" || \
      fail "PPA-WU05B14 exact linear-response low-air postimage drift: src/runtime/mod_root_uptake_compensation_execution.f90"
    test "$(git rev-parse HEAD:src/process/mod_frost_hydraulic_effect.f90)" = "2c8adba7986e7d85749c4c36d26530748fbbab9e" || \
      fail "PPA-WU05B14 exact linear-response low-air postimage drift: src/process/mod_frost_hydraulic_effect.f90"
    test "$(git rev-parse HEAD:src/solver/mod_frost_hydraulic_provider.f90)" = "08492a7272860629c9ffee34968c9cc29952bd58" || \
      fail "PPA-WU05B14 exact linear-response low-air postimage drift: src/solver/mod_frost_hydraulic_provider.f90"
    git merge-base --is-ancestor 177b680c8992e03f8ab0c41dfcd02c660b3cf8da HEAD || fail "PPA-WU05B14 lost admitted B8 source/closeout"
    test "$(git rev-parse HEAD:src/runtime/mod_fmr_drainage_response_binding.f90)" = "263cf55b2c336d149ba41b4d04f510e10c4207e2" || fail "PPA-WU05B14 generator postimage drift: src/runtime/mod_fmr_drainage_response_binding.f90"
    test "$(git rev-parse HEAD:src/process/mod_drainage_process.f90)" = "dbacd49da3bb0b94f822f9ee0478d15183e9c0fa" || fail "PPA-WU05B14 generator postimage drift: src/process/mod_drainage_process.f90"
    test "$(git rev-parse HEAD:src/process/mod_drainage_multilevel_aggregation.f90)" = "70d35512ef7c5958f7e4bf284cba104a7b641fdb" || fail "PPA-WU05B14 generator postimage drift: src/process/mod_drainage_multilevel_aggregation.f90"
    git merge-base --is-ancestor 879a9c65b0badb650c9b4e4fe194b7e6ffcc02f6 HEAD || fail "PPA-WU05B14 lost exact B11 admitted closeout"
    test "$(git rev-parse HEAD:src/process/mod_drainage_hooghoudt_ipos1_response.f90)" = "74eab52a181f21406d58fb267fb5e9829a98c91a" || fail "PPA-WU05B14 exact scientific postimage drift: src/process/mod_drainage_hooghoudt_ipos1_response.f90"
    test "$(git rev-parse HEAD:src/process/mod_drainage_hooghoudt_ipos23_response.f90)" = "af9517fae0beba11ba08313a8b6b5d65aa73177e" || fail "PPA-WU05B14 exact scientific postimage drift: src/process/mod_drainage_hooghoudt_ipos23_response.f90"
    test "$(git rev-parse HEAD:src/process/mod_drainage_ernst_ipos45_response.f90)" = "6640afbe25e8770a8ac8e5a6d9a1126cf39b1098" || fail "PPA-WU05B14 exact scientific postimage drift: src/process/mod_drainage_ernst_ipos45_response.f90"
    test "$(git rev-parse HEAD:src/process/mod_drainage_hooghoudt_equivalent_depth.f90)" = "6b7b2bb1fd259879d3f26c46abfc071ea2b2f108" || fail "PPA-WU05B14 exact scientific postimage drift: src/process/mod_drainage_hooghoudt_equivalent_depth.f90"
    test "$(git rev-parse HEAD:src/process/mod_drainage_ernst_ipos45_preparation.f90)" = "fa1d5d400bb32be42e78889c0ff2a3bcab335142" || fail "PPA-WU05B14 exact scientific postimage drift: src/process/mod_drainage_ernst_ipos45_preparation.f90"
    git merge-base --is-ancestor 703b70c49dbc5fb4f2c54381608432d13bb67cf7 HEAD || fail "PPA-WU05B14 lost exact B12 closeout"
    test "$(git rev-parse HEAD:src/process/mod_drainage_empirical_interflow_response.f90)" = "37e12f2b89bd0fcac12a2d95a70afc14600ab10c" || fail "PPA-WU05B14 exact empirical response postimage drift"
    git merge-base --is-ancestor 0511717b6c428d18dc223c9e81fd73da3bf5c3fd HEAD || fail "PPA-WU05B14 lost exact B13 closeout"
    test "$(git rev-parse HEAD:src/process/mod_drainage_extended_exchange.f90)" = "d55e24c9d5cce03c71e4cc5f304dfdd699ca5a56" || fail "PPA-WU05B14 exact signed process postimage drift"
    backend_authority="$(git rev-parse HEAD:$BACKEND)"
    echo "FCI_CANONICAL_PPA_WU05B14_EXACT_EXTENDED_RESPONSE_CANDIDATE=ACTIVE"

    git merge-base --is-ancestor 86b71ad71fa74d09eee3733c3e8f0f13355257f3 HEAD || fail "PPA-WU05B14 lost admitted B9 source/closeout"
  elif git merge-base --is-ancestor 74e851cda073dd0d0adf1e9d578d1bd059ab63f4 HEAD; then
    git merge-base --is-ancestor febfff8103c4d60324a103d832521bb3f3754a67 HEAD || fail "PPA-WU05B13 lost B10 composed closeout"
    test "$(git rev-parse HEAD:src/process/mod_drainage_tabulated_response.f90)" = "03ea81ed05c50b41194000c5215c231819889b58" || fail "PPA-WU05B13 exact additive table-validator postimage drift"
    git merge-base --is-ancestor 024c6a5510757a02851426806248b0e2afe45a6b HEAD || fail "PPA-WU05B13 lost normal-drain and guarded reference admissions"
    git merge-base --is-ancestor 2d4d540903a0a7d4cc67bd2e5f8f900834cbc2f5 HEAD || fail "PPA-WU05B13 lost selected salt/root frost admission"
    test "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_reference_backend.f90)" = "9e2198ca2bb7ce6142f0cde17d14902b81c55aeb" || \
      fail "PPA-WU05B13 exact linear-response low-air postimage drift: src/runtime/mod_fmr_serialized_reference_backend.f90"
    test "$(git rev-parse HEAD:src/runtime/mod_fmr_production_application_bootstrap.f90)" = "a8b0f4eba2d28ac21a6494268b337a288ffadf59" || \
      fail "PPA-WU05B13 exact linear-response low-air postimage drift: src/runtime/mod_fmr_production_application_bootstrap.f90"
    test "$(git rev-parse HEAD:src/process/mod_frost_geometry_effect.f90)" = "b4067615db7059f7061f4555cec6ec9c1312fe4c" || \
      fail "PPA-WU05B13 exact linear-response low-air postimage drift: src/process/mod_frost_geometry_effect.f90"
    test "$(git rev-parse HEAD:src/process/mod_frost_low_air_drainage_effect.f90)" = "4b6cf0b24fc3c2b8e39c982dcc6c80294ab08a91" || \
      fail "PPA-WU05B13 exact linear-response low-air postimage drift: src/process/mod_frost_low_air_drainage_effect.f90"
    test "$(git rev-parse HEAD:src/process/mod_frost_drainage_effect.f90)" = "333149580aea22f57a0bdc0cd33a7d1c4245766a" || \
      fail "PPA-WU05B13 exact linear-response low-air postimage drift: src/process/mod_frost_drainage_effect.f90"
    test "$(git rev-parse HEAD:src/process/mod_frost_bottom_boundary_effect.f90)" = "5dbf9052bdc65fc5fb1830f74da70b3e912adb7b" || \
      fail "PPA-WU05B13 exact linear-response low-air postimage drift: src/process/mod_frost_bottom_boundary_effect.f90"
    test "$(git rev-parse HEAD:src/process/mod_root_frost_stress.f90)" = "a99d870ac2911dd0b9cfe1aef3a0fd299dcfcf38" || \
      fail "PPA-WU05B13 exact linear-response low-air postimage drift: src/process/mod_root_frost_stress.f90"
    if git merge-base --is-ancestor 4c0615bfdb3a3e12db2b988eff97db749cca0511 HEAD; then
      test "$(git rev-parse HEAD:src/process/mod_root_uptake_compensation.f90)" = "a19db82afe85b2c7b34fa8a2da0922581c662fbb" || \
        fail "PPA-WU05B13 concurrent exact-root admitted postimage drift"
      echo 'FCI_CANONICAL_PPA_WU05B13_EXACT01_ROOT_RECONCILIATION=ACTIVE'
    else
    test "$(git rev-parse HEAD:src/process/mod_root_uptake_compensation.f90)" = "4c6172384a1255bfe4b2fb809ae159fe624a91a0" || \
      fail "PPA-WU05B13 exact linear-response low-air postimage drift: src/process/mod_root_uptake_compensation.f90"
    fi
    test "$(git rev-parse HEAD:src/runtime/mod_root_uptake_compensation_execution.f90)" = "6affaec2e7a55544e722ed1204ca9e5de555b478" || \
      fail "PPA-WU05B13 exact linear-response low-air postimage drift: src/runtime/mod_root_uptake_compensation_execution.f90"
    test "$(git rev-parse HEAD:src/process/mod_frost_hydraulic_effect.f90)" = "2c8adba7986e7d85749c4c36d26530748fbbab9e" || \
      fail "PPA-WU05B13 exact linear-response low-air postimage drift: src/process/mod_frost_hydraulic_effect.f90"
    test "$(git rev-parse HEAD:src/solver/mod_frost_hydraulic_provider.f90)" = "08492a7272860629c9ffee34968c9cc29952bd58" || \
      fail "PPA-WU05B13 exact linear-response low-air postimage drift: src/solver/mod_frost_hydraulic_provider.f90"
    git merge-base --is-ancestor 177b680c8992e03f8ab0c41dfcd02c660b3cf8da HEAD || fail "PPA-WU05B13 lost admitted B8 source/closeout"
    test "$(git rev-parse HEAD:src/runtime/mod_fmr_drainage_response_binding.f90)" = "263cf55b2c336d149ba41b4d04f510e10c4207e2" || fail "PPA-WU05B13 generator postimage drift: src/runtime/mod_fmr_drainage_response_binding.f90"
    test "$(git rev-parse HEAD:src/process/mod_drainage_process.f90)" = "dbacd49da3bb0b94f822f9ee0478d15183e9c0fa" || fail "PPA-WU05B13 generator postimage drift: src/process/mod_drainage_process.f90"
    test "$(git rev-parse HEAD:src/process/mod_drainage_multilevel_aggregation.f90)" = "70d35512ef7c5958f7e4bf284cba104a7b641fdb" || fail "PPA-WU05B13 generator postimage drift: src/process/mod_drainage_multilevel_aggregation.f90"
    git merge-base --is-ancestor 879a9c65b0badb650c9b4e4fe194b7e6ffcc02f6 HEAD || fail "PPA-WU05B13 lost exact B11 admitted closeout"
    test "$(git rev-parse HEAD:src/process/mod_drainage_hooghoudt_ipos1_response.f90)" = "74eab52a181f21406d58fb267fb5e9829a98c91a" || fail "PPA-WU05B13 exact scientific postimage drift: src/process/mod_drainage_hooghoudt_ipos1_response.f90"
    test "$(git rev-parse HEAD:src/process/mod_drainage_hooghoudt_ipos23_response.f90)" = "af9517fae0beba11ba08313a8b6b5d65aa73177e" || fail "PPA-WU05B13 exact scientific postimage drift: src/process/mod_drainage_hooghoudt_ipos23_response.f90"
    test "$(git rev-parse HEAD:src/process/mod_drainage_ernst_ipos45_response.f90)" = "6640afbe25e8770a8ac8e5a6d9a1126cf39b1098" || fail "PPA-WU05B13 exact scientific postimage drift: src/process/mod_drainage_ernst_ipos45_response.f90"
    test "$(git rev-parse HEAD:src/process/mod_drainage_hooghoudt_equivalent_depth.f90)" = "6b7b2bb1fd259879d3f26c46abfc071ea2b2f108" || fail "PPA-WU05B13 exact scientific postimage drift: src/process/mod_drainage_hooghoudt_equivalent_depth.f90"
    test "$(git rev-parse HEAD:src/process/mod_drainage_ernst_ipos45_preparation.f90)" = "fa1d5d400bb32be42e78889c0ff2a3bcab335142" || fail "PPA-WU05B13 exact scientific postimage drift: src/process/mod_drainage_ernst_ipos45_preparation.f90"
    git merge-base --is-ancestor 703b70c49dbc5fb4f2c54381608432d13bb67cf7 HEAD || fail "PPA-WU05B13 lost exact B12 closeout"
    test "$(git rev-parse HEAD:src/process/mod_drainage_empirical_interflow_response.f90)" = "37e12f2b89bd0fcac12a2d95a70afc14600ab10c" || fail "PPA-WU05B13 exact empirical response postimage drift"
    backend_authority="$(git rev-parse HEAD:$BACKEND)"
    echo "FCI_CANONICAL_PPA_WU05B13_EXACT_EMPIRICAL_RESPONSE_CANDIDATE=ACTIVE"

    git merge-base --is-ancestor 86b71ad71fa74d09eee3733c3e8f0f13355257f3 HEAD || fail "PPA-WU05B13 lost admitted B9 source/closeout"
  elif git merge-base --is-ancestor a6b66768af290f707cb033c9aa7173c9d20105e1 HEAD; then
    git merge-base --is-ancestor febfff8103c4d60324a103d832521bb3f3754a67 HEAD || fail "PPA-WU05B12 lost B10 composed closeout"
    test "$(git rev-parse HEAD:src/process/mod_drainage_tabulated_response.f90)" = "03ea81ed05c50b41194000c5215c231819889b58" || fail "PPA-WU05B12 exact additive table-validator postimage drift"
    git merge-base --is-ancestor 024c6a5510757a02851426806248b0e2afe45a6b HEAD || fail "PPA-WU05B12 lost normal-drain and guarded reference admissions"
    git merge-base --is-ancestor 2d4d540903a0a7d4cc67bd2e5f8f900834cbc2f5 HEAD || fail "PPA-WU05B12 lost selected salt/root frost admission"
    test "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_reference_backend.f90)" = "bdbd42bad63b4f4dd000ae439abb0679c1b67374" || \
      fail "PPA-WU05B12 exact linear-response low-air postimage drift: src/runtime/mod_fmr_serialized_reference_backend.f90"
    test "$(git rev-parse HEAD:src/runtime/mod_fmr_production_application_bootstrap.f90)" = "a8b0f4eba2d28ac21a6494268b337a288ffadf59" || \
      fail "PPA-WU05B12 exact linear-response low-air postimage drift: src/runtime/mod_fmr_production_application_bootstrap.f90"
    test "$(git rev-parse HEAD:src/process/mod_frost_geometry_effect.f90)" = "b4067615db7059f7061f4555cec6ec9c1312fe4c" || \
      fail "PPA-WU05B12 exact linear-response low-air postimage drift: src/process/mod_frost_geometry_effect.f90"
    test "$(git rev-parse HEAD:src/process/mod_frost_low_air_drainage_effect.f90)" = "4b6cf0b24fc3c2b8e39c982dcc6c80294ab08a91" || \
      fail "PPA-WU05B12 exact linear-response low-air postimage drift: src/process/mod_frost_low_air_drainage_effect.f90"
    test "$(git rev-parse HEAD:src/process/mod_frost_drainage_effect.f90)" = "333149580aea22f57a0bdc0cd33a7d1c4245766a" || \
      fail "PPA-WU05B12 exact linear-response low-air postimage drift: src/process/mod_frost_drainage_effect.f90"
    test "$(git rev-parse HEAD:src/process/mod_frost_bottom_boundary_effect.f90)" = "5dbf9052bdc65fc5fb1830f74da70b3e912adb7b" || \
      fail "PPA-WU05B12 exact linear-response low-air postimage drift: src/process/mod_frost_bottom_boundary_effect.f90"
    test "$(git rev-parse HEAD:src/process/mod_root_frost_stress.f90)" = "a99d870ac2911dd0b9cfe1aef3a0fd299dcfcf38" || \
      fail "PPA-WU05B12 exact linear-response low-air postimage drift: src/process/mod_root_frost_stress.f90"
    if git merge-base --is-ancestor 4c0615bfdb3a3e12db2b988eff97db749cca0511 HEAD; then
      test "$(git rev-parse HEAD:src/process/mod_root_uptake_compensation.f90)" = "a19db82afe85b2c7b34fa8a2da0922581c662fbb" || \
        fail "PPA-WU05B12 concurrent exact-root admitted postimage drift"
      echo 'FCI_CANONICAL_PPA_WU05B12_EXACT01_ROOT_RECONCILIATION=ACTIVE'
    else
    test "$(git rev-parse HEAD:src/process/mod_root_uptake_compensation.f90)" = "4c6172384a1255bfe4b2fb809ae159fe624a91a0" || \
      fail "PPA-WU05B12 exact linear-response low-air postimage drift: src/process/mod_root_uptake_compensation.f90"
    fi
    test "$(git rev-parse HEAD:src/runtime/mod_root_uptake_compensation_execution.f90)" = "6affaec2e7a55544e722ed1204ca9e5de555b478" || \
      fail "PPA-WU05B12 exact linear-response low-air postimage drift: src/runtime/mod_root_uptake_compensation_execution.f90"
    test "$(git rev-parse HEAD:src/process/mod_frost_hydraulic_effect.f90)" = "2c8adba7986e7d85749c4c36d26530748fbbab9e" || \
      fail "PPA-WU05B12 exact linear-response low-air postimage drift: src/process/mod_frost_hydraulic_effect.f90"
    test "$(git rev-parse HEAD:src/solver/mod_frost_hydraulic_provider.f90)" = "08492a7272860629c9ffee34968c9cc29952bd58" || \
      fail "PPA-WU05B12 exact linear-response low-air postimage drift: src/solver/mod_frost_hydraulic_provider.f90"
    git merge-base --is-ancestor 177b680c8992e03f8ab0c41dfcd02c660b3cf8da HEAD || fail "PPA-WU05B12 lost admitted B8 source/closeout"
    test "$(git rev-parse HEAD:src/runtime/mod_fmr_drainage_response_binding.f90)" = "263cf55b2c336d149ba41b4d04f510e10c4207e2" || fail "PPA-WU05B12 generator postimage drift: src/runtime/mod_fmr_drainage_response_binding.f90"
    test "$(git rev-parse HEAD:src/process/mod_drainage_process.f90)" = "dbacd49da3bb0b94f822f9ee0478d15183e9c0fa" || fail "PPA-WU05B12 generator postimage drift: src/process/mod_drainage_process.f90"
    test "$(git rev-parse HEAD:src/process/mod_drainage_multilevel_aggregation.f90)" = "70d35512ef7c5958f7e4bf284cba104a7b641fdb" || fail "PPA-WU05B12 generator postimage drift: src/process/mod_drainage_multilevel_aggregation.f90"
    git merge-base --is-ancestor 879a9c65b0badb650c9b4e4fe194b7e6ffcc02f6 HEAD || fail "PPA-WU05B12 lost exact B11 admitted closeout"
    test "$(git rev-parse HEAD:src/process/mod_drainage_hooghoudt_ipos1_response.f90)" = "74eab52a181f21406d58fb267fb5e9829a98c91a" || fail "PPA-WU05B12 exact scientific postimage drift: src/process/mod_drainage_hooghoudt_ipos1_response.f90"
    test "$(git rev-parse HEAD:src/process/mod_drainage_hooghoudt_ipos23_response.f90)" = "af9517fae0beba11ba08313a8b6b5d65aa73177e" || fail "PPA-WU05B12 exact scientific postimage drift: src/process/mod_drainage_hooghoudt_ipos23_response.f90"
    test "$(git rev-parse HEAD:src/process/mod_drainage_ernst_ipos45_response.f90)" = "6640afbe25e8770a8ac8e5a6d9a1126cf39b1098" || fail "PPA-WU05B12 exact scientific postimage drift: src/process/mod_drainage_ernst_ipos45_response.f90"
    test "$(git rev-parse HEAD:src/process/mod_drainage_hooghoudt_equivalent_depth.f90)" = "6b7b2bb1fd259879d3f26c46abfc071ea2b2f108" || fail "PPA-WU05B12 exact scientific postimage drift: src/process/mod_drainage_hooghoudt_equivalent_depth.f90"
    test "$(git rev-parse HEAD:src/process/mod_drainage_ernst_ipos45_preparation.f90)" = "fa1d5d400bb32be42e78889c0ff2a3bcab335142" || fail "PPA-WU05B12 exact scientific postimage drift: src/process/mod_drainage_ernst_ipos45_preparation.f90"
    backend_authority="$(git rev-parse HEAD:$BACKEND)"
    echo "FCI_CANONICAL_PPA_WU05B12_EXACT_ANALYTIC_RESPONSE_CANDIDATE=ACTIVE"

    git merge-base --is-ancestor 86b71ad71fa74d09eee3733c3e8f0f13355257f3 HEAD || fail "PPA-WU05B12 lost admitted B9 source/closeout"
  elif git merge-base --is-ancestor 42cbcf1327663340c48ef7869eb34261bff41a91 HEAD; then
    git merge-base --is-ancestor febfff8103c4d60324a103d832521bb3f3754a67 HEAD || fail "PPA-WU05B11 lost B10 composed closeout"
    test "$(git rev-parse HEAD:src/process/mod_drainage_tabulated_response.f90)" = "03ea81ed05c50b41194000c5215c231819889b58" || fail "PPA-WU05B11 exact additive table-validator postimage drift"
    git merge-base --is-ancestor 024c6a5510757a02851426806248b0e2afe45a6b HEAD || fail "PPA-WU05B11 lost normal-drain and guarded reference admissions"
    git merge-base --is-ancestor 2d4d540903a0a7d4cc67bd2e5f8f900834cbc2f5 HEAD || fail "PPA-WU05B11 lost selected salt/root frost admission"
    test "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_reference_backend.f90)" = "84b6dc73960e897efb19f5d91c51cc2214811ae1" || \
      fail "PPA-WU05B11 exact linear-response low-air postimage drift: src/runtime/mod_fmr_serialized_reference_backend.f90"
    test "$(git rev-parse HEAD:src/runtime/mod_fmr_production_application_bootstrap.f90)" = "a8b0f4eba2d28ac21a6494268b337a288ffadf59" || \
      fail "PPA-WU05B11 exact linear-response low-air postimage drift: src/runtime/mod_fmr_production_application_bootstrap.f90"
    test "$(git rev-parse HEAD:src/process/mod_frost_geometry_effect.f90)" = "b4067615db7059f7061f4555cec6ec9c1312fe4c" || \
      fail "PPA-WU05B11 exact linear-response low-air postimage drift: src/process/mod_frost_geometry_effect.f90"
    test "$(git rev-parse HEAD:src/process/mod_frost_low_air_drainage_effect.f90)" = "4b6cf0b24fc3c2b8e39c982dcc6c80294ab08a91" || \
      fail "PPA-WU05B11 exact linear-response low-air postimage drift: src/process/mod_frost_low_air_drainage_effect.f90"
    test "$(git rev-parse HEAD:src/process/mod_frost_drainage_effect.f90)" = "333149580aea22f57a0bdc0cd33a7d1c4245766a" || \
      fail "PPA-WU05B11 exact linear-response low-air postimage drift: src/process/mod_frost_drainage_effect.f90"
    test "$(git rev-parse HEAD:src/process/mod_frost_bottom_boundary_effect.f90)" = "5dbf9052bdc65fc5fb1830f74da70b3e912adb7b" || \
      fail "PPA-WU05B11 exact linear-response low-air postimage drift: src/process/mod_frost_bottom_boundary_effect.f90"
    test "$(git rev-parse HEAD:src/process/mod_root_frost_stress.f90)" = "a99d870ac2911dd0b9cfe1aef3a0fd299dcfcf38" || \
      fail "PPA-WU05B11 exact linear-response low-air postimage drift: src/process/mod_root_frost_stress.f90"
    if git merge-base --is-ancestor 4c0615bfdb3a3e12db2b988eff97db749cca0511 HEAD; then
      test "$(git rev-parse HEAD:src/process/mod_root_uptake_compensation.f90)" = "a19db82afe85b2c7b34fa8a2da0922581c662fbb" || \
        fail "PPA-WU05B11 concurrent exact-root admitted postimage drift"
      echo 'FCI_CANONICAL_PPA_WU05B11_EXACT01_ROOT_RECONCILIATION=ACTIVE'
    else
    test "$(git rev-parse HEAD:src/process/mod_root_uptake_compensation.f90)" = "4c6172384a1255bfe4b2fb809ae159fe624a91a0" || \
      fail "PPA-WU05B11 exact linear-response low-air postimage drift: src/process/mod_root_uptake_compensation.f90"
    fi
    test "$(git rev-parse HEAD:src/runtime/mod_root_uptake_compensation_execution.f90)" = "6affaec2e7a55544e722ed1204ca9e5de555b478" || \
      fail "PPA-WU05B11 exact linear-response low-air postimage drift: src/runtime/mod_root_uptake_compensation_execution.f90"
    test "$(git rev-parse HEAD:src/process/mod_frost_hydraulic_effect.f90)" = "2c8adba7986e7d85749c4c36d26530748fbbab9e" || \
      fail "PPA-WU05B11 exact linear-response low-air postimage drift: src/process/mod_frost_hydraulic_effect.f90"
    test "$(git rev-parse HEAD:src/solver/mod_frost_hydraulic_provider.f90)" = "08492a7272860629c9ffee34968c9cc29952bd58" || \
      fail "PPA-WU05B11 exact linear-response low-air postimage drift: src/solver/mod_frost_hydraulic_provider.f90"
    git merge-base --is-ancestor 177b680c8992e03f8ab0c41dfcd02c660b3cf8da HEAD || fail "PPA-WU05B11 lost admitted B8 source/closeout"
    test "$(git rev-parse HEAD:src/runtime/mod_fmr_drainage_response_binding.f90)" = "263cf55b2c336d149ba41b4d04f510e10c4207e2" || fail "PPA-WU05B11 generator postimage drift: src/runtime/mod_fmr_drainage_response_binding.f90"
    test "$(git rev-parse HEAD:src/process/mod_drainage_process.f90)" = "dbacd49da3bb0b94f822f9ee0478d15183e9c0fa" || fail "PPA-WU05B11 generator postimage drift: src/process/mod_drainage_process.f90"
    test "$(git rev-parse HEAD:src/process/mod_drainage_multilevel_aggregation.f90)" = "70d35512ef7c5958f7e4bf284cba104a7b641fdb" || fail "PPA-WU05B11 generator postimage drift: src/process/mod_drainage_multilevel_aggregation.f90"
    backend_authority="$(git rev-parse HEAD:$BACKEND)"
    echo "FCI_CANONICAL_PPA_WU05B11_EXACT_TABULATED_RESPONSE_CANDIDATE=ACTIVE"

    git merge-base --is-ancestor 86b71ad71fa74d09eee3733c3e8f0f13355257f3 HEAD || fail "PPA-WU05B11 lost admitted B9 source/closeout"
  elif git merge-base --is-ancestor ca50308d11888b9b284c740f5d67a6f37c46063a HEAD; then
    git merge-base --is-ancestor 024c6a5510757a02851426806248b0e2afe45a6b HEAD || fail "PPA-WU05B10 lost normal-drain and guarded reference admissions"
    git merge-base --is-ancestor 2d4d540903a0a7d4cc67bd2e5f8f900834cbc2f5 HEAD || fail "PPA-WU05B10 lost selected salt/root frost admission"
    test "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_reference_backend.f90)" = "f77b00119af3483703ff503016e71696003d7212" || \
      fail "PPA-WU05B10 exact linear-response low-air postimage drift: src/runtime/mod_fmr_serialized_reference_backend.f90"
    test "$(git rev-parse HEAD:src/runtime/mod_fmr_production_application_bootstrap.f90)" = "a8b0f4eba2d28ac21a6494268b337a288ffadf59" || \
      fail "PPA-WU05B10 exact linear-response low-air postimage drift: src/runtime/mod_fmr_production_application_bootstrap.f90"
    test "$(git rev-parse HEAD:src/process/mod_frost_geometry_effect.f90)" = "b4067615db7059f7061f4555cec6ec9c1312fe4c" || \
      fail "PPA-WU05B10 exact linear-response low-air postimage drift: src/process/mod_frost_geometry_effect.f90"
    test "$(git rev-parse HEAD:src/process/mod_frost_low_air_drainage_effect.f90)" = "4b6cf0b24fc3c2b8e39c982dcc6c80294ab08a91" || \
      fail "PPA-WU05B10 exact linear-response low-air postimage drift: src/process/mod_frost_low_air_drainage_effect.f90"
    test "$(git rev-parse HEAD:src/process/mod_frost_drainage_effect.f90)" = "333149580aea22f57a0bdc0cd33a7d1c4245766a" || \
      fail "PPA-WU05B10 exact linear-response low-air postimage drift: src/process/mod_frost_drainage_effect.f90"
    test "$(git rev-parse HEAD:src/process/mod_frost_bottom_boundary_effect.f90)" = "5dbf9052bdc65fc5fb1830f74da70b3e912adb7b" || \
      fail "PPA-WU05B10 exact linear-response low-air postimage drift: src/process/mod_frost_bottom_boundary_effect.f90"
    test "$(git rev-parse HEAD:src/process/mod_root_frost_stress.f90)" = "a99d870ac2911dd0b9cfe1aef3a0fd299dcfcf38" || \
      fail "PPA-WU05B10 exact linear-response low-air postimage drift: src/process/mod_root_frost_stress.f90"
    if git merge-base --is-ancestor 4c0615bfdb3a3e12db2b988eff97db749cca0511 HEAD; then
      test "$(git rev-parse HEAD:src/process/mod_root_uptake_compensation.f90)" = "a19db82afe85b2c7b34fa8a2da0922581c662fbb" || \
        fail "PPA-WU05B10 concurrent exact-root admitted postimage drift"
      echo 'FCI_CANONICAL_PPA_WU05B10_EXACT01_ROOT_RECONCILIATION=ACTIVE'
    else
    test "$(git rev-parse HEAD:src/process/mod_root_uptake_compensation.f90)" = "4c6172384a1255bfe4b2fb809ae159fe624a91a0" || \
      fail "PPA-WU05B10 exact linear-response low-air postimage drift: src/process/mod_root_uptake_compensation.f90"
    fi
    test "$(git rev-parse HEAD:src/runtime/mod_root_uptake_compensation_execution.f90)" = "6affaec2e7a55544e722ed1204ca9e5de555b478" || \
      fail "PPA-WU05B10 exact linear-response low-air postimage drift: src/runtime/mod_root_uptake_compensation_execution.f90"
    test "$(git rev-parse HEAD:src/process/mod_frost_hydraulic_effect.f90)" = "2c8adba7986e7d85749c4c36d26530748fbbab9e" || \
      fail "PPA-WU05B10 exact linear-response low-air postimage drift: src/process/mod_frost_hydraulic_effect.f90"
    test "$(git rev-parse HEAD:src/solver/mod_frost_hydraulic_provider.f90)" = "08492a7272860629c9ffee34968c9cc29952bd58" || \
      fail "PPA-WU05B10 exact linear-response low-air postimage drift: src/solver/mod_frost_hydraulic_provider.f90"
    git merge-base --is-ancestor 177b680c8992e03f8ab0c41dfcd02c660b3cf8da HEAD || fail "PPA-WU05B10 lost admitted B8 source/closeout"
    test "$(git rev-parse HEAD:src/runtime/mod_fmr_drainage_response_binding.f90)" = "263cf55b2c336d149ba41b4d04f510e10c4207e2" || fail "PPA-WU05B10 generator postimage drift: src/runtime/mod_fmr_drainage_response_binding.f90"
    test "$(git rev-parse HEAD:src/process/mod_drainage_process.f90)" = "dbacd49da3bb0b94f822f9ee0478d15183e9c0fa" || fail "PPA-WU05B10 generator postimage drift: src/process/mod_drainage_process.f90"
    test "$(git rev-parse HEAD:src/process/mod_drainage_multilevel_aggregation.f90)" = "70d35512ef7c5958f7e4bf284cba104a7b641fdb" || fail "PPA-WU05B10 generator postimage drift: src/process/mod_drainage_multilevel_aggregation.f90"
    backend_authority="$(git rev-parse HEAD:$BACKEND)"
    echo "FCI_CANONICAL_PPA_WU05B10_EXACT_LINEAR_RESPONSE_LOW_AIR_CANDIDATE=ACTIVE"

    git merge-base --is-ancestor 86b71ad71fa74d09eee3733c3e8f0f13355257f3 HEAD || fail "PPA-WU05B10 lost admitted B9 source/closeout"
  elif git merge-base --is-ancestor a55dd0860d807c4fcf22f7f351dbd31e475fe917 HEAD; then
    git merge-base --is-ancestor 024c6a5510757a02851426806248b0e2afe45a6b HEAD || fail "PPA-WU05B9 lost normal-drain and guarded reference admissions"
    git merge-base --is-ancestor 2d4d540903a0a7d4cc67bd2e5f8f900834cbc2f5 HEAD || fail "PPA-WU05B9 lost selected salt/root frost admission"
    test "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_reference_backend.f90)" = "e72452277f7fdda5d7cd37b24b97fd0baf5647fc" || \
      fail "PPA-WU05B9 exact linear-response normal postimage drift: src/runtime/mod_fmr_serialized_reference_backend.f90"
    test "$(git rev-parse HEAD:src/runtime/mod_fmr_production_application_bootstrap.f90)" = "adb1b26da3ee797675d9ac80b2e33fef8a149edb" || \
      fail "PPA-WU05B9 exact linear-response normal postimage drift: src/runtime/mod_fmr_production_application_bootstrap.f90"
    test "$(git rev-parse HEAD:src/process/mod_frost_geometry_effect.f90)" = "b4067615db7059f7061f4555cec6ec9c1312fe4c" || \
      fail "PPA-WU05B9 exact linear-response normal postimage drift: src/process/mod_frost_geometry_effect.f90"
    test "$(git rev-parse HEAD:src/process/mod_frost_low_air_drainage_effect.f90)" = "4b6cf0b24fc3c2b8e39c982dcc6c80294ab08a91" || \
      fail "PPA-WU05B9 exact linear-response normal postimage drift: src/process/mod_frost_low_air_drainage_effect.f90"
    test "$(git rev-parse HEAD:src/process/mod_frost_drainage_effect.f90)" = "333149580aea22f57a0bdc0cd33a7d1c4245766a" || \
      fail "PPA-WU05B9 exact linear-response normal postimage drift: src/process/mod_frost_drainage_effect.f90"
    test "$(git rev-parse HEAD:src/process/mod_frost_bottom_boundary_effect.f90)" = "5dbf9052bdc65fc5fb1830f74da70b3e912adb7b" || \
      fail "PPA-WU05B9 exact linear-response normal postimage drift: src/process/mod_frost_bottom_boundary_effect.f90"
    test "$(git rev-parse HEAD:src/process/mod_root_frost_stress.f90)" = "a99d870ac2911dd0b9cfe1aef3a0fd299dcfcf38" || \
      fail "PPA-WU05B9 exact linear-response normal postimage drift: src/process/mod_root_frost_stress.f90"
    test "$(git rev-parse HEAD:src/process/mod_root_uptake_compensation.f90)" = "4c6172384a1255bfe4b2fb809ae159fe624a91a0" || \
      fail "PPA-WU05B9 exact linear-response normal postimage drift: src/process/mod_root_uptake_compensation.f90"
    test "$(git rev-parse HEAD:src/runtime/mod_root_uptake_compensation_execution.f90)" = "6affaec2e7a55544e722ed1204ca9e5de555b478" || \
      fail "PPA-WU05B9 exact linear-response normal postimage drift: src/runtime/mod_root_uptake_compensation_execution.f90"
    test "$(git rev-parse HEAD:src/process/mod_frost_hydraulic_effect.f90)" = "2c8adba7986e7d85749c4c36d26530748fbbab9e" || \
      fail "PPA-WU05B9 exact linear-response normal postimage drift: src/process/mod_frost_hydraulic_effect.f90"
    test "$(git rev-parse HEAD:src/solver/mod_frost_hydraulic_provider.f90)" = "08492a7272860629c9ffee34968c9cc29952bd58" || \
      fail "PPA-WU05B9 exact linear-response normal postimage drift: src/solver/mod_frost_hydraulic_provider.f90"
    git merge-base --is-ancestor 177b680c8992e03f8ab0c41dfcd02c660b3cf8da HEAD || fail "PPA-WU05B9 lost admitted B8 source/closeout"
    test "$(git rev-parse HEAD:src/runtime/mod_fmr_drainage_response_binding.f90)" = "263cf55b2c336d149ba41b4d04f510e10c4207e2" || fail "PPA-WU05B9 generator postimage drift: src/runtime/mod_fmr_drainage_response_binding.f90"
    test "$(git rev-parse HEAD:src/process/mod_drainage_process.f90)" = "dbacd49da3bb0b94f822f9ee0478d15183e9c0fa" || fail "PPA-WU05B9 generator postimage drift: src/process/mod_drainage_process.f90"
    test "$(git rev-parse HEAD:src/process/mod_drainage_multilevel_aggregation.f90)" = "70d35512ef7c5958f7e4bf284cba104a7b641fdb" || fail "PPA-WU05B9 generator postimage drift: src/process/mod_drainage_multilevel_aggregation.f90"
    backend_authority="$(git rev-parse HEAD:$BACKEND)"
    echo "FCI_CANONICAL_PPA_WU05B9_EXACT_LINEAR_RESPONSE_NORMAL_CANDIDATE=ACTIVE"

  elif git merge-base --is-ancestor 5427a3e4e9502944e117066f0ee4c2e1277f16cf HEAD; then
    git merge-base --is-ancestor 024c6a5510757a02851426806248b0e2afe45a6b HEAD || fail "PPA-WU05B8 lost normal-drain and guarded reference admissions"
    git merge-base --is-ancestor 2d4d540903a0a7d4cc67bd2e5f8f900834cbc2f5 HEAD || fail "PPA-WU05B8 lost selected salt/root frost admission"
    test "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_reference_backend.f90)" = "69fcbf1898d615d0c0e17b06de7ded141224b3de" || \
      fail "PPA-WU05B8 exact bracketed low-air postimage drift: src/runtime/mod_fmr_serialized_reference_backend.f90"
    test "$(git rev-parse HEAD:src/runtime/mod_fmr_production_application_bootstrap.f90)" = "f7f4097d965533c167b6442efe7615662ae4522d" || \
      fail "PPA-WU05B8 exact bracketed low-air postimage drift: src/runtime/mod_fmr_production_application_bootstrap.f90"
    test "$(git rev-parse HEAD:src/process/mod_frost_geometry_effect.f90)" = "b4067615db7059f7061f4555cec6ec9c1312fe4c" || \
      fail "PPA-WU05B8 exact bracketed low-air postimage drift: src/process/mod_frost_geometry_effect.f90"
    test "$(git rev-parse HEAD:src/process/mod_frost_low_air_drainage_effect.f90)" = "4b6cf0b24fc3c2b8e39c982dcc6c80294ab08a91" || \
      fail "PPA-WU05B8 exact bracketed low-air postimage drift: src/process/mod_frost_low_air_drainage_effect.f90"
    test "$(git rev-parse HEAD:src/process/mod_frost_drainage_effect.f90)" = "333149580aea22f57a0bdc0cd33a7d1c4245766a" || \
      fail "PPA-WU05B8 exact bracketed low-air postimage drift: src/process/mod_frost_drainage_effect.f90"
    test "$(git rev-parse HEAD:src/process/mod_frost_bottom_boundary_effect.f90)" = "5dbf9052bdc65fc5fb1830f74da70b3e912adb7b" || \
      fail "PPA-WU05B8 exact bracketed low-air postimage drift: src/process/mod_frost_bottom_boundary_effect.f90"
    test "$(git rev-parse HEAD:src/process/mod_root_frost_stress.f90)" = "a99d870ac2911dd0b9cfe1aef3a0fd299dcfcf38" || \
      fail "PPA-WU05B8 exact bracketed low-air postimage drift: src/process/mod_root_frost_stress.f90"
    test "$(git rev-parse HEAD:src/process/mod_root_uptake_compensation.f90)" = "4c6172384a1255bfe4b2fb809ae159fe624a91a0" || \
      fail "PPA-WU05B8 exact bracketed low-air postimage drift: src/process/mod_root_uptake_compensation.f90"
    test "$(git rev-parse HEAD:src/runtime/mod_root_uptake_compensation_execution.f90)" = "6affaec2e7a55544e722ed1204ca9e5de555b478" || \
      fail "PPA-WU05B8 exact bracketed low-air postimage drift: src/runtime/mod_root_uptake_compensation_execution.f90"
    test "$(git rev-parse HEAD:src/process/mod_frost_hydraulic_effect.f90)" = "2c8adba7986e7d85749c4c36d26530748fbbab9e" || \
      fail "PPA-WU05B8 exact bracketed low-air postimage drift: src/process/mod_frost_hydraulic_effect.f90"
    test "$(git rev-parse HEAD:src/solver/mod_frost_hydraulic_provider.f90)" = "08492a7272860629c9ffee34968c9cc29952bd58" || \
      fail "PPA-WU05B8 exact bracketed low-air postimage drift: src/solver/mod_frost_hydraulic_provider.f90"
    backend_authority="$(git rev-parse HEAD:$BACKEND)"
    echo "FCI_CANONICAL_PPA_WU05B8_EXACT_BRACKETED_LOW_AIR_CANDIDATE=ACTIVE"
  elif git merge-base --is-ancestor a4e092bf95f7b0db7f5d64f2d83f63a535a3d4f2 HEAD; then
    git merge-base --is-ancestor b872ddbd930ea08b058575877a03774d313742cc HEAD || fail "PPA-WU05B6 lost admitted frost/reference baseline"
    test "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_reference_backend.f90)" = "84993a601cd57f4e164000f7c7e0ca8cc4992c41" || \
      fail "PPA-WU05B6 exact normal drainage postimage drift: src/runtime/mod_fmr_serialized_reference_backend.f90"
    test "$(git rev-parse HEAD:src/runtime/mod_fmr_production_application_bootstrap.f90)" = "973a0d36265170b7d40095c9d9f6bccef2a8f2b7" || \
      fail "PPA-WU05B6 exact normal drainage postimage drift: src/runtime/mod_fmr_production_application_bootstrap.f90"
    test "$(git rev-parse HEAD:src/process/mod_frost_drainage_effect.f90)" = "333149580aea22f57a0bdc0cd33a7d1c4245766a" || \
      fail "PPA-WU05B6 exact normal drainage postimage drift: src/process/mod_frost_drainage_effect.f90"
    test "$(git rev-parse HEAD:src/process/mod_frost_bottom_boundary_effect.f90)" = "5dbf9052bdc65fc5fb1830f74da70b3e912adb7b" || \
      fail "PPA-WU05B6 exact normal drainage postimage drift: src/process/mod_frost_bottom_boundary_effect.f90"
    test "$(git rev-parse HEAD:src/process/mod_root_frost_stress.f90)" = "a99d870ac2911dd0b9cfe1aef3a0fd299dcfcf38" || \
      fail "PPA-WU05B6 exact normal drainage postimage drift: src/process/mod_root_frost_stress.f90"
    test "$(git rev-parse HEAD:src/process/mod_root_uptake_compensation.f90)" = "36d90b2673b287f560f52d1c9b079ab729c47025" || \
      fail "PPA-WU05B6 exact normal drainage postimage drift: src/process/mod_root_uptake_compensation.f90"
    test "$(git rev-parse HEAD:src/runtime/mod_root_uptake_compensation_execution.f90)" = "6affaec2e7a55544e722ed1204ca9e5de555b478" || \
      fail "PPA-WU05B6 exact normal drainage postimage drift: src/runtime/mod_root_uptake_compensation_execution.f90"
    test "$(git rev-parse HEAD:src/process/mod_frost_hydraulic_effect.f90)" = "2c8adba7986e7d85749c4c36d26530748fbbab9e" || \
      fail "PPA-WU05B6 exact normal drainage postimage drift: src/process/mod_frost_hydraulic_effect.f90"
    test "$(git rev-parse HEAD:src/solver/mod_frost_hydraulic_provider.f90)" = "08492a7272860629c9ffee34968c9cc29952bd58" || \
      fail "PPA-WU05B6 exact normal drainage postimage drift: src/solver/mod_frost_hydraulic_provider.f90"
    backend_authority="$(git rev-parse HEAD:$BACKEND)"
    echo "FCI_CANONICAL_PPA_WU05B6_EXACT_NORMAL_DRAIN_CANDIDATE=ACTIVE"
  elif git merge-base --is-ancestor 021e87e7af2045c389ecfdaa2d4d633e434b3a89 HEAD; then
    git merge-base --is-ancestor 526258e3d78d47df657222630b2e46103cac3eb3 HEAD || fail "PPA-WU05B4 lost admitted B2/B3/Walsum-salt baseline"
    test "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_reference_backend.f90)" = "d9789308792307b97f5507722b591a8a01d6872d" || \
      fail "PPA-WU05B4 bounded joint frost postimage drift: src/runtime/mod_fmr_serialized_reference_backend.f90"
    test "$(git rev-parse HEAD:src/runtime/mod_fmr_production_application_bootstrap.f90)" = "5c84f6828f1af810191131cca90297ac07148e11" || \
      fail "PPA-WU05B4 bounded joint frost postimage drift: src/runtime/mod_fmr_production_application_bootstrap.f90"
    test "$(git rev-parse HEAD:src/process/mod_frost_bottom_boundary_effect.f90)" = "5dbf9052bdc65fc5fb1830f74da70b3e912adb7b" || \
      fail "PPA-WU05B4 bounded joint frost postimage drift: src/process/mod_frost_bottom_boundary_effect.f90"
    test "$(git rev-parse HEAD:src/process/mod_root_frost_stress.f90)" = "a99d870ac2911dd0b9cfe1aef3a0fd299dcfcf38" || \
      fail "PPA-WU05B4 bounded joint frost postimage drift: src/process/mod_root_frost_stress.f90"
    test "$(git rev-parse HEAD:src/process/mod_root_uptake_compensation.f90)" = "36d90b2673b287f560f52d1c9b079ab729c47025" || \
      fail "PPA-WU05B4 bounded joint frost postimage drift: src/process/mod_root_uptake_compensation.f90"
    test "$(git rev-parse HEAD:src/runtime/mod_root_uptake_compensation_execution.f90)" = "6affaec2e7a55544e722ed1204ca9e5de555b478" || \
      fail "PPA-WU05B4 bounded joint frost postimage drift: src/runtime/mod_root_uptake_compensation_execution.f90"
    test "$(git rev-parse HEAD:src/process/mod_frost_hydraulic_effect.f90)" = "2c8adba7986e7d85749c4c36d26530748fbbab9e" || \
      fail "PPA-WU05B4 bounded joint frost postimage drift: src/process/mod_frost_hydraulic_effect.f90"
    test "$(git rev-parse HEAD:src/solver/mod_frost_hydraulic_provider.f90)" = "08492a7272860629c9ffee34968c9cc29952bd58" || \
      fail "PPA-WU05B4 bounded joint frost postimage drift: src/solver/mod_frost_hydraulic_provider.f90"
    backend_authority="$(git rev-parse HEAD:$BACKEND)"
    echo "FCI_CANONICAL_PPA_WU05B4_EXACT_ROOT_BOTTOM_CANDIDATE=ACTIVE"
  elif git merge-base --is-ancestor 58d86a8590181acd5274008d82afb5596aa9e0f7 HEAD; then
    git merge-base --is-ancestor a370f6f487c017af9931ffc46d4c5c9fb1288d8c HEAD || fail "PPA-WU05B3 lost admitted root/Walsum-salt baseline"
    test "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_reference_backend.f90)" = "1ac0a8032c08ad2119a929ae1deb338abe70a441" || \
      fail "PPA-WU05B3 bounded no-drain postimage drift: src/runtime/mod_fmr_serialized_reference_backend.f90"
    test "$(git rev-parse HEAD:src/runtime/mod_fmr_production_application_bootstrap.f90)" = "9b44d4e536b783d892b2052eed4d36edb46b7838" || \
      fail "PPA-WU05B3 bounded no-drain postimage drift: src/runtime/mod_fmr_production_application_bootstrap.f90"
    test "$(git rev-parse HEAD:src/process/mod_frost_bottom_boundary_effect.f90)" = "5dbf9052bdc65fc5fb1830f74da70b3e912adb7b" || \
      fail "PPA-WU05B3 bounded no-drain postimage drift: src/process/mod_frost_bottom_boundary_effect.f90"
    test "$(git rev-parse HEAD:src/process/mod_root_frost_stress.f90)" = "a99d870ac2911dd0b9cfe1aef3a0fd299dcfcf38" || \
      fail "PPA-WU05B3 bounded no-drain postimage drift: src/process/mod_root_frost_stress.f90"
    test "$(git rev-parse HEAD:src/process/mod_root_uptake_compensation.f90)" = "36d90b2673b287f560f52d1c9b079ab729c47025" || \
      fail "PPA-WU05B3 bounded no-drain postimage drift: src/process/mod_root_uptake_compensation.f90"
    test "$(git rev-parse HEAD:src/runtime/mod_root_uptake_compensation_execution.f90)" = "6affaec2e7a55544e722ed1204ca9e5de555b478" || \
      fail "PPA-WU05B3 bounded no-drain postimage drift: src/runtime/mod_root_uptake_compensation_execution.f90"
    test "$(git rev-parse HEAD:src/process/mod_frost_hydraulic_effect.f90)" = "2c8adba7986e7d85749c4c36d26530748fbbab9e" || \
      fail "PPA-WU05B3 bounded no-drain postimage drift: src/process/mod_frost_hydraulic_effect.f90"
    test "$(git rev-parse HEAD:src/solver/mod_frost_hydraulic_provider.f90)" = "08492a7272860629c9ffee34968c9cc29952bd58" || \
      fail "PPA-WU05B3 bounded no-drain postimage drift: src/solver/mod_frost_hydraulic_provider.f90"
    backend_authority="$(git rev-parse HEAD:$BACKEND)"
    echo "FCI_CANONICAL_PPA_WU05B3_EXACT_FROZEN_BOTTOM_CANDIDATE=ACTIVE"
  elif git merge-base --is-ancestor 4e21f0efeb4db6069c3c6d38fdf6dc2e5033f238 HEAD; then
    git merge-base --is-ancestor 916035e78305cae5f88c30d5805b5d9c33a348f8 HEAD || \
      fail 'PPA-WU05B2 lost canonically admitted hydraulic frost baseline'
    test "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_reference_backend.f90)" = "93d99478474a59ade337c42e993dcf55dff9272d" || \
      fail 'PPA-WU05B2 bounded root composition postimage drift: src/runtime/mod_fmr_serialized_reference_backend.f90'
    test "$(git rev-parse HEAD:src/process/mod_root_frost_stress.f90)" = "a99d870ac2911dd0b9cfe1aef3a0fd299dcfcf38" || \
      fail 'PPA-WU05B2 bounded root composition postimage drift: src/process/mod_root_frost_stress.f90'
    test "$(git rev-parse HEAD:src/process/mod_root_uptake_compensation.f90)" = "36d90b2673b287f560f52d1c9b079ab729c47025" || \
      fail 'PPA-WU05B2 bounded root composition postimage drift: src/process/mod_root_uptake_compensation.f90'
    test "$(git rev-parse HEAD:src/runtime/mod_root_uptake_compensation_execution.f90)" = "6affaec2e7a55544e722ed1204ca9e5de555b478" || \
      fail 'PPA-WU05B2 bounded root composition postimage drift: src/runtime/mod_root_uptake_compensation_execution.f90'
    test "$(git rev-parse HEAD:src/runtime/mod_fmr_production_application_bootstrap.f90)" = "6feabfac3d24d67b13cb5dfdc4a9929cb9ed0252" || \
      fail 'PPA-WU05B2 bounded root composition postimage drift: src/runtime/mod_fmr_production_application_bootstrap.f90'
    backend_authority="$(git rev-parse HEAD:$BACKEND)"
    echo 'FCI_CANONICAL_PPA_WU05B2_EXACT_ROOT_COMPOSITION_CANDIDATE=ACTIVE'
  elif git merge-base --is-ancestor "$PPA_WU05B_QUALIFIED" HEAD; then
    test "$(git rev-parse "HEAD^2:$BACKEND")" = "$PPA_WU05B_BACKEND" || \
      fail 'PR parent does not carry the exact qualified PPA-WU05B backend postimage'
    backend_authority="$PPA_WU05B_MERGE_BACKEND"
    test "$(git rev-parse HEAD:src/process/mod_frost_hydraulic_effect.f90)" = "$PPA_WU05B_EFFECT" || \
      fail 'PPA-WU05B frost hydraulic effect successor drift'
    test "$(git rev-parse HEAD:src/solver/mod_frost_hydraulic_provider.f90)" = "$PPA_WU05B_PROVIDER" || \
      fail 'PPA-WU05B frost hydraulic provider successor drift'
    echo 'FCI_CANONICAL_PPA_WU05B_TESTED_MERGE_BACKEND_SUCCESSOR=ACTIVE'
  fi
  test "$(git rev-parse HEAD:src/solver/mod_b110_default_mvg_provider.f90)" = \
       "$(git rev-parse "$dependency_authority:src/solver/mod_b110_default_mvg_provider.f90")" || \
    fail 'candidate changed current default-MvG provider target postimage'
  test "$(git rev-parse HEAD:$BACKEND)" = "$backend_authority" || \
    fail 'admitted serialized-backend successor drift'
  echo 'FCI_CANONICAL_PPA_WU04B_BACKEND_SUCCESSOR=PASS'
elif git merge-base --is-ancestor "$PPA_WU04A_ADMISSION" HEAD; then
  git merge-base --is-ancestor "$PPA_WU04A_QUALIFIED" "$PPA_WU04A_ADMISSION" || \
    fail 'PPA-WU04-A qualified head is not contained by canonical admission'
  test "$(git rev-parse HEAD:src/solver/mod_b110_default_mvg_provider.f90)" = "$FSI39_PROVIDER" || \
    fail 'PPA-WU04-A successor lost admitted F-SI39 default-MvG provider'
  test "$(git rev-parse HEAD:$BACKEND)" = "$PPA_WU04A_BACKEND" || \
    fail 'admitted PPA-WU04-A serialized-backend successor drift'
  echo 'FCI_CANONICAL_PPA_WU04A_BACKEND_SUCCESSOR=PASS'
elif git merge-base --is-ancestor "$PPA_LOW02_ADMISSION" HEAD; then
  # PPA-LOW02-TIME is a later, independently qualified serialized-backend
  # successor layered on top of the admitted F-ROM1A observation seam.
  # Accept only its exact canonical admission and exact qualified backend blob.
  git merge-base --is-ancestor "$PPA_LOW02_QUALIFIED" "$PPA_LOW02_ADMISSION" || \
    fail 'PPA-LOW02 qualified head is not contained by canonical admission'
  test "$(git rev-parse HEAD:src/solver/mod_b110_default_mvg_provider.f90)" = "$FSI39_PROVIDER" || \
    fail 'PPA-LOW02 successor lost admitted F-SI39 default-MvG provider'
  test "$(git rev-parse HEAD:$BACKEND)" = "$PPA_LOW02_BACKEND" || \
    fail 'admitted PPA-LOW02 serialized backend successor drift'
  echo 'FCI_CANONICAL_FSI39_PROVIDER_SUCCESSOR=PASS'
  echo 'FCI_CANONICAL_PPA_LOW02_BACKEND_SUCCESSOR=PASS'
elif git merge-base --is-ancestor "$F_ROM1A_PRODUCTION" HEAD; then
  test "$(git rev-parse HEAD:src/solver/mod_b110_default_mvg_provider.f90)" = "$FSI39_PROVIDER" ||     fail 'admitted F-SI39 default-MvG provider successor drift under F-ROM1A'
  test "$(git rev-parse HEAD:$BACKEND)" = "$F_ROM1A_BACKEND" ||     fail 'admitted F-ROM1A serialized backend successor drift'
  echo 'FCI_CANONICAL_FSI39_PROVIDER_SUCCESSOR=PASS'
  echo 'FCI_CANONICAL_F_ROM1A_BACKEND_SUCCESSOR=PASS'
elif git merge-base --is-ancestor "$FSI39_PRODUCTION" HEAD; then
  test "$(git rev-parse HEAD:src/solver/mod_b110_default_mvg_provider.f90)" = "$FSI39_PROVIDER" ||     fail 'admitted F-SI39 default-MvG provider successor drift'
  test "$(git rev-parse HEAD:$BACKEND)" = "$FSI39_BACKEND" ||     fail 'admitted F-SI39 serialized backend successor drift'
  echo 'FCI_CANONICAL_FSI39_PROVIDER_SUCCESSOR=PASS'
  echo 'FCI_CANONICAL_FSI39_BACKEND_SUCCESSOR=PASS'
elif git merge-base --is-ancestor "$FGC44_PRODUCTION" HEAD; then
  test "$(git rev-parse HEAD:src/solver/mod_b110_default_mvg_provider.f90)" =     "$(git rev-parse "$AUTH:src/solver/mod_b110_default_mvg_provider.f90")" ||     fail 'pre-F-SI39 default-MvG provider drift'
  test "$(git rev-parse HEAD:$BACKEND)" = "$BACKEND_FGC44" || fail 'admitted F-GC44 serialized backend successor drift'
  echo 'FCI_CANONICAL_FGC44_BACKEND_SUCCESSOR=PASS'
elif git merge-base --is-ancestor "$FGC31_RECONCILED" HEAD; then
  test "$(git rev-parse HEAD:src/solver/mod_b110_default_mvg_provider.f90)" =     "$(git rev-parse "$AUTH:src/solver/mod_b110_default_mvg_provider.f90")" ||     fail 'pre-F-SI39 default-MvG provider drift'
  test "$(git rev-parse HEAD:$BACKEND)" = "$BACKEND_FGC31" || fail 'admitted F-GC31 serialized backend successor drift'
  echo 'FCI_CANONICAL_FGC31_BACKEND_SUCCESSOR=PASS'
else
  test "$(git rev-parse HEAD:src/solver/mod_b110_default_mvg_provider.f90)" =     "$(git rev-parse "$AUTH:src/solver/mod_b110_default_mvg_provider.f90")" ||     fail 'pre-F-SI39 default-MvG provider drift'
  test "$(git rev-parse HEAD:$BACKEND)" = "$BACKEND_FROSS12" || fail 'admitted F-ROSS12 serialized backend drift'
fi
if [[ "$(git rev-parse HEAD:$FROSS17_KERNEL)" == "$FROSS22_TIERED_KERNEL" ]] && [[ "$(git rev-parse HEAD:$ROSS_ADAPTER)" == "$FROSS22_TIERED_SOLVER" ]]; then
  echo 'FCI_CANONICAL_FROSS22_TIERED_SOLVER_POSTIMAGE=PASS'
else
  test "$(git rev-parse HEAD:$ROSS_ADAPTER)" = "$ROSS_ADAPTER_P2E05" || fail 'RossFast adapter is not the qualified P2E05 or F-ROSS22 tiered successor blob'
fi

# Route only an exact, independently qualified F-ROSS13 production successor
# through its stronger preservation gate. Otherwise preserve the historical
# P2E05 semantic-successor route unchanged.
if git merge-base --is-ancestor "$FROSS13_PRODUCTION" HEAD && \
   [[ "$(git rev-parse HEAD:$FROSS13_MODEL)" == "$FROSS13_MODEL_POSTIMAGE" ]] && \
   [[ "$(git rev-parse HEAD:$FROSS13_PROVIDER)" == "$FROSS13_PROVIDER_POSTIMAGE" ]]; then
  if [[ "$(git rev-parse HEAD:$FROSS17_KERNEL)" == "$FROSS22_TIERED_KERNEL" ]] && [[ "$(git rev-parse HEAD:$ROSS_ADAPTER)" == "$FROSS22_TIERED_SOLVER" ]]; then
    PPA_WU05B_MOVING_CANONICAL_PRESERVATION=1 bash tests/fci/run_fci_fross22_tiered_successor_preservation.sh
    echo 'FCI_CANONICAL_FROSS22_TIERED_SEMANTIC_SUCCESSOR_ROUTE=PASS'
  elif [[ "$(git rev-parse HEAD:$FROSS17_KERNEL)" == "$FROSS17_CACHE_KERNEL" ]]; then
    bash tests/fci/run_fci107_fross17_cache_successor_preservation.sh
    echo 'FCI_CANONICAL_FROSS17_CACHE_SEMANTIC_SUCCESSOR_ROUTE=PASS'
  else
    bash tests/fci/run_fci96_fross13_semantic_successor_preservation.sh
    echo 'FCI_CANONICAL_FROSS13_SEMANTIC_SUCCESSOR_ROUTE=PASS'
  fi
else
  bash tests/fci/run_fci96_p2e05_semantic_successor_preservation.sh
fi

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
if git merge-base --is-ancestor "$FSI39_PRODUCTION" HEAD; then
  echo 'FCI_CANONICAL_FSI39_EXACT_SEMANTIC_SUCCESSOR_PRESERVATION=PASS'
fi
if git merge-base --is-ancestor "$PPA_LOW02_ADMISSION" HEAD; then
  echo 'FCI_CANONICAL_PPA_LOW02_EXACT_BACKEND_SUCCESSOR_PRESERVATION=PASS'
  echo 'FCI_CANONICAL_F_ROM1A_KERNEL_UNDER_PPA_LOW02_SUCCESSOR=PASS'
elif git merge-base --is-ancestor "$F_ROM1A_PRODUCTION" HEAD; then
  echo 'FCI_CANONICAL_F_ROM1A_EXACT_TWO_FILE_SUCCESSOR_PRESERVATION=PASS'
fi
if git merge-base --is-ancestor "$PPA_ROOT_HYD01_ADMISSION" HEAD; then
  echo 'FCI_CANONICAL_PPA_ROOT_HYD01_EXACT_TEMPORAL_INDICATOR_SUCCESSOR_PRESERVATION=PASS'
fi
echo 'FCI_CANONICAL_MOVING_PRESERVATION_NO_HISTORICAL_DELTA_ASSUMPTION=PASS'
echo 'FCI_CANONICAL_LINEAGE_AWARE_GATE PASS'
