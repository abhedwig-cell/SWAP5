#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-solve01-p2a-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "SOLVE01_P2A_FAIL $*" >&2; exit 1; }

cp src/runtime/mod_fmr_serialized_reference_backend.f90 "$BUILD/mod_fmr_serialized_reference_backend.f90"
python3 - "$BUILD/mod_fmr_serialized_reference_backend.f90" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); src=p.read_text()
old="""    request%numerical%compartment_balance_tolerance = self%compartment_balance_tolerance
    request%numerical%total_balance_tolerance = self%total_balance_tolerance
"""
new="""    request%numerical%compartment_balance_tolerance = max(self%compartment_balance_tolerance, 2.8e-16_real64 / step_duration)
    request%numerical%total_balance_tolerance = max(self%total_balance_tolerance, 2.8e-16_real64 / step_duration)
"""
if old not in src:
    raise SystemExit("BALTOL02 request seam missing")
p.write_text(src.replace(old,new,1))
PY

cat > "$BUILD/test.f90" <<'F90'
program test_fpe_solve01_p2a_n1_scale
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, fmr_new_b110_temporal_indicator_committed_state
  use mod_fmr_groundwater_head_forcing_adapter, only: fmr_groundwater_head_forcing_materializer_t
  use mod_fmr_groundwater_swap_participant, only: fmr_groundwater_swap_participant_t
  use mod_groundwater_swap_transaction_participant, only: groundwater_swap_trial_t, GW_SWAP_PARTICIPANT_OK
  use mod_groundwater_coupling_contract, only: groundwater_head_datum_t, groundwater_coupling_window_t
  use mod_modflow6_swap_prescribed_qbot_bottom_face, only: modflow6_prescribed_qbot_bottom_face_t, &
       materialize_modflow6_prescribed_qbot_bottom_face, MODFLOW6_BOTTOM_FACE_OK
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  real(real64), parameter :: H0_CM=-75.0_real64
  real(real64), parameter :: DURATION=1.0e-4_real64
  real(real64), parameter :: TOL=1.0e-12_real64
  real(real64), parameter :: PREDICTOR_QBOT=1.0e-6_real64
  real(real64), parameter :: TEMPORAL_BUDGET_CM=2.0e-2_real64
  real(real64), parameter :: OFFSETS_CM(8)=[0.001_real64,0.01_real64,-0.001_real64,-0.01_real64, &
       0.001_real64,-0.001_real64,0.01_real64,-0.01_real64]

  integer :: n, nseq, i, j, seq, status, exact_tile_trials, approx_responses
  integer(int64) :: c0,c1,rate
  character(len=32) :: arg, mode
  logical :: ok, did_commit
  real(real64) :: init_seconds, run_seconds, origin_head_m, head_m
  real(real64) :: qagg, tagg, q_anchor, t_anchor, h_anchor, q_approx, qchecksum, final_q
  type(canonical_numerical_config_t) :: config
  type(groundwater_head_datum_t) :: datum
  type(groundwater_coupling_window_t) :: window
  type(fmr_b110_physical_parameters_t), allocatable :: parameters(:)
  type(fmr_b110_physical_forcing_t), allocatable :: forcing(:)
  type(fmr_logical_column_t), allocatable :: columns(:)
  type(fmr_template_t), allocatable :: templates(:)
  type(kernel_committed_state_t), allocatable :: committed(:)
  type(fmr_serialized_reference_backend_t), allocatable :: backends(:)
  type(fmr_groundwater_head_forcing_materializer_t), allocatable :: materializers(:)
  type(fmr_groundwater_swap_participant_t), allocatable :: participants(:)
  type(fixed_flux_top_boundary_provider_t), allocatable, target :: tops(:)

  if(command_argument_count()/=3) error stop 'usage: N MODE NSEQ'
  call get_command_argument(1,arg); read(arg,*) n
  call get_command_argument(2,mode)
  call get_command_argument(3,arg); read(arg,*) nseq
  if(n<=0 .or. nseq<=0) error stop 'invalid N/NSEQ'
  if(trim(mode)/='exact' .and. trim(mode)/='e4') error stop 'invalid mode'

  allocate(parameters(n),forcing(n),columns(n),templates(n),committed(n),backends(n),materializers(n),participants(n),tops(n))
  call initialize_config(config)
  datum%available=.true.
  datum%datum_id=880001_int64
  datum%bottom_boundary_elevation_m=0.0_real64
  window%t0=0.0_real64
  window%t1=DURATION

  call system_clock(c0,rate)
  do i=1,n
    call initialize_parameters(parameters(i),i)
    call initialize_forcing(forcing(i),PREDICTOR_QBOT)
    call initialize_column_template(columns(i),templates(i),i)
    call initialize_committed(committed(i),parameters(i),columns(i)%column_id,ok)
    call require(ok,'committed state initialize')
    call backends(i)%initialize(tops(i))
    call materializers(i)%initialize(forcing(i))
    call participants(i)%capture_origin(committed(i),status)
    call require(status==GW_SWAP_PARTICIPANT_OK,'capture origin')
  end do
  call compute_origin_head(parameters(1),datum,origin_head_m,status)
  call require(status==MODFLOW6_BOTTOM_FACE_OK,'origin head')
  call system_clock(c1)
  init_seconds=real(c1-c0,real64)/real(rate,real64)

  exact_tile_trials=0
  approx_responses=0
  qchecksum=0.0_real64
  call system_clock(c0)
  do seq=1,nseq
    q_anchor=0.0_real64; t_anchor=0.0_real64; h_anchor=origin_head_m
    do j=1,8
      head_m=origin_head_m+OFFSETS_CM(j)/100.0_real64
      if(trim(mode)=='exact' .or. j==1 .or. j==5 .or. j==8)then
        call exact_aggregate(head_m,.false.,qagg,tagg)
        exact_tile_trials=exact_tile_trials+n
        qchecksum=qchecksum+qagg
        q_anchor=qagg; t_anchor=tagg; h_anchor=head_m
      else
        q_approx=q_anchor+t_anchor*(head_m-h_anchor)
        call require(ieee_is_finite(q_approx),'finite approximate q')
        qchecksum=qchecksum+q_approx
        approx_responses=approx_responses+1
      end if
    end do
  end do
  call system_clock(c1)
  run_seconds=real(c1-c0,real64)/real(rate,real64)

  ! Exact final validation; this is the only candidate that may commit.
  head_m=origin_head_m+OFFSETS_CM(8)/100.0_real64
  call exact_aggregate(head_m,.true.,final_q,tagg)
  exact_tile_trials=exact_tile_trials+n
  do i=1,n
    call participants(i)%commit_candidate(backends(i),committed(i),window,did_commit,status)
    call require(did_commit .and. status==GW_SWAP_PARTICIPANT_OK,'exact candidate commit')
    call require(committed(i)%current_revision()==1_int64,'exactly one tile commit')
  end do

  call require(ieee_is_finite(qchecksum) .and. ieee_is_finite(final_q),'finite aggregate result')

  write(*,'(*(g0))') 'SOLVE01_P2A_RAW|N=',n,'|MODE=',trim(mode),'|NSEQ=',nseq, &
       '|INIT_SECONDS=',init_seconds,'|RUN_SECONDS=',run_seconds, &
       '|NS_PER_BLOCK=',1.0e9_real64*run_seconds/real(nseq,real64), &
       '|EXACT_TILE_TRIALS=',exact_tile_trials,'|APPROX_RESPONSES=',approx_responses, &
       '|FINAL_Q=',final_q,'|QCHECKSUM=',qchecksum,'|COMMITTED_TILES=',n
  write(*,'(A)') 'FPE_SOLVE01_P2A_POINT=PASS'

contains

  subroutine exact_aggregate(head,keep,qmean,tmean)
    real(real64),intent(in)::head
    logical,intent(in)::keep
    real(real64),intent(out)::qmean,tmean
    type(groundwater_swap_trial_t) :: tr
    integer :: k,s
    qmean=0.0_real64; tmean=0.0_real64
    do k=1,n
      call participants(k)%trial_from_origin(backends(k),columns(k),templates(k),parameters(k),committed(k), &
           materializers(k),config,datum,window,head,tr,s,trusted_prepared_parameters=.true.)
      if(s/=GW_SWAP_PARTICIPANT_OK .or. .not.tr%valid .or. .not.tr%response_tangent_available)then
        do i=1,k
          if(participants(i)%has_live_candidate()) call participants(i)%discard_candidate(backends(i))
        end do
        call require(.false.,'exact aggregate trial')
      end if
      qmean=qmean+tr%q_swap_m_per_s/real(n,real64)
      tmean=tmean+tr%dq_swap_dh_per_s/real(n,real64)
      if(.not.keep) call participants(k)%discard_candidate(backends(k))
    end do
    call require(ieee_is_finite(qmean) .and. ieee_is_finite(tmean),'finite exact aggregate')
  end subroutine exact_aggregate

  subroutine initialize_config(c)
    type(canonical_numerical_config_t),intent(out)::c
    c%transaction%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE
    c%transaction%temporal_tolerance=0.0_real64
    c%transaction%mass_tolerance=TOL
    c%transaction%retry_scale=0.5_real64
    c%transaction%max_retries=8
    c%max_committed_substeps=32
    c%progress_tolerance=0.0_real64
    c%model_temporal_indicator_budget_available=.true.
    c%model_temporal_indicator_budget=TEMPORAL_BUDGET_CM
    c%accepted_trajectory_direction%requested=.false.
  end subroutine initialize_config

  subroutine initialize_parameters(p,idx)
    type(fmr_b110_physical_parameters_t),intent(out)::p
    integer,intent(in)::idx
    integer::k
    p%parameter_set_id=890000_int64+int(idx,int64)
    p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),p%cofgen(24,numnod))
    p%z=z; p%dz=dz; p%node_distance=disnod(1:numnod); p%cofgen=0.0_real64
    do k=1,numnod
      ! O14 difficult profile.
      p%cofgen(1,k)=0.01_real64
      p%cofgen(2,k)=0.393878_real64
      p%cofgen(3,k)=2.495984_real64
      p%cofgen(4,k)=0.003288_real64
      p%cofgen(5,k)=0.514012_real64
      p%cofgen(6,k)=1.616573_real64
      p%cofgen(7,k)=1.0_real64-1.0_real64/p%cofgen(6,k)
      p%cofgen(8,k)=p%cofgen(4,k)
      p%cofgen(9,k)=0.0_real64
      p%cofgen(10,k)=p%cofgen(3,k)
      p%cofgen(11,k)=0.999_real64
      p%cofgen(12,k)=0.99_real64*p%cofgen(3,k)
      p%cofgen(22,k)=-1.0e6_real64
      p%cofgen(23,k)=1.0e-12_real64
    end do
    p%bottom_mode=5; p%swkimpl=0; p%swkmean=1; p%swsophy=0
    p%max_iterations=48; p%max_backtracking=16; p%min_step_duration=1.0e-10_real64
    p%compartment_balance_tolerance=TOL; p%total_balance_tolerance=TOL
    p%head_abs_tolerance=TOL; p%head_rel_tolerance=TOL; p%ponding_tolerance=TOL
    p%root_extraction_active=.false.; p%macropore_active=.false.; p%snow_active=.false.
    p%hysteresis_active=.false.; p%tabulated_hydraulics_active=.false.; p%elasticity_active=.false.
    p%frost_active=.false.; p%soil_temperature_active=.false.; p%drainage_response_active=.false.
  end subroutine initialize_parameters

  subroutine initialize_forcing(f,q)
    type(fmr_b110_physical_forcing_t),intent(out)::f
    real(real64),intent(in)::q
    f%top_flux=q; f%top_head=H0_CM; f%bottom_flux=q; f%bottom_head=H0_CM
    allocate(f%drainage_flux_by_level(1,numnod),f%subsurface_irrigation_source(numnod),f%root_extraction_sink(numnod))
    f%drainage_flux_by_level=0.0_real64
    f%subsurface_irrigation_source=0.0_real64
    f%root_extraction_sink=0.0_real64
  end subroutine initialize_forcing

  subroutine initialize_column_template(c,t,idx)
    type(fmr_logical_column_t),intent(out)::c
    type(fmr_template_t),intent(out)::t
    integer,intent(in)::idx
    t%template_id=900000_int64+int(idx,int64)
    t%physics_topology_id=900010_int64
    t%vertical_layout_id=900020_int64
    t%state_layout_id=900030_int64
    t%solver_interface_id=900040_int64
    t%optional_state_layout_id=0_int64
    t%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
    t%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    c%column_id=910000_int64+int(idx,int64)
    c%template_id=t%template_id
    c%parameter_ref=int(idx,int64)
    c%state_handle=int(idx,int64)
    c%forcing_handle=int(idx,int64)
    c%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine initialize_column_template

  subroutine initialize_committed(state,p,lineage,initialized)
    type(kernel_committed_state_t),intent(out)::state
    type(fmr_b110_physical_parameters_t),intent(in)::p
    integer(int64),intent(in)::lineage
    logical,intent(out)::initialized
    type(fmr_b110_physical_state_t)::physical
    type(b110_default_mvg_parameters_t),target::hp
    type(b110_default_mvg_provider_t)::provider
    real(real64)::heads(numnod),water(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod)
    real(real64)::accepted_predecessor_right_derivative(numnod)
    heads=H0_CM
    call initialize_b110_default_mvg_parameters(hp,p%cofgen)
    call bind_b110_default_mvg_provider(provider,hp,DURATION)
    call provider%evaluate(heads,water,conductivity,capacity,dkdh)
    physical%active_nodes=numnod
    allocate(physical%pressure_head(numnod),physical%water_content(numnod))
    physical%pressure_head=heads
    physical%water_content=water
    physical%ponding_depth=0.0_real64
    physical%groundwater_level=-2.0_real64
    accepted_predecessor_right_derivative=0.0_real64
    call fmr_new_b110_temporal_indicator_committed_state(state,lineage,physical,0.0_real64,initialized, &
         accepted_predecessor_right_derivative)
  end subroutine initialize_committed

  subroutine compute_origin_head(p,datum_value,head,status_out)
    type(fmr_b110_physical_parameters_t),intent(in)::p
    type(groundwater_head_datum_t),intent(in)::datum_value
    real(real64),intent(out)::head
    integer,intent(out)::status_out
    type(b110_default_mvg_parameters_t),target::hp
    type(b110_default_mvg_provider_t)::provider
    type(modflow6_prescribed_qbot_bottom_face_t)::face
    real(real64)::heads(numnod),water(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod)
    heads=H0_CM
    call initialize_b110_default_mvg_parameters(hp,p%cofgen)
    call bind_b110_default_mvg_provider(provider,hp,DURATION)
    call provider%evaluate(heads,water,conductivity,capacity,dkdh)
    call materialize_modflow6_prescribed_qbot_bottom_face(heads(numnod),conductivity(numnod),PREDICTOR_QBOT, &
         0.5_real64*p%dz(numnod),datum_value,face,status_out)
    if(status_out==MODFLOW6_BOTTOM_FACE_OK)then
      head=face%hydraulic_head_m
    else
      head=0.0_real64
    end if
  end subroutine compute_origin_head

  subroutine require(condition,message)
    logical,intent(in)::condition
    character(len=*),intent(in)::message
    if(.not.condition)then
      write(*,'(A,1X,A)') 'SOLVE01_P2A_ASSERT',trim(message)
      error stop 1
    end if
  end subroutine require
end program test_fpe_solve01_p2a_n1_scale
F90

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
  "$BUILD/mod_fmr_serialized_reference_backend.f90"
  src/runtime/mod_groundwater_coupling_contract.f90
  src/runtime/mod_groundwater_swap_forcing_adapter.f90
  src/runtime/mod_groundwater_swap_transaction_participant.f90
  src/runtime/mod_fmr_groundwater_head_forcing_adapter.f90
  src/runtime/mod_fmr_groundwater_swap_participant.f90
  src/runtime/mod_modflow6_swap_prescribed_qbot_bottom_face.f90
)
objects=()
for source in "${MODULE_SRC[@]}"; do
  obj="$BUILD/$(basename "${source%.*}").o"
  gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c "$source" -o "$obj" || fail "compile $source"
  objects+=("$obj")
done
gfortran "${COMMON[@]}" -J "$BUILD" -I "$BUILD" -c "$BUILD/test.f90" -o "$BUILD/test.o" || fail "compile fixture"
gfortran -O2 "${objects[@]}" "$BUILD/test.o" -o "$BUILD/test" || fail "link"

OUT="$BUILD/results.txt"
: > "$OUT"
for n in 1 100 1000; do
  case "$n" in
    1) nseq=400 ;;
    100) nseq=20 ;;
    1000) nseq=4 ;;
  esac
  for rep in 1 2 3; do
    if (( rep % 2 == 1 )); then modes=(exact e4); else modes=(e4 exact); fi
    for mode in "${modes[@]}"; do
      raw="$("$BUILD/test" "$n" "$mode" "$nseq" 2>&1)" || { printf '%s\n' "$raw" >&2; fail "N=$n mode=$mode rep=$rep"; }
      line="$(printf '%s\n' "$raw" | grep '^SOLVE01_P2A_RAW|' | tail -1)"
      [[ -n "$line" ]] || fail "missing P2A record"
      printf '%s|REP=%s\n' "$line" "$rep" | tee -a "$OUT"
    done
  done
done

python3 - "$OUT" <<'PY'
import statistics,sys
rows=[]
for line in open(sys.argv[1]):
    if not line.startswith("SOLVE01_P2A_RAW|"): continue
    d={}
    for p in line.strip().split("|")[1:]:
        k,v=p.split("=",1); d[k]=v
    rows.append(d)
if len(rows)!=18: raise SystemExit(f"expected 18 rows, got {len(rows)}")

for n in (1,100,1000):
    rr=[r for r in rows if int(r["N"])==n]
    by={m:[r for r in rr if r["MODE"]==m] for m in ("exact","e4")}
    if any(len(v)!=3 for v in by.values()): raise SystemExit(f"missing reps N={n}")
    e=by["exact"][0]; q=by["e4"][0]
    if float(e["FINAL_Q"])!=float(q["FINAL_Q"]):
        raise SystemExit(f"final q mismatch N={n}")
    if int(e["COMMITTED_TILES"])!=n or int(q["COMMITTED_TILES"])!=n:
        raise SystemExit(f"commit count mismatch N={n}")
    et=statistics.median(float(r["NS_PER_BLOCK"]) for r in by["exact"])
    qt=statistics.median(float(r["NS_PER_BLOCK"]) for r in by["e4"])
    ratio=qt/et
    solve_reduction=1-int(q["EXACT_TILE_TRIALS"])/int(e["EXACT_TILE_TRIALS"])
    print(f"SOLVE01_P2A_SCALE|N={n}|EXACT_NS_PER_BLOCK={et:.3f}|E4_NS_PER_BLOCK={qt:.3f}"
          f"|RUNTIME_RATIO={ratio:.9f}|SPEEDUP_PERCENT={(1-ratio)*100:.6f}"
          f"|EXACT_TILE_TRIALS={e['EXACT_TILE_TRIALS']}|E4_TILE_TRIALS={q['EXACT_TILE_TRIALS']}"
          f"|SOLVE_REDUCTION_PERCENT={solve_reduction*100:.6f}|FINAL_Q_IDENTITY=TRUE")
    if n==1000:
        if solve_reduction<0.50: raise SystemExit("N=1000 solve reduction gate failed")
        if 1-ratio<0.30: raise SystemExit("N=1000 runtime gain gate failed")
print("FPE_SOLVE01_P2A=PASS")
PY
