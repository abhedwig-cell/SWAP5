program test_lare_rs1_gw_library
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

  integer, parameter :: NHIST=6, NSTEPS=1024
  integer, parameter :: SYM_HOLD=1, SYM_TOP_PLUS=2, SYM_TOP_MINUS=3, SYM_RISE=4, SYM_FALL=5, &
                        SYM_COMBINED_RISE_PLUS=6, SYM_COMBINED_FALL_MINUS=7
  real(real64), parameter :: seed_dt=0.0016_real64
  integer, parameter :: seed_intervals=2
  real(real64), parameter :: step_dt=0.0008_real64
  real(real64), parameter :: original_total_tol=1.0e-12_real64
  real(real64), parameter :: hard_mass_gate=1.0e-12_real64
  integer(int64), parameter :: column_id=971001_int64

  integer :: ih,total_states,total_fallbacks
  real(real64) :: max_abs_mass

  call require(numnod==16,'LAREGW1 geometry frozen at 16 nodes')
  call require(abs(sum(dz(1:numnod))-160.0_real64)<=1.0e-12_real64,'LAREGW1 depth frozen')
  total_states=0;total_fallbacks=0;max_abs_mass=0.0_real64

  do ih=1,NHIST
    call run_history(ih,total_states,total_fallbacks,max_abs_mass)
  end do

  call require(total_states==NHIST*NSTEPS,'LAREGW1 exact library state count')
  write(*,'(A,I0)') 'LAREGW1_HISTORY_COUNT=',NHIST
  write(*,'(A,I0)') 'LAREGW1_STEPS_PER_HISTORY=',NSTEPS
  write(*,'(A,I0)') 'LAREGW1_STATE_COUNT=',total_states
  write(*,'(A,I0)') 'LAREGW1_TOTAL_FALLBACK_COUNT=',total_fallbacks
  write(*,'(*(g0))') 'LAREGW1_MAX_ABS_MASS=',max_abs_mass
  write(*,'(A)') 'LAREGW1_B14_MATERIAL_TRANSFER_GENERATED=FALSE'
  write(*,'(A)') 'LAREGW1_EXECUTION_COMPLETE=PASS'

contains

  subroutine run_history(ih,total_states,total_fallbacks,max_abs_mass)
    integer,intent(in) :: ih
    integer,intent(inout) :: total_states,total_fallbacks
    real(real64),intent(inout) :: max_abs_mass
    type(fmr_b110_physical_parameters_t) :: p
    type(fmr_b110_physical_forcing_t) :: forcing
    type(fmr_b110_physical_state_t) :: initial_state
    type(kernel_committed_state_t) :: state
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    real(real64) :: h0,k0,qeq,t0,t1,mass,bex,bflux
    integer :: step,symbol,status,nl,ir,back
    character(len=96) :: route
    logical :: ok,fallback_used
    integer :: history_fallbacks
    real(real64) :: history_max_mass

    call initialize_parameters(p)
    call initialize_state(p,initial_se(ih),h0,k0,initial_state)
    qeq=-k0
    call initialize_identity(column,template)
    call initialize_forcing(forcing,qeq,qeq,h0)
    call fmr_new_b110_committed_state(state,column_id,initial_state,0.0_real64,ok)
    call require(ok.and.state%ready(),'ROM1A initial committed state')

    p%bottom_mode=2
    p%total_balance_tolerance=original_total_tol
    call seed_steady(column,template,p,state,forcing,qeq,ok)
    call require(ok,'ROM1A gravity-consistent seed')

    t0=real(seed_intervals,real64)*seed_dt
    history_fallbacks=0
    history_max_mass=0.0_real64

    do step=1,NSTEPS
      symbol=history_symbol(ih,step)
      call configure_symbol(symbol,h0,k0,qeq,p,forcing)
      t1=real(seed_intervals,real64)*seed_dt+real(step,real64)*step_dt
      call strict_first_sample(column,template,p,state,forcing,t0,t1,ok,mass,bex,bflux,status,route,nl,ir,back,fallback_used)
      call require(ok,'ROM1A accepted history step')
      call require(abs(mass)<=hard_mass_gate,'ROM1A hard mass gate')
      call require(state%current_revision()==int(seed_intervals+step,int64),'ROM1A exact revision progression')
      call require_current_time(state,t1)
      history_max_mass=max(history_max_mass,abs(mass))
      max_abs_mass=max(max_abs_mass,abs(mass))
      if(fallback_used)then
        history_fallbacks=history_fallbacks+1
        total_fallbacks=total_fallbacks+1
      end if
      total_states=total_states+1
      call emit_state(ih,step,symbol,state,forcing,t0,t1,mass,bex,bflux,nl,back,fallback_used)
      t0=t1
    end do

    write(*,'(*(g0))') 'LAREGW1_HISTORY_PASS|SPLIT=',trim(split_label(ih)),'|HISTORY=',trim(history_label(ih)), &
         '|STATES=',NSTEPS,'|FALLBACKS=',history_fallbacks,'|MAX_ABS_MASS=',history_max_mass, &
         '|FINAL_REV=',state%current_revision(),'|FINAL_T=',t0
  end subroutine run_history

  subroutine strict_first_sample(column,template,p,state,forcing,t0,t1,ok,mass,bex,bflux,status,route,nl,ir,back,fallback_used)
    type(fmr_logical_column_t),intent(in) :: column
    type(fmr_template_t),intent(in) :: template
    type(fmr_b110_physical_parameters_t),intent(inout) :: p
    type(kernel_committed_state_t),intent(inout) :: state
    type(fmr_b110_physical_forcing_t),intent(in) :: forcing
    real(real64),intent(in) :: t0,t1
    logical,intent(out) :: ok,fallback_used
    real(real64),intent(out) :: mass,bex,bflux
    integer,intent(out) :: status,nl,ir,back
    character(len=*),intent(out) :: route
    type(fmr_b110_physical_parameters_t) :: fallback_p
    class(transaction_state_t),allocatable :: before,after
    real(real64) :: rep_bound,fallback_tol,local_fallback_tol,rsum,rmax,abs_integrated,local_integrated
    integer :: bal_flags,head_flags,imax,failed_nl,failed_back
    integer(int64) :: rev_before,lineage_before
    real(real64) :: time_before,time_after
    logical :: got,time_ok,bound_ok,unchanged
    character(len=24) :: failure_class

    fallback_used=.false.
    p%total_balance_tolerance=original_total_tol

    rev_before=state%current_revision()
    lineage_before=state%current_lineage_id()
    call state%current_time(time_before,time_ok)
    call require(time_ok.and.same_bits(time_before,t0),'ROM1A pre-attempt committed time')
    call state%snapshot(before,got)
    call require(got,'ROM1A pre-attempt snapshot')
    call prospective_bound(state,p,rep_bound,bound_ok)
    call require(bound_ok.and.rep_bound>0.0_real64,'ROM1AR1 prospective representation bound')

    call sample_fresh(column,template,p,state,forcing,t0,t1,ok,mass,bex,bflux,status,route,nl,ir,back)
    if(ok)then
      if(allocated(before))deallocate(before)
      return
    end if

    ! R1 combines only the separately-qualified D2 mode-2 and R3D4 mode-5 policies.
    if(p%bottom_mode/=2 .and. p%bottom_mode/=5)then
      if(allocated(before))deallocate(before)
      return
    end if

    call state%current_time(time_after,time_ok)
    call require(time_ok.and.same_bits(time_after,time_before),'ROM1A failed first attempt time immutable')
    call require(state%current_revision()==rev_before,'ROM1A failed first attempt revision immutable')
    call require(state%current_lineage_id()==lineage_before,'ROM1A failed first attempt lineage immutable')
    call state%snapshot(after,got)
    call require(got,'ROM1A failed first attempt snapshot')
    unchanged=state_bits_equal(before,after)
    call require(unchanged,'ROM1A failed first attempt physical state immutable')

    failed_nl=nl;failed_back=back
    call diagnose_failed_interval(p,forcing,state,t0,t1,status,failed_nl,failed_back, &
         failure_class,bal_flags,head_flags,rmax,rsum,imax)
    abs_integrated=abs(rsum)*(t1-t0)
    local_integrated=abs(rmax)*(t1-t0)
    call require(ieee_is_finite(abs_integrated).and.abs_integrated<=rep_bound, &
         'ROM1AR1D3 total residual within pre-solve bound')

    fallback_tol=max(original_total_tol,rep_bound/(t1-t0))
    fallback_p=p
    fallback_p%total_balance_tolerance=fallback_tol

    select case(trim(failure_class))
    case('RETRY_TOTAL_ONLY')
      call require(bal_flags==0.and.head_flags==0,'ROM1AR1D3 total-only flag contract')
      call require(rmax<=p%compartment_balance_tolerance,'ROM1AR1D3 total-only local criterion unchanged')
      fallback_p%compartment_balance_tolerance=p%compartment_balance_tolerance
    case('RETRY_LOCAL_BALANCE')
      call require(bal_flags>0.and.head_flags==0,'ROM1AR1D3 local-only flag contract')
      call require(ieee_is_finite(local_integrated).and.local_integrated<=1.6e-15_real64, &
           'ROM1AR1D3 local residual within prior integrated allowance')
      local_fallback_tol=max(p%compartment_balance_tolerance,1.6e-15_real64/(t1-t0))
      fallback_p%compartment_balance_tolerance=local_fallback_tol
    case default
      call require(.false.,'ROM1AR1D3 failure class not authorized')
    end select

    call sample_fresh(column,template,fallback_p,state,forcing,t0,t1,ok,mass,bex,bflux,status,route,nl,ir,back)
    call require(ok,'ROM1AR1D3 qualified fallback reattempt')
    fallback_used=.true.

    write(*,'(*(g0))') 'LAREGW1_FALLBACK|HISTORY_STEP_T0=',t0,'|T1=',t1,'|BOTTOM_MODE=',p%bottom_mode, &
         '|CLASS=',trim(failure_class),'|BAL_FLAGS=',bal_flags,'|HEAD_FLAGS=',head_flags, &
         '|RMAX=',rmax,'|RSUM=',rsum,'|IMAX=',imax,'|REP_BOUND_CM=',rep_bound, &
         '|ABS_TOTAL_RESIDUAL_CM=',abs_integrated,'|LOCAL_INTEGRATED_CM=',local_integrated, &
         '|FALLBACK_CP_TOL=',fallback_p%compartment_balance_tolerance,'|FALLBACK_TOTAL_TOL=',fallback_tol, &
         '|FAILED_NL=',failed_nl,'|FAILED_BACKTRACK=',failed_back,'|ACCEPT_NL=',nl,'|ACCEPT_BACKTRACK=',back

    if(allocated(before))deallocate(before)
    if(allocated(after))deallocate(after)
  end subroutine strict_first_sample

  subroutine emit_state(ih,step,symbol,state,forcing,t0,t1,mass,bex,bflux,nl,back,fallback_used)
    integer,intent(in) :: ih,step,symbol,nl,back
    type(kernel_committed_state_t),intent(in) :: state
    type(fmr_b110_physical_forcing_t),intent(in) :: forcing
    real(real64),intent(in) :: t0,t1,mass,bex,bflux
    logical,intent(in) :: fallback_used
    class(transaction_state_t),allocatable :: snap
    logical :: got
    real(real64) :: total,upper,lower
    integer :: node

    call state%snapshot(snap,got)
    call require(got,'ROM1A state snapshot for output')
    select type(physical=>snap)
    type is(fmr_b110_physical_state_t)
      call metrics_from_physical(physical,total,upper,lower)
      call require(all(ieee_is_finite(physical%pressure_head)).and.all(ieee_is_finite(physical%water_content)), &
           'ROM1A finite full profiles')
      write(*,'(*(g0))') 'LAREGW1_STATE|SPLIT=',trim(split_label(ih)),'|HISTORY=',trim(history_label(ih)), &
           '|STEP=',step,'|REL_T=',real(step,real64)*step_dt,'|T=',t1,'|REV=',state%current_revision(), &
           '|SYMBOL=',trim(symbol_label(symbol)),'|BOTTOM_MODE=',merge(5,2,is_head_symbol(symbol)), &
           '|TOTAL_STORAGE=',total,'|UPPER_STORAGE=',upper,'|LOWER_STORAGE=',lower, &
           '|TOP_EXCHANGE=',forcing%top_flux*(t1-t0),'|BOTTOM_OUTWARD_EXCHANGE=',bex,'|BOTTOM_FLUX=',bflux, &
           '|MASS=',mass,'|NL=',nl,'|BACKTRACK=',back,'|FALLBACK=',fallback_used
      do node=1,numnod
        write(*,'(*(g0))') 'LAREGW1_NODE|SPLIT=',trim(split_label(ih)),'|HISTORY=',trim(history_label(ih)), &
             '|STEP=',step,'|NODE=',node,'|H=',physical%pressure_head(node),'|THETA=',physical%water_content(node)
      end do
    class default
      call require(.false.,'ROM1A expected B110 physical state')
    end select
    if(allocated(snap))deallocate(snap)
  end subroutine emit_state

  subroutine metrics_from_physical(physical,total,upper,lower)
    type(fmr_b110_physical_state_t),intent(in) :: physical
    real(real64),intent(out) :: total,upper,lower
    total=sum(physical%water_content(1:numnod)*dz(1:numnod))
    upper=sum(physical%water_content(1:4)*dz(1:4))
    lower=sum(physical%water_content(5:numnod)*dz(5:numnod))
    call require(ieee_is_finite(total).and.ieee_is_finite(upper).and.ieee_is_finite(lower),'ROM1A finite primary outputs')
  end subroutine metrics_from_physical

  subroutine require_current_time(state,expected)
    type(kernel_committed_state_t),intent(in) :: state
    real(real64),intent(in) :: expected
    real(real64) :: actual
    logical :: ok
    call state%current_time(actual,ok)
    call require(ok.and.same_bits(actual,expected),'ROM1A exact committed time progression')
  end subroutine require_current_time

  pure real(real64) function initial_se(ih) result(value)
    integer,intent(in) :: ih
    select case(ih)
    case(1); value=0.85_real64
    case(2); value=0.65_real64
    case(3); value=0.85_real64
    case(4); value=0.95_real64
    case(5); value=0.85_real64
    case(6); value=0.65_real64
    case default; value=-1.0_real64
    end select
  end function initial_se

  integer function history_symbol(ih,step) result(symbol)
    integer,intent(in) :: ih,step
    select case(ih)
    case(1)
      if(step<=24)then; symbol=SYM_FALL
      else if(step<=64)then; symbol=SYM_RISE
      else; symbol=SYM_HOLD; end if
    case(2)
      symbol=SYM_HOLD
    case(3)
      if(step<=256)then; symbol=SYM_TOP_PLUS
      else if(step<=512)then; symbol=SYM_HOLD
      else if(step<=768)then; symbol=SYM_TOP_MINUS
      else; symbol=SYM_HOLD; end if
    case(4)
      if(step<=256)then; symbol=SYM_FALL
      else if(step<=768)then; symbol=SYM_RISE
      else; symbol=SYM_HOLD; end if
    case(5)
      if(step<=256)then; symbol=SYM_RISE
      else if(step<=768)then; symbol=SYM_FALL
      else; symbol=SYM_HOLD; end if
    case(6)
      if(step<=256)then; symbol=SYM_COMBINED_RISE_PLUS
      else if(step<=512)then; symbol=SYM_HOLD
      else if(step<=768)then; symbol=SYM_COMBINED_FALL_MINUS
      else; symbol=SYM_HOLD; end if
    case default
      symbol=0
    end select
    call require(symbol>=SYM_HOLD.and.symbol<=SYM_COMBINED_FALL_MINUS,'LAREGW1 valid history symbol')
  end function history_symbol

  function history_label(ih) result(label)
    integer,intent(in) :: ih
    character(len=3) :: label
    write(label,'(A1,I2.2)') 'G',ih-1
  end function history_label

  pure function split_label(ih) result(label)
    integer,intent(in) :: ih
    character(len=9) :: label
    if(ih>=1.and.ih<=NHIST)then
      label='GW_STAGE_A'
    else
      label='INVALID  '
    end if
  end function split_label

  pure function symbol_label(symbol) result(label)
    integer,intent(in) :: symbol
    character(len=24) :: label
    select case(symbol)
    case(SYM_HOLD); label='HOLD'
    case(SYM_TOP_PLUS); label='TOP_PLUS'
    case(SYM_TOP_MINUS); label='TOP_MINUS'
    case(SYM_RISE); label='BOTTOM_HEAD_RISE'
    case(SYM_FALL); label='BOTTOM_HEAD_FALL'
    case(SYM_COMBINED_RISE_PLUS); label='COMBINED_RISE_PLUS'
    case(SYM_COMBINED_FALL_MINUS); label='COMBINED_FALL_MINUS'
    case default; label='UNKNOWN'
    end select
  end function symbol_label

  subroutine configure_symbol(symbol,h0,k0,qeq,p,forcing)
    integer,intent(in) :: symbol
    real(real64),intent(in) :: h0,k0,qeq
    type(fmr_b110_physical_parameters_t),intent(inout) :: p
    type(fmr_b110_physical_forcing_t),intent(inout) :: forcing
    p%total_balance_tolerance=original_total_tol
    forcing%top_head=0.0_real64
    forcing%bottom_flux=qeq
    forcing%bottom_head=h0
    select case(symbol)
    case(SYM_HOLD)
      p%bottom_mode=2;forcing%top_flux=qeq
    case(SYM_TOP_PLUS)
      p%bottom_mode=2;forcing%top_flux=qeq+0.01_real64*k0
    case(SYM_TOP_MINUS)
      p%bottom_mode=2;forcing%top_flux=qeq-0.01_real64*k0
    case(SYM_RISE)
      p%bottom_mode=5;forcing%top_flux=qeq;forcing%bottom_head=0.75_real64*h0
    case(SYM_FALL)
      p%bottom_mode=5;forcing%top_flux=qeq;forcing%bottom_head=1.25_real64*h0
    case(SYM_COMBINED_RISE_PLUS)
      p%bottom_mode=5;forcing%top_flux=qeq+0.01_real64*k0;forcing%bottom_head=0.75_real64*h0
    case(SYM_COMBINED_FALL_MINUS)
      p%bottom_mode=5;forcing%top_flux=qeq-0.01_real64*k0;forcing%bottom_head=1.25_real64*h0
    case default
      call require(.false.,'ROM1A configure known symbol')
    end select
  end subroutine configure_symbol

  logical function is_head_symbol(symbol)
    integer,intent(in) :: symbol
    is_head_symbol=symbol==SYM_RISE.or.symbol==SYM_FALL.or. &
         symbol==SYM_COMBINED_RISE_PLUS.or.symbol==SYM_COMBINED_FALL_MINUS
  end function is_head_symbol

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
    forcing%top_flux=qeq;forcing%bottom_flux=qeq;forcing%bottom_head=0.0_real64
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
    if(.not.ok)then
      if(candidate%ready())call backend%discard_reference_floor_candidate(candidate,diagnostics)
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
    call require(fmr_status==SW_SOLVE_RETRY_ADVISED,'ROM1A FMR failed status retry-advised')
    pset%parameter_set_id=p%parameter_set_id;pset%active_nodes=numnod
    allocate(pset%z(numnod),pset%dz(numnod),pset%node_distance(numnod))
    pset%z=p%z;pset%dz=p%dz;pset%node_distance=p%node_distance
    call initialize_b110_default_mvg_parameters(hp,p%cofgen)
    call bind_b110_default_mvg_provider(constitutive,hp,t1-t0)
    drainage=0.0_real64;irrigation=0.0_real64;root_sink=0.0_real64
    call bind_b110_source_sink_provider(source_sink,drainage,irrigation,root_sink)
    request%parameters=>pset;request%step_duration=t1-t0
    request%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX;request%boundary%bottom_mode=p%bottom_mode
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
    call state%snapshot(snap,got);call require(got,'ROM1A diagnostic snapshot')
    select type(physical=>snap)
    type is(fmr_b110_physical_state_t)
      request%base_state%active_nodes=physical%active_nodes
      allocate(request%base_state%pressure_head(numnod),request%base_state%water_content(numnod))
      request%base_state%pressure_head=physical%pressure_head;request%base_state%water_content=physical%water_content
      request%base_state%ponding_depth=physical%ponding_depth;request%base_state%groundwater_level=physical%groundwater_level
    class default
      call require(.false.,'ROM1A diagnostic B110 state')
    end select
    call bind_b110_serialized_legacy_context(request,context_ok);call require(context_ok,'ROM1A diagnostic context')
    call solver%solve(request,workspace,result)
    call require(result%status==SW_SOLVE_RETRY_ADVISED,'ROM1A direct retry advised')
    call require(trim(result%diagnostics%route)=='legacy-reference-retry','ROM1A direct retry route')
    call require(result%diagnostics%nonlinear_iterations==fmr_nl,'ROM1A direct/FMR nonlinear identity')
    call require(result%diagnostics%backtracking_attempts==fmr_back,'ROM1A direct/FMR backtracking identity')
    bal=count(workspace%richards%nonconverged_balance)
    head=count(workspace%richards%nonconverged_head)
    rsum=sum(workspace%richards%residual)
    rmax=maxval(abs(workspace%richards%residual))
    imax=maxloc(abs(workspace%richards%residual),dim=1)
    if(bal>0.and.head>0)then;class_name='RETRY_MIXED'
    else if(bal>0)then;class_name='RETRY_LOCAL_BALANCE'
    else if(head>0)then;class_name='RETRY_HEAD'
    else if(ieee_is_finite(rsum).and.ieee_is_finite(rmax).and.rmax<=p%compartment_balance_tolerance.and.abs(rsum)>original_total_tol)then
      class_name='RETRY_TOTAL_ONLY'
    else;class_name='RETRY_OTHER';end if
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

  subroutine initialize_parameters(p)
    type(fmr_b110_physical_parameters_t),intent(out) :: p
    real(real64) :: tr,ts,alpha,nn,ks,lam,mm
    integer :: k
    tr=0.02_real64;ts=0.427494_real64;alpha=0.021659_real64
    nn=1.734737_real64;ks=31.225016_real64;lam=0.98087_real64
    mm=1.0_real64-1.0_real64/nn
    p%parameter_set_id=971001_int64;p%active_nodes=numnod
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

  subroutine initialize_state(p,se_anchor,h0,k0,state)
    type(fmr_b110_physical_parameters_t),intent(in) :: p
    real(real64),intent(in) :: se_anchor
    real(real64),intent(out) :: h0,k0
    type(fmr_b110_physical_state_t),intent(out) :: state
    type(b110_default_mvg_parameters_t),target :: hp
    type(b110_default_mvg_provider_t) :: provider
    real(real64) :: m,heads(numnod),water(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod)
    m=1.0_real64-1.0_real64/p%cofgen(6,1)
    h0=-(se_anchor**(-1.0_real64/m)-1.0_real64)**(1.0_real64/p%cofgen(6,1))/p%cofgen(4,1)
    heads=h0
    call initialize_b110_default_mvg_parameters(hp,p%cofgen)
    call bind_b110_default_mvg_provider(provider,hp,seed_dt)
    call provider%evaluate(heads,water,conductivity,capacity,dkdh)
    k0=conductivity(1)
    call require(k0>0.0_real64.and.all(ieee_is_finite(water)),'ROM1A finite seed')
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
    tmpl%template_id=971001_int64;tmpl%physics_topology_id=971002_int64
    tmpl%vertical_layout_id=971003_int64;tmpl%state_layout_id=971004_int64;tmpl%solver_interface_id=971005_int64
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
      write(*,'(A,1X,A)') 'LAREGW1_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_lare_rs1_gw_library