program test_fpe_elastic65_mode7_csafe_binding
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_transaction_reference, only: TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, &
       kernel_result_t, kernel_candidate_state_t, kernel_diagnostics_t
  use mod_fmr_checkpoint_orchestrator, only: fmr_capture_checkpoint
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, &
       FMR_BACKEND_SERIALIZED_REFERENCE, FMR_OPTIONAL_STATE_LAYOUT_BASE, &
       FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_b110_physical_state_t, &
       fmr_serialized_reference_backend_t, fmr_serialized_physical_observation_t, &
       fmr_new_b110_temporal_indicator_committed_state, prepare_fmr_b110_default_mvg
  use mod_b110_default_mvg_provider, only: b110_default_mvg_provider_t, bind_b110_default_mvg_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_fmr_mode7_temporal_head_envelope, only: FMR_MODE7_HEAD_ALPHA
  implicit none

  integer, parameter :: N=16
  real(real64), parameter :: H0=-75.0_real64, DT=0.01_real64
  real(real64), parameter :: TOL=1.0e-10_real64, PERT=1.0e-6_real64
  integer(int64), parameter :: ID=650065_int64

  type(fmr_b110_physical_parameters_t), target :: p
  type(fmr_b110_physical_forcing_t) :: forcing
  type(fmr_b110_physical_state_t) :: state
  type(fmr_logical_column_t) :: column
  type(fmr_template_t) :: template
  type(kernel_committed_state_t) :: committed
  type(kernel_checkpoint_t) :: checkpoint
  type(kernel_result_t) :: result
  type(kernel_candidate_state_t) :: candidate
  type(kernel_diagnostics_t) :: diagnostics
  type(fmr_serialized_reference_backend_t) :: backend
  type(fmr_serialized_physical_observation_t) :: obs
  type(fixed_flux_top_boundary_provider_t), target :: top
  type(b110_default_mvg_provider_t) :: provider
  type(canonical_numerical_config_t) :: config
  real(real64) :: heads(N),water(N),cond(N),cap(N),dk(N),previous(N)
  real(real64) :: qeq,budget_probe,budget_retry,expected
  logical :: ok

  call init_parameters(p)
  call prepare_fmr_b110_default_mvg(p,ok)
  call require(ok,'prepared parameters')

  heads=H0
  call bind_b110_default_mvg_provider(provider,p%prepared_default_mvg,DT)
  call provider%evaluate(heads,water,cond,cap,dk)
  call require(all(ieee_is_finite(water)).and.all(ieee_is_finite(cond)),'initial constitutive')
  qeq=-cond(1)

  state%active_nodes=N
  allocate(state%pressure_head(N),state%water_content(N))
  state%pressure_head=heads
  state%water_content=water
  state%ponding_depth=0.0_real64
  state%groundwater_level=-2.0_real64
  previous=0.0_real64
  call fmr_new_b110_temporal_indicator_committed_state(committed,ID,state,0.0_real64,ok,previous)
  call require(ok,'temporal committed state')
  call fmr_capture_checkpoint(committed,checkpoint,ok)
  call require(ok,'checkpoint')

  call init_column(column,template)
  call init_forcing(forcing,qeq+PERT)
  call backend%initialize(top)

  ! Probe with a deliberately generous caller-owned physical head budget.
  budget_probe=100.0_real64
  call init_config(config,budget_probe,0)
  call backend%run_trial(column,template,p,committed,forcing,config,0.0_real64,DT,checkpoint, &
       result,candidate,diagnostics,trusted_prepared_parameters=.true.)
  obs=backend%observation()
  call require(obs%temporal_indicator_available,'probe indicator available')
  call require(obs%temporal_certificate_available,'probe certificate available')
  expected=FMR_MODE7_HEAD_ALPHA*obs%temporal_head_inf_bound/budget_probe
  call require(same_real(obs%temporal_normalized_indicator,expected),'A1 exact ELASTIC61 normalization')
  call require(same_real(obs%temporal_head_budget,budget_probe),'A1 caller budget preserved')
  call require(result%status==0,'probe accepted')
  write(*,'(A,ES24.16E3)')'ELASTIC65_PROBE_BINF=',obs%temporal_head_inf_bound
  write(*,'(A,ES24.16E3)')'ELASTIC65_PROBE_NORMALIZED=',obs%temporal_normalized_indicator
  write(*,'(A)')'F_PE_ELASTIC65_A1_MODE7_NORMALIZATION=PASS'

  ! Force the first dt to reject. With this simple free-drainage perturbation
  ! the defect bound contracts under refinement; choose a physical budget just
  ! below the first-attempt estimated error and allow the existing transaction
  ! path to refine/recheck.
  budget_retry=0.75_real64*FMR_MODE7_HEAD_ALPHA*obs%temporal_head_inf_bound
  call require(budget_retry>0.0_real64,'positive retry budget')
  call init_config(config,budget_retry,8)
  call backend%run_trial(column,template,p,committed,forcing,config,0.0_real64,DT,checkpoint, &
       result,candidate,diagnostics,trusted_prepared_parameters=.true.)
  obs=backend%observation()
  call require(result%status==0,'retry path accepted')
  call require(diagnostics%retries>=1,'at least one retry')
  call require(diagnostics%temporal_rejections>=1,'first temporal rejection')
  call require(result%accepted_dt<DT,'accepted refined dt')
  call require(obs%temporal_certificate_available,'accepted certificate available')
  call require(obs%temporal_normalized_indicator<=1.0_real64,'accepted normalized certificate')
  call require(diagnostics%mass_rejections==0,'mass gate independently green')
  write(*,'(A,I0,A,ES24.16E3)')'ELASTIC65_RETRY_COUNT=',diagnostics%retries, &
       ':ACCEPTED_DT=',result%accepted_dt
  write(*,'(A)')'F_PE_ELASTIC65_A2_REFINE_RECHECK=PASS'
  write(*,'(A)')'F_PE_ELASTIC65_A4_MASS_INDEPENDENT=PASS'

  ! Missing budget must fail closed through the existing model-certificate path.
  call init_config(config,0.0_real64,1)
  config%model_temporal_indicator_budget_available=.false.
  call backend%run_trial(column,template,p,committed,forcing,config,0.0_real64,DT,checkpoint, &
       result,candidate,diagnostics,trusted_prepared_parameters=.true.)
  call require(result%status/=0,'missing budget rejected')
  call require(diagnostics%temporal_certificate_unavailable_rejections>=1,'missing budget unavailable counter')
  write(*,'(A)')'F_PE_ELASTIC65_A3_MISSING_BUDGET_FAIL_CLOSED=PASS'

  ! swkimpl=1 remains outside the admitted mode-7 indicator envelope.
  p%swkimpl=1
  call prepare_fmr_b110_default_mvg(p,ok)
  call require(ok,'swkimpl1 prepared')
  call init_config(config,budget_probe,1)
  call backend%run_trial(column,template,p,committed,forcing,config,0.0_real64,DT,checkpoint, &
       result,candidate,diagnostics,trusted_prepared_parameters=.true.)
  call require(result%status/=0,'swkimpl1 rejected')
  call require(diagnostics%temporal_certificate_unavailable_rejections>=1 .or. diagnostics%solver_rejections>=1, &
       'swkimpl1 fail closed')
  write(*,'(A)')'F_PE_ELASTIC65_A7_SWKIMPL1_FAIL_CLOSED=PASS'

  write(*,'(A)')'F_PE_ELASTIC65=PASS'

contains

  subroutine init_parameters(q)
    type(fmr_b110_physical_parameters_t),intent(out)::q
    integer::k
    q%parameter_set_id=ID
    q%active_nodes=N
    allocate(q%z(N),q%dz(N),q%node_distance(N),q%cofgen(24,N))
    do k=1,N
      q%dz(k)=10.0_real64
      q%z(k)=-(real(k,real64)-0.5_real64)*10.0_real64
      q%node_distance(k)=10.0_real64
      q%cofgen(:,k)=0.0_real64
      q%cofgen(1,k)=0.032_real64;q%cofgen(2,k)=0.423_real64;q%cofgen(3,k)=4.75_real64
      q%cofgen(4,k)=0.0135_real64;q%cofgen(5,k)=0.365_real64;q%cofgen(6,k)=1.455_real64
      q%cofgen(7,k)=1.0_real64-1.0_real64/q%cofgen(6,k);q%cofgen(8,k)=q%cofgen(4,k)
      q%cofgen(9,k)=0.0_real64;q%cofgen(10,k)=q%cofgen(3,k);q%cofgen(11,k)=0.999_real64
      q%cofgen(12,k)=0.99_real64*q%cofgen(3,k);q%cofgen(22,k)=-1.0e6_real64;q%cofgen(23,k)=1.0e-12_real64
    end do
    q%bottom_mode=7;q%swkimpl=0;q%swkmean=1;q%swsophy=0
    q%max_iterations=32;q%max_backtracking=12;q%min_step_duration=1.0e-10_real64
    q%compartment_balance_tolerance=TOL;q%total_balance_tolerance=TOL
    q%head_abs_tolerance=TOL;q%head_rel_tolerance=TOL;q%ponding_tolerance=TOL
    q%root_extraction_active=.false.;q%macropore_active=.false.;q%snow_active=.false.
    q%hysteresis_active=.false.;q%tabulated_hydraulics_active=.false.;q%direct_retention_active=.false.
    q%elasticity_active=.false.;q%frost_active=.false.;q%soil_temperature_active=.false.
    q%drainage_response_active=.false.;q%drainage_qbot_smooth_freatic_projection=.false.
  end subroutine

  subroutine init_forcing(f,qtop)
    type(fmr_b110_physical_forcing_t),intent(out)::f
    real(real64),intent(in)::qtop
    f%top_flux=qtop;f%top_head=H0
    f%bottom_flux=777777.0_real64;f%bottom_head=-999999.0_real64
    allocate(f%drainage_flux_by_level(1,N),f%subsurface_irrigation_source(N),f%root_extraction_sink(N))
    f%drainage_flux_by_level=0.0_real64
    f%subsurface_irrigation_source=0.0_real64
    f%root_extraction_sink=0.0_real64
  end subroutine

  subroutine init_column(c,t)
    type(fmr_logical_column_t),intent(out)::c
    type(fmr_template_t),intent(out)::t
    t%template_id=650001_int64;t%physics_topology_id=650002_int64;t%vertical_layout_id=650003_int64
    t%state_layout_id=650004_int64;t%solver_interface_id=650005_int64
    t%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_BASE
    t%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
    t%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    c%column_id=ID;c%template_id=t%template_id;c%parameter_ref=1_int64;c%state_handle=1_int64
    c%forcing_handle=1_int64;c%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine

  subroutine init_config(c,budget,max_retries)
    type(canonical_numerical_config_t),intent(out)::c
    real(real64),intent(in)::budget
    integer,intent(in)::max_retries
    c%transaction%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE
    c%transaction%temporal_tolerance=0.0_real64
    c%transaction%mass_tolerance=TOL
    c%transaction%retry_scale=0.5_real64
    c%transaction%max_retries=max_retries
    c%max_committed_substeps=32
    c%progress_tolerance=0.0_real64
    c%model_temporal_indicator_budget_available=.true.
    c%model_temporal_indicator_budget=budget
  end subroutine

  pure logical function same_real(a,b) result(same)
    real(real64),intent(in)::a,b
    real(real64)::scale
    scale=max(1.0_real64,abs(a),abs(b))
    same=abs(a-b)<=32.0_real64*epsilon(1.0_real64)*scale
  end function

  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition)then
      write(*,'(A,1X,A)')'F_PE_ELASTIC65_FAIL',trim(label)
      error stop 1
    end if
  end subroutine
end program test_fpe_elastic65_mode7_csafe_binding
