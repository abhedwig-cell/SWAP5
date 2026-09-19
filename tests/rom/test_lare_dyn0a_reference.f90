program test_lare_dyn0a_reference
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

  integer, parameter :: NHIST=24, NSTEPS=1024
  integer, parameter :: FORCE_EQ=1, FORCE_WET=2, FORCE_DRY=3, FORCE_WET_DRY=4
  integer, parameter :: BOTTOM_FIXED_FLUX=1, BOTTOM_FREE_DRAINAGE=2
  real(real64), parameter :: seed_dt=0.0016_real64
  integer, parameter :: seed_intervals=2
  real(real64), parameter :: step_dt=0.0008_real64
  real(real64), parameter :: original_total_tol=1.0e-12_real64
  real(real64), parameter :: hard_mass_gate=1.0e-12_real64
  integer(int64), parameter :: column_id=971001_int64

  integer :: ih,total_states,total_fallbacks,bottom_filter,active_histories,env_status
  real(real64) :: max_abs_mass
  character(len=32) :: filter_raw

  call require(abs(sum(dz(1:numnod))-160.0_real64)<=1.0e-12_real64,'LAREDYN0R depth frozen')
  bottom_filter=0
  filter_raw=''
  call get_environment_variable('LARE_DYN0A_BOTTOM_FILTER',filter_raw,status=env_status)
  if(env_status==0.and.len_trim(filter_raw)>0)then
    read(filter_raw,*,iostat=env_status)bottom_filter
    call require(env_status==0.and.bottom_filter>=0.and.bottom_filter<=2,'LAREDYN0R valid bottom filter')
  end if

  total_states=0;total_fallbacks=0;max_abs_mass=0.0_real64;active_histories=0

  do ih=1,NHIST
    if(bottom_filter==0.or.bottom_kind(ih)==bottom_filter)then
      call run_history(ih,total_states,total_fallbacks,max_abs_mass)
      active_histories=active_histories+1
    end if
  end do

  call require(total_states==active_histories*NSTEPS,'LAREDYN0R exact library state count')
  write(*,'(A,I0)') 'LAREDYN0R_HISTORY_COUNT=',active_histories
  write(*,'(A,I0)') 'LAREDYN0R_BOTTOM_FILTER=',bottom_filter
  write(*,'(A,I0)') 'LAREDYN0R_STEPS_PER_HISTORY=',NSTEPS
  write(*,'(A,I0)') 'LAREDYN0R_STATE_COUNT=',total_states
  write(*,'(A,I0)') 'LAREDYN0R_TOTAL_FALLBACK_COUNT=',total_fallbacks
  write(*,'(*(g0))') 'LAREDYN0R_MAX_ABS_MASS=',max_abs_mass
  write(*,'(A,I0)') 'LAREDYN0R_ACTIVE_NODES=',numnod
  write(*,'(*(g0))') 'LAREDYN0R_PROFILE_DEPTH_CM=',sum(dz(1:numnod))
  write(*,'(A)') 'LAREDYN0R_EXECUTION_COMPLETE=PASS'

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
    integer :: step,status,nl,ir,back
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
    call require(ok.and.state%ready(),'LAREDYN0R initial committed state')

    p%bottom_mode=2
    p%total_balance_tolerance=original_total_tol
    call seed_steady(column,template,p,state,forcing,qeq,ok)
    call require(ok,'LAREDYN0R gravity-consistent seed')

    t0=real(seed_intervals,real64)*seed_dt
    history_fallbacks=0
    history_max_mass=0.0_real64

    do step=1,NSTEPS
      call configure_case(ih,step,h0,k0,qeq,p,forcing)
      t1=real(seed_intervals,real64)*seed_dt+real(step,real64)*step_dt
      call strict_first_sample(column,template,p,state,forcing,t0,t1,ok,mass,bex,bflux,status,route,nl,ir,back,fallback_used)
      call require(ok,'LAREDYN0R accepted history step')
      call require(abs(mass)<=hard_mass_gate,'LAREDYN0R hard mass gate')
      call require(state%current_revision()==int(seed_intervals+step,int64),'LAREDYN0R exact revision progression')
      call require_current_time(state,t1)
      history_max_mass=max(history_max_mass,abs(mass))
      max_abs_mass=max(max_abs_mass,abs(mass))
      if(fallback_used)then
        history_fallbacks=history_fallbacks+1
        total_fallbacks=total_fallbacks+1
      end if
      total_states=total_states+1
      call emit_state(ih,step,state,forcing,t0,t1,mass,bex,bflux,nl,back,fallback_used)
      t0=t1
    end do

    write(*,'(*(g0))') 'LAREDYN0R_HISTORY_PASS|CASE=',trim(case_label(ih)),'|SE0=',initial_se(ih), &
         '|FORCING=',trim(forcing_label(forcing_kind(ih))),'|BOTTOM=',trim(bottom_label(bottom_kind(ih))), &
         '|STATES=',NSTEPS,'|FALLBACKS=',history_fallbacks,'|MAX_ABS_MASS=',history_max_mass, &
         '|FINAL_REV=',state%current_revision(),'|FINAL_T=',t0
  end subroutine run_history

  subroutine strict_first_sample(column,template,p,state,forcing,t0,t1,ok,mass,bex,bflux,status,route,nl,ir,back,fallback_used)
    type(fmr_logical_column_t),intent(in) :: column
    type(fmr_template_t),intent(in) :: template
    type(fmr_b110_physical_parameters_t),intent(inout) :: p