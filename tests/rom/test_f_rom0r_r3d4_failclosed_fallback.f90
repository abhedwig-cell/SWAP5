program test_f_rom0r_r3d4_failclosed_fallback
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
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, SW_SOLVE_CONVERGED, SW_SOLVE_RETRY_ADVISED
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_b110_serialized_context_binding, only: bind_b110_serialized_legacy_context
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  real(real64), parameter :: se0=0.85_real64
  real(real64), parameter :: seed_dt=0.0016_real64
  integer, parameter :: seed_intervals=2
  real(real64), parameter :: perturb_dt=0.0008_real64
  integer, parameter :: perturb_intervals=16
  real(real64), parameter :: original_total_tol=1.0e-12_real64
  real(real64), parameter :: hard_mass_gate=1.0e-12_real64
  integer(int64), parameter :: column_id=963401_int64
  character(len=8), parameter :: materials(2)=[character(len=8) :: 'B01','B14']
  character(len=20), parameter :: cases(2)=[character(len=20) :: 'BOTTOM_HEAD_RISE','BOTTOM_HEAD_FALL']

  real(real64) :: policy_lower(2,2),policy_bottom_exchange(2,2)
  logical :: policy_complete(2,2),overlap_complete(2,2)
  integer :: fallback_count(2,2)
  integer :: imat,icase

  call require(numnod==16,'R3D4 geometry frozen at 16 nodes')
  call require(abs(sum(dz(1:numnod))-160.0_real64)<=1.0e-12_real64,'R3D4 depth frozen')

  policy_lower=0.0_real64
  policy_bottom_exchange=0.0_real64
  policy_complete=.false.
  overlap_complete=.false.
  fallback_count=0

  do imat=1,size(materials)
    do icase=1,size(cases)
      call run_pair(trim(materials(imat)),trim(cases(icase)),imat,icase,policy_lower(imat,icase), &
           policy_bottom_exchange(imat,icase),policy_complete(imat,icase),overlap_complete(imat,icase), &
           fallback_count(imat,icase))
    end do
  end do

  do imat=1,size(materials)
    if(policy_complete(imat,1).and.policy_complete(imat,2)) then
      write(*,'(*(g0))') 'F_ROM0R_R3D4_DIRECTION|MATERIAL=',trim(materials(imat)), &
           '|RISE_LOWER=',policy_lower(imat,1),'|FALL_LOWER=',policy_lower(imat,2), &
           '|LOWER_ORDER=',policy_lower(imat,1)>policy_lower(imat,2), &
           '|RISE_BOTTOM_OUT=',policy_bottom_exchange(imat,1), &
           '|FALL_BOTTOM_OUT=',policy_bottom_exchange(imat,2), &
           '|EXCHANGE_ORDER=',policy_bottom_exchange(imat,1)<policy_bottom_exchange(imat,2)
    end if
  end do

  write(*,'(A,I0)') 'F_ROM0R_R3D4_POLICY_COMPLETE_COUNT=',count(policy_complete)
  write(*,'(A,I0)') 'F_ROM0R_R3D4_OVERLAP_COMPLETE_COUNT=',count(overlap_complete)
  write(*,'(A,I0)') 'F_ROM0R_R3D4_TOTAL_FALLBACK_COUNT=',sum(fallback_count)
  write(*,'(A)') 'F_ROM0R_R3D4_EXECUTION_COMPLETE=PASS'

contains

  subroutine run_pair(material_id,case_id,imat,icase,final_lower,final_bottom_exchange,policy_ok,overlap_ok,nfallback)
    character(len=*),intent(in) :: material_id,case_id
    integer,intent(in) :: imat,icase
    real(real64),intent(out) :: final_lower,final_bottom_exchange
    logical,intent(out) :: policy_ok,overlap_ok
    integer,intent(out) :: nfallback

    type(fmr_b110_physical_parameters_t) :: base_parameters,policy_parameters,fallback_parameters
    type(fmr_b110_physical_forcing_t) :: forcing
    type(fmr_b110_physical_state_t) :: initial_state
    type(kernel_committed_state_t) :: base_state,policy_state
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template

    real(real64) :: h0,k0,qeq,hbot,t0,t1,rep_bound,fallback_tol
    real(real64) :: bh(numnod,perturb_intervals),bt(numnod,perturb_intervals)
    real(real64) :: bpond(perturb_intervals),bgwl(perturb_intervals)
    real(real64) :: bmass(perturb_intervals),bbex(perturb_intervals),bbflux(perturb_intervals)
    integer :: bnl(perturb_intervals),bback(perturb_intervals)
    logical :: bvalid(perturb_intervals)
    real(real64) :: mass,bex,bflux,cumulative_bottom,total_storage,upper_storage,lower_storage
    real(real64) :: rsum,rmax,abs_integrated
    integer :: i,base_pass_steps,base_fail_step,solver_status,nl,ir,back,bal_flags,head_flags,imax
    integer :: failed_nl,failed_back
    character(len=96) :: route
    character(len=24) :: failure_class
    logical :: ok,neutral,unchanged
    integer(int64) :: rev_before,lineage_before
    real(real64) :: time_before,time_after
    class(transaction_state_t),allocatable :: snap_before,snap_after
    logical :: got,time_ok

    final_lower=0.0_real64;final_bottom_exchange=0.0_real64
    policy_ok=.false.;overlap_ok=.false.;nfallback=0
    bvalid=.false.;bh=0.0_real64;bt=0.0_real64;bpond=0.0_real64;bgwl=0.0_real64
    bmass=0.0_real64;bbex=0.0_real64;bbflux=0.0_real64;bnl=0;bback=0

    call initialize_parameters(material_id,base_parameters)
    policy_parameters=base_parameters
    call initialize_state(base_parameters,h0,k0,initial_state)
    qeq=-k0
    select case(trim(case_id))
    case('BOTTOM_HEAD_RISE'); hbot=0.75_real64*h0
    case('BOTTOM_HEAD_FALL'); hbot=1.25_real64*h0
    case default
      call require(.false.,'known R3D4 case');hbot=h0
    end select
    call initialize_identity(column,template)
    call initialize_forcing(forcing,qeq,qeq,h0)

    ! Paired reproduction of original R3 control.
    call fmr_new_b110_committed_state(base_state,column_id,initial_state,0.0_real64,ok)
    call require(ok,'baseline initial state')
    base_parameters%bottom_mode=2
    base_parameters%total_balance_tolerance=original_total_tol
    call seed_steady(column,template,base_parameters,base_state,forcing,qeq,ok)
    call require(ok,'baseline seed')
    base_parameters%bottom_mode=5
    forcing%top_flux=qeq;forcing%bottom_flux=qeq;forcing%bottom_head=hbot
    t0=real(seed_intervals,real64)*seed_dt
    base_pass_steps=0;base_fail_step=0
    do i=1,perturb_intervals
      t1=real(seed_intervals,real64)*seed_dt+real(i,real64)*perturb_dt
      call sample_fresh(column,template,base_parameters,base_state,forcing,t0,t1,ok,mass,bex,bflux, &
           solver_status,route,nl,ir,back)
      if(.not.ok) then
        base_fail_step=i
        exit
      end if
      base_pass_steps=i;bvalid(i)=.true.
      bmass(i)=mass;bbex(i)=bex;bbflux(i)=bflux;bnl(i)=nl;bback(i)=back
      call capture_state(base_state,bh(:,i),bt(:,i),bpond(i),bgwl(i),ok)
      call require(ok,'baseline capture')
      t0=t1
    end do
    if(trim(material_id)=='B01'.and.trim(case_id)=='BOTTOM_HEAD_RISE') call require(base_fail_step==11,'B01 rise provenance')
    if(trim(material_id)=='B01'.and.trim(case_id)=='BOTTOM_HEAD_FALL') call require(base_fail_step==10,'B01 fall provenance')
    if(trim(material_id)=='B14') call require(base_pass_steps==16.and.base_fail_step==0,'B14 provenance')
    write(*,'(*(g0))') 'F_ROM0R_R3D4_CONTROL|MATERIAL=',trim(material_id),'|CASE=',trim(case_id), &
         '|PASS_STEPS=',base_pass_steps,'|FAIL_STEP=',base_fail_step

    ! Fail-closed policy trajectory. Original criterion is always attempted first.
    call fmr_new_b110_committed_state(policy_state,column_id,initial_state,0.0_real64,ok)
    call require(ok,'policy initial state')
    policy_parameters%bottom_mode=2
    policy_parameters%total_balance_tolerance=original_total_tol
    call seed_steady(column,template,policy_parameters,policy_state,forcing,qeq,ok)
    call require(ok,'policy seed')
    policy_parameters%bottom_mode=5
    forcing%top_flux=qeq;forcing%bottom_flux=qeq;forcing%bottom_head=hbot
    t0=real(seed_intervals,real64)*seed_dt
    cumulative_bottom=0.0_real64
    overlap_ok=.true.

    do i=1,perturb_intervals
      t1=real(seed_intervals,real64)*seed_dt+real(i,real64)*perturb_dt
      call prospective_bound(policy_state,policy_parameters,rep_bound,ok)
      call require(ok.and.rep_bound>0.0_real64,'pre-solve representation bound')

      rev_before=policy_state%current_revision()
      lineage_before=policy_state%current_lineage_id()
      call policy_state%current_time(time_before,time_ok)
      call require(time_ok.and.same_bits(time_before,t0),'pre-attempt committed time')
      call policy_state%snapshot(snap_before,got)
      call require(got,'pre-attempt snapshot')

      policy_parameters%total_balance_tolerance=original_total_tol
      call sample_fresh(column,template,policy_parameters,policy_state,forcing,t0,t1,ok,mass,bex,bflux, &
           solver_status,route,nl,ir,back)

      if(ok) then
        if(bvalid(i)) then
          call compare_with_baseline(policy_state,bh(:,i),bt(:,i),bpond(i),bgwl(i),bmass(i),bbex(i),bbflux(i), &
               bnl(i),bback(i),mass,bex,bflux,nl,back,neutral)
          overlap_ok=overlap_ok.and.neutral
          call require(neutral,'original-accepted overlap bit neutrality')
        end if
        cumulative_bottom=cumulative_bottom+bex
        write(*,'(*(g0))') 'F_ROM0R_R3D4_STEP|MATERIAL=',trim(material_id),'|CASE=',trim(case_id), &
             '|STEP=',i,'|ROUTE=ORIGINAL|OVERLAP=',bvalid(i),'|NEUTRAL=',merge('T','F',.not.bvalid(i).or.neutral), &
             '|MASS=',mass,'|BOTTOM_EXCHANGE=',bex,'|BOTTOM_FLUX=',bflux,'|NL=',nl,'|BACKTRACK=',back
        t0=t1
        if(allocated(snap_before))deallocate(snap_before)
        cycle
      end if

      ! Fallback on an original accepted overlap is forbidden.
      call require(.not.bvalid(i),'fallback attempted on original accepted overlap')

      call policy_state%current_time(time_after,time_ok)
      call require(time_ok.and.same_bits(time_after,time_before),'failed first attempt time immutable')
      call require(policy_state%current_revision()==rev_before,'failed first attempt revision immutable')
      call require(policy_state%current_lineage_id()==lineage_before,'failed first attempt lineage immutable')
      call policy_state%snapshot(snap_after,got)
      call require(got,'failed first attempt snapshot')
      unchanged=state_bits_equal(snap_before,snap_after)
      call require(unchanged,'failed first attempt physical state immutable')
      failed_nl=nl;failed_back=back

      call diagnose_failed_interval(policy_parameters,forcing,policy_state,t0,t1,solver_status,failed_nl,failed_back, &
           failure_class,bal_flags,head_flags,rmax,rsum,imax)
      call require(trim(failure_class)=='RETRY_TOTAL_ONLY','fallback trigger exact total-only')
      abs_integrated=abs(rsum)*(t1-t0)
      call require(ieee_is_finite(abs_integrated).and.abs_integrated<=rep_bound,'failed residual inside pre-solve bound')

      fallback_tol=max(original_total_tol,rep_bound/(t1-t0))
      fallback_parameters=policy_parameters
      fallback_parameters%total_balance_tolerance=fallback_tol
      call sample_fresh(column,template,fallback_parameters,policy_state,forcing,t0,t1,ok,mass,bex,bflux, &
           solver_status,route,nl,ir,back)
      call require(ok,'qualified fallback reattempt')
      nfallback=nfallback+1
      cumulative_bottom=cumulative_bottom+bex

      write(*,'(*(g0))') 'F_ROM0R_R3D4_FALLBACK|MATERIAL=',trim(material_id),'|CASE=',trim(case_id), &
           '|STEP=',i,'|CLASS=',trim(failure_class),'|BAL_FLAGS=',bal_flags,'|HEAD_FLAGS=',head_flags, &
           '|RMAX=',rmax,'|RSUM=',rsum,'|IMAX=',imax,'|REP_BOUND_CM=',rep_bound, &
           '|ABS_TOTAL_RESIDUAL_CM=',abs_integrated,'|RESIDUAL_OVER_BOUND=',abs_integrated/rep_bound, &
           '|FALLBACK_TOTAL_TOL=',fallback_tol,'|FAILED_NL=',failed_nl,'|FAILED_BACKTRACK=',failed_back, &
           '|ACCEPT_NL=',nl,'|ACCEPT_BACKTRACK=',back,'|MASS=',mass,'|BOTTOM_EXCHANGE=',bex,'|BOTTOM_FLUX=',bflux

      t0=t1
      if(allocated(snap_before))deallocate(snap_before)
      if(allocated(snap_after))deallocate(snap_after)
    end do

    call state_metrics(policy_state,total_storage,upper_storage,lower_storage,ok)
    call require(ok,'policy final metrics')
    final_lower=lower_storage
    final_bottom_exchange=cumulative_bottom
    policy_ok=.true.
    if(trim(material_id)=='B14') call require(nfallback==0,'B14 must not need fallback')
    if(trim(material_id)=='B01') call require(nfallback>0,'B01 must exercise fallback')
    write(*,'(*(g0))') 'F_ROM0R_R3D4_POLICY_CASE_PASS|MATERIAL=',trim(material_id),'|CASE=',trim(case_id), &
         '|FINAL_STORAGE=',total_storage,'|UPPER_STORAGE=',upper_storage,'|LOWER_STORAGE=',lower_storage, &
         '|CUM_BOTTOM_OUTWARD_EXCHANGE=',cumulative_bottom,'|FALLBACKS=',nfallback,'|OVERLAP_NEUTRALITY=',overlap_ok, &
         '|FINAL_REV=',policy_state%current_revision(),'|FINAL_T=',t0
  end subroutine run_pair

  subroutine seed_steady(column,template,p,state,forcing,qeq,ok)
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
      call sample_fresh(column,template,p,state,forcing,t0,t1,ok,mass,bex,bflux,status,route,nl,ir,back)
      if(.not.ok)return
      t0=t1
    end do
  end subroutine seed_steady

  subroutine sample_fresh(column,template,p,state,forcing,t0,t1,ok,mass,bex,bflux,status,route,nl,ir,back)
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
    type(fmr_serialized_reference_backend_t) :: backend
    type(fixed_flux_top_boundary_provider_t),target :: top
    type(kernel_reference_floor_result_t) :: result
    type(kernel_reference_floor_candidate_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics
    type(fmr_serialized_physical_observation_t) :: observation
    logical :: did_commit
    integer :: commit_status

    mass=huge(0.0_real64);bex=0.0_real64;bflux=0.0_real64
    call backend%initialize(top)
    call backend%run_reference_floor_sample(column,template,p,state,forcing,t0,t1,hard_mass_gate,result,candidate,diagnostics)
    observation=backend%observation()
    status=observation%solver_status;route=trim(observation%solver_diagnostics%route)
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
  end subroutine sample_fresh

  subroutine diagnose_failed_interval(p,forcing,state,t0,t1,fmr_status,fmr_nl,fmr_back,class_name,bal,head,rmax,rsum,imax)
    type(fmr_b110_physical_parameters_t),intent(in) :: p
    type(fmr_b110_physical_forcing_t),intent(in) :: forcing
    type(kernel_committed_state_t),intent(in) :: state
    real(real64),intent(in) :: t0,t1
    integer,intent(in) :: fmr_status,fmr_nl,fmr_back
    character(len=*),intent(out) :: class_name
    integer,intent(out) :: bal,head,imax
    real(real64),intent(out) :: rmax,rsum

    type(soil_water_parameter_set_t),target :: pset
    type(b110_default_mvg_parameters_t),target :: hp
    type(b110_default_mvg_provider_t),target :: constitutive
    type(b110_source_sink_provider_t),target :: source_sink
    type(fixed_flux_top_boundary_provider_t),target :: top
    real(real64),target :: drainage(1,numnod),irrigation(numnod),root_sink(numnod)
    type(soil_water_solve_request_t) :: request
    type(soil_water_solve_result_t) :: result
    type(reference_richards_legacy_solver_t) :: solver
    type(reference_richards_legacy_workspace_t) :: workspace
    class(transaction_state_t),allocatable :: snap
    logical :: got,context_ok

    call require(fmr_status==SW_SOLVE_RETRY_ADVISED,'FMR failed status retry-advised')
    pset%parameter_set_id=p%parameter_set_id;pset%active_nodes=numnod
    allocate(pset%z(numnod),pset%dz(numnod),pset%node_distance(numnod))
    pset%z=p%z;pset%dz=p%dz;pset%node_distance=p%node_distance
    call initialize_b110_default_mvg_parameters(hp,p%cofgen)
    call bind_b110_default_mvg_provider(constitutive,hp,t1-t0)
    drainage=0.0_real64;irrigation=0.0_real64;root_sink=0.0_real64
    call bind_b110_source_sink_provider(source_sink,drainage,irrigation,root_sink)

    request%parameters=>pset;request%step_duration=t1-t0
    request%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX;request%boundary%bottom_mode=5
    request%boundary%top_flux=forcing%top_flux;request%boundary%top_head=forcing%top_head
    request%boundary%bottom_flux=forcing%bottom_flux;request%boundary%bottom_head=forcing%bottom_head
    request%numerical%max_iterations=p%max_iterations;request%numerical%max_backtracking=p%max_backtracking
    request%numerical%conductivity_implicit_mode=p%swkimpl;request%numerical%conductivity_mean_method=p%swkmean
    request%numerical%min_step_duration=p%min_step_duration
    request%numerical%compartment_balance_tolerance=p%compartment_balance_tolerance
    request%numerical%total_balance_tolerance=original_total_tol
    request%numerical%head_abs_tolerance=p%head_abs_tolerance;request%numerical%head_rel_tolerance=p%head_rel_tolerance
    request%numerical%ponding_tolerance=p%ponding_tolerance;request%physical%macropore_active=.false.
    request%evaluation%constitutive=>constitutive;request%evaluation%source_sink=>source_sink;request%evaluation%top_boundary=>top

    call state%snapshot(snap,got);call require(got,'diagnostic state snapshot')
    select type(physical=>snap)
    type is(fmr_b110_physical_state_t)
      request%base_state%active_nodes=physical%active_nodes
      allocate(request%base_state%pressure_head(numnod),request%base_state%water_content(numnod))
      request%base_state%pressure_head=physical%pressure_head;request%base_state%water_content=physical%water_content
      request%base_state%ponding_depth=physical%ponding_depth;request%base_state%groundwater_level=physical%groundwater_level
    class default
      call require(.false.,'diagnostic B110 state')
    end select

    call bind_b110_serialized_legacy_context(request,context_ok);call require(context_ok,'diagnostic serialized context')
    call solver%solve(request,workspace,result)
    call require(result%status==SW_SOLVE_RETRY_ADVISED,'direct retry-advised')
    call require(trim(result%diagnostics%route)=='legacy-reference-retry','direct retry route')
    call require(result%diagnostics%nonlinear_iterations==fmr_nl,'FMR/direct nonlinear identity')
    call require(result%diagnostics%backtracking_attempts==fmr_back,'FMR/direct backtracking identity')

    bal=count(workspace%richards%nonconverged_balance)
    head=count(workspace%richards%nonconverged_head)
    rsum=sum(workspace%richards%residual)
    rmax=maxval(abs(workspace%richards%residual))
    imax=maxloc(abs(workspace%richards%residual),dim=1)
    if(bal>0.and.head>0) then
      class_name='RETRY_MIXED'
    else if(bal>0) then
      class_name='RETRY_LOCAL_BALANCE'
    else if(head>0) then
      class_name='RETRY_HEAD'
    else if(ieee_is_finite(rsum).and.ieee_is_finite(rmax).and.rmax<=p%compartment_balance_tolerance.and. &
            abs(rsum)>original_total_tol) then
      class_name='RETRY_TOTAL_ONLY'
    else
      class_name='RETRY_OTHER'
    end if
    if(allocated(snap))deallocate(snap)
  end subroutine diagnose_failed_interval

  subroutine prospective_bound(state,p,bound,ok)
    type(kernel_committed_state_t),intent(in) :: state
    type(fmr_b110_physical_parameters_t),intent(in) :: p
    real(real64),intent(out) :: bound
    logical,intent(out) :: ok
    class(transaction_state_t),allocatable :: snap
    logical :: got
    integer :: i
    real(real64) :: theta_s
    bound=0.0_real64;ok=.false.;theta_s=p%cofgen(2,1)
    call state%snapshot(snap,got);if(.not.got)return
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
    call state%snapshot(snap,got);if(.not.got)return
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
    ok=.false.;call state%snapshot(snap,got);if(.not.got)return
    select type(physical=>snap)
    type is(fmr_b110_physical_state_t)
      h=physical%pressure_head;theta=physical%water_content;pond=physical%ponding_depth;gwl=physical%groundwater_level
      ok=.true.
    class default
      ok=.false.
    end select
    if(allocated(snap))deallocate(snap)
  end subroutine capture_state

  logical function state_bits_equal(left,right) result(equal)
    class(transaction_state_t),allocatable,intent(in) :: left,right
    equal=.false.
    select type(a=>left)
    type is(fmr_b110_physical_state_t)
      select type(b=>right)
      type is(fmr_b110_physical_state_t)
        equal=a%active_nodes==b%active_nodes.and.array_bits_equal(a%pressure_head,b%pressure_head).and. &
             array_bits_equal(a%water_content,b%water_content).and.same_bits(a%ponding_depth,b%ponding_depth).and. &
             same_bits(a%groundwater_level,b%groundwater_level)
      end select
    end select
  end function state_bits_equal

  subroutine state_metrics(state,total,upper,lower,ok)
    type(kernel_committed_state_t),intent(in) :: state
    real(real64),intent(out) :: total,upper,lower
    logical,intent(out) :: ok
    class(transaction_state_t),allocatable :: snap
    logical :: got
    total=0.0_real64;upper=0.0_real64;lower=0.0_real64;ok=.false.
    call state%snapshot(snap,got);if(.not.got)return
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
    array_bits_equal=size(a)==size(b);if(.not.array_bits_equal)return
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
      call require(.false.,'known R3D4 material');tr=0.0_real64;ts=0.0_real64;alpha=0.0_real64;nn=2.0_real64;ks=0.0_real64;lam=0.0_real64
    end select
    mm=1.0_real64-1.0_real64/nn
    p%parameter_set_id=963401_int64;p%active_nodes=numnod
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
    call require(k0>0.0_real64.and.all(ieee_is_finite(water)),'finite R3D4 seed')
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
    tmpl%template_id=963401_int64;tmpl%physics_topology_id=963402_int64
    tmpl%vertical_layout_id=963403_int64;tmpl%state_layout_id=963404_int64;tmpl%solver_interface_id=963405_int64
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
      write(*,'(A,1X,A)') 'F_ROM0R_R3D4_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_f_rom0r_r3d4_failclosed_fallback
