#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-approx01-a1-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

python3 - "$BUILD/test.f90" <<'PY'
from pathlib import Path
import sys
src=Path("tests/fgc/test_fgc44_real_fmr_participant.f90").read_text()

src=src.replace(
"  real(real64), parameter :: h0_cm=-75.0_real64\n",
"  real(real64) :: h0_cm\n",1)

decl="""  real(real64) :: qeq, committed_time, origin_head_m
"""
rep="""  real(real64) :: qeq, committed_time, origin_head_m
  real(real64) :: bench_seconds,qsum,tsum
  integer(int64) :: c0,c1,rate
  integer :: iter,fresh_count,reuse_count,ntrial
  logical :: bench_cache,bench_a2c
  character(len=8) :: bench_material,bench_mode
  character(len=64) :: bench_arg
"""
if decl not in src: raise SystemExit("declaration seam missing")
src=src.replace(decl,rep,1)

start=src.index("  call initialize_parameters(parameters)")
end=src.index("\ncontains\n",start)
main=r"""  if(command_argument_count()/=4) error stop 'usage: MATERIAL H0_CM MODE NTRIAL'
  call get_command_argument(1,bench_material)
  call get_command_argument(2,bench_arg); read(bench_arg,*) h0_cm
  call get_command_argument(3,bench_mode)
  call get_command_argument(4,bench_arg); read(bench_arg,*) ntrial
  if(ntrial<=0) error stop 'invalid ntrial'
  bench_cache=trim(bench_mode)=='a1' .or. trim(bench_mode)=='stack'
  bench_a2c=trim(bench_mode)=='a2c' .or. trim(bench_mode)=='stack'
  if(.not.(trim(bench_mode)=='exact' .or. trim(bench_mode)=='a1' .or. &
           trim(bench_mode)=='a2c' .or. trim(bench_mode)=='stack')) error stop 'invalid benchmark mode'

  call initialize_parameters(parameters)
  parameters%practical_richards_a2c_active=bench_a2c
  qeq=predictor_qbot
  call initialize_forcing(base_forcing,qeq)
  call initialize_column_template(column,template)
  call initialize_config(config)
  call initialize_committed(committed,parameters,ok)
  call require(ok,'PROFILE06 committed state initialized')

  call backend%initialize(top)
  call materializer%initialize(base_forcing)
  datum%available=.true.
  datum%datum_id=540044_int64
  datum%bottom_boundary_elevation_m=0.0_real64
  window%t0=0.0_real64
  window%t1=duration
  call compute_origin_head(parameters,datum,origin_head_m,status)
  call require(status==MODFLOW6_BOTTOM_FACE_OK,'PROFILE06 materialize origin head')

  call participant%configure_tangent_cache(bench_cache,0.005_real64,8)
  call participant%capture_origin(committed,status)
  call require(status==GW_SWAP_PARTICIPANT_OK,'PROFILE06 capture origin')

  call system_clock(c0,rate)
  qsum=0.0_real64
  tsum=0.0_real64
  do iter=1,ntrial
    call participant%trial_from_origin(backend,column,template,parameters,committed,materializer,config,datum,window, &
         origin_head_m,trial1,status)
    call require(status==GW_SWAP_PARTICIPANT_OK .and. trial1%valid,'PROFILE06 repeated trial')
    call require(trial1%response_tangent_available,'PROFILE06 tangent available')
    qsum=qsum+trial1%q_swap_m_per_s
    tsum=tsum+trial1%dq_swap_dh_per_s
    call participant%discard_candidate(backend)
  end do
  call system_clock(c1)
  bench_seconds=real(c1-c0,real64)/real(rate,real64)
  call participant%tangent_cache_counts(fresh_count,reuse_count)

  if(bench_cache) then
    call require(fresh_count>0 .and. reuse_count>0,'PROFILE06 A1 cache exercised')
    call require(fresh_count+reuse_count==ntrial,'PROFILE06 A1 cache accounting')
  end if
  call require(ieee_is_finite(qsum) .and. ieee_is_finite(tsum),'PROFILE06 finite checksums')

  write(*,'(*(g0))') 'PROFILE06_P2_RAW|MATERIAL=',trim(bench_material),'|H0=',h0_cm,'|MODE=',trim(bench_mode), &
       '|TRIALS=',ntrial,'|SECONDS=',bench_seconds,'|NS_PER_TRIAL=',1.0e9_real64*bench_seconds/real(ntrial,real64), &
       '|FRESH=',fresh_count,'|REUSE=',reuse_count,'|QSUM=',qsum,'|TSUM=',tsum
  write(*,'(A)') 'FPE_PROFILE06_P2_POINT=PASS'
"""
src=src[:start]+main+src[end:]

old_init="""    integer::k
    p%parameter_set_id=540044_int64; p%active_nodes=numnod
"""
new_init="""    integer::k
    real(real64) :: tr,ts,alpha,nvg,ksat,lambda
    call material_parameters(trim(bench_material),tr,ts,alpha,nvg,ksat,lambda)
    p%parameter_set_id=540044_int64; p%active_nodes=numnod
"""
if old_init not in src: raise SystemExit("initialize_parameters declaration seam missing")
src=src.replace(old_init,new_init,1)

old_values="""      p%cofgen(1,k)=0.032_real64; p%cofgen(2,k)=0.423_real64; p%cofgen(3,k)=4.75_real64
      p%cofgen(4,k)=0.0135_real64; p%cofgen(5,k)=0.365_real64; p%cofgen(6,k)=1.455_real64
      p%cofgen(7,k)=1.0_real64-1.0_real64/p%cofgen(6,k); p%cofgen(8,k)=p%cofgen(4,k)
      p%cofgen(9,k)=0.0_real64; p%cofgen(10,k)=p%cofgen(3,k); p%cofgen(11,k)=0.999_real64
      p%cofgen(12,k)=0.99_real64*p%cofgen(3,k); p%cofgen(22,k)=-1.0e6_real64; p%cofgen(23,k)=1.0e-12_real64
"""
new_values="""      p%cofgen(1,k)=tr; p%cofgen(2,k)=ts; p%cofgen(3,k)=ksat
      p%cofgen(4,k)=alpha; p%cofgen(5,k)=lambda; p%cofgen(6,k)=nvg
      p%cofgen(7,k)=1.0_real64-1.0_real64/nvg; p%cofgen(8,k)=alpha
      p%cofgen(9,k)=0.0_real64; p%cofgen(10,k)=ksat; p%cofgen(11,k)=0.999_real64
      p%cofgen(12,k)=0.99_real64*ksat; p%cofgen(22,k)=-1.0e6_real64; p%cofgen(23,k)=1.0e-12_real64
"""
if old_values not in src: raise SystemExit("material values seam missing")
src=src.replace(old_values,new_values,1)

marker="  subroutine require(x,msg)\n"
idx=src.index(marker)
material_sub=r"""  subroutine material_parameters(name,tr,ts,alpha,nvg,ksat,lambda)
    character(len=*),intent(in)::name
    real(real64),intent(out)::tr,ts,alpha,nvg,ksat,lambda
    select case(trim(name))
    case('B01')
      tr=0.02_real64; ts=0.427494_real64; alpha=0.021659_real64; nvg=1.734737_real64
      ksat=31.225016_real64; lambda=0.98087_real64
    case('B12')
      tr=0.01_real64; ts=0.529749_real64; alpha=0.016562_real64; nvg=1.090671_real64
      ksat=2.245895_real64; lambda=-4.493581_real64
    case('O05')
      tr=0.01_real64; ts=0.336701_real64; alpha=0.030304_real64; nvg=2.887502_real64
      ksat=17.418504_real64; lambda=0.0736_real64
    case('O14')
      tr=0.01_real64; ts=0.393878_real64; alpha=0.003288_real64; nvg=1.616573_real64
      ksat=2.495984_real64; lambda=0.514012_real64
    case default
      error stop 'unknown PROFILE06 material'
    end select
  end subroutine material_parameters

"""
src=src[:idx]+material_sub+src[idx:]
Path(sys.argv[1]).write_text(src)
PY

COMMON=(-std=f2008 -ffree-line-length-none -O2)
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
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_default_mvg_directional_provider.f90
  src/solver/mod_b110_direct_retention_core.f90
  src/solver/mod_b110_direct_retention_provider.f90
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
  src/runtime/mod_groundwater_coupling_contract.f90
  src/runtime/mod_modflow6_swap_prescribed_qbot_bottom_face.f90
  src/runtime/mod_groundwater_swap_forcing_adapter.f90
  src/runtime/mod_groundwater_swap_transaction_participant.f90
  src/runtime/mod_fmr_groundwater_head_forcing_adapter.f90
  src/runtime/mod_fmr_groundwater_swap_participant.f90
)
objects=()
for source in "${MODULE_SRC[@]}"; do
  obj="$BUILD/$(basename "${source%.*}").o"
  gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c "$source" -o "$obj"
  objects+=("$obj")
done
gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c "$BUILD/test.f90" -o "$BUILD/test.o"
gfortran -O2 "${objects[@]}" "$BUILD/test.o" -o "$BUILD/test"

RESULT="$BUILD/results.txt"
: > "$RESULT"
ntrial=4000
reps=5
cases=("B01|wet|-10" "B01|mid|-75" "B12|wet|-10" "O05|wet|-10" "O14|wet|-10" "O14|mid|-75")
for case_spec in "${cases[@]}"; do
  IFS='|' read -r material regime h0 <<< "$case_spec"
  for mode in exact a1 a2c stack; do
    for rep in $(seq 1 "$reps"); do
      raw="$("$BUILD/test" "$material" "$h0" "$mode" "$ntrial" 2>&1)" || { printf '%s\n' "$raw" >&2; fail "$material $regime $mode rep $rep"; }
      line="$(printf '%s\n' "$raw" | grep '^PROFILE06_P2_RAW|' | tail -1)"
      [[ -n "$line" ]] || fail "missing P2 record"
      printf '%s|REGIME=%s|REP=%s\n' "$line" "$regime" "$rep" | tee -a "$RESULT"
    done
  done
done

python3 - "$RESULT" <<'PY'
import statistics,sys
rows=[]
for line in open(sys.argv[1]):
    if not line.startswith("PROFILE06_P2_RAW|"): continue
    d={}
    for p in line.strip().split("|")[1:]:
        k,v=p.split("=",1); d[k]=v
    rows.append(d)
if len(rows)!=6*4*5:
    raise SystemExit(f"expected 120 P2 rows, got {len(rows)}")

cases={}
for r in rows:
    key=(r["MATERIAL"],r["REGIME"])
    cases.setdefault(key,{}).setdefault(r["MODE"],[]).append(r)

complementary=0
for key,modes in sorted(cases.items()):
    for mode in ("exact","a1","a2c","stack"):
        if len(modes.get(mode,[]))!=5:
            raise SystemExit(f"{key} {mode}: missing reps")
    med={}
    for mode,rs in modes.items():
        med[mode]=statistics.median(float(r["NS_PER_TRIAL"]) for r in rs)
    exact=med["exact"]
    ratios={m:med[m]/exact for m in ("a1","a2c","stack")}
    stack_a1=med["stack"]/med["a1"]
    stack_a2c=med["stack"]/med["a2c"]

    # Checksums are deterministic within an arm. A1 must match exact to roundoff.
    q0=statistics.median(float(r["QSUM"]) for r in modes["exact"])
    t0=statistics.median(float(r["TSUM"]) for r in modes["exact"])
    qa1=statistics.median(float(r["QSUM"]) for r in modes["a1"])
    ta1=statistics.median(float(r["TSUM"]) for r in modes["a1"])
    qa2=statistics.median(float(r["QSUM"]) for r in modes["a2c"])
    ta2=statistics.median(float(r["TSUM"]) for r in modes["a2c"])
    qst=statistics.median(float(r["QSUM"]) for r in modes["stack"])
    tst=statistics.median(float(r["TSUM"]) for r in modes["stack"])
    def rel(a,b): return abs(a-b)/max(abs(a),1e-30)
    if rel(q0,qa1)>1e-13 or rel(t0,ta1)>1e-13:
        raise SystemExit(f"A1 checksum drift {key}")
    if rel(qa2,qst)>1e-13 or rel(ta2,tst)>1e-13:
        raise SystemExit(f"stack/A2C checksum drift {key}")
    if rel(q0,qa2)>1e-6 or rel(t0,ta2)>1e-6:
        raise SystemExit(f"A2C checksum outside qualified-scale bound {key}")

    fresh=statistics.median(int(r["FRESH"]) for r in modes["a1"])
    reuse=statistics.median(int(r["REUSE"]) for r in modes["a1"])
    if reuse<=0 or fresh<=0:
        raise SystemExit(f"A1 cache not exercised {key}")
    if stack_a1<1 and stack_a2c<1:
        complementary += 1
    print(
      f"PROFILE06_P2_CASE|MATERIAL={key[0]}|REGIME={key[1]}"
      f"|EXACT_NS={med['exact']:.3f}|A1_NS={med['a1']:.3f}|A2C_NS={med['a2c']:.3f}|STACK_NS={med['stack']:.3f}"
      f"|A1_SPEEDUP_PERCENT={(1-ratios['a1'])*100:.6f}|A2C_SPEEDUP_PERCENT={(1-ratios['a2c'])*100:.6f}"
      f"|STACK_SPEEDUP_PERCENT={(1-ratios['stack'])*100:.6f}"
      f"|STACK_VS_A1_SPEEDUP_PERCENT={(1-stack_a1)*100:.6f}|STACK_VS_A2C_SPEEDUP_PERCENT={(1-stack_a2c)*100:.6f}"
      f"|A1_FRESH_MEDIAN={fresh}|A1_REUSE_MEDIAN={reuse}"
      f"|A2C_Q_REL={rel(q0,qa2):.17e}|A2C_TANGENT_REL={rel(t0,ta2):.17e}"
    )
print(f"PROFILE06_P2_SUMMARY|CASES=6|COMPLEMENTARY_CASES={complementary}")
print("FPE_PROFILE06_P2=PASS")
PY
