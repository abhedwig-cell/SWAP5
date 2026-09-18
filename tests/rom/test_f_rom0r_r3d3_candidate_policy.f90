program test_f_rom0r_r3d3_candidate_policy
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: transaction_state_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_reference_floor_result_t, &
       kernel_reference_floor_candidate_t, kernel_diagnostics_t, KERNEL_REFERENCE_FLOOR_STATUS_OK, &
       KERNEL_COMMIT_STATUS_COMMITTED
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_NUMERICAL_CONTINUATION_NONE, FMR_OPTIONAL_STATE_LAYOUT_BASE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, fmr_serialized_physical_observation_t, &
       fmr_new_b110_committed_state
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_soil_water_solver_contract, only: SW_SOLVE_CONVERGED
  implicit none

  real(real64), parameter :: se0=0.85_real64
  real(real64), parameter :: seed_dt=0.0016_real64
  integer, parameter :: seed_intervals=2
  real(real64), parameter :: perturb_dt=0.0008_real64
  integer, parameter :: perturb_intervals=16
  real(real64), parameter :: original_total_tol=1.0e-12_real64
  real(real64), parameter :: hard_mass_gate=1.0e-12_real64
  integer(int64), parameter :: column_id=963301_int64
  character(len=8), parameter :: materials(2)=[character(len=8) :: 'B01','B14']
  character(len=20), parameter :: cases(2)=[character(len=20) :: 'BOTTOM_HEAD_RISE','BOTTOM_HEAD_FALL']

  real(real64) :: candidate_lower(2,2),candidate_bottom_exchange(2,2)
  logical :: candidate_complete(2,2),neutrality_complete(2,2)
  integer :: imat,icase

  call require(numnod==16,'R3D3 geometry frozen at 16 nodes')
  call require(abs(sum(dz(1:numnod))-160.0_real64)<=1.0e-12_real64,'R3D3 depth frozen')

  candidate_lower=0.0_real64
  candidate_bottom_exchange=0.0_real64
  candidate_complete=.false.
  neutrality_complete=.false.

  do imat=1,size(materials)
    do icase=1,size(cases)
      call run_pair(trim(materials(imat)),trim(cases(icase)),imat,icase, &
           candidate_lower(imat,icase),candidate_bottom_exchange(imat,icase), &
           candidate_complete(imat,icase),neutrality_complete(imat,icase))
    end do
  end do

  do imat=1,size(materials)
    if(candidate_complete(imat,1).and.candidate_complete(imat,2)) then
      write(*,'(*(g0))') 'F_ROM0R_R3D3_DIRECTION|MATERIAL=',trim(materials(imat)), &
           '|RISE_LOWER=',candidate_lower(imat,1),'|FALL_LOWER=',candidate_lower(imat,2), &
           '|LOWER_ORDER=',candidate_lower(imat,1)>candidate_lower(imat,2), &
           '|RISE_BOTTOM_OUT=',candidate_bottom_exchange(imat,1), &
           '|FALL_BOTTOM_OUT=',candidate_bottom_exchange(imat,2), &
           '|EXCHANGE_ORDER=',candidate_bottom_exchange(imat,1)<candidate_bottom_exchange(imat,2)
    end if
  end do

  write(*,'(A,I0)') 'F_ROM0R_R3D3_CANDIDATE_COMPLETE_COUNT=',count(candidate_complete)
  write(*,'(A,I0)') 'F_ROM0R_R3D3_NEUTRALITY_COMPLETE_COUNT=',count(neutrality_complete)
  write(*,'(A)') 'F_ROM0R_R3D3_EXECUTION_COMPLETE=PASS'

contains

  subroutine run_pair(material_id,case_id,imat,icase,final_lower,final_bottom_exchange,candidate_ok,neutrality_ok)
    character(len=*),intent(in) :: material_id,case_id
    integer,intent(in) :: imat,icase
    real(real64),intent(out) :: final_lower,final_bottom_exchange
    logical,intent(out) :: candidate_ok,neutrality_ok

    type(fmr_b110_physical_parameters_t) :: base_parameters,policy_parameters
    type(fmr_b110_physical_forcing_t) :: forcing
    type(fmr_b110_physical_state_t) :: initial_state
    type(fmr_serialized_reference_backend_t) :: base_backend,policy_backend
    type(fixed_flux_top_boundary_provider_t),target :: base_top,policy_top
    type(kernel_committed_state_t) :: base_state,policy_state
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template

    real(real64) :: h0,k0,qeq,hbot,t0,t1
    real(real64) :: bh(numnod,perturb_intervals),bt(numnod,perturb_intervals)
    real(real64) :: bpond(perturb_intervals),bgwl(perturb_intervals)
    real(real64) :: bmass(perturb_intervals),bbex(perturb_intervals),bbflux(perturb_intervals)
    integer :: bnl(perturb_intervals),bback(perturb_intervals)
    logical :: bvalid(perturb_intervals)
    integer :: i,base_pass_steps,base_fail_step
    logical :: ok,neutral
    real(real64) :: mass,bex,bflux,rep_bound,policy_tol,total_storage,upper_storage,lower_storage
    integer :: solver_status,nl,internal_retries,backtracking
    character(len=96) :: route
    real(real64) :: cumulative_bottom

    final_lower=0.0_real64
    final_bottom_exchange=0.0_real64
    candidate_ok=.false.
    neutrality_ok=.false.
    bvalid=.false.
    bh=0.0_real64;bt=0.0_real64;bpond=0.0_real64;bgwl=0.0_real64
    bmass=0.0_real64;bbex=0.0_real64;bbflux=0.0_real64
    bnl=0;bback=0

    call initialize_parameters(material_id,base_parameters)
    policy_parameters=base_parameters
    call initialize_state(base_parameters,h0,k0,initial_state)
    qeq=-k0
    select case(trim(case_id))
    case('BOTTOM_HEAD_RISE'); hbot=0.75_real64*h0
    case('BOTTOM_HEAD_FALL'); hbot=1.25_real64*h0
    case default
      call require(.false.,'known R3D3 case'); hbot=h0
    end select
    call initialize_identity(column,template)
    call initialize_forcing(forcing,qeq,qeq,h0)

    ! Original R3 control trajectory.
    call fmr_new_b110_committed_state(base_state,column_id,initial_state,0.0_real64,ok)
    call require(ok,'base initial state')
    call base_backend%initialize(base_top)
    base_parameters%bottom_mode=2
    base_parameters%total_balance_tolerance=original_total_tol
    call seed_steady(base_backend,column,template,base_parameters,base_state,forcing,qeq,ok)
    call require(ok,'base seed')
    base_parameters%bottom_mode=5
    forcing%top_flux=qeq;forcing%bottom_flux=qeq;forcing%bottom_head=hbot
    t0=real(seed_intervals,real64)*seed_dt
    base_pass_steps=0;base_fail_step=0
    do i=1,perturb_intervals
      t1=real(seed_intervals,real64)*seed_dt+real(i,real64)*perturb_dt
      call sample_once(base_backend,column,template,base_parameters,base_state,forcing,t0,t1,ok,mass,bex,bflux, &
           solver_status,route,nl,internal_retries,backtracking)
      if(.not.ok) then
        base_fail_step=i
        exit
      end if
      base_pass_steps=i
      bvalid(i)=.true.
      bmass(i)=mass;bbex(i)=bex;bbflux(i)=bflux;bnl(i)=nl;bback(i)=backtracking
      call capture_state(base_state,bh(:,i),bt(:,i),bpond(i),bgwl(i),ok)
      call require(ok,'capture baseline state')
      t0=t1
    end do

    if(trim(material_id)=='B01'.and.trim(case_id)=='BOTTOM_HEAD_RISE') call require(base_fail_step==11,'B01 rise baseline provenance')
    if(trim(material_id)=='B01'.and.trim(case_id)=='BOTTOM_HEAD_FALL') call require(base_fail_step==10,'B01 fall baseline provenance')
    if(trim(material_id)=='B14') call require(base_pass_steps==16.and.base_fail_step==0,'B14 baseline provenance')

    write(*,'(*(g0))') 'F_ROM0R_R3D3_CONTROL|MATERIAL=',trim(material_id),'|CASE=',trim(case_id), &
         '|PASS_STEPS=',base_pass_steps,'|FAIL_STEP=',base_fail_step

    ! Candidate policy trajectory, fresh state/backend, same seed.
    call fmr_new_b110_committed_state(policy_state,column_id,initial_state,0.0_real64,ok)
    call require(ok,'policy initial state')
    call policy_backend%initialize(policy_top)
    policy_parameters%bottom_mode=2
    policy_parameters%total_balance_tolerance=original_total_tol
    call seed_steady(policy_backend,column,template,policy_parameters,policy_state,forcing,qeq,ok)
    call require(ok,'policy seed')
    policy_parameters%bottom_mode=5
    forcing%top_flux=qeq;forcing%bottom_flux=qeq;forcing%bottom_head=hbot
    t0=real(seed_intervals,real64)*seed_dt
    cumulative_bottom=0.0_real64
    neutrality_ok=.true.

    do i=1,perturb_intervals
      t1=real(seed_intervals,real64)*seed_dt+real(i,real64)*perturb_dt
      call prospective_bound(policy_state,policy_parameters,rep_bound,ok)
      call require(ok.and.rep_bound>0.0_real64,'finite positive pre-solve representation bound')
      policy_tol=max(original_total_tol,rep_bound/(t1-t0))
      policy_parameters%total_balance_tolerance=policy_tol

      call sample_once(policy_backend,column,template,policy_parameters,policy_state,forcing,t0,t1,ok,mass,bex,bflux, &
           solver_status,route,nl,internal_retries,backtracking)
      if(.not.ok) then
        write(*,'(*(g0))') 'F_ROM0R_R3D3_POLICY_FAIL|MATERIAL=',trim(material_id),'|CASE=',trim(case_id), &
             '|STEP=',i,'|T0=',t0,'|T1=',t1,'|REP_BOUND_CM=',rep_bound,'|TOTAL_TOL=',policy_tol, &
             '|SOLVER_STATUS=',solver_status,'|ROUTE=',trim(route),'|NL=',nl,'|BACKTRACK=',backtracking
        candidate_ok=.false.
        return
      end if

      neutral=.true.
      if(bvalid(i)) then
        call compare_with_baseline(policy_state,bh(:,i),bt(:,i),bpond(i),bgwl(i),bmass(i),bbex(i),bbflux(i), &
             bnl(i),bback(i),mass,bex,bflux,nl,backtracking,neutral)
        neutrality_ok=neutrality_ok.and.neutral
      end if
      cumulative_bottom=cumulative_bottom+bex

      write(*,'(*(g0))') 'F_ROM0R_R3D3_POLICY_STEP|MATERIAL=',trim(material_id),'|CASE=',trim(case_id), &
           '|STEP=',i,'|REP_BOUND_CM=',rep_bound,'|TOTAL_TOL=',policy_tol,'|OVERLAP=',bvalid(i), &
           '|NEUTRAL=',neutral,'|MASS=',mass,'|BOTTOM_EXCHANGE=',bex,'|BOTTOM_FLUX=',bflux, &
           '|NL=',nl,'|BACKTRACK=',backtracking
      t0=t1
    end do

    call state_metrics(policy_state,total_storage,upper_storage,lower_storage,ok)
    call require(ok,'candidate final state metrics')
    final_lower=lower_storage
    final_bottom_exchange=cumulative_bottom
    candidate_ok=.true.
    write(*,'(*(g0))') 'F_ROM0R_R3D3_POLICY_CASE_PASS|MATERIAL=',trim(material_id),'|CASE=',trim(case_id), &
         '|FINAL_STORAGE=',total_storage,'|UPPER_STORAGE=',upper_storage,'|LOWER_STORAGE=',lower_storage, &
         '|CUM_BOTTOM_OUTWARD_EXCHANGE=',cumulative_bottom,'|NEUTRALITY=',neutrality_ok, &
         '|FINAL_REV=',policy_state%current_revision(),'|FINAL_T=',t0
  end subroutine run_pair

  subroutine seed_steady(backend,column,template,p,state,forcing,qeq,ok)
    type(fmr_serialized_reference_backend_t),intent(inout) :: backend
    type(fmr_logical_column_t),intent(in) :: column
    type(fmr_template_t),intent(in) :: template
    type(fmr_b110_physical_parameters_t),intent(in) :: p
    type(kernel_committed_state_t),intent(inout) :: state
    type(fmr_b110_physical_forcing_t),intent(inout) :: forcing
    real(real64),intent(in) :: qeq
    logical,intent(out) :: ok
    real(real64) :: mass,bex,bflux,t0,t1
    integer :: i,status,nl,ir,back
    character(len=96) :: route
    ok=.true.;t0=0.0_real64
    forcing%top_flux=qeq;forcing%bottom_flux=qeq
    do i=1,seed_intervals
      t1=real(i,real64)*seed_dt
      call sample_once(backend,column,template,p,state,forcing,t0,t1,ok,mass,bex,bflux,status,route,nl,ir,back)
      if(.not.ok)return
      t0=t1
    end do
  end subroutine seed_steady

  subroutine sample_once(backend,column,template,p,state,forcing,t0,t1,ok,mass,bex,bflux,status,route,nl,ir,back)
    type(fmr_serialized_reference_backend_t),intent(inout) :: backend
    type(fmr_logical_column_t),intent(in) :: column
    type(fmr_template_t),intent(in) :: template
    type(fmr_b110_physical_parameters_t),intent(in) :: p
    type(kernel_committed_state_t),intent(inout) :: state
    type(fmr_b110_physical_forcing_t),intent(in) :: forcing
    real(real64),intent(in) :: t0,t1
    logical,intent(out) :: ok
    real(real64),intent(out) :: mass,bex,bflux
    integer,intent(out) :: status,nl,ir,back
    character(len=*),intent(out) :: route
    type(kernel_reference_floor_result_t) :: result
    type(kernel_reference_floor_candidate_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics
    type(fmr_serialized_physical_observation_t) :: observation
    logical :: did_commit
    integer :: commit_status

    mass=huge(0.0_real64);bex=0.0_real64;bflux=0.0_real64
    call backend%run_reference_floor_sample(column,template,p,state,forcing,t0,t1,hard_mass_gate,result,candidate,diagnostics)
    observation=backend%observation()
    status=observation%solver_status
    route=trim(observation%solver_diagnostics%route)
    nl=result%nonlinear_iterations;ir=result%internal_retries;back=result%backtracking_attempts
    ok=result%status==KERNEL_REFERENCE_FLOOR_STATUS_OK.and.result%sample_valid.and.candidate%ready().and. &
       result%physical_advances==1.and.result%internal_retries==0.and.diagnostics%retries==0.and. &
       result%mass%complete.and.ieee_is_finite(result%mass%residual).and.abs(result%mass%residual)<=hard_mass_gate.and. &
       observation%solver_executed.and.observation%solver_status==SW_SOLVE_CONVERGED.and. &
       result%bottom_interface_exchange_available.and.ieee_is_finite(result%bottom_outward_exchange_native).and. &
       ieee_is_finite(result%terminal_bottom_outward_flux_native)
    if(.not.ok) then
      if(candidate%ready()) call backend%discard_reference_floor_candidate(candidate,diagnostics)
      return
    end if
    mass=result%mass%residual;bex=result%bottom_outward_exchange_native;bflux=result%terminal_bottom_outward_flux_native
    call backend%commit_reference_floor_candidate(state,candidate,diagnostics,did_commit,commit_status)
    ok=did_commit.and.commit_status==KERNEL_COMMIT_STATUS_COMMITTED.and..not.candidate%ready()
  end subroutine sample_once

  subroutine prospective_bound(state,p,bound,ok)
    type(kernel_committed_state_t),intent(in) :: state
    type(fmr_b110_physical_parameters_t),intent(in) :: p
    real(real64),intent(out) :: bound
    logical,intent(out) :: ok
    class(transaction_state_t),allocatable :: snap
    logical :: got
    integer :: i
    real(real64) :: theta_s
    bound=0.0_real64;ok=.false.
    theta_s=p%cofgen(2,1)
    call state%snapshot(snap,got)
    if(.not.got)return
    select type(physical=>snap)
    type is(fmr_b110_physical_state_t)
      if(physical%active_nodes/=numnod)return
      do i=1,numnod
        if(.not.ieee_is_finite(physical%water_content(i)))return
        if(physical%water_content(i)<=0.0_real64.or.physical%water_content(i)>=theta_s)return
        if(spacing(physical%water_content(i))>spacing(theta_s))return
        bound=bound+0.5_real64*(spacing(theta_s)+spacing(physical%water_content(i)))*p%dz(i)
      end do
      ok=ieee_is_finite(bound).and.bound>0.0_real64
    class default
      ok=.false.
    end select
    if(allocated(snap))deallocate(snap)
  end subroutine prospective_bound

  subroutine compare_with_baseline(state,h,theta,pond,gwl,bmass,bbex,bbflux,bnl,bback,mass,bex,bflux,nl,back,neutral)
    type(kernel_committed_state_t),intent(in) :: state
    real(real64),intent(in) :: h(:),theta(:),pond,gwl,bmass,bbex,bbflux,mass,bex,bflux
    integer,intent(in) :: bnl,bback,nl,back
    logical,intent(out) :: neutral
    class(transaction_state_t),allocatable :: snap
    logical :: got
    neutral=.false.
    if(.not.same_bits(bmass,mass).or..not.same_bits(bbex,bex).or..not.same_bits(bbflux,bflux))return
    if(bnl/=nl.or.bback/=back)return
    call state%snapshot(snap,got)
    if(.not.got)return
    select type(physical=>snap)
    type is(fmr_b110_physical_state_t)
      neutral=array_bits_equal(physical%pressure_head,h).and.array_bits_equal(physical%water_content,theta).and. &
           same_bits(physical%ponding_depth,pond).and.same_bits(physical%groundwater_level,gwl)
    class default
      neutral=.false.
    end select
    if(allocated(snap))deallocate(snap)
  end subroutine compare_with_baseline

  subroutine capture_state(state,h,theta,pond,gwl,ok)
    type(kernel_committed_state_t),intent(in) :: state
    real(real64),intent(out) :: h(:),theta(:),pond,gwl
    logical,intent(out) :: ok
    class(transaction_state_t),allocatable :: snap
    logical :: got
    ok=.false.
    call state%snapshot(snap,got)
    if(.not.got)return
    select type(physical=>snap)
    type is(fmr_b110_physical_state_t)
      h=physical%pressure_head;theta=physical%water_content
      pond=physical%ponding_depth;gwl=physical%groundwater_level
      ok=.true.
    class default
      ok=.false.
    end select
    if(allocated(snap))deallocate(snap)
  end subroutine capture_state

  subroutine state_metrics(state,total,upper,lower,ok)
    type(kernel_committed_state_t),intent(in) :: state
    real(real64),intent(out) :: total,upper,lower
    logical,intent(out) :: ok
    class(transaction_state_t),allocatable :: snap
    logical :: got
    call state%snapshot(snap,got);ok=.false.;total=0.0_real64;upper=0.0_real64;lower=0.0_real64
    if(.not.got)return
    select type(physical=>snap)
    type is(fmr_b110_physical_state_t)
      total=sum(physical%water_content*dz(1:numnod))
      upper=sum(physical%water_content(1:4)*dz(1:4))
      lower=sum(physical%water_content(5:numnod)*dz(5:numnod))
      ok=ieee_is_finite(total).and.ieee_is_finite(upper).and.ieee_is_finite(lower)
    class default
      ok=.false.
    end select
    if(allocated(snap))deallocate(snap)
  end subroutine state_metrics

  pure logical function array_bits_equal(a,b)
    real(real64),intent(in) :: a(:),b(:)
    integer :: i
    array_bits_equal=size(a)==size(b)
    if(.not.array_bits_equal)return
    do i=1,size(a)
      if(.not.same_bits(a(i),b(i)))then;array_bits_equal=.false.;return;end if
    end do
  end function array_bits_equal

  pure logical function same_bits(a,b)
    real(real64),intent(in) :: a,b
    integer(int64) :: ia,ib
    ia=transfer(a,ia);ib=transfer(b,ib);same_bits=ia==ib
  end function same_bits

  subroutine initialize_parameters(material_id,p)
    character(len=*),intent(in) :: material_id
    type(fmr_b110_physical_parameters_t),intent(out) :: p
    real(real64) :: tr,ts,alpha,nn,ks,lam,mm
    integer :: k
    select case(trim(material_id))
    case('B01')
      tr=0.02_real64;ts=0.427494_real64;alpha=0.021659_real64;nn=1.734737_real64;ks=31.225016_real64;lam=0.98087_real64
    case('B14')
      tr=0.01_real64;ts=0.416774_real64;alpha=0.00541_real64;nn=1.301528_real64;ks=0.895023_real64;lam=-0.334926_real64
    case default
      call require(.false.,'known R3D3 material');tr=0.0_real64;ts=0.0_real64;alpha=0.0_real64;nn=2.0_real64;ks=0.0_real64;lam=0.0_real64
    end select
    mm=1.0_real64-1.0_real64/nn
    p%parameter_set_id=963301_int64;p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),p%cofgen(24,numnod))
    p%z=z;p%dz=dz;p%node_distance=disnod(1:numnod);p%cofgen=0.0_real64
    do k=1,numnod
      p%cofgen(1,k)=tr;p%cofgen(2,k)=ts;p%cofgen(3,k)=ks;p%cofgen(4,k)=alpha;p%cofgen(5,k)=lam;p%cofgen(6,k)=nn
      p%cofgen(7,k)=mm;p%cofgen(8,k)=alpha;p%cofgen(9,k)=0.0_real64;p%cofgen(10,k)=ks
      p%cofgen(11,k)=0.999_real64;p%cofgen(12,k)=0.99_real64*ks;p%cofgen(22,k)=-1.0e6_real64;p%cofgen(23,k)=1.0e-12_real64
    end do
    p%bottom_mode=2;p%swkimpl=0;p%swkmean=1;p%swsophy=0
    p%max_iterations=16;p%max_backtracking=8;p%min_step_duration=1.0e-8_real64
    p%compartment_balance_tolerance=1.0e-12_real64;p%total_balance_tolerance=original_total_tol
    p%head_abs_tolerance=1.0e-12_real64;p%head_rel_tolerance=1.0e-12_real64;p%ponding_tolerance=1.0e-12_real64
    p%root_extraction_active=.false.;p%macropore_active=.false.;p%snow_active=.false.
    p%hysteresis_active=.false.;p%tabulated_hydraulics_active=.false.;p%ksatexm_extension_active=.false.
    p%elasticity_active=.false.;p%frost_active=.false.;p%soil_temperature_active=.false.
    p%drainage_response_active=.false.;p%drainage_qbot_smooth_freatic_projection=.false.
  end subroutine initialize_parameters

  subroutine initialize_state(p,h0,k0,state)
    type(fmr_b110_physical_parameters_t),intent(in) :: p
    real(real64),intent(out) :: h0,k0
    type(fmr_b110_physical_state_t),intent(out) :: state
    type(b110_default_mvg_parameters_t),target :: hp
    type(b110_default_mvg_provider_t) :: provider
    real(real64) :: m,heads(numnod),water(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod)
    m=1.0_real64-1.0_real64/p%cofgen(6,1)
    h0=-(se0**(-1.0_real64/m)-1.0_real64)**(1.0_real64/p%cofgen(6,1))/p%cofgen(4,1)
    heads=h0
    call initialize_b110_default_mvg_parameters(hp,p%cofgen)
    call bind_b110_default_mvg_provider(provider,hp,seed_dt)
    call provider%evaluate(heads,water,conductivity,capacity,dkdh)
    k0=conductivity(1)
    call require(k0>0.0_real64.and.all(ieee_is_finite(water)),'finite R3D3 seed')
    state%active_nodes=numnod
    allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head=heads;state%water_content=water
    state%ponding_depth=0.0_real64;state%groundwater_level=-999.0_real64
  end subroutine initialize_state

  subroutine initialize_forcing(f,qt,qb,hb)
    type(fmr_b110_physical_forcing_t),intent(out) :: f
    real(real64),intent(in) :: qt,qb,hb
    f%top_flux=qt;f%top_head=0.0_real64;f%bottom_flux=qb;f%bottom_head=hb
    allocate(f%drainage_flux_by_level(1,numnod),f%subsurface_irrigation_source(numnod),f%root_extraction_sink(numnod))
    f%drainage_flux_by_level=0.0_real64;f%subsurface_irrigation_source=0.0_real64;f%root_extraction_sink=0.0_real64
  end subroutine initialize_forcing

  subroutine initialize_identity(col,tmpl)
    type(fmr_logical_column_t),intent(out) :: col
    type(fmr_template_t),intent(out) :: tmpl
    tmpl%template_id=963301_int64;tmpl%physics_topology_id=963302_int64
    tmpl%vertical_layout_id=963303_int64;tmpl%state_layout_id=963304_int64;tmpl%solver_interface_id=963305_int64
    tmpl%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_BASE
    tmpl%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
    tmpl%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    col%column_id=column_id;col%template_id=tmpl%template_id;col%parameter_ref=1_int64
    col%state_handle=1_int64;col%forcing_handle=1_int64;col%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine initialize_identity

  subroutine require(condition,label)
    logical,intent(in) :: condition
    character(len=*),intent(in) :: label
    if(.not.condition)then
      write(*,'(A,1X,A)') 'F_ROM0R_R3D3_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_f_rom0r_r3d3_candidate_policy
