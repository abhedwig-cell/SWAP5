#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == --drain-dramet3-owner-only ]]; then
  cd "$(dirname "$0")/../.."
  python3 -B tests/fmig431/verify_dramet3_successor.py
  exit $?
fi
if [[ "${1:-}" == --drain-dislayer-owner-only ]]; then
  cd "$(cd "$(dirname "$0")/../.." && pwd)"
  python3 -B tests/fmig431/verify_dislayer_successor.py
  echo 'FCI_DRAIN_DISLAYER_OWNER=PASS'
  exit 0
fi

# Separate infiltration owner only; no broad numerical execution.
if [[ "${1:-}" == --drain-inf-owner-only ]]; then
  cd "$(cd "$(dirname "$0")/../.." && pwd)"
  python3 -B tests/fmig431/verify_inf_split_successor.py
  echo 'FCI_DRAIN_INF_SPLIT_OWNER=PASS'
  exit 0
fi

# Current full TCS6 owner, selected by exact science/postimages, with immutable
# incumbent proof and fresh native application preservation. No full-FCI claim.
if [[ "${1:-}" == --mc-irr01-owner-only ]] && [[ -f "$(dirname "$0")/../mc-irr01/verify_tcs6_successor.py" ]]; then
  cd "$(cd "$(dirname "$0")/../.." && pwd)"
  python3 -B tests/mc-irr01/verify_tcs6_successor.py
  echo 'FCI_CANONICAL_MC_IRR01_CURRENT_OVERLAP_PRESERVATION=PASS'
  exit 0
fi


# Classic annual source/state owner only; never a full moving PASS.
if [[ "${1:-}" == --crop-annual-owner-only ]]; then
  cd "$(cd "$(dirname "$0")/../.." && pwd)"
  python3 -B tests/fmig431/annual/verify_annual_successor.py
  echo 'FCI_CLASSIC_ANNUAL_OWNER_RECONCILIATION=PASS'
  exit 0
fi

# Signed DIVDRA owner only; no unrelated numerical suite or full F-CI claim.
if [[ "${1:-}" == --drain-signed-owner-only ]]; then
  cd "$(cd "$(dirname "$0")/../.." && pwd)"
  python3 -B tests/fmig431/verify_signed_divdra_successor.py
  echo 'FCI_DRAIN_SIGNED_OWNER_RECONCILIATION=PASS'
  exit 0
fi

# Bounded pond source/science owner only; never a full moving numerical PASS.
if [[ "${1:-}" == --sol-pond-owner-only ]]; then
  cd "$(cd "$(dirname "$0")/../.." && pwd)"
  python3 -B tests/nut-sol/verify_pond_successor.py
  echo 'FCI_SOL_POND_OWNER_RECONCILIATION=PASS'
  exit 0
fi

# INT12-C explicit owner prerequisite. It never establishes full moving PASS.
if [[ "${1:-}" == --int12c-owner-only ]]; then
  cd "$(cd "$(dirname "$0")/../.." && pwd)"
  python3 -B tests/fpm/verify_int12c_successor.py
  echo 'FCI_INT12C_OWNER_RECONCILIATION=PASS'
  exit 0
fi

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

# Explicit preflight; produces a conservative selection report, never F-CI PASS.
# Example: bash tests/fci/run_fci_canonical_p2e05_moving_preservation.sh --plan-rossfast-impact integration/f-ci-canonical
if [[ "${1:-}" == --plan-rossfast-impact ]]; then
  if [[ -z "${2:-}" || -n "${3:-}" ]]; then
    echo 'Usage: --plan-rossfast-impact BASE_REF' >&2
    exit 2
  fi
  python3 -B tests/fci/select_component_impact.py --base "$2"
  exit $?
fi

# Explicit harvest owner qualification only; never a full moving PASS.
if [[ "${1:-}" == --crop-harvest-owner-only ]]; then
  python3 -B tests/crop-harvest/verify_harvest_successor.py
  echo 'FCI_CROP_HARVEST_OWNER_RECONCILIATION=PASS'
  exit 0
fi

# Source/evidence-only owner selection. This is never a full moving PASS.
if [[ "${1:-}" == --nut-thermal-owner-only ]]; then
  python3 -B tests/nut-thermal/verify_thermal_successor.py
  python3 -B tests/crop-co2/verify_co2_successor.py
  echo 'FCI_NUT_THERMAL_OWNER_RECONCILIATION=PASS'
  exit 0
fi
nut_thermal_exact_successor=0
NUT_THERMAL_BACKEND=7e1b034e5cd134050e695c9a097c44a3eaeca344

# Decision in the existing work-unit, before any compile or owner invocation.
# The focused irrigation route selects its own expensive group, not full F-CI.
selection_group=full_fci
if [[ "${1:-}" == --mc-irr01-allocation-only ]]; then
  selection_group=irrigation_allocation
fi
python3 tests/modularity/run_modular_tests.py --check-selection "$selection_group"

# Shared qualification preserves all original driver executions; no result reuse.
case "${FCI_IRR01_BUILD_MODE:-SHARED}" in
  SHARED|SEPARATE) ;;
  *) printf '%s\n' 'FCI_IRR01_BUILD_MODE must be SHARED or SEPARATE' >&2; exit 2 ;;
esac

# Opt-in receipt controller. OFF follows the original command directly.
fci_group() {
  local group="$1"; shift
  case "${FCI_RESUME_MODE:-OFF}" in
    OFF) "$@" ;;
    SHADOW|RESUME)
      if [[ -n "$(declare -Fx)" ]]; then
        printf '%s\n' 'FCI_RESUME_RUN unqualified exported shell functions' >&2
        command "$@"
      else
        command python3 tools/fci/resume_group.py "$group" "$@"
      fi ;;
    *) fail 'unknown FCI_RESUME_MODE' ;;
  esac
}

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
# Only the two exact repairs are eligible, with complete fresh owner and
# coupling proof. This prerequisite does not replace any science below.
modular_repair_exact_successor=0
joint_exact_successor=0
if [[ "$(git rev-parse HEAD:src/runtime/mod_canonical_contracts.f90)" == 732cf70f9aeec59bb7dfb136ba4d6e61b918780b ]]; then
  # Delegated MC-MET01/HY/RT/F-KT reconciliation. Exact source eligibility
  # alone cannot enter preservation: complete fresh owner/coupling is required.
  python3 tests/modularity/verify_joint_preservation.py || fail 'joint successor complete current owner evidence missing'
  joint_exact_successor=1
fi
if [[ "$(git rev-parse HEAD:$BACKEND)" == 7dd238a0c9fae518beba9eb9dbac5fde1bbd5c18 ]]; then
  python3 tests/modularity/verify_modular_repair_evidence.py ||
    fail 'modular repairs require sealed current-source owner and coupling evidence'
  modular_repair_exact_successor=1
fi

verify_mc_irr01_allocation_successor() {
  git cat-file -e HEAD:src/runtime/mod_fmr_irrigation_allocation_binding.f90 2>/dev/null || fail 'missing allocation successor'
  test "$(git rev-parse HEAD:src/runtime/mod_fmr_irrigation_allocation_binding.f90)" = ab5ac97c5017da9ba0560e674fb5888e422de5e5 || fail 'allocation dependency identity: src/runtime/mod_fmr_irrigation_allocation_binding.f90'
  test "$(git rev-parse HEAD:tests/f-app07/run_mc_irr01_allocated_root_restart.sh)" = c3d1b0c2da5f3a78132c8a0c38148758f3abd4ca || fail 'allocation dependency identity: tests/f-app07/run_mc_irr01_allocated_root_restart.sh'
  test "$(git rev-parse HEAD:tests/f-app07/test_mc_irr01_allocated_root_restart.f90)" = 1108400284dcd685660d0dd6b439eeb7002ffc05 || fail 'allocation dependency identity: tests/f-app07/test_mc_irr01_allocated_root_restart.f90'
  test "$(git rev-parse HEAD:tests/f-app07/run_mc_irr01_allocated_sensor_restart.sh)" = d076298b49c9c0892fe449a5f5b8ba071cb5c81a || fail 'allocation dependency identity: tests/f-app07/run_mc_irr01_allocated_sensor_restart.sh'
  test "$(git rev-parse HEAD:tests/f-app07/test_mc_irr01_allocated_sensor_restart.f90)" = 3b2c6e35287a8ecfcc6c87202c4ca0a470e5e4a7 || fail 'allocation dependency identity: tests/f-app07/test_mc_irr01_allocated_sensor_restart.f90'
  case "${FCI_IRR01_BUILD_MODE:-SHARED}" in
    SHARED)
      test "$(git rev-parse HEAD:tests/performance/run_mc_irr01_shared_build_experiment.sh)" = 72340b78020de210310b90d74fc86d958722ad20 || fail 'unqualified allocation shared runner'
      test "$(git rev-parse HEAD:tools/performance/irrigation_build_identity.py)" = 0ed9c2d762c3aac971265b379e51d7d9915c36b0 || fail 'unqualified allocation source selector'
      bash tests/performance/run_mc_irr01_shared_build_experiment.sh || fail 'allocation root and sensor/repeated-event/restart shared build'
      ;;
    SEPARATE)
      bash tests/f-app07/run_mc_irr01_allocated_root_restart.sh || fail 'allocation root/repeated-event/restart'
      bash tests/f-app07/run_mc_irr01_allocated_sensor_restart.sh || fail 'allocation sensor/restart'
      ;;
  esac
  echo "FCI_CANONICAL_MC_IRR01_ALLOCATION_BUILD_MODE=${FCI_IRR01_BUILD_MODE:-SHARED}"
  echo 'FCI_CANONICAL_MC_IRR01_ALLOCATION_SUCCESSOR=PASS'
}

if [[ "${1:-}" == --mc-irr01-allocation-only ]]; then
  verify_mc_irr01_allocation_successor
  echo 'FCI_CANONICAL_MC_IRR01_ALLOCATION_FOCUSED=PASS'
  exit 0
fi

verify_crop_frost_highest(){
  if [[ -f src/runtime/mod_fmr_biomass_root_uptake_input.f90 ]]; then
    python3 tests/root-growth/verify_swrd3_successor.py
    echo 'SWRD3_HIGHEST_NOT_SELECTED_POLICY_FAST_PHYSICAL_OWNER_BOUND=PASS'
    return
  fi
  if [[ "$(git rev-parse HEAD:src/runtime/mod_fmr_production_application_bootstrap.f90)" == 5a93008ed2fb18d0798ec0c967729815d156ec26 ]]; then
    python3 tests/crop-co2/verify_co2_successor.py
    echo 'CROP_CO2_HIGHEST_NOT_SELECTED_POLICY_FAST_OWNER_BOUND=PASS'
    return
  fi
  if [[ "$(git rev-parse HEAD:src/runtime/mod_fmr_production_application_bootstrap.f90)" == cb845eecd2409d6ee473bd7a0cb8194c0b501ad6 ]]; then
    # Programme policy selects independent short physical/numerical contracts
    # for this exact crop successor. No long-highest PASS is asserted.
    python3 tests/crop-cycle/verify_oxygen_successor.py
    echo 'CROP_OXYGEN_HIGHEST_NOT_SELECTED_POLICY_FAST_OWNER_BOUND=PASS'
    return
  fi
  if [[ "$(git rev-parse HEAD:src/runtime/mod_fmr_production_application_bootstrap.f90)" == 8b480b09f47bb4443d755109c9093486853c0809 ]]; then
    python3 tests/mc-met01/verify_daily_demand_successor.py
    return
  fi
  if [[ "$(git rev-parse HEAD:src/runtime/mod_fmr_production_application_bootstrap.f90)" == 2ae6e3aafe9f4987b562618443b0ccd48a133a4c ]]; then
    python3 tests/mc-met01/verify_raintb_successor.py
    return
  fi
  if [[ "$(git rev-parse HEAD:src/runtime/mod_fmr_production_application_bootstrap.f90)" == 851cb80954e1be909f6ec54661c0b12b80f225cd || "$(git rev-parse HEAD:src/runtime/mod_fmr_production_application_bootstrap.f90)" == 23c2db74b1254e5e97e608764d186a59eeb694d5 ]]; then
    python3 tests/fmig431/run_crop_rooted_weather_frost_successor.py --verify-only
  elif [[ "$(git rev-parse HEAD:src/runtime/mod_fmr_production_application_bootstrap.f90)" == bc04a4239b2b0d8ef21f962af14be6ef28fbe436 ]]; then
    python3 tests/fmig431/run_crop_task2_frost_successor.py --verify-only
  else
    python3 tests/frost/run_frost_nan_guard_highest_successor.py --verify-only
  fi
}

# The existing PR1119 invalid-input guard changes no finite-input formula.
# Admit this exact blob only with complete current-source highest-route
# evidence and the original invalid-input oracle. Other source drift remains
# subject to every existing owning gate and exact postimage check below.
if [[ "$(git rev-parse HEAD:src/process/mod_frost_hydraulic_effect.f90)" == 0dd5b541af936d292d23575f798c3cdd5be19c47 ]]; then
  verify_crop_frost_highest || fail 'frost NaN guard exact source; complete highest evidence remains separate admission gate'
  fci_group frost-invalid bash tests/frost/run_frost_invalid_input_preservation.sh || fail 'frost NaN guard original invalid-input O0/O2'
  fci_group frost-independent bash tests/frost/run_frost_nan_guard_independent.sh || fail 'frost NaN guard independent nonfinite bit-preservation O0/O2'
  echo 'FCI_CANONICAL_FROST_NAN_GUARD_EXACT_SCIENTIFIC_SUCCESSOR=PASS'
fi

if [[ "$(git rev-parse HEAD:src/adapter/mod_b110_production_soil_water_task2.f90)" == ed678be6e27621ac076a883c947abba8032ac7e6 ]]; then
  bash tests/fci/run_fci93_fsi35_semantic_successor_preservation.sh || fail 'F-CI93 non-M1 fixed-K immutable preservation'
  echo 'FCI_CANONICAL_FCI93_NON_M1_FIXED_K_PRESERVATION=PASS'
fi

# Central proposed successor for the existing constitutive storage-increment
# interface. Only this exact arithmetic postimage is eligible; no tolerance,
# history, state or provider changes are authorized by this exception.
mc_irr01_storage_exact_successor=0
if git merge-base --is-ancestor 669a75ff996938fd0538c715ec43fe93d06b74de HEAD && \
   [[ "$(git rev-parse HEAD:src/legacy/b1_10_port/headcalc.f90)" == 7ff36cbadf8acfaa09e129ff54aa54a933c3f1ac ]] && \
   [[ "$(git rev-parse HEAD:src/solver/mod_b110_default_mvg_provider.f90)" == bde864f59082d0aef5bf0eb51526fa5e7c1091ed ]] && \
   [[ "$(git rev-parse HEAD:src/solver/mod_soil_water_solver_contract.f90)" == 7b16c3fcf58179f1491104a1dce3279010b4178a ]]; then
  mc_irr01_storage_exact_successor=1
fi
verify_mc_irr01_storage_successor() {
  (( mc_irr01_storage_exact_successor )) || return 0
  test "$(git rev-parse HEAD:tests/f-app07/run_mc_irr01_shared_storage_preservation.sh)" = b7f635583b8d2257d59590a872d276907e7d7c5f || \
    fail 'MC-IRR01 shared storage qualification runner drift'
  local path
  for path in tests/verification/test_bofek00_dynamic_top_correction.f90 \
              tests/verification/test_bofek00_frozen_wet_trajectory.f90 \
              tests/fsi/test_fsi25_reference_indicator_production_seam.f90 \
              tests/fsi/test_fsi39_b110_ksatexm.f90 \
              tests/rom/compile_f_rom0_fortran_closure.py \
              tests/rom/materialize_f_rom0_headcalc_stubs.py; do
    test "$(git rev-parse "HEAD:$path")" = "$(git rev-parse "669a75ff996938fd0538c715ec43fe93d06b74de:$path")" || \
      fail "MC-IRR01 shared storage immutable assertion drift: $path"
  done
  bash tests/f-app07/run_mc_irr01_shared_storage_preservation.sh || \
    fail 'MC-IRR01 shared storage BOFEK/F-SI O0/O2 preservation'
  echo 'FCI_CANONICAL_MC_IRR01_SHARED_STORAGE_ARITHMETIC_SUCCESSOR=PASS'
}

# Bounded MC-HEAT01 successor: exact owner code and immutable qualification
# runners only. Unrecognized thermal/backend changes remain fail-closed.
mc_heat01_exact_successor=0
MC_HEAT01_QUALIFIED=decd2e67b8a182f1448a173b18bbc232749dd5b5
MC_HEAT01_BACKEND=01d1981cc7aebb1553463b1cee955bb21da05fe6
if (( modular_repair_exact_successor )); then
  MC_HEAT01_BACKEND=7dd238a0c9fae518beba9eb9dbac5fde1bbd5c18
fi
if git merge-base --is-ancestor "$MC_HEAT01_QUALIFIED" HEAD && \
   [[ "$(git rev-parse HEAD:src/process/mod_soil_temperature_contract.f90)" == 2c358fa353226846ce6c6e4e561aa59e5de94620 ]] && \
   [[ "$(git rev-parse HEAD:src/process/mod_restricted_soil_temperature.f90)" == 6d881983c8d97c6d82854c59a2dc6c9fd36f7350 ]] && \
   [[ "$(git rev-parse HEAD:$BACKEND)" == "$MC_HEAT01_BACKEND" ]]; then
  mc_heat01_exact_successor=1
fi

verify_mc_heat01_owner_successor() {
  (( mc_heat01_exact_successor )) || return 0
  local path
  for path in tests/fmig431/run_mc_heat01_runtime.sh \
              tests/fmig431/run_mc_heat01_thermal_boundary.sh \
              tests/fmig431/test_mc_heat01_runtime.f90 \
              tests/fmig431/test_mc_heat01_thermal_boundary.f90 \
              tests/fci/test_fci43_restricted_soil_temperature_independent.f90 \
              reference/swap-4.3.1/b1_11_frost_source/SWAP/temperature.f90; do
    test "$(git rev-parse "HEAD:$path")" = "$(git rev-parse "$MC_HEAT01_QUALIFIED:$path")" || \
      fail "MC-HEAT01 immutable qualification dependency drift: $path"
  done
  bash tests/fmig431/run_mc_heat01_thermal_boundary.sh || fail 'MC-HEAT01 process/default F-VQ58 O0/O2 preservation'
  bash tests/fmig431/run_mc_heat01_runtime.sh || fail 'MC-HEAT01 original runtime/transaction/restart O0/O2 preservation'
  bash tests/fkt/run_fkt22_fmr_runtime_gate.sh || fail 'MC-HEAT01 FKT22 serialized trajectory preservation'
  bash tests/frost/run_ppa_wu05b_frost_runtime.sh || fail 'MC-HEAT01 bounded frost runtime preservation'
  echo 'FCI_CANONICAL_MC_HEAT01_EXACT_OWNER_DEFAULT_RUNTIME_FROST_SUCCESSOR=PASS'
}

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
# A metadata checkpoint cannot hide this material crop change from the
# owning preservation gates. This exact successor compares to its admitted
# canonical source baseline, even when the immediate parent has the same src.
if [[ "$(git rev-parse HEAD:src/runtime/mod_fmr_production_application_bootstrap.f90)" == 851cb80954e1be909f6ec54661c0b12b80f225cd ]]; then
  dependency_authority=e35ea0c6801ad0c225ff02e60f24996d2bc0156d
fi
if [[ "$(git rev-parse HEAD:src/runtime/mod_fmr_production_application_bootstrap.f90)" == 23c2db74b1254e5e97e608764d186a59eeb694d5 ]]; then
  dependency_authority=1e689fd2c31bac468df01540b314ea128be4554a
fi
if [[ "$(git rev-parse HEAD:src/runtime/mod_fmr_production_application_bootstrap.f90)" == 2ae6e3aafe9f4987b562618443b0ccd48a133a4c ]]; then
  dependency_authority=c545077ab2d2839007a4ac202f7896575d0ad9ba
fi
if [[ "$(git rev-parse HEAD:src/runtime/mod_fmr_production_application_bootstrap.f90)" == 8b480b09f47bb4443d755109c9093486853c0809 ]]; then
  python3 tests/mc-met01/verify_daily_demand_successor.py || fail 'daily demand complete highest evidence missing'
  dependency_authority=bd17f0a9a7c19516e66af8f80e2b7128890b3aee
  if (( joint_exact_successor )); then
    dependency_authority=c591205c5e03f1c96c6488eb53c562265f749556
  fi
fi
if [[ "$(git rev-parse HEAD:src/runtime/mod_fmr_production_application_bootstrap.f90)" == cb845eecd2409d6ee473bd7a0cb8194c0b501ad6 ]]; then
  python3 tests/crop-cycle/verify_oxygen_successor.py || fail 'crop oxygen complete owner evidence missing'
  dependency_authority=f0dd03704cd6eb19336269438e99c6bf5db08024
fi
if [[ "$(git rev-parse HEAD:src/runtime/mod_fmr_production_application_bootstrap.f90)" == 5a93008ed2fb18d0798ec0c967729815d156ec26 ]]; then
  python3 tests/crop-co2/verify_co2_successor.py || fail 'CO2 complete current owner evidence missing'
  dependency_authority=82209d0df68d14c5ebe707e9b6303f9b150488ca
fi
if [[ -f src/process/mod_b111_soil_n_mineral_owner.f90 ]]; then
  if [[ -f src/runtime/mod_fmr_b111_age_route.f90 ]]; then
    python3 tests/nut-sol/verify_age_successor.py --incumbent-mineral || fail 'unqualified age/mineral owner coexistence'
  else
    python3 tests/nut-mineral/verify_mineral_successor.py || fail 'unqualified daily mineral owner successor'
  fi
  dependency_authority=ee2d84498bec23c55449f5d7fd8ebd9ecb7bfdde
fi
if [[ -f src/process/mod_b111_soil_n_reactive_owner.f90 ]]; then
  if [[ -f src/runtime/mod_fmr_b111_age_route.f90 ]]; then
    python3 tests/nut-sol/verify_age_successor.py --incumbent-mineral || fail 'unqualified age/reactive N owner coexistence'
  else
    python3 tests/nut-reactive/verify_reactive_successor.py || fail 'unqualified reactive daily N successor'
  fi
  dependency_authority=eb03024d99ef9256335eb6e2f3f74bccce8145f0
fi
if [[ -f src/crop/mod_crop_soil_n_day.f90 ]]; then
  python3 tests/nut-crop/verify_crop_supply_successor.py || fail 'unqualified daily crop Soil-N supply successor'
  dependency_authority=f8eca95ba623dc18db0110cd1b84af46857c8b9b
fi
if [[ -f src/process/mod_soil_n_day_environment.f90 ]]; then
  python3 tests/nut-environment/verify_environment_successor.py || fail 'unqualified daily Soil-N environment successor'
  dependency_authority=dca8cbd87ceff62406d0d1a38447b7a7bc8fbd1c
fi
if [[ -f src/crop/mod_crop_soil_n_material_day.f90 ]]; then
  python3 tests/nut-material/verify_material_successor.py || fail 'unqualified explicit soil-N material day successor'
  dependency_authority=48e6aeb15a66dfd11a85de39dc6f8229842d1fd1
fi
if [[ -f src/runtime/mod_fmr_biomass_root_uptake_input.f90 ]]; then
  python3 tests/root-growth/verify_swrd3_successor.py || fail 'unqualified SWRD3 daily production'
  dependency_authority=3b661766dc59298a7f541c970c2d3a55602d926c
fi
if [[ -f integration/audits/MC_NUT01_ACCEPTED_THERMAL_STATUS.json ]]; then
  python3 -B tests/nut-thermal/verify_thermal_successor.py || fail 'unqualified accepted thermal N owner'
  nut_thermal_exact_successor=1
fi
# This exact additive work unit is based on reconciled live canonical, not
# an obsolete intermediate crop donor. Its full delta guard prevents a metadata
# checkpoint from hiding any science change. All numerical gates below remain.
if [[ -f integration/audits/MC_SOL01_SURFACE_AGE01_STATUS.json ]]; then
  dependency_authority="$(python3 -B - <<'PY_AGE_BASE'
import sys
sys.path.insert(0,'tests/nut-sol')
import verify_surface_age_successor as age
age.verify_qualification()
print(age.record()['baseline'])
PY_AGE_BASE
)" || fail 'unqualified surface-age canonical dependency boundary'
  # The backend is unchanged from this registered canonical authority.
  # Older thermal owner pins predate independent admitted optional extensions.
  NUT_THERMAL_BACKEND="$(git rev-parse "$dependency_authority:$BACKEND")"
fi
echo "FCI_CANONICAL_CURRENT_TARGET_DEPENDENCY_BASELINE=$dependency_authority"
crop_file_weather_exact_successor=0
for weather_path in src/adapter/mod_swap_daily_weather_file_adapter.f90 src/runtime/mod_fmr_production_application_bootstrap.f90 src/runtime/mod_fmr_serialized_multiswap_runtime.f90; do
  if [[ "$(git rev-parse "HEAD:$weather_path" 2>/dev/null)" != "$(git rev-parse "$dependency_authority:$weather_path" 2>/dev/null)" ]]; then
    bash tests/fci/run_crop_file_weather_production_successor.sh --verify-only || fail 'unqualified file-weather production successor'
    crop_file_weather_exact_successor=1
    break
  fi
done
drain_signed_exact_successor=0
if [[ -f tests/fmig431/verify_signed_divdra_successor.py ]]; then
  python3 -B tests/fmig431/verify_signed_divdra_successor.py || fail 'unqualified ordinary signed DIVDRA successor'
  drain_signed_exact_successor=1
fi
for path in "${dependency_surface[@]}"; do
  if (( drain_signed_exact_successor )); then
    case "$path" in
      src/process/mod_drainage_spatial_distribution.f90|src/runtime/mod_fmr_divdra_runtime_binding.f90|src/runtime/mod_fmr_divdra_serialized_composition.f90|src/runtime/mod_fmr_divdra_serialized_runtime.f90)
        continue ;; # Exact successor, complete focused evidence and incumbent bodies checked above.
    esac
  fi
  if (( nut_thermal_exact_successor )) && [[ "$path" == "$BACKEND" ]]; then
    test "$(git rev-parse "HEAD:$path")" = "$NUT_THERMAL_BACKEND" || fail 'thermal backend default projection drift'
    continue
  fi
  if (( crop_file_weather_exact_successor )) && [[ "$path" == src/runtime/mod_fmr_serialized_multiswap_runtime.f90 ]]; then
    continue # Exact postimage checked above; all F-KT semantics remain guarded.
  fi
  case "$path" in
    src/runtime/mod_canonical_contracts.f90|src/runtime/mod_canonical_interval_runtime.f90)
      if (( joint_exact_successor )); then continue; fi ;;
    src/process/mod_soil_temperature_contract.f90|src/process/mod_restricted_soil_temperature.f90)
      if (( mc_heat01_exact_successor )); then continue; fi ;;
  esac
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
    if [[ "$path" == src/legacy/b1_10_port/headcalc.f90 ]] && (( mc_irr01_storage_exact_successor )); then continue; fi
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
# Exact MC-CROP01 successor is never wildcard admission: only known F-KT
# and B110 blobs may enter this branch, with unchanged reference and all other
# production sources proved by the independent source guard.
crop_fkt_b110_exact_successor=0
# The SHA-exact shared-owner successor applies only to a PR that actually
# modifies kernel/backend versus canonical first parent. Crop-only PRs
# inherit the admitted blobs and use their own focused source gates.
if [[ "$(git rev-parse HEAD:src/kernel/mod_kernel_transactions.f90)" == "da7a00b6aec996cff504d8d30a90e51a8cce2162" &&
      "$(git rev-parse HEAD:$BACKEND)" == "b218ac657db52612bc12da671716c97430200f0a" ]] &&
   { [[ "$(git rev-parse HEAD:src/kernel/mod_kernel_transactions.f90)" != "$(git rev-parse "$dependency_authority:src/kernel/mod_kernel_transactions.f90")" ]] ||
     [[ "$(git rev-parse HEAD:$BACKEND)" != "$(git rev-parse "$dependency_authority:$BACKEND")" ]]; }; then
  bash tests/fci/run_crop_fkt_b110_exact_source_successor.sh --verify-only ||
    fail 'crop certified F-KT/B110 exact source successor rejected'
  crop_fkt_b110_exact_successor=1
  echo 'FCI_CANONICAL_CROP_FKT_B110_EXACT_SOURCE_SUCCESSOR=PASS'
fi
if git merge-base --is-ancestor "$F_ROM1A_PRODUCTION" HEAD; then
  if (( crop_fkt_b110_exact_successor )); then
    test "$(git rev-parse HEAD:src/kernel/mod_kernel_transactions.f90)" = "da7a00b6aec996cff504d8d30a90e51a8cce2162" ||
      fail 'crop F-KT exact kernel source drift'
  else
  test "$(git rev-parse HEAD:src/kernel/mod_kernel_transactions.f90)" = \
       "$(git rev-parse "$dependency_authority:src/kernel/mod_kernel_transactions.f90")" || \
    fail 'candidate changed current kernel-transaction target postimage'
  fi
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
irrigation_owner_verified=0
verify_mc_irr01_owner_successor() {
  if (( irrigation_owner_verified )); then return; fi
  if [[ -f integration/audits/MC_SOL01_SURFACE_AGE01_STATUS.json ]]; then
    # This unit changes no irrigation code. The complete exact-delta age
    # validator and the current irrigation/HIST owner retain its native proof;
    # do not compare current management against an obsolete intermediate donor.
    python3 -B tests/nut-sol/verify_surface_age_successor.py || fail 'surface-age exact boundary for irrigation owner'
    python3 -B tests/mc-irr01/verify_tcs6_successor.py || fail 'current irrigation owner science under surface-age successor'
    irrigation_owner_verified=1
    echo 'FCI_CANONICAL_MC_IRR01_CURRENT_OWNER_SOURCE_AND_EVIDENCE=PASS'
    return
  fi
  local candidate_path
  declare -A irrigation_owner_blobs=(
    [src/process/mod_irrigation_availability_policy.f90]=aed1ca5ae88a02da2493978bceca77805fe51eb4
    [src/process/mod_irrigation_process.f90]=c14ce960691c9a8835253b5aa576fc3eef9c11ec
    [src/process/mod_irrigation_root_zone_summary.f90]=81fb9e35d1fe0026bf5719175a3af8f3d080592e
    [src/process/mod_scheduled_irrigation_management_policy.f90]=2f135457852c7256d25c19afc9eba3dd06b52f4b
    [src/process/mod_tcs1_dcs2_sprinkling_irrigation_process.f90]=88a3f5c3f78624ec2da91252de932c4c36ac7ea0
    [src/runtime/mod_fmr_hupsel_irrigation_application_binding.f90]=e952aa327319bf23a7336d0740670e8f802cd147
    [src/runtime/mod_fmr_irrigation_management_restart.f90]=2fc1090a9871d3373840c88f2ef13093f733c11f
    [src/runtime/mod_fmr_scheduled_irrigation_application.f90]=91a8b3f50d3f041c69ad2f6e8e88482c058a9eca
    [src/runtime/mod_fmr_scheduled_irrigation_forcing_binding.f90]=1104bc35080780bf95d8b8ef85d02f1e1f2f803d
    [src/runtime/mod_fmr_scheduled_management_irrigation_application.f90]=cb19ae772cad71c293a9097c2e8a24585f5e870e
    [src/runtime/mod_fmr_scheduled_management_irrigation_routing.f90]=f604dfbcd28258af4e6339f15138b158e946ed45
  )
  irrigation_owner_blobs[src/runtime/mod_fmr_management_irrigation_forcing_binding.f90]=649006fb63395fa2980bae8e6853eedc6f122bed
  irrigation_owner_blobs[src/runtime/mod_fmr_sensor_depth_irrigation_binding.f90]=649143a63dd29df8e1ec5b15ac75e8244d05c87f
  local root_salt_successor=0
  if [[ "$(git rev-parse HEAD:src/process/mod_irrigation_process.f90)" == a917a2c7b912cd85e19d22ddfe3468683e936a3e ]] &&
     [[ "$(git rev-parse HEAD:src/runtime/mod_fmr_scheduled_management_irrigation_application.f90)" == 4f5bbd6147b6d67ab31db4bb53f68ec00d25d3e3 ]]; then
    git merge-base --is-ancestor 9d95eacb6619f7fece1d3bfe7b3e068304836ecd HEAD || fail 'root salt successor lineage'
    test "$(git rev-parse HEAD:src/legacy/b1_10_port/headcalc.f90)" = 7ff36cbadf8acfaa09e129ff54aa54a933c3f1ac || fail 'root salt shared storage prerequisite'
    irrigation_owner_blobs[src/process/mod_irrigation_process.f90]=a917a2c7b912cd85e19d22ddfe3468683e936a3e
    irrigation_owner_blobs[src/runtime/mod_fmr_scheduled_management_irrigation_application.f90]=4f5bbd6147b6d67ab31db4bb53f68ec00d25d3e3
    root_salt_successor=1
  fi
  for candidate_path in "${!irrigation_owner_blobs[@]}"; do
    test "$(git rev-parse "HEAD:$candidate_path")" = "${irrigation_owner_blobs[$candidate_path]}" ||
      fail "unqualified MC-IRR01 owner blob: $candidate_path"
  done
  bash tests/f-app07/run_fapp07_tcs1_dcs2_process.sh ||
    fail 'MC-IRR01 exact owner and composed-path O0/O2 preservation failed'
  bash tests/mc-irr01/run_mc_irr01_management_policy.sh || fail 'MC-IRR01 management preservation'
  bash tests/mc-irr01/run_mc_irr01_literal_management.sh || fail 'MC-IRR01 exact B1.11 management oracle'
  bash tests/mc-irr01/run_mc_irr01_literal_availability.sh || fail 'MC-IRR01 exact B1.11 TASK4 oracle'
  bash tests/f-app07/run_mc_irr01_management_physical_runtime.sh || fail 'MC-IRR01 physical binding and rollback'
  bash tests/f-app07/run_mc_irr01_sensor_depth_runtime.sh || fail 'MC-IRR01 sensor depth physical/restart composition'
  if (( root_salt_successor )); then
    test "$(git rev-parse HEAD:tests/mc-irr01/run_mc_irr01_literal_root_salt.sh)" = a734c0fdf9f1169fcb0ff30db4fd7766005774a4 || fail 'root salt literal gate identity'
    test "$(git rev-parse HEAD:tests/f-app07/run_mc_irr01_root_salt_realistic.sh)" = 461b1d570e7f163cc0c194f2604c6890441dba84 || fail 'root salt physical gate identity'
    test "$(git rev-parse HEAD:tests/f-app07/test_mc_irr01_root_salt_realistic.f90)" = 02e5bbe0b49d02ef97c12ad5831449fc4b553178 || fail "root salt physical fixture identity: tests/f-app07/test_mc_irr01_root_salt_realistic.f90"
    test "$(git rev-parse HEAD:tests/f-app07/mc_irr01_realistic_headcalc_stubs.f90)" = 88795f8ca83afa4754e78f1bec32dc8aea598e30 || fail "root salt physical fixture identity: tests/f-app07/mc_irr01_realistic_headcalc_stubs.f90"
    bash tests/mc-irr01/run_mc_irr01_literal_root_salt.sh || fail 'root salt source semantics preservation'
    bash tests/f-app07/run_mc_irr01_root_salt_realistic.sh || fail 'root salt physical source/depth/availability preservation'
    echo 'FCI_CANONICAL_MC_IRR01_ROOT_SALT_SUCCESSOR=PASS'
  fi
  if git cat-file -e HEAD:src/runtime/mod_fmr_accepted_salt_irrigation_binding.f90 2>/dev/null; then
    (( root_salt_successor )) || fail 'accepted salt root prerequisite'
    git merge-base --is-ancestor cb841851db6a4f459835b4943cf442595898ecd3 HEAD || fail 'accepted salt PR1015 lineage'
    test "$(git rev-parse HEAD:src/runtime/mod_fmr_accepted_salt_irrigation_binding.f90)" = a9ba5313efc564fd26d3951457aa40f1d92cb214 || fail 'accepted salt dependency identity: src/runtime/mod_fmr_accepted_salt_irrigation_binding.f90'
    test "$(git rev-parse HEAD:tests/f-app07/run_mc_irr01_accepted_salt_restart.sh)" = 74128e215430d1b97893d63821523d65671a623b || fail 'accepted salt dependency identity: tests/f-app07/run_mc_irr01_accepted_salt_restart.sh'
    test "$(git rev-parse HEAD:tests/f-app07/test_mc_irr01_accepted_salt_restart.f90)" = 7dabc5b191e8def3fcfcd78e74fbfe359ccb80a7 || fail 'accepted salt dependency identity: tests/f-app07/test_mc_irr01_accepted_salt_restart.f90'
    test "$(git rev-parse HEAD:tests/f-app07/run_mc_irr01_accepted_salt_root_restart.sh)" = 742f9ecaaf90fbf14e09c15a03e7de61d9b04a35 || fail 'accepted salt dependency identity: tests/f-app07/run_mc_irr01_accepted_salt_root_restart.sh'
    test "$(git rev-parse HEAD:tests/f-app07/test_mc_irr01_accepted_salt_root_restart.f90)" = 2e28ef5ac19d18dd5cc474609e28032474326ddd || fail 'accepted salt dependency identity: tests/f-app07/test_mc_irr01_accepted_salt_root_restart.f90'
    bash tests/f-app07/run_mc_irr01_accepted_salt_restart.sh || fail 'accepted salt sensor physical/restart'
    bash tests/f-app07/run_mc_irr01_accepted_salt_root_restart.sh || fail 'accepted salt root physical/restart'
    echo 'FCI_CANONICAL_MC_IRR01_ACCEPTED_SALT_SUCCESSOR=PASS'
  fi
  if git cat-file -e HEAD:src/runtime/mod_fmr_irrigation_allocation_binding.f90 2>/dev/null; then
    verify_mc_irr01_allocation_successor
  fi
  echo 'FCI_CANONICAL_MC_IRR01_EXACT_OWNER_SUCCESSOR=PASS' 
  irrigation_owner_verified=1
}

# Explicit focused replay of the unchanged current irrigation owner function
# after an independently admitted concurrent owner delta. Normal full moving
# preservation still runs every required route and is unchanged.
if [[ "${1:-}" == --mc-irr01-owner-only ]]; then
  verify_mc_irr01_owner_successor
  echo 'FCI_CANONICAL_MC_IRR01_CURRENT_OVERLAP_PRESERVATION=PASS'
  exit 0
fi

check_b19_micro_root_recomposition() {
  if [[ -f tests/fmig431/verify_dislayer_successor.py ]]; then
    python3 -B tests/fmig431/verify_dislayer_successor.py
    echo 'FCI_B19_DISLAYER_CURRENT_OWNER_RECONCILIATION=PASS'
    return 0
  fi
  local ppa_weather_guard_changed=0
  local crop_positive_window_changed=0
  local crop_event_constructor_changed=0
  local crop_lifecycle_changed=0
  local crop_physical_restart_changed=0
  local crop_unified_restart_changed=0
  local crop_accepted_heat_changed=0
  local crop_certified_sow_changed=0
  local crop_certified_daily_changed=0
  local crop_germination_source_order_changed=0
  local crop_tav_day_changed=0
  local crop_tav_meteo_changed=0
  local crop_tav_period_changed=0
  local crop_meteo_load006_changed=0
  local crop_weather_register_changed=0
  local crop_weather_ppa_binding_changed=0
  local crop_weather_owner_test_changed=0
  local crop_weather_preflight_changed=0
  local crop_weather_event_changed=0
  local crop_b111_germ_sum_changed=0
  local crop_atomic_hydroheat_changed=0
  local crop_head_depth_changed=0
  local crop_havg_changed=0
  local crop_sow_node_changed=0
  local crop_grid_sow_changed=0
  local crop_hydraulic_provenance_changed=0
  local crop_hydraulic_provenance_changed=0
  local irrigation_owner_changed=0
  local nlglob14z47_changed=0
  local candidate_path
  while IFS= read -r candidate_path; do
    case "$candidate_path" in
      src/process/mod_frost_divdra_drainage_effect.f90|src/process/mod_drainage_b19_separate_infiltration_adapter.f90|src/runtime/mod_fmr_divdra_separate_infiltration_binding.f90|src/runtime/mod_fmr_divdra_serialized_composition.f90|src/runtime/mod_fmr_divdra_serialized_runtime.f90 )
        python3 -B tests/fmig431/verify_inf_split_successor.py || fail 'unqualified shared separate-infiltration successor'
        ;;
      src/runtime/mod_canonical_contracts.f90|src/runtime/mod_canonical_interval_runtime.f90 )
        (( joint_exact_successor )) || fail "unqualified numerical successor: $candidate_path"
        ;;
      src/process/mod_reference_et_demand_process.f90 )
        test "$(git rev-parse HEAD:src/process/mod_reference_et_demand_process.f90)" = \
          "0a8fc91570c6297a54109740de3a26153dc44283" ||
          fail 'unqualified daily-demand process postimage'
        python3 tests/mc-met01/verify_daily_demand_successor.py ||
          fail 'daily-demand process source/owner/highest qualification missing'
        ;;
      src/process/mod_frost_hydraulic_effect.f90 )
        verify_crop_frost_highest ||
          fail 'unqualified frost hydraulic guard source change'
        ;;
      src/legacy/b1_10_port/headcalc.f90 )
        (( mc_irr01_storage_exact_successor )) || fail "unqualified shared storage arithmetic: $candidate_path" ;;
      src/kernel/mod_kernel_transactions.f90 )
        (( crop_fkt_b110_exact_successor )) ||
          fail "unqualified shared crop F-KT/B110 owner source change: $candidate_path"
        ;;
      src/runtime/mod_fmr_wofost_crop_transaction.f90 )
        python3 -B tests/root-growth/verify_swrd2_successor.py || fail 'unqualified persistent SWRD2 crop transaction'
        ;;
      src/runtime/mod_fmr_biomass_root_uptake_input.f90|src/crop/mod_wofost_emergence_initialization.f90|src/adapter/mod_swap_daily_weather_file_adapter.f90|src/runtime/mod_fmr_production_application_bootstrap.f90|src/runtime/mod_fmr_serialized_multiswap_runtime.f90 )
        (( crop_file_weather_exact_successor )) || fail "unqualified production weather/commit path: $candidate_path"
        ;;
      src/runtime/mod_fmr_serialized_reference_backend.f90 )
        (( crop_fkt_b110_exact_successor || mc_heat01_exact_successor || nut_thermal_exact_successor )) ||
          fail "unqualified shared serialized backend source change: $candidate_path"
        ;;
      src/runtime/mod_groundwater_multiswap_publication.f90 )
        (( modular_repair_exact_successor )) ||
          fail "unqualified MultiSWAP beginning-balance repair: $candidate_path"
        ;;
      src/process/mod_soil_temperature_contract.f90|src/process/mod_restricted_soil_temperature.f90 )
        (( mc_heat01_exact_successor )) || fail "unqualified MC-HEAT01 source change: $candidate_path" ;;
      src/adapter/mod_crop_atmospheric_co2_forcing.f90 )
        python3 tests/crop-co2/verify_co2_successor.py || fail 'unqualified annual CO2 forcing successor'
        ;;
      src/adapter/mod_ppa_wu03_common_forcing_adapter.f90 ) ppa_weather_guard_changed=1 ;;
      tests/fapp/test_ppa_wu03_common_forcing_adapter.f90 ) ppa_weather_guard_changed=1 ;;
      src/crop/mod_crop_adaptive_root_profile_owner.f90 ) ;;
      src/crop/mod_crop_root_anaerobic_extension_gate.f90 ) ;;
      src/crop/mod_crop_root_depth_biomass.f90 ) ;;
      src/crop/mod_crop_root_depth_rate_owner.f90 ) ;;
      src/crop/mod_crop_root_extension_supply_limit.f90 ) ;;
      src/crop/mod_wofost_crop_owner_state.f90 ) ;;
      src/crop/mod_wofost_actual_biomass_state.f90 )
        python3 -B tests/fmig431/annual/verify_annual_successor.py || fail 'unqualified classic mortality state successor'
        ;;
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
      src/runtime/mod_fmr_wofost_crop_transaction.f90 ) crop_event_constructor_changed=1 ;;
      tests/fmig431/patch_crop_lifecycle_fwof38_fixture.py|tests/fmig431/run_crop_lifecycle_fkt_compatibility.sh ) crop_positive_window_changed=1 ;;
      src/process/mod_root_water_uptake_process.f90 ) ;;
      src/crop/mod_crop_root_length_density_constant.f90 ) ;;
      src/crop/mod_crop_rotation_calendar.f90 ) ;;
      src/crop/mod_crop_rotation_transition.f90 ) crop_unified_restart_changed=1 ;;
      src/crop/mod_crop_rotation_lifecycle_preflight.f90 ) ;;
      src/crop/mod_crop_preparation_sowing_preflight.f90 ) ;;
      src/crop/mod_crop_germination_preflight.f90 ) crop_germination_source_order_changed=1 ;;
      src/crop/mod_crop_lifecycle_daily_composition.f90 ) ;;
      src/crop/mod_crop_lifecycle_continuation.f90 ) crop_lifecycle_changed=1 ;;
      src/crop/mod_crop_previous_day_emergence_gate.f90 ) crop_lifecycle_changed=1 ;;
      src/crop/mod_crop_b111_pressure_head_average.f90 ) crop_havg_changed=1 ;;
      src/crop/mod_crop_b111_sowing_node.f90 ) crop_sow_node_changed=1 ;;
      src/crop/mod_crop_b110_grid_sowing_preflight.f90 ) crop_grid_sow_changed=1 ;;
      src/runtime/mod_fmr_crop_accepted_head_depth_binding.f90 ) crop_head_depth_changed=1 ;;
      src/runtime/mod_fmr_crop_accepted_soil_temperature.f90 ) crop_accepted_heat_changed=1 ;;
      src/runtime/mod_fmr_crop_atomic_accepted_hydroheat.f90 ) crop_atomic_hydroheat_changed=1 ;;
      src/runtime/mod_fmr_crop_certified_sowing_source.f90 ) crop_certified_sow_changed=1 ;;
      src/runtime/mod_fmr_crop_certified_hydrothermal_forcing.f90 ) crop_certified_sow_changed=1 ;;
      src/runtime/mod_fmr_crop_certified_germination_moisture.f90|src/runtime/mod_fmr_crop_certified_daily_preflight.f90 ) crop_certified_daily_changed=1 ;;
      src/crop/mod_crop_tav_day_window.f90 ) crop_tav_day_changed=1 ;;
      src/crop/mod_crop_tav_meteorological_candidate.f90 ) crop_tav_meteo_changed=1 ;;
      src/crop/mod_crop_tav_detailed_period_candidate.f90 ) crop_tav_period_changed=1 ;;
      src/crop/mod_crop_b111_meteo_loading_candidate.f90 ) crop_meteo_load006_changed=1 ;;
      src/crop/mod_crop_weather_day_owner.f90 ) crop_weather_register_changed=1 ;;
      src/adapter/mod_ppa_wu03_common_forcing_adapter.f90 ) crop_weather_ppa_binding_changed=1 ;;
      tests/fmig431/test_crop_weather_day_owner.f90 ) crop_weather_owner_test_changed=1 ;;
      src/runtime/mod_fmr_crop_weather_day_preflight.f90 ) crop_weather_preflight_changed=1 ;;
      src/runtime/mod_fmr_crop_weather_physical_event_composition.f90 ) crop_weather_event_changed=1 ;;
      tests/fmig431/test_crop_weather_preflight_read_boundary.f90 ) crop_weather_preflight_changed=1 ;;
      src/crop/mod_crop_b111_germination_sum_candidate.f90 ) crop_b111_germ_sum_changed=1 ;;
      src/runtime/mod_fmr_crop_rotation_receipt_binding.f90 ) ;;
      src/runtime/mod_fmr_crop_physical_calendar_restart_coherence.f90 ) crop_physical_restart_changed=1; crop_unified_restart_changed=1 ;;
      src/runtime/mod_fmr_crop_accepted_hydraulic_provenance.f90 ) crop_hydraulic_provenance_changed=1 ;;
      src/runtime/mod_fmr_crop_accepted_hydraulic_provenance.f90 ) crop_hydraulic_provenance_changed=1 ;;
      src/runtime/mod_fmr_micro_constant_lrv_binding.f90 ) ;;
      src/process/mod_irrigation_availability_policy.f90 ) irrigation_owner_changed=1 ;;
      src/process/mod_irrigation_process.f90 ) irrigation_owner_changed=1 ;;
      src/process/mod_irrigation_root_zone_summary.f90 ) irrigation_owner_changed=1 ;;
      src/process/mod_scheduled_irrigation_management_policy.f90 ) irrigation_owner_changed=1 ;;
      src/process/mod_tcs1_dcs2_sprinkling_irrigation_process.f90 ) irrigation_owner_changed=1 ;;
      src/runtime/mod_fmr_hupsel_irrigation_application_binding.f90 ) irrigation_owner_changed=1 ;;
      src/runtime/mod_fmr_irrigation_management_restart.f90 ) irrigation_owner_changed=1 ;;
      src/runtime/mod_fmr_scheduled_irrigation_application.f90 ) irrigation_owner_changed=1 ;;
      src/runtime/mod_fmr_scheduled_irrigation_forcing_binding.f90 ) irrigation_owner_changed=1 ;;
      src/runtime/mod_fmr_scheduled_management_irrigation_application.f90 ) irrigation_owner_changed=1 ;;
      src/runtime/mod_fmr_scheduled_management_irrigation_routing.f90 ) irrigation_owner_changed=1 ;;
      src/runtime/mod_fmr_management_irrigation_forcing_binding.f90 ) irrigation_owner_changed=1 ;;
      src/runtime/mod_fmr_sensor_depth_irrigation_binding.f90 ) irrigation_owner_changed=1 ;;
      src/runtime/mod_fmr_accepted_salt_irrigation_binding.f90 ) irrigation_owner_changed=1 ;;
      src/runtime/mod_fmr_irrigation_allocation_binding.f90 ) irrigation_owner_changed=1 ;;
      src/runtime/mod_moving_interface_manager.f90 ) nlglob14z47_changed=1 ;;
      src/adapter/mod_matrix_joint_restart_file.f90|src/process/mod_b111_pond_solute_exchange.f90|src/process/mod_b111_reactive_solute_substep.f90|src/process/mod_b111_solute_decay.f90|src/process/mod_b111_solute_sorption.f90|src/process/mod_solute_compartment_state.f90|src/runtime/mod_fmr_b111_matrix_joint_application.f90|src/runtime/mod_fmr_b111_matrix_solute_route.f90 )
        python3 tests/crop-co2/verify_co2_successor.py --source-only || fail "unqualified additive matrix successor: $candidate_path"
        ;;
      src/process/mod_soil_n_pool_state.f90|src/process/mod_b111_soil_n_storage_conversion.f90|src/process/mod_b111_soil_n_transport.f90|src/process/mod_b111_soil_n_mineral_owner.f90|src/runtime/mod_fmr_b111_mineral_route.f90|src/runtime/mod_fmr_b111_mineral_joint_application.f90|src/adapter/mod_mineral_joint_restart_file.f90 )
        if [[ -f src/runtime/mod_fmr_b111_age_route.f90 ]]; then
          python3 tests/nut-sol/verify_age_successor.py --incumbent-mineral || fail "unqualified age/mineral coexistence: $candidate_path"
        else
          python3 tests/nut-mineral/verify_mineral_successor.py || fail "unqualified mineral successor: $candidate_path"
        fi
        ;;
      src/process/mod_b111_surface_age_budget.f90|src/process/mod_b111_surface_age_owner.f90|src/process/mod_b111_surface_age_soil_handoff.f90|src/runtime/mod_b111_surface_age_trace_bridge.f90|src/adapter/mod_b111_surface_age_disk.f90|src/adapter/mod_b111_age_triplet_disk.f90|src/adapter/mod_b111_age_snapshot_disk.f90 )
        python3 -B tests/nut-sol/verify_surface_age_successor.py || fail "unqualified surface-age successor: $candidate_path"
        ;;
      src/process/mod_b111_age_tracer_substep.f90|src/runtime/mod_fmr_b111_age_route.f90|src/runtime/mod_fmr_b111_age_joint_application.f90|src/adapter/mod_age_joint_restart_file.f90 )
        python3 tests/nut-sol/verify_age_successor.py || fail "unqualified accepted age successor: $candidate_path"
        ;;
      src/process/mod_b111_soil_organic_turnover.f90|src/process/mod_b111_soil_n_organic_mineralization_transfer.f90|src/process/mod_b111_soil_n_organic_turnover_transfer.f90|src/process/mod_b111_soil_organic_dissimilation.f90|src/process/mod_b111_soil_n_rate_factors.f90|src/process/mod_b111_soil_n_daily_exchange.f90|src/process/mod_b111_soil_n_daily_candidate.f90|src/process/mod_b111_soil_n_organic_rate_environment.f90|src/process/mod_b111_soil_n_reactive_owner.f90|src/runtime/mod_fmr_b111_reactive_n_route.f90|src/runtime/mod_fmr_b111_reactive_n_joint_application.f90|src/adapter/mod_reactive_n_joint_restart_file.f90 )
        if [[ -f src/runtime/mod_fmr_b111_age_route.f90 ]]; then
          python3 tests/nut-sol/verify_age_successor.py --incumbent-mineral || fail "unqualified age/reactive N coexistence: $candidate_path"
        else
          python3 tests/nut-reactive/verify_reactive_successor.py || fail "unqualified reactive successor: $candidate_path"
        fi
        ;;
      src/process/mod_b111_persistent_pond.f90|src/runtime/mod_fmr_b111_pond_solute_route.f90|src/runtime/mod_fmr_b111_pond_joint_application.f90 )
        python3 -B tests/nut-sol/verify_pond_successor.py || fail "unqualified persistent pond successor: $candidate_path"
        ;;
      src/process/mod_b111_surface_supply.f90|src/runtime/mod_fmr_b111_surface_solute_route.f90|src/runtime/mod_fmr_b111_surface_joint_application.f90 )
        python3 tests/nut-sol/verify_surface_successor.py --incumbent-mineral || fail "unqualified surface input successor: $candidate_path"
        ;;
      src/crop/mod_wofost81_crop_owner_state.f90|src/crop/mod_wofost81_one_day_candidate.f90|src/crop/mod_wofost81_harvest_materials.f90 )
        python3 -B tests/crop-harvest/verify_harvest_successor.py || fail "unqualified explicit harvest successor: $candidate_path"
        ;;
      src/crop/mod_crop_soil_n_configuration.f90|src/crop/mod_crop_soil_n_day.f90|src/runtime/mod_fmr_crop_soil_n_joint_application.f90|src/adapter/mod_crop_soil_n_joint_restart_file.f90 )
        python3 tests/nut-crop/verify_crop_supply_successor.py || fail "unqualified crop Soil-N successor: $candidate_path"
        ;;
      src/process/mod_soil_n_day_environment.f90 )
        python3 tests/nut-environment/verify_environment_successor.py || fail "unqualified daily environment: $candidate_path"
        ;;
      src/process/mod_b111_soil_n_addition.f90|src/crop/mod_crop_soil_n_material_day.f90|src/runtime/mod_fmr_crop_soil_n_material_application.f90|src/process/mod_crop_senescence_residue.f90|src/crop/mod_crop_soil_n_senescence_day.f90|src/runtime/mod_fmr_crop_soil_n_senescence_application.f90|src/process/mod_soil_n_amendment_calendar.f90|src/crop/mod_crop_soil_n_calendar_day.f90|src/runtime/mod_fmr_crop_soil_n_calendar_application.f90|src/process/mod_soil_n_amendment_input.f90|src/process/mod_soil_n_profile_temperature.f90|src/runtime/mod_fmr_soil_n_accepted_temperature.f90|src/runtime/mod_fmr_crop_soil_n_thermal_application.f90 )
        python3 tests/nut-material/verify_material_successor.py || fail "unqualified material day successor: $candidate_path"
        ;;
      *) fail "B19+MICRO unqualified source change: $candidate_path" ;;
    esac
  done < <(git diff --name-only "$dependency_authority" HEAD -- src tests/fapp/test_ppa_wu03_common_forcing_adapter.f90 tests/fmig431/test_crop_weather_day_owner.f90 tests/fmig431/test_crop_weather_preflight_read_boundary.f90 tests/fmig431/patch_crop_lifecycle_fwof38_fixture.py tests/fmig431/run_crop_lifecycle_fkt_compatibility.sh)
  if (( irrigation_owner_changed )); then verify_mc_irr01_owner_successor; fi
  if (( nlglob14z47_changed )); then
    test "$(git rev-parse HEAD:src/runtime/mod_moving_interface_manager.f90)" = \
      "fc3805e1f106b5de1ee3a492920d0c21eba7bd1d" ||
      fail 'unqualified F-PE-NLGLOB14Z47 moving-interface manager blob'
    bash tests/fpe/run_fpe_nlglob14z47.sh ||
      fail 'F-PE-NLGLOB14Z47 exact eligibility successor O0/O2 preservation failed'
    echo 'FCI_CANONICAL_NLGLOB14Z47_EXACT_ELIGIBILITY_SUCCESSOR=PASS'
  fi
  if (( ppa_weather_guard_changed )); then
    test "$(git rev-parse HEAD:src/adapter/mod_ppa_wu03_common_forcing_adapter.f90)" = "7ddaaddcedc04fad6ba9d38ca4626332014f8d5b" ||
      fail 'unqualified PPA-WU03 shared weather guard source'
    test "$(git rev-parse HEAD:tests/fapp/test_ppa_wu03_common_forcing_adapter.f90)" = "75bf7cecfc8ab7099410574fa899d9b395977e31" ||
      fail 'unqualified PPA-WU03 shared weather owner test'
    test "$(git rev-parse HEAD:tests/fapp/run_ppa_wu03_common_forcing_adapter.sh)" = "588fdbf890a14fc558cbf932f82467df18599d55" ||
      fail 'unqualified PPA-WU03 owner runner'
    test "$(git rev-parse HEAD:tests/fapp/run_ppa_wu03_independent.sh)" = "4e028359102aaaf9a678284d0b3ce8bad1b9ac72" ||
      fail 'unqualified PPA-WU03 independent runner'
    bash tests/fapp/run_ppa_wu03_common_forcing_adapter.sh ||
      fail 'PPA-WU03 shared weather owner O0/O2 physical qualification failed'
    bash tests/fapp/run_ppa_wu03_independent.sh ||
      fail 'PPA-WU03 shared weather independent O0/O2 qualification failed'
    echo 'FCI_CANONICAL_PPA_WU03_CROP_SHARED_WEATHER_GUARD=PASS'
  fi
  if (( crop_b111_germ_sum_changed )); then
    test "$(git rev-parse HEAD:src/crop/mod_crop_b111_germination_sum_candidate.f90)" =       "13e83db9e7dad60a62c11134f8951d65a23c7dc6" ||
      fail 'unqualified changed B1.11 germination arithmetic blob'
    bash tests/fmig431/run_crop_b111_germination_sum_candidate.sh ||
      fail 'B1.11 germination daily candidate O0/O2 failed'
    bash tests/fmig431/run_crop_b111_germination_source_oracle.sh ||
      fail 'B1.11 germination source oracle O0/O2 failed'
    bash tests/fmig431/run_crop_b111_germination_boundaries.sh ||
      fail 'B1.11 germination boundary negative O0/O2 failed'
    echo 'FCI_CANONICAL_CROP_B111_GERMINATION_EXACT_SOURCE=PASS'
  fi
  if (( crop_positive_window_changed )); then
    test "$(git rev-parse HEAD:tests/fmig431/patch_crop_lifecycle_fwof38_fixture.py)" = "73255c2ad901444a815819de336995094cd5d5f9" ||
      fail 'unqualified positive crop accepted-window fixture'
    test "$(git rev-parse HEAD:tests/fmig431/run_crop_lifecycle_fkt_compatibility.sh)" = "3948f633748db18239a4b59b9b8ce26f1af95012" ||
      fail 'unqualified positive crop accepted-window runner'
    bash tests/fmig431/run_crop_lifecycle_fkt_compatibility.sh ||
      fail 'positive FWO38 weather/B110 accepted-window O0/O2 failed'
    echo 'FCI_CANONICAL_CROP_POSITIVE_WINDOW_BRIDGE=PASS'
  fi
  if (( crop_event_constructor_changed )); then
    expected_crop_blob=3c6fea3ca43b35b563f25f5dbbd24e90e89b4509
    if (( crop_file_weather_exact_successor )); then
      expected_crop_blob=0f7fccc714a908083f4550394ca1fdd28f354d47
      if [[ "$(git rev-parse HEAD:src/runtime/mod_fmr_production_application_bootstrap.f90)" == 851cb80954e1be909f6ec54661c0b12b80f225cd || "$(git rev-parse HEAD:src/runtime/mod_fmr_production_application_bootstrap.f90)" == 23c2db74b1254e5e97e608764d186a59eeb694d5 ]]; then
        expected_crop_blob=39b4f75c92ea44d6b4e4be326ddf731f54522dfd
      fi
      if [[ "$(git rev-parse HEAD:src/runtime/mod_fmr_production_application_bootstrap.f90)" == 2ae6e3aafe9f4987b562618443b0ccd48a133a4c || "$(git rev-parse HEAD:src/runtime/mod_fmr_production_application_bootstrap.f90)" == 8b480b09f47bb4443d755109c9093486853c0809 ]]; then
        expected_crop_blob=39b4f75c92ea44d6b4e4be326ddf731f54522dfd
      fi
    fi
    test "$(git rev-parse HEAD:src/runtime/mod_fmr_wofost_crop_transaction.f90)" = "$expected_crop_blob" ||
      fail 'unqualified WOFOST crop event constructor source'
    bash tests/fmig431/run_crop_lifecycle_fkt_compatibility.sh ||
      fail 'physical F-KT crop lifecycle constructor O0/O2 negatives failed'
    echo 'FCI_CANONICAL_CROP_EVENT_CONSTRUCTOR_EXACT=PASS'
  fi
  if (( crop_weather_event_changed )); then
    expected_crop_blob=8e2e554bbffdd1dad579d63d36ae9a844e2bc2d7
    if (( crop_file_weather_exact_successor )); then expected_crop_blob=14b8d5e07c7abb08416a3d64e05fc06e9737af4a; fi
    test "$(git rev-parse HEAD:src/runtime/mod_fmr_crop_weather_physical_event_composition.f90)" = "$expected_crop_blob" ||
      fail 'unqualified source for weather-to-physical crop event composition'
    bash tests/fmig431/run_crop_weather_preflight_read_boundary.sh ||
      fail 'weather-to-physical crop event gate O0/O2 failed'
    echo 'FCI_CANONICAL_CROP_WEATHER_EVENT_COMPOSITION=PASS'
  fi
  if (( crop_weather_preflight_changed )); then
    test "$(git rev-parse HEAD:tests/fmig431/test_crop_weather_preflight_read_boundary.f90)" = "64ef8f27ad312a61f1d362ba6dccdbd1bd6f13ed" ||
      fail 'unqualified integrated weather heat-off restart test blob'
    test "$(git rev-parse HEAD:tests/fmig431/run_crop_weather_preflight_read_boundary.sh)" = "db3e496a5d13b72784ab642c46dd086d588273f0" ||
      fail 'unqualified two-day weather preflight runner blob'
    test "$(git rev-parse HEAD:src/runtime/mod_fmr_crop_weather_day_preflight.f90)" = "8a99fb56d1b88d47989560c526d99a3888c841dd" ||
      fail 'unqualified weather to F-KT preflight bridge source'
    bash tests/fmig431/run_crop_weather_preflight_read_boundary.sh ||
      fail 'weather and certified F-KT daystart preflight O0/O2 failed'
    echo 'FCI_CANONICAL_CROP_WEATHER_PREFLIGHT_READ_BOUNDARY=PASS'
    echo 'FCI_CANONICAL_CROP_TWO_DAY_DAYSTART_RESTART=PASS'
  fi
  if (( crop_weather_owner_test_changed )); then
    test "$(git rev-parse HEAD:tests/fmig431/test_crop_weather_day_owner.f90)" = "2e994d52f3c66bfd63b9da938cd1ceb78e4f1763" ||
      fail 'unqualified weather-day retry/restart test postimage'
    bash tests/fmig431/run_crop_weather_day_owner.sh ||
      fail 'weather-day retry/restart exact test O0/O2 failed'
    echo 'FCI_CANONICAL_CROP_WEATHER_DAY_RETRY_RESTART=PASS'
  fi
  if (( crop_weather_ppa_binding_changed )); then
    test "$(git rev-parse HEAD:src/adapter/mod_ppa_wu03_common_forcing_adapter.f90)" = "7ddaaddcedc04fad6ba9d38ca4626332014f8d5b" ||
      fail 'unqualified weather-bound PPA-WU03 adapter postimage'
    test "$(git rev-parse HEAD:tests/fapp/test_ppa_wu03_common_forcing_adapter.f90)" = "75bf7cecfc8ab7099410574fa899d9b395977e31" ||
      fail 'unqualified weather-bound PPA-WU03 owner test'
    bash tests/fapp/run_ppa_wu03_common_forcing_adapter.sh ||
      fail 'weather-bound PPA-WU03 owner O0/O2 failed'
    echo 'FCI_CANONICAL_PPA_WU03_WEATHER_BOUND_FORCING=PASS'
    echo 'FCI_CANONICAL_PPA_WU03_TWO_COMMITTED_WEATHER_INTERVALS=PASS'
    echo 'FCI_CANONICAL_PPA_WU03_TWO_WEATHER_DAYS_CONTINUOUS_ACCEPT=PASS'
  fi
  if (( crop_weather_register_changed )); then
    test "$(git rev-parse HEAD:src/crop/mod_crop_weather_day_owner.f90)" = "60df1fe8e9cc9715b85db1885435ffb2b08bda14" ||
      fail 'unqualified weather-day register source'
    bash tests/fmig431/run_crop_weather_day_owner.sh ||
      fail 'weather-day register O0/O2 ingestion and restart matrix failed'
    echo 'FCI_CANONICAL_CROP_WEATHER_DAY_REGISTER=PASS'
    echo 'FCI_CANONICAL_SHARED_METEO_MINMAX_TAV_READ=PASS'
    echo 'FCI_CANONICAL_CROP_WEATHER_FORCING_SPAN=PASS'
  fi
  if (( crop_meteo_load006_changed )); then
    test "$(git rev-parse HEAD:src/crop/mod_crop_b111_meteo_loading_candidate.f90)" = "db1b9b9e7e6322992611333e3bfbb18b52194a93" ||
      fail 'unqualified B1.11 SWAP-006 meteorological loading candidate blob'
    bash tests/fmig431/run_crop_b111_meteo_loading_candidate.sh ||
      fail 'source-bound SWAP-006 loading O0/O2 negative matrix failed'
    echo 'FCI_CANONICAL_CROP_SW006_METEO_LOADING_EXACT=PASS'
  fi
  if (( crop_tav_period_changed )); then
    test "$(git rev-parse HEAD:src/crop/mod_crop_tav_detailed_period_candidate.f90)" = \
      "51bed01fbb1d8cece1650235aa2bc518c6f1209d" ||
      fail 'unqualified detailed meteorological period candidate source'
    bash tests/fmig431/run_crop_tav_detailed_period_candidate.sh ||
      fail 'bounded detailed meteorological period candidate O0/O2 failed'
    echo 'FCI_CANONICAL_CROP_TAV_DETAILED_PERIOD_EXACT=PASS'
  fi
  if (( crop_tav_meteo_changed )); then
    bash tests/fmig431/run_crop_tav_meteorological_candidate.sh ||
      fail 'bounded meteorological TAV candidate O0/O2 failed'
  fi
  if (( crop_tav_day_changed )); then
    bash tests/fmig431/run_crop_tav_day_window.sh || \
      fail 'untrusted atmospheric tav day candidate O0 O2 preservation failed'
  fi
  if (( crop_germination_source_order_changed )); then
    test "$(git rev-parse HEAD:src/crop/mod_crop_germination_preflight.f90)" =       "d61d86a2b79a7d4f9687988e666fd907d9fff245" ||
      fail 'unqualified B1.11 germination preflight source order blob'
    bash tests/fmig431/run_crop_germination_preflight.sh ||
      fail 'B1.11 previously admitted germination preflight O0/O2 failed'
    bash tests/fmig431/run_crop_b111_preflight_source_order.sh ||
      fail 'B1.11 bitwise germination order O0/O2 failed'
    echo 'FCI_CANONICAL_B111_GERMINATION_PREFLIGHT_EXACT_ORDER=PASS'
  fi
  if (( crop_certified_daily_changed )); then
    test "$(git rev-parse HEAD:src/runtime/mod_fmr_crop_certified_daily_preflight.f90)" = "3c6242ee6e052478eb107600c21a7d30858a76c7" ||
      fail 'unqualified B1.11 SWSOW0 heat-off daily preflight source'

    bash tests/fmig431/run_crop_certified_daily_preflight.sh ||
      fail 'certified F-KT B1.11 daily preparation/sowing/germination O0/O2 failed'
    bash tests/fmig431/run_crop_germination_preflight.sh ||
      fail 'source B1.11 germination preflight preservation failed'
    bash tests/fmig431/run_crop_preparation_sowing_preflight.sh ||
      fail 'source B1.11 preparation/sowing preflight preservation failed'
  fi
  if (( crop_certified_sow_changed )); then
    bash tests/fmig431/run_crop_fkt_parameter_identity.sh || \
      fail 'F-KT B110 parameter identity O0/O2 failed'
    bash tests/fmig431/run_crop_certified_sowing_source.sh || \
      fail 'F-KT certified sowing source O0/O2 failed'
    bash tests/fmig431/run_crop_certified_hydrothermal_forcing.sh || \
      fail 'F-KT certified B1.11 hydrothermal forcing O0/O2 failed'
    if (( crop_fkt_b110_exact_successor )); then
      bash tests/fmig431/run_crop_fkt_b110_scientific_successor.sh ||
        fail 'certified F-KT/B110 successor scientific B19/MICRO failed'
    else
    bash tests/fmig431/run_crop_lifecycle_b19_micro_cross_preservation.sh || \
      fail 'F-KT certified sowing B19/MICRO preservation failed'
    fi
  fi
  if (( crop_atomic_hydroheat_changed )); then
    bash tests/fmig431/run_crop_atomic_accepted_hydroheat.sh || \
      fail 'atomic accepted F-KT hydrothermal O0/O2 gate failed'
    bash tests/fmig431/run_crop_lifecycle_b19_micro_cross_preservation.sh || \
      fail 'atomic accepted F-KT hydrothermal B19/MICRO preservation failed'
  fi
  if (( crop_accepted_heat_changed )); then
    bash tests/fmig431/run_crop_accepted_soil_temperature.sh || \
      fail 'F-KT committed soil heat O0/O2 gate failed'
    bash tests/fmig431/run_crop_lifecycle_b19_micro_cross_preservation.sh || \
      fail 'F-KT crop heat B19/MICRO preservation failed'
  fi
  if (( crop_head_depth_changed )); then
    bash tests/fmig431/run_crop_accepted_head_depth_binding.sh || \
      fail 'accepted F-KT pF depth binding O0/O2 failed'
    bash tests/fmig431/run_crop_lifecycle_b19_micro_cross_preservation.sh || \
      fail 'accepted F-KT pF depth B19/MICRO preservation failed'
  fi
  if (( crop_havg_changed )); then
    bash tests/fmig431/run_crop_b111_pressure_head_average.sh || \
      fail 'B1.11 crop weighted pF O0/O2 tests failed'
    bash tests/fmig431/run_crop_lifecycle_b19_micro_cross_preservation.sh || \
      fail 'B1.11 crop weighted pF B19/MICRO preservation failed'
  fi
  if (( crop_grid_sow_changed )); then
    bash tests/fmig431/run_crop_b110_grid_sowing_preflight.sh || \
      fail 'B110 crop grid sowing preflight O0/O2 failed'
    bash tests/fmig431/run_crop_lifecycle_b19_micro_cross_preservation.sh || \
      fail 'B110 crop grid sowing preflight B19/MICRO preservation failed'
  fi
  if (( crop_sow_node_changed )); then
    bash tests/fmig431/run_crop_b111_sowing_node.sh || \
      fail 'B1.11 sowing temperature node O0/O2 failed'
    bash tests/fmig431/run_crop_lifecycle_b19_micro_cross_preservation.sh || \
      fail 'B1.11 sowing node B19/MICRO preservation failed'
  fi
  if (( crop_lifecycle_changed )); then
    # This source is admitted to the restricted B19/MICRO candidate surface
    # ONLY after its full exact-head F-KT O0/O2 plus actual MICRO02/03/05/06
    # and B19 current-source O0/O2 cross-preservation gate has succeeded.
    # No unconditional source allowlisting or modification of frozen physics.
    test -f tests/fmig431/run_crop_lifecycle_b19_micro_cross_preservation.sh || \
      fail 'missing qualified lifecycle B19/MICRO cross-preservation gate'
    if (( crop_file_weather_exact_successor )); then
      # Exact historical profile is verified above. The old cross-wrapper
      # pins pre-admission backend/bootstrap blobs; retain its physical
      # tests through the admitted current-owner scientific successor.
      bash tests/fmig431/run_crop_previous_day_emergence_gate.sh || fail 'previous-day emergence failed'
      bash tests/fmig431/run_crop_lifecycle_continuation.sh || fail 'lifecycle continuation failed'
      bash tests/fmig431/run_crop_fkt_b110_scientific_successor.sh || fail 'current lifecycle B19/MICRO preservation failed'
    else
      bash tests/fmig431/run_crop_lifecycle_b19_micro_cross_preservation.sh || \
        fail 'lifecycle B19/MICRO cross-preservation failed'
    fi
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
  if (( crop_hydraulic_provenance_changed )); then
    # A new read-only accepted F-KT hydraulic view is NOT unconditionally
    # admitted. Require positive/negative O0/O2 real B110 owner binding and
    # actual current-head B19/MICRO source/runtime cross-preservation.
    bash tests/fmig431/run_crop_accepted_hydraulic_provenance.sh || \
      fail 'crop accepted hydraulic F-KT provenance O0/O2 failed'
    bash tests/fmig431/run_crop_lifecycle_b19_micro_cross_preservation.sh || \
      fail 'crop accepted hydraulic B19/MICRO cross-preservation failed'
  fi
  if (( crop_unified_restart_changed )); then
    # Both calendar revision and F-KT accepted physical/calendar checkpoint
    # must pass whole same-tree replay; no new crop publication authority.
    bash tests/fmig431/run_crop_rotation_calendar.sh || \
      fail 'crop calendar selector preservation failed'
    bash tests/fmig431/run_crop_rotation_transition.sh || \
      fail 'crop calendar trial/revision preservation failed'
    bash tests/fmig431/run_crop_rotation_receipt_full_gate.sh || \
      fail 'crop committed-receipt publication preservation failed'
    bash tests/fmig431/run_crop_unified_restart_bundle.sh || \
      fail 'crop unified physical/calendar persistence replay failed'
  fi
  if (( crop_file_weather_exact_successor )); then
    bash tests/fci/run_crop_file_weather_production_successor.sh || fail 'file-weather integrated owner/scientific preservation failed'
    echo 'FCI_CANONICAL_FILE_WEATHER_PRODUCTION_O0_O2=PASS'
  fi
  for candidate_path in "$BACKEND" src/runtime/mod_fmr_production_application_bootstrap.f90; do
    if (( crop_file_weather_exact_successor )) && [[ "$candidate_path" == src/runtime/mod_fmr_production_application_bootstrap.f90 ]]; then
      continue # Independently qualified exact bootstrap, no wildcard drift.
    fi
    if (( nut_thermal_exact_successor )) && [[ "$candidate_path" == "$BACKEND" ]]; then
      test "$(git rev-parse "HEAD:$candidate_path")" = "$NUT_THERMAL_BACKEND" || fail 'thermal backend exact successor drift'
    elif (( mc_heat01_exact_successor )) && [[ "$candidate_path" == "$BACKEND" ]]; then
      test "$(git rev-parse "HEAD:$candidate_path")" = "$MC_HEAT01_BACKEND" || fail 'MC-HEAT01 shared backend exact successor drift'
    elif (( crop_fkt_b110_exact_successor )) && [[ "$candidate_path" == "$BACKEND" ]]; then
      test "$(git rev-parse "HEAD:$candidate_path")" = "b218ac657db52612bc12da671716c97430200f0a" ||
        fail 'crop B110 certified successor backend postimage drift'
    else
      test "$(git rev-parse "HEAD:$candidate_path")" = "$(git rev-parse "$dependency_authority:$candidate_path")" ||
        fail "B19+MICRO shared-owner postimage changed: $candidate_path"
    fi
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
      if (( nut_thermal_exact_successor )); then
        test "$(git rev-parse HEAD:$BACKEND)" = "$NUT_THERMAL_BACKEND" || fail 'thermal exact backend drift'
      elif (( mc_heat01_exact_successor )); then
        test "$(git rev-parse HEAD:$BACKEND)" = "$MC_HEAT01_BACKEND" || fail 'MC-HEAT01 exact backend drift'
      elif (( crop_fkt_b110_exact_successor )); then
        test "$(git rev-parse HEAD:$BACKEND)" = "b218ac657db52612bc12da671716c97430200f0a" ||
          fail 'B19/MICRO crop B110 exact successor backend drift'
      else
      test "$(git rev-parse HEAD:$BACKEND)" = "$(git rev-parse "$dependency_authority:$BACKEND")" || fail 'B19+MICRO current-target serialized backend drift'
      fi
      if (( ! crop_file_weather_exact_successor )); then
        test "$(git rev-parse HEAD:src/runtime/mod_fmr_production_application_bootstrap.f90)" = "$(git rev-parse "$dependency_authority:src/runtime/mod_fmr_production_application_bootstrap.f90")" || fail 'B19+MICRO current-target application bootstrap drift'
      fi
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
  if (( nut_thermal_exact_successor )); then
    backend_authority="$NUT_THERMAL_BACKEND"
  elif (( mc_heat01_exact_successor )); then
    backend_authority="$MC_HEAT01_BACKEND"
  elif (( crop_fkt_b110_exact_successor )); then
    backend_authority="b218ac657db52612bc12da671716c97430200f0a"
  fi
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

verify_mc_heat01_owner_successor
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
# Irrigation remains owner-qualified even when the backend follows its exact
# historical branch and bypasses the B19/MICRO recomposition function.
verify_mc_irr01_owner_successor
verify_mc_irr01_storage_successor
echo 'FCI_CANONICAL_LINEAGE_AWARE_GATE PASS'
