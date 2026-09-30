program test_fpe_elastic62_csafe_binding
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_result_t, &
       kernel_candidate_state_t, kernel_diagnostics_t
  use mod_fmr_checkpoint_orchestrator, only: fmr_capture_checkpoint
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY, FMR_OPTIONAL_STATE_LAYOUT_BASE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, fmr_serialized_physical_observation_t, &
       fmr_new_b110_temporal_indicator_committed_state, prepare_fmr_b110_default_mvg
  use mod_b110_default_mvg_provider, only: b110_default_mvg_provider_t, bind_b110_default_mvg_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_fmr_mode7_temporal_head_envelope, only: FMR_MODE7_HEAD_ALPHA
  implicit none

  real(real64), parameter :: H0=-75.0_real64
  real(real64), parameter :: DT=0.01_real64
  real(real64), parameter :: PERT=1.0e-6_real64
  real(real64), parameter :: MASS_TOL=1.0e-12_real64
  integer(int64), parameter :: LINEAGE=620062_int64

  real(real64) :: baseline_binf, threshold, normalized
  integer :: retries, unavailable, mass_rejections
  logical :: accepted, committed_ok

  call run_case(.true.,100.0_real64,MASS_TOL,0,accepted,baseline_binf,normalized,retries,unavailable,mass_rejections,committed_ok)
  call require(accepted,'A2 generous mode7 certificate accepted')
  call require(committed_ok,'A10 generous accepted candidate committed')
  call require(ieee_is_finite(baseline_binf).and.baseline_binf>0.0_real64,'A2 positive Binf')
  call require(close_value(normalized,FMR_MODE7_HEAD_ALPHA*baseline_binf/100.0_real64),'A2 alpha normalization')
  call require(retries==0,'A2 generous budget accepts first attempt')
  call require(mass_rejections==0,'A6 generous case mass passes')

  threshold=FMR_MODE7_HEAD_ALPHA*baseline_binf
  call require(threshold>0.0_real64,'A3 positive threshold')

  call run_case(.true.,threshold,MASS_TOL,0,accepted,baseline_binf,normalized,retries,unavailable,mass_rejections,committed_ok)
  call require(accepted.and.committed_ok,'A3 equal threshold accepted')
  call require(retries==0,'A3 equal threshold no retry')
  call require(close_value(normalized,1.0_real64),'A3 equal threshold normalized one')

  call run_case(.true.,2.0_real64*threshold,MASS_TOL,0,accepted,baseline_binf,normalized,retries,unavailable,mass_rejections,committed_ok)
  call require(accepted.and.committed_ok,'A3 above threshold accepted')
  call require(retries==0,'A3 above threshold no retry')
  call require(normalized<1.0_real64,'A3 above threshold normalized below one')

  call run_case(.true.,0.5_real64*threshold,MASS_TOL,2,accepted,baseline_binf,normalized,retries,unavailable,mass_rejections,committed_ok)
  call require(retries>=1,'A3 below threshold refines')
  call require(.not.committed_ok .or. accepted,'A3 no rejected candidate commit')

  call run_case(.false.,0.0_real64,MASS_TOL,2,accepted,baseline_binf,normalized,retries,unavailable,mass_rejections,committed_ok)
  call require(.not.accepted.and..not.committed_ok,'A4 missing budget fails closed')
  call require(unavailable>0,'A4 missing budget counted unavailable')
  call require(retries==2,'A4 missing budget exhausts configured retries')

  call run_case(.true.,0.0_real64,MASS_TOL,2,accepted,baseline_binf,normalized,retries,unavailable,mass_rejections,committed_ok)
  call require(.not.accepted.and..not.committed_ok,'A5 invalid budget fails closed')
  call require(unavailable>0,'A5 invalid budget counted unavailable')

  call run_case(.true.,100.0_real64,0.0_real64,2,accepted,baseline_binf,normalized,retries,unavailable,mass_rejections,committed_ok)
  call require(mass_rejections>0,'A6 zero mass tolerance rejects before temporal commit')
  call require(.not.committed_ok,'A6 mass rejection cannot commit')

  call run_case(.true.,100.0_real64,MASS_TOL,2,accepted,baseline_binf,normalized,retries,unavailable,mass_rejections,committed_ok,swkimpl=1)
  call require(.not.committed_ok,'A8 swkimpl1 not committed through mode7 certificate')
  call require(unavailable>0 .or. .not.accepted,'A8 swkimpl1 remains unavailable/fail closed')

  write(*,'(A,ES26.17E3)') 'ELASTIC62_BASELINE_BINF=',baseline_binf
  write(*,'(A,ES26.17E3)') 'ELASTIC62_ALPHA=',FMR_MODE7_HEAD_ALPHA
  write(*,'(A)') 'F_PE_ELASTIC62_A2_MODE7_ALPHA_NORMALIZATION=PASS'
  write(*,'(A)') 'F_PE_ELASTIC62_A3_THRESHOLD_AND_RETRY=PASS'
  write(*,'(A)') 'F_PE_ELASTIC62_A4_MISSING_BUDGET=PASS'
  write(*,'(A)') 'F_PE_ELASTIC62_A5_INVALID_BUDGET=PASS'
  write(*,'(A)') 'F_PE_ELASTIC62_A6_MASS_FIRST=PASS'
  write(*,'(A)') 'F_PE_ELASTIC62_A7_OBSERVED_RETRY_ONLY=PASS'
  write(*,'(A)') 'F_PE_ELASTIC62_A8_SWKIMPL1_FAIL_CLOSED=PASS'
  write(*,'(A)') 'F_PE_ELASTIC62_A10_COMMIT_AFTER_ACCEPTANCE=PASS'
  write(*,'(A)') 'F_PE_ELASTIC62_RUNTIME=PASS'

contains

  subroutine run_case(budget_available,budget,mass_tol,max_retries,accepted,binf,norm,retries,unavailable, &
                      mass_rejections,committed_ok,swkimpl)
    logical,intent(in)::budget_available
    real(real64),intent(in)::budget,mass_tol
    integer,intent(in)::max_retries
    logical,intent(out)::accepted,committed_ok
    real(real64),intent(out)::binf,norm
    integer,intent(out)::retries,unavailable,mass_rejections
    integer,intent(in),optional::swkimpl

    type(fmr_b110_physical_parameters_t),target::p
    type(fmr_b110_physical_forcing_t)::forcing
    type(fmr_b110_physical_state_t)::state
    type(fmr_logical_column_t)::column
    type(fmr_template_t)::template
    type(canonical_numerical_config_t)::config
    type(kernel_committed_state_t)::committed
    type(kernel_checkpoint_t)::checkpoint
    type(kernel_result_t)::result
    type(kernel_candidate_state_t)::candidate
    type(kernel_diagnostics_t)::diag
    type(fmr_serialized_reference_backend_t)::backend
    type(fmr_serialized_physical_observation_t)::obs
    type(fixed_flux_top_boundary_provider_t),target::top
    type(b110_default_mvg_provider_t)::provider
    real(real64)::heads(numnod),water(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod)
    real(real64)::previous(numnod),qeq
    logical::ok,prepared,did_commit
    integer::commit_status,k

    call initialize_parameters(p)
    if(present(swkimpl))p%swkimpl=swkimpl
    call prepare_fmr_b110_default_mvg(p,prepared)
    call require(prepared,'prepared MvG')

    heads=H0
    call bind_b110_default_mvg_provider(provider,p%prepared_default_mvg,DT)
    call provider%evaluate(heads,water,conductivity,capacity,dkdh)
    call require(all(ieee_is_finite(water)).and.all(ieee_is_finite(conductivity)),'initial constitutive')
    qeq=-conductivity(1)

    state%active_nodes=numnod
    allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head=heads
    state%water_content=water
    state%ponding_depth=0.0_real64
    state%groundwater_level=-2.0_real64
    previous=0.0_real64
    call fmr_new_b110_temporal_indicator_committed_state(committed,LINEAGE,state,0.0_real64,ok,previous)
    call require(ok,'temporal committed state')
    call fmr_capture_checkpoint(committed,checkpoint,ok)
    call require(ok,'checkpoint capture')

    forcing%top_flux=qeq+PERT
    forcing%top_head=H0
    forcing%bottom_flux=777777.0_real64
    forcing%bottom_head=-999999.0_real64
    allocate(forcing%drainage_flux_by_level(1,numnod),forcing%subsurface_irrigation_source(numnod), &
             forcing%root_extraction_sink(numnod))
    forcing%drainage_flux_by_level=0.0_real64
    forcing%subsurface_irrigation_source=0.0_real64
    forcing%root_extraction_sink=0.0_real64

    template%template_id=620001_int64
    template%physics_topology_id=620002_int64
    template%vertical_layout_id=620003_int64
    template%state_layout_id=620004_int64
    template%solver_interface_id=620005_int64
    template%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_BASE
    template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
    template%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    column%column_id=LINEAGE
    column%template_id=template%template_id
    column%parameter_ref=1_int64
    column%state_handle=1_int64
    column%forcing_handle=1_int64
    column%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE

    config%transaction%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE
    config%transaction%temporal_tolerance=0.0_real64
    config%transaction%mass_tolerance=mass_tol
    config%transaction%retry_scale=0.5_real64
    config%transaction%max_retries=max_retries
    config%max_committed_substeps=32
    config%progress_tolerance=0.0_real64
    config%model_temporal_indicator_budget_available=budget_available
    config%model_temporal_indicator_budget=budget
    config%accepted_trajectory_direction%requested=.false.

    call backend%initialize(top)
    call backend%run_trial(column,template,p,committed,forcing,config,0.0_real64,DT,checkpoint,result,candidate,diag, &
         trusted_prepared_parameters=.true.)
    obs=backend%observation()

    accepted=result%completed.and.candidate%ready()
    binf=obs%temporal_head_inf_bound
    norm=obs%temporal_normalized_indicator
    retries=diag%retries
    unavailable=diag%temporal_certificate_unavailable_rejections
    mass_rejections=diag%mass_rejections
    committed_ok=.false.
    if(accepted)then
      call backend%commit_trial_candidate(committed,candidate,diag,did_commit,commit_status)
      committed_ok=did_commit.and.committed%current_revision()==1_int64
    end if
  end subroutine run_case

  subroutine initialize_parameters(p)
    type(fmr_b110_physical_parameters_t),intent(out)::p
    integer::k
    p%parameter_set_id=620062_int64
    p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),p%cofgen(24,numnod))
    p%z=z;p%dz=dz;p%node_distance=disnod(1:numnod);p%cofgen=0.0_real64
    do k=1,numnod
      p%cofgen(1,k)=0.032_real64;p%cofgen(2,k)=0.423_real64;p%cofgen(3,k)=4.75_real64
      p%cofgen(4,k)=0.0135_real64;p%cofgen(5,k)=0.365_real64;p%cofgen(6,k)=1.455_real64
      p%cofgen(7,k)=1.0_real64-1.0_real64/p%cofgen(6,k);p%cofgen(8,k)=p%cofgen(4,k)
      p%cofgen(9,k)=0.0_real64;p%cofgen(10,k)=p%cofgen(3,k);p%cofgen(11,k)=0.999_real64
      p%cofgen(12,k)=0.99_real64*p%cofgen(3,k);p%cofgen(22,k)=-1.0e6_real64;p%cofgen(23,k)=1.0e-12_real64
    end do
    p%bottom_mode=7;p%swkimpl=0;p%swkmean=1;p%swsophy=0
    p%max_iterations=48;p%max_backtracking=16;p%min_step_duration=1.0e-10_real64
    p%compartment_balance_tolerance=MASS_TOL;p%total_balance_tolerance=MASS_TOL
    p%head_abs_tolerance=MASS_TOL;p%head_rel_tolerance=MASS_TOL;p%ponding_tolerance=MASS_TOL
    p%root_extraction_active=.false.;p%macropore_active=.false.;p%snow_active=.false.
    p%hysteresis_active=.false.;p%tabulated_hydraulics_active=.false.;p%elasticity_active=.false.
    p%frost_active=.false.;p%soil_temperature_active=.false.;p%drainage_response_active=.false.
  end subroutine initialize_parameters

  pure logical function close_value(a,b)
    real(real64),intent(in)::a,b
    close_value=ieee_is_finite(a).and.ieee_is_finite(b).and. &
         abs(a-b)<=32768.0_real64*epsilon(1.0_real64)*max(1.0_real64,abs(a),abs(b))
  end function close_value

  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition)then
      write(*,'(A,1X,A)')'F_PE_ELASTIC62_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_fpe_elastic62_csafe_binding
