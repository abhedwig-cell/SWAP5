#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-multi02-p0-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/mod"
trap 'rm -rf "$BUILD"' EXIT

cat > "$BUILD/test.f90" <<'F90'
program test_fpe_multi02_p0
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use omp_lib, only: omp_get_num_threads
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, fmr_new_b110_temporal_indicator_committed_state, &
       prepare_fmr_b110_default_mvg
  use mod_fmr_groundwater_head_forcing_adapter, only: fmr_groundwater_head_forcing_materializer_t
  use mod_fmr_groundwater_swap_participant, only: fmr_groundwater_temporal_budget_policy_t
  use mod_fmr_groundwater_participant_registry, only: fmr_groundwater_participant_registry_t, FMR_GW_REGISTRY_OK
  use mod_groundwater_swap_transaction_participant, only: groundwater_swap_trial_t, GW_SWAP_PARTICIPANT_OK
  use mod_groundwater_coupling_contract, only: groundwater_head_datum_t, groundwater_coupling_window_t
  use mod_modflow6_swap_prescribed_qbot_bottom_face, only: modflow6_prescribed_qbot_bottom_face_t, &
       materialize_modflow6_prescribed_qbot_bottom_face, MODFLOW6_BOTTOM_FACE_OK
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  integer, parameter :: NREP=5
  real(real64), parameter :: H0_CM=-75.0_real64, DT=1.0e-4_real64, QBOT=1.0e-6_real64
  real(real64), parameter :: TOL=1.0e-12_real64

  integer :: n,workers,i,w,rep,status,participant_status,active,maxsim,team_seen
  integer(int64) :: c0,c1,rate
  character(len=64) :: arg, mode
  real(real64) :: href, serial_t(NREP), parallel_t(NREP), qdiff,tdiff
  real(real64), allocatable :: target_head(:)
  real(real64) :: qsum,tsum
  logical :: ok,prepared,mixed,mixed_balanced

  type(fmr_b110_physical_parameters_t), target :: parameters
  type(fmr_b110_physical_forcing_t), target, allocatable :: forcings(:)
  type(fmr_b110_physical_state_t) :: initial_state
  type(fmr_logical_column_t), allocatable :: columns(:)
  type(fmr_template_t) :: template
  type(kernel_committed_state_t), target, allocatable :: committed(:)
  type(fmr_groundwater_head_forcing_materializer_t), target, allocatable :: materializers(:)
  type(fmr_serialized_reference_backend_t), target, allocatable :: backends(:)
  type(fixed_flux_top_boundary_provider_t), target :: top
  type(fmr_groundwater_participant_registry_t) :: registry
  type(canonical_numerical_config_t) :: numerical
  type(fmr_groundwater_temporal_budget_policy_t) :: policy
  type(groundwater_head_datum_t) :: datum
  type(groundwater_coupling_window_t) :: window
  integer(int64), allocatable :: handles(:)
  type(groundwater_swap_trial_t), allocatable :: serial_trials(:), parallel_trials(:)
  integer, allocatable :: pstatus(:), rstatus(:)

  if(command_argument_count()<2 .or. command_argument_count()>3) error stop 'usage N WORKERS [MIXED|MIXED_BALANCED]'
  call get_command_argument(1,arg); read(arg,*) n
  call get_command_argument(2,arg); read(arg,*) workers
  mixed=.false.; mixed_balanced=.false.; mode=''
  if(command_argument_count()==3)then
    call get_command_argument(3,mode)
    mixed=trim(mode)=='MIXED' .or. trim(mode)=='MIXED_BALANCED'
    mixed_balanced=trim(mode)=='MIXED_BALANCED'
    if(.not.mixed) error stop 'bad mode'
  end if
  if(n<=0 .or. .not.(workers==1 .or. workers==2 .or. workers==4)) error stop 'bad args'

  call initialize_parameters(parameters)
  call prepare_fmr_b110_default_mvg(parameters,prepared)
  if(.not.prepared) error stop 'prepare hydraulics'
  call initialize_state(parameters,initial_state)
  call initialize_template(template)
  call initialize_numerical(numerical)
  call initialize_datum_head(parameters,datum,href,status)
  if(status/=MODFLOW6_BOTTOM_FACE_OK) error stop 'datum head'

  policy%enabled=.true.
  policy%coefficient=0.65_real64
  policy%floor_cm=1.0e-5_real64
  window%t0=0.0_real64; window%t1=DT

  allocate(columns(n),committed(n),forcings(n),materializers(n),handles(n),target_head(n))
  target_head=href
  if(mixed)then
    do i=1,n
      if(mixed_balanced)then
        if(mod((i-1)/4,4)==mod(i-1,4)) target_head(i)=href+1.0e-3_real64
      else
        if(mod(i-1,4)==0) target_head(i)=href+1.0e-3_real64
      end if
    end do
  end if
  allocate(serial_trials(n),parallel_trials(n),pstatus(n),rstatus(n))
  allocate(backends(workers))
  do w=1,workers
    call backends(w)%initialize(top)
  end do
  call registry%initialize(n,status)
  if(status/=FMR_GW_REGISTRY_OK) error stop 'registry init'

  do i=1,n
    call initialize_forcing(forcings(i))
    call materializers(i)%initialize(forcings(i))
    columns(i)%column_id=100000_int64+int(i,int64)
    columns(i)%template_id=template%template_id
    columns(i)%parameter_ref=1_int64
    columns(i)%state_handle=int(i,int64)
    columns(i)%forcing_handle=int(i,int64)
    columns(i)%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    call initialize_committed(committed(i),initial_state,columns(i)%column_id,ok)
    if(.not.ok) error stop 'committed init'
    w=1+mod(i-1,workers)
    call registry%bind(columns(i)%column_id,backends(w),columns(i),template,parameters,committed(i),materializers(i), &
         numerical,datum,handles(i),status,immutable_parameters=.true.,temporal_budget_policy=policy)
    if(status/=FMR_GW_REGISTRY_OK) error stop 'registry bind'
    call registry%capture_origin(handles(i),participant_status,status)
    if(status/=FMR_GW_REGISTRY_OK .or. participant_status/=GW_SWAP_PARTICIPANT_OK) error stop 'capture'
  end do

  qdiff=0.0_real64; tdiff=0.0_real64
  do rep=1,NREP
    call system_clock(c0,count_rate=rate)
    do i=1,n
      call registry%trial_from_origin(handles(i),window,target_head(i),serial_trials(i),participant_status,status)
      if(status/=FMR_GW_REGISTRY_OK .or. participant_status/=GW_SWAP_PARTICIPANT_OK .or. .not.serial_trials(i)%valid) &
           error stop 'serial trial'
    end do
    call system_clock(c1)
    serial_t(rep)=real(c1-c0,real64)/real(rate,real64)
    do i=1,n
      call registry%discard_candidate(handles(i),status)
      if(status/=FMR_GW_REGISTRY_OK) error stop 'serial discard'
    end do

    pstatus=GW_SWAP_PARTICIPANT_OK
    rstatus=FMR_GW_REGISTRY_OK
    parallel_trials=groundwater_swap_trial_t()
    active=0; maxsim=0; team_seen=0
    call system_clock(c0)
!$omp parallel default(shared) private(i,participant_status,status) num_threads(workers)
!$omp single
    team_seen=omp_get_num_threads()
!$omp end single
!$omp do schedule(static,1)
    do i=1,n
!$omp critical(multi02_active)
      active=active+1
      maxsim=max(maxsim,active)
!$omp end critical(multi02_active)
      call registry%trial_from_origin(handles(i),window,target_head(i),parallel_trials(i),participant_status,status)
      pstatus(i)=participant_status
      rstatus(i)=status
!$omp critical(multi02_active)
      active=active-1
!$omp end critical(multi02_active)
    end do
!$omp end do
!$omp end parallel
    call system_clock(c1)
    parallel_t(rep)=real(c1-c0,real64)/real(rate,real64)

    if(team_seen/=workers) error stop 'omp team mismatch'
    if(any(rstatus/=FMR_GW_REGISTRY_OK) .or. any(pstatus/=GW_SWAP_PARTICIPANT_OK) .or. &
       any(.not.parallel_trials%valid)) error stop 'parallel trial'
    do i=1,n
      qdiff=max(qdiff,abs(parallel_trials(i)%q_swap_m_per_s-serial_trials(i)%q_swap_m_per_s))
      if(parallel_trials(i)%response_tangent_available .neqv. serial_trials(i)%response_tangent_available) &
           error stop 'tangent availability'
      if(parallel_trials(i)%response_tangent_available) then
        tdiff=max(tdiff,abs(parallel_trials(i)%dq_swap_dh_per_s-serial_trials(i)%dq_swap_dh_per_s))
      end if
    end do
    do i=1,n
      call registry%discard_candidate(handles(i),status)
      if(status/=FMR_GW_REGISTRY_OK) error stop 'parallel discard'
    end do
  end do

  call sort5(serial_t); call sort5(parallel_t)
  qsum=sum(parallel_trials%q_swap_m_per_s)
  tsum=0.0_real64
  do i=1,n
    if(parallel_trials(i)%response_tangent_available) tsum=tsum+parallel_trials(i)%dq_swap_dh_per_s
  end do

  if(qdiff>64.0_real64*epsilon(1.0_real64)*max(1.0_real64,maxval(abs(serial_trials%q_swap_m_per_s)))) &
       error stop 'q semantic drift'
  if(tdiff>256.0_real64*epsilon(1.0_real64)*max(1.0_real64,maxval(abs(serial_trials%dq_swap_dh_per_s)))) &
       error stop 'tangent semantic drift'

  write(*,'(*(g0))') 'MULTI02_P0|N=',n,'|WORKERS=',workers, &
       '|SERIAL_SECONDS=',serial_t(3),'|PARALLEL_SECONDS=',parallel_t(3), &
       '|SPEEDUP=',serial_t(3)/parallel_t(3),'|NS_PER_TILE=',1.0e9_real64*parallel_t(3)/real(n,real64), &
       '|MAX_SIMULTANEOUS=',maxsim,'|OMP_TEAM=',team_seen,'|MAX_Q_DIFF=',qdiff,'|MAX_T_DIFF=',tdiff, &
       '|QSUM=',qsum,'|TSUM=',tsum,'|MIXED=',mixed,'|MIXED_BALANCED=',mixed_balanced
  write(*,'(A)') 'FPE_MULTI02_P0=PASS'

contains
  subroutine initialize_parameters(p)
    type(fmr_b110_physical_parameters_t),intent(out)::p
    integer::k
    p%parameter_set_id=620001_int64
    p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),p%cofgen(24,numnod))
    p%z=z; p%dz=dz; p%node_distance=disnod(1:numnod); p%cofgen=0.0_real64
    do k=1,numnod
      p%cofgen(1,k)=0.032_real64; p%cofgen(2,k)=0.423_real64; p%cofgen(3,k)=4.75_real64
      p%cofgen(4,k)=0.0135_real64; p%cofgen(5,k)=0.365_real64; p%cofgen(6,k)=1.455_real64
      p%cofgen(7,k)=1.0_real64-1.0_real64/p%cofgen(6,k); p%cofgen(8,k)=p%cofgen(4,k)
      p%cofgen(9,k)=0.0_real64; p%cofgen(10,k)=p%cofgen(3,k); p%cofgen(11,k)=0.999_real64
      p%cofgen(12,k)=0.99_real64*p%cofgen(3,k); p%cofgen(22,k)=-1.0e6_real64; p%cofgen(23,k)=1.0e-12_real64
    end do
    p%bottom_mode=5; p%swkimpl=0; p%swkmean=1; p%swsophy=0
    p%max_iterations=16; p%max_backtracking=8; p%min_step_duration=1.0e-8_real64
    p%compartment_balance_tolerance=TOL; p%total_balance_tolerance=TOL
    p%head_abs_tolerance=TOL; p%head_rel_tolerance=TOL; p%ponding_tolerance=TOL
    p%root_extraction_active=.false.; p%macropore_active=.false.; p%snow_active=.false.
    p%hysteresis_active=.false.; p%tabulated_hydraulics_active=.false.; p%elasticity_active=.false.
    p%frost_active=.false.; p%soil_temperature_active=.false.; p%drainage_response_active=.false.
  end subroutine initialize_parameters

  subroutine initialize_template(t)
    type(fmr_template_t),intent(out)::t
    t%template_id=610200_int64; t%physics_topology_id=610210_int64; t%vertical_layout_id=610220_int64
    t%state_layout_id=610230_int64; t%solver_interface_id=610240_int64; t%optional_state_layout_id=0_int64
    t%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
    t%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine initialize_template

  subroutine initialize_numerical(v)
    type(canonical_numerical_config_t),intent(out)::v
    v%transaction%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE
    v%transaction%temporal_tolerance=0.0_real64; v%transaction%mass_tolerance=TOL
    v%transaction%retry_scale=0.5_real64; v%transaction%max_retries=8
    v%max_committed_substeps=32; v%progress_tolerance=0.0_real64
    v%model_temporal_indicator_budget_available=.true.; v%model_temporal_indicator_budget=1.0e-5_real64
    v%accepted_trajectory_direction%requested=.true.
  end subroutine initialize_numerical

  subroutine initialize_forcing(f)
    type(fmr_b110_physical_forcing_t),intent(out)::f
    f%top_flux=QBOT; f%top_head=H0_CM; f%bottom_flux=QBOT; f%bottom_head=H0_CM
    allocate(f%drainage_flux_by_level(1,numnod),f%subsurface_irrigation_source(numnod),f%root_extraction_sink(numnod))
    f%drainage_flux_by_level=0.0_real64; f%subsurface_irrigation_source=0.0_real64; f%root_extraction_sink=0.0_real64
  end subroutine initialize_forcing

  subroutine initialize_state(p,s)
    type(fmr_b110_physical_parameters_t),intent(in)::p
    type(fmr_b110_physical_state_t),intent(out)::s
    type(b110_default_mvg_parameters_t),target::hp
    type(b110_default_mvg_provider_t)::provider
    real(real64)::h(numnod),water(numnod),k(numnod),cap(numnod),dk(numnod)
    h=H0_CM
    call initialize_b110_default_mvg_parameters(hp,p%cofgen)
    call bind_b110_default_mvg_provider(provider,hp,DT)
    call provider%evaluate(h,water,k,cap,dk)
    s%active_nodes=numnod; allocate(s%pressure_head(numnod),s%water_content(numnod))
    s%pressure_head=h; s%water_content=water; s%ponding_depth=0.0_real64; s%groundwater_level=-2.0_real64
  end subroutine initialize_state

  subroutine initialize_committed(c,s,lineage,success)
    type(kernel_committed_state_t),intent(out)::c
    type(fmr_b110_physical_state_t),intent(in)::s
    integer(int64),intent(in)::lineage
    logical,intent(out)::success
    real(real64)::history(numnod)
    history=400.0_real64
    call fmr_new_b110_temporal_indicator_committed_state(c,lineage,s,0.0_real64,success,history)
  end subroutine initialize_committed

  subroutine initialize_datum_head(p,d,h,status)
    type(fmr_b110_physical_parameters_t),intent(in)::p
    type(groundwater_head_datum_t),intent(out)::d
    real(real64),intent(out)::h
    integer,intent(out)::status
    type(b110_default_mvg_parameters_t),target::hp
    type(b110_default_mvg_provider_t)::provider
    type(modflow6_prescribed_qbot_bottom_face_t)::face
    real(real64)::heads(numnod),water(numnod),k(numnod),cap(numnod),dk(numnod)
    heads=H0_CM
    call initialize_b110_default_mvg_parameters(hp,p%cofgen)
    call bind_b110_default_mvg_provider(provider,hp,DT)
    call provider%evaluate(heads,water,k,cap,dk)
    d%available=.true.; d%datum_id=630001_int64; d%bottom_boundary_elevation_m=0.0_real64
    call materialize_modflow6_prescribed_qbot_bottom_face(heads(numnod),k(numnod),QBOT,0.5_real64*p%dz(numnod),d,face,status)
    if(status==MODFLOW6_BOTTOM_FACE_OK) h=face%hydraulic_head_m
  end subroutine initialize_datum_head

  subroutine sort5(v)
    real(real64),intent(inout)::v(5)
    real(real64)::tmp
    integer::a,b
    do a=1,4
      do b=a+1,5
        if(v(b)<v(a))then; tmp=v(a); v(a)=v(b); v(b)=tmp; end if
      end do
    end do
  end subroutine sort5
end program test_fpe_multi02_p0
F90

COMMON=(-std=f2008 -ffree-line-length-none -O3 -fopenmp)
mapfile -t MODULE_SRC < <(python3 - <<'PY'
from pathlib import Path
s=Path("tests/fpe/run_fpe_profile04_repeated_decomposition.sh").read_text()
a=s.index("MODULE_SRC=(")+len("MODULE_SRC=(")
b=s.index("\n)\n",a)
for line in s[a:b].splitlines():
    line=line.strip()
    if line:
        print(line)
PY
)

objects=()
for src in "${MODULE_SRC[@]}"; do
  obj="$BUILD/mod/$(basename "${src%.*}").o"
  gfortran "${COMMON[@]}" -J "$BUILD/mod" -I "$BUILD/mod" -c "$src" -o "$obj"
  objects+=("$obj")
done
gfortran "${COMMON[@]}" -J "$BUILD/mod" -I "$BUILD/mod" -c "$BUILD/test.f90" -o "$BUILD/test.o"
gfortran -O3 -fopenmp "${objects[@]}" "$BUILD/test.o" -o "$BUILD/test"

export OMP_DYNAMIC=FALSE
export OMP_THREAD_LIMIT=4
export OMP_PROC_BIND=spread
export OMP_PLACES=cores

OUT="$BUILD/out.txt"; : > "$OUT"
extra_args=()
if [[ -n "${MULTI02_MIXED_MODE:-}" ]]; then
  extra_args=("${MULTI02_MIXED_MODE}")
elif [[ "${MULTI02_MIXED:-0}" == "1" ]]; then
  extra_args=(MIXED)
fi
for n in 100 1000; do
  for w in 1 2 4; do
    "$BUILD/test" "$n" "$w" "${extra_args[@]}" | tee -a "$OUT"
  done
done

python3 - "$OUT" <<'PY'
import sys
rows=[]
for line in open(sys.argv[1]):
    if not line.startswith("MULTI02_P0|"): continue
    d={}
    for part in line.strip().split("|")[1:]:
        k,v=part.split("=",1); d[k]=v
    rows.append(d)
if len(rows)!=6: raise SystemExit(f"expected 6 rows, got {len(rows)}")
by={(int(r["N"]),int(r["WORKERS"])):r for r in rows}
for n in (100,1000):
    base=float(by[(n,1)]["PARALLEL_SECONDS"])
    for w in (1,2,4):
        r=by[(n,w)]; t=float(r["PARALLEL_SECONDS"]); speed=base/t
        print(f"MULTI02_P0_SUMMARY|N={n}|WORKERS={w}|SECONDS={t:.9f}|SPEEDUP={speed:.6f}"
              f"|EFFICIENCY={speed/w:.6f}|NS_PER_TILE={float(r['NS_PER_TILE']):.3f}"
              f"|MAX_SIMULTANEOUS={r['MAX_SIMULTANEOUS']}|MAX_Q_DIFF={r['MAX_Q_DIFF']}|MAX_T_DIFF={r['MAX_T_DIFF']}")
        if w>1 and int(r["MAX_SIMULTANEOUS"])<2:
            raise SystemExit(f"no concurrency N={n} W={w}")
print("FPE_MULTI02_P0_AGGREGATE=PASS")
PY
