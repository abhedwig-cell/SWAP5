#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-dir01-repair05-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/base" "$BUILD/candidate" "$BUILD/src"
trap 'rm -rf "$BUILD"' EXIT

cp src/solver/mod_b110_default_mvg_provider.f90 "$BUILD/src/provider_base.f90"
cp src/solver/mod_b110_default_mvg_directional_provider.f90 "$BUILD/src/directional_base.f90"
cp src/adapter/mod_reference_richards_accepted_step_directional_service.f90 "$BUILD/src/service_base.f90"

python3 - "$BUILD/src/provider_candidate.f90" <<'PY'
from pathlib import Path
import sys
src=Path("src/solver/mod_b110_default_mvg_provider.f90").read_text()
needle="  public :: bind_b110_default_mvg_provider\n"
if needle not in src:
    raise SystemExit("Repair05 provider public seam missing")
src=src.replace(needle,needle+"  public :: b110_hconduc\n",1)
Path(sys.argv[1]).write_text(src)
PY

python3 - "$BUILD/src/directional_candidate.f90" <<'PY'
from pathlib import Path
import sys
src=Path("src/solver/mod_b110_default_mvg_directional_provider.f90").read_text()
src=src.replace(
"  use mod_b110_default_mvg_provider, only: b110_default_mvg_provider_t",
"  use mod_b110_default_mvg_provider, only: b110_default_mvg_provider_t, b110_hconduc",1)
src=src.replace(
"""  subroutine evaluate_b110_default_mvg_state_direction(provider, pressure_head, pressure_head_direction, &
                                                        water_content_direction, conductivity_direction, &
                                                        available, route)""",
"""  subroutine evaluate_b110_default_mvg_state_direction(provider, pressure_head, pressure_head_direction, &
                                                        water_content_direction, conductivity_direction, &
                                                        base_conductivity, available, route)""",1)
src=src.replace(
"    real(real64), intent(out) :: water_content_direction(:), conductivity_direction(:)\n",
"    real(real64), intent(out) :: water_content_direction(:), conductivity_direction(:), base_conductivity(:)\n",1)
src=src.replace(
"    real(real64) :: dthetadh, dkdh\n",
"    real(real64) :: theta, dthetadh, dkdh\n",1)
src=src.replace(
"    conductivity_direction = 0.0_real64\n",
"    conductivity_direction = 0.0_real64\n    base_conductivity = 0.0_real64\n",1)
src=src.replace(
"""        size(water_content_direction) /= n .or. size(conductivity_direction) /= n) then""",
"""        size(water_content_direction) /= n .or. size(conductivity_direction) /= n .or. &
        size(base_conductivity) /= n) then""",1)
src=src.replace(
"       call b110_smooth_derivatives(provider%parameters%cofgen(:,i), pressure_head(i), dthetadh, dkdh, node_ok)\n",
"       call b110_smooth_derivatives(provider%parameters%cofgen(:,i), pressure_head(i), theta, dthetadh, dkdh, node_ok)\n",1)
src=src.replace(
"""       water_content_direction(i) = dthetadh * pressure_head_direction(i)
       conductivity_direction(i) = dkdh * pressure_head_direction(i)
""",
"""       base_conductivity(i) = b110_hconduc(provider%parameters%cofgen(:,i), pressure_head(i), theta, &
            provider%parameters%ksatexm_extension_enabled)
       water_content_direction(i) = dthetadh * pressure_head_direction(i)
       conductivity_direction(i) = dkdh * pressure_head_direction(i)
""",1)
src=src.replace(
"""    if (any(.not. ieee_is_finite(water_content_direction)) .or. &
        any(.not. ieee_is_finite(conductivity_direction))) then""",
"""    if (any(.not. ieee_is_finite(water_content_direction)) .or. &
        any(.not. ieee_is_finite(conductivity_direction)) .or. &
        any(.not. ieee_is_finite(base_conductivity))) then""",1)
src=src.replace(
"""  subroutine b110_smooth_derivatives(c, head, dthetadh, dkdh, ok)
    real(real64), intent(in) :: c(:), head
    real(real64), intent(out) :: dthetadh, dkdh""",
"""  subroutine b110_smooth_derivatives(c, head, theta, dthetadh, dkdh, ok)
    real(real64), intent(in) :: c(:), head
    real(real64), intent(out) :: theta, dthetadh, dkdh""",1)
# theta was previously a local
src=src.replace(
"    real(real64) :: theta, relsat, invm, one_minus_term, term1\n",
"    real(real64) :: relsat, invm, one_minus_term, term1\n",1)
src=src.replace(
"    dthetadh = 0.0_real64\n    dkdh = 0.0_real64\n",
"    theta = 0.0_real64\n    dthetadh = 0.0_real64\n    dkdh = 0.0_real64\n",1)
Path(sys.argv[1]).write_text(src)
PY

python3 - "$BUILD/src/service_candidate.f90" <<'PY'
from pathlib import Path
import sys
src=Path("src/adapter/mod_reference_richards_accepted_step_directional_service.f90").read_text()
old="""    ! Re-evaluate the immutable constitutive value provider at the step base
    ! state for the exact frozen K values used by swkimpl=0. Its historical
    ! dconductivity_dhead output is deliberately reserved/zero, therefore the
    ! derivative comes only from the explicit B1.10 sibling capability.
    call request%evaluation%constitutive%evaluate_demand(request%base_state%pressure_head, &
         CONSTITUTIVE_DEMAND_CONDUCTIVITY, ref_ws%richards%provider_theta, ref_ws%richards%provider_k, &
         ref_ws%richards%provider_capacity, ref_ws%richards%provider_dkdh)
    if (any(.not. ieee_is_finite(ref_ws%richards%provider_k(1:n)))) then
       direction_result%status = SW_STEP_DIRECTION_UNAVAILABLE
       direction_result%route = 'base-constitutive-value-nonfinite'
       return
    end if

    select type (hyd => request%evaluation%constitutive)
    type is (b110_default_mvg_provider_t)
       call evaluate_b110_default_mvg_state_direction(hyd, request%base_state%pressure_head, &
            direction_request%incoming_pressure_head, ref_ws%richards%provider_theta, &
            ref_ws%richards%band_aux(:,1), constitutive_direction_ok, constitutive_direction_route)
    type is (b110_direct_retention_provider_t)
       call evaluate_b110_direct_retention_state_direction(hyd, request%base_state%pressure_head, &
            direction_request%incoming_pressure_head, ref_ws%richards%provider_theta, &
            ref_ws%richards%band_aux(:,1), constitutive_direction_ok, constitutive_direction_route)
"""
new="""    select type (hyd => request%evaluation%constitutive)
    type is (b110_default_mvg_provider_t)
       ! Fused exact default-MvG base value + directional derivative pass.
       call evaluate_b110_default_mvg_state_direction(hyd, request%base_state%pressure_head, &
            direction_request%incoming_pressure_head, ref_ws%richards%provider_theta, &
            ref_ws%richards%band_aux(:,1), ref_ws%richards%provider_k, &
            constitutive_direction_ok, constitutive_direction_route)
    type is (b110_direct_retention_provider_t)
       ! Direct-retention keeps the existing value-provider path unchanged.
       call request%evaluation%constitutive%evaluate_demand(request%base_state%pressure_head, &
            CONSTITUTIVE_DEMAND_CONDUCTIVITY, ref_ws%richards%provider_theta, ref_ws%richards%provider_k, &
            ref_ws%richards%provider_capacity, ref_ws%richards%provider_dkdh)
       if (any(.not. ieee_is_finite(ref_ws%richards%provider_k(1:n)))) then
          direction_result%status = SW_STEP_DIRECTION_UNAVAILABLE
          direction_result%route = 'base-constitutive-value-nonfinite'
          return
       end if
       call evaluate_b110_direct_retention_state_direction(hyd, request%base_state%pressure_head, &
            direction_request%incoming_pressure_head, ref_ws%richards%provider_theta, &
            ref_ws%richards%band_aux(:,1), constitutive_direction_ok, constitutive_direction_route)
"""
if old not in src:
    raise SystemExit("Repair05 service fusion seam missing")
src=src.replace(old,new,1)
# For default route, validate fused K after select.
needle="""    if (.not. constitutive_direction_ok) then
       direction_result%status = SW_STEP_DIRECTION_UNAVAILABLE
       direction_result%route = constitutive_direction_route
       return
    end if
"""
replacement=needle+"""    if (any(.not. ieee_is_finite(ref_ws%richards%provider_k(1:n)))) then
       direction_result%status = SW_STEP_DIRECTION_UNAVAILABLE
       direction_result%route = 'base-constitutive-value-nonfinite'
       return
    end if
"""
if needle not in src:
    raise SystemExit("Repair05 post-direction seam missing")
src=src.replace(needle,replacement,1)
Path(sys.argv[1]).write_text(src)
PY

python3 - "$BUILD/test.f90" <<'PY'
from pathlib import Path
import sys
src=Path("tests/fpe/test_fpe_profile03_h03_application_host_timing.f90").read_text()
src=src.replace("SW_STEP_CONTROL_BOTTOM_FLUX","SW_STEP_CONTROL_BOTTOM_HEAD")
src=src.replace("forcing%bottom_head = -999999.0_real64","forcing%bottom_head = h0")
Path(sys.argv[1]).write_text(src)
PY

COMMON=(-std=f2008 -ffree-line-length-none -O2)
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
  src/process/mod_drainage_extended_exchange.f90
  src/runtime/mod_fmr_drainage_response_binding.f90
  src/solver/mod_b110_smooth_freatic_projection.f90
  src/runtime/mod_fmr_drainage_qbot_directional_binding.f90
  src/process/mod_soil_temperature_contract.f90
  src/process/mod_restricted_soil_temperature.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_reference_linear_solver.f90
  PROVIDER_PLACEHOLDER
  DIRECTIONAL_PROVIDER_PLACEHOLDER
  src/solver/mod_b110_direct_retention_core.f90
  src/solver/mod_b110_direct_retention_provider.f90
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
  src/process/mod_snow_process.f90
  src/process/mod_restricted_fixed_weir_surface_water.f90
  src/runtime/mod_fmr_soil_water_application_host.f90
  src/runtime/mod_rossfast_d3r_execution_policy.f90
  src/runtime/mod_rossfast_d3r_model_binding.f90
  src/solver/mod_rossfast_d3r_table_kernel.f90
  src/solver/mod_rossfast_d3r_table_provider.f90
  src/solver/mod_rossfast_d3r_soil_water_solver.f90
  src/runtime/mod_fmr_rossfast_solver_selection_binding.f90
  SERVICE_PLACEHOLDER
  src/runtime/mod_fmr_serialized_reference_backend.f90
)

compile_variant(){
  local name="$1"
  local out="$BUILD/$name"
  local objects=()
  for source in "${SRC[@]}"; do
    case "$source" in
      PROVIDER_PLACEHOLDER)
        [[ "$name" == base ]] && source="$BUILD/src/provider_base.f90" || source="$BUILD/src/provider_candidate.f90" ;;
      DIRECTIONAL_PROVIDER_PLACEHOLDER)
        [[ "$name" == base ]] && source="$BUILD/src/directional_base.f90" || source="$BUILD/src/directional_candidate.f90" ;;
      SERVICE_PLACEHOLDER)
        [[ "$name" == base ]] && source="$BUILD/src/service_base.f90" || source="$BUILD/src/service_candidate.f90" ;;
    esac
    local obj="$out/$(basename "${source%.*}").o"
    gfortran "${COMMON[@]}" -J "$out" -I "$out" -c "$source" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -J "$out" -I "$out" -c "$BUILD/test.f90" -o "$out/test.o"
  gfortran -O2 "${objects[@]}" "$out/test.o" -o "$out/test"
}
compile_variant base
compile_variant candidate

CALLS=20000
PAIRS=10
OUT="$BUILD/results.csv"
echo 'pair,variant,ns,checksum,derivative,steps,backsolves' > "$OUT"

run_one(){
  local pair="$1" variant="$2" raw timing derivative steps backsolves
  raw="$("$BUILD/$variant/test" "$CALLS" directional zero-waste-paired)"
  timing="$(printf '%s\n' "$raw" | grep '^PROFILE03_E1_TIMING')"
  derivative="$(printf '%s\n' "$raw" | grep '^FKT22_FMR_BOTTOM_EXCHANGE_DERIVATIVE=' | cut -d= -f2-)"
  steps="$(printf '%s\n' "$raw" | grep '^FKT22_FMR_ACCEPTED_STEPS=' | cut -d= -f2-)"
  backsolves="$(printf '%s\n' "$raw" | grep '^FKT22_FMR_ACCEPTED_BACKSOLVES=' | cut -d= -f2-)"
  python3 - "$pair" "$variant" "$timing" "$derivative" "$steps" "$backsolves" "$OUT" <<'PY'
import csv,re,sys
pair,variant,line,derivative,steps,backsolves,path=sys.argv[1:]
def v(k):
    m=re.search(rf'{k}=\s*([^,]+)',line)
    if not m: raise SystemExit(f'missing {k}: {line}')
    return m.group(1).strip()
with open(path,'a',newline='') as f:
    csv.writer(f).writerow([pair,variant,v('ns_per_interval'),v('checksum'),derivative.strip(),steps.strip(),backsolves.strip()])
print(line)
PY
}
for pair in $(seq 1 "$PAIRS"); do
  if (( pair % 2 == 1 )); then run_one "$pair" base; run_one "$pair" candidate
  else run_one "$pair" candidate; run_one "$pair" base; fi
done

python3 - "$OUT" <<'PY'
import csv,statistics,sys
rows=list(csv.DictReader(open(sys.argv[1])))
by={}
for r in rows: by.setdefault(int(r['pair']),{})[r['variant']]=r
ratios=[]; deltas=[]
for pair,v in sorted(by.items()):
    b=v['base']; c=v['candidate']
    for k in ('checksum','derivative','steps','backsolves'):
        if b[k]!=c[k]: raise SystemExit(f'preservation drift pair={pair} field={k}: {b[k]} != {c[k]}')
    bn=float(b['ns']); cn=float(c['ns'])
    ratios.append(cn/bn); deltas.append(cn-bn)
print(f'DIR01_REPAIR05_MEAN_RATIO={statistics.mean(ratios):.9f}')
print(f'DIR01_REPAIR05_MEDIAN_RATIO={statistics.median(ratios):.9f}')
print(f'DIR01_REPAIR05_MEAN_SPEEDUP_PERCENT={(1-statistics.mean(ratios))*100:.6f}')
print(f'DIR01_REPAIR05_MEDIAN_SPEEDUP_PERCENT={(1-statistics.median(ratios))*100:.6f}')
print(f'DIR01_REPAIR05_MEAN_DELTA_NS={statistics.mean(deltas):.6f}')
print(f'DIR01_REPAIR05_MIN_RATIO={min(ratios):.9f}')
print(f'DIR01_REPAIR05_MAX_RATIO={max(ratios):.9f}')
print('FPE_DIR01_REPAIR05_EXPERIMENT=PASS')
PY
