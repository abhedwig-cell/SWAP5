program test_fapp09_ribasim_external_surface_water_profile
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan, ieee_is_finite
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_EXTERNAL_FULL_HALF
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_candidate_state_t, &
       kernel_result_t, kernel_diagnostics_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_NUMERICAL_CONTINUATION_NONE, FMR_OPTIONAL_STATE_LAYOUT_BASE, &
       FMR_OPTIONAL_STATE_LAYOUT_FIXED_WEIR_SURFACE_WATER
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, &
       fmr_b110_fixed_weir_surface_water_state_t, fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_serialized_reference_backend_t, fmr_serialized_physical_observation_t, fmr_new_b110_committed_state, &
       fmr_new_b110_fixed_weir_surface_water_committed_state, prepare_fmr_b110_default_mvg, &
       FMR_TOP_SURFACE_FORMULATION_UNIFIED_CV
  use mod_fmr_drainage_response_binding, only: FMR_DRAIN_VARIANT_EXTENDED_SIGNED
  use mod_drainage_extended_exchange, only: EXT_DRAIN_TUBE, EXT_DRAIN_TOP_NONE
  use mod_fmr_surface_water_head_forcing_adapter, only: fmr_surface_water_head_forcing_materializer_t, &
       FMR_SW_HEAD_FORCING_OK, FMR_SW_HEAD_FORCING_INVALID_REQUEST, FMR_SW_HEAD_FORCING_PROFILE_NOT_ADMITTED, &
       FMR_SW_HEAD_FORCING_COMPETING_DRAINAGE_INPUT, FMR_SW_HEAD_FORCING_NONFINITE_HEAD
  use mod_fmr_surface_water_swap_participant, only: fmr_surface_water_swap_participant_t, fmr_surface_water_trial_t, &
       fmr_surface_water_external_profile_admitted, FMR_SW_PARTICIPANT_OK, &
       FMR_SW_PARTICIPANT_ORIGIN_DRIFT, FMR_SW_PARTICIPANT_EXCHANGE_MISMATCH
  use mod_fmr_surface_water_component_receipt, only: fmr_surface_water_component_receipt_t
  use mod_fmr04_fixed_top_provider, only: fmr04_fixed_flux_top_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  implicit none

  real(real64), parameter :: t0=9123.125_real64
  real(real64), parameter :: t1=9123.375_real64
  real(real64), parameter :: duration=t1-t0
  real(real64), parameter :: initial_head=-123.0_real64
  real(real64), parameter :: initial_gwl=-2.25_real64
  real(real64), parameter :: signed_rate=1.0e-2_real64
  real(real64), parameter :: exchange_tol=1.0e-12_real64
  integer(int64), parameter :: column_id=49009_int64
  character(len=32) :: mode

  call get_command_argument(1,mode)

  call verify_materializer_guards()
  if (trim(mode)=='transition'.or.trim(mode)=='transition-characterize') call verify_transition_scope()
  call verify_owner_xor()
  call verify_positive_recomposition_and_commit()
  if (trim(mode)/='preservation') then
    call verify_external_top_observation()
    if (trim(mode)/='characterize'.and.trim(mode)/='transition-characterize'.and.trim(mode)/='unified-cv') &
         call verify_external_top_component_transaction()
  else
    call verify_default_off_capability()
  end if
  call verify_negative_commit()
  call verify_stale_origin()
  write(*,'(A)') 'FAPP09_RIBASIM_EXTERNAL_SURFACE_WATER_PROFILE=PASS'

contains

  subroutine verify_transition_scope()
    type(kernel_committed_state_t) :: committed
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    type(fmr_b110_physical_parameters_t) :: parameters, unsupported
    type(fmr_b110_physical_forcing_t) :: base
    type(canonical_numerical_config_t) :: config
    logical :: prepared

    call initialize_case(committed,column,template,parameters,base,config,signed_rate)
    call require(parameters%near_saturation_transition_width_cm==0.2_real64, &
         'transition scope fixture is opt-in')
    unsupported=parameters
    unsupported%bottom_mode=-2
    call prepare_fmr_b110_default_mvg(unsupported,prepared)
    call require(.not.prepared,'transition law rejects unqualified lower-boundary mode')
    unsupported=parameters
    unsupported%swkimpl=1
    call prepare_fmr_b110_default_mvg(unsupported,prepared)
    call require(.not.prepared,'transition law rejects unqualified conductivity Jacobian mode')
    write(*,'(A)') 'FAPP09_NEAR_SATURATION_SCOPE_GUARD=PASS'
  end subroutine verify_transition_scope

  subroutine verify_materializer_guards()
    type(kernel_committed_state_t) :: committed
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    type(fmr_b110_physical_parameters_t) :: parameters, multilevel_parameters
    type(fmr_b110_physical_forcing_t) :: base, materialized, competing
    type(canonical_numerical_config_t) :: config
    type(fmr_surface_water_head_forcing_materializer_t) :: materializer, bad_materializer
    real(real64) :: heads(1), bad_heads(2)
    integer :: status

    call initialize_case(committed,column,template,parameters,base,config,signed_rate)
    call materializer%initialize(base,parameters,status)
    call require(status==FMR_SW_HEAD_FORCING_OK .and. materializer%ready(),'materializer initializes')

    heads(1)=-12.25_real64
    call materializer%materialize(heads,materialized,status)
    call require(status==FMR_SW_HEAD_FORCING_OK,'finite external head materialized')
    call require(allocated(materialized%drainage_response_controls),'typed controls allocated')
    call require(materialized%drainage_response_controls(1)%resolved_surface_water_head_supplied, &
         'external head supplied flag')
    call require(.not. materialized%drainage_response_controls(1)%drain_head_supplied, &
         'legacy generic drain head not simultaneously supplied')

    bad_heads=[-12.25_real64,-13.0_real64]
    call materializer%materialize(bad_heads,materialized,status)
    call require(status==FMR_SW_HEAD_FORCING_INVALID_REQUEST,'wrong external head vector rejected')

    heads(1)=ieee_value(0.0_real64,ieee_quiet_nan)
    call materializer%materialize(heads,materialized,status)
    call require(status==FMR_SW_HEAD_FORCING_NONFINITE_HEAD,'nonfinite external head rejected')

    competing=base
    allocate(competing%drainage_flux_by_level(1,numnod))
    competing%drainage_flux_by_level=0.0_real64
    call bad_materializer%initialize(competing,parameters,status)
    call require(status==FMR_SW_HEAD_FORCING_COMPETING_DRAINAGE_INPUT,'competing drainage forcing rejected')

    multilevel_parameters = parameters
    deallocate(multilevel_parameters%drainage_response_levels)
    allocate(multilevel_parameters%drainage_response_levels(2))
    multilevel_parameters%drainage_response_levels = parameters%drainage_response_levels(1)
    call bad_materializer%initialize(base,multilevel_parameters,status)
    call require(status==FMR_SW_HEAD_FORCING_PROFILE_NOT_ADMITTED,'unqualified multilevel profile rejected')
    write(*,'(A)') 'FAPP09_SINGLE_LEVEL_V1_SCOPE=PASS'
    write(*,'(A)') 'FAPP09_TYPED_EXTERNAL_HEAD_MATERIALIZER=PASS'
  end subroutine verify_materializer_guards

  subroutine verify_owner_xor()
    type(kernel_committed_state_t) :: committed, fixed_committed
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template, fixed_template
    type(fmr_b110_physical_parameters_t) :: parameters
    type(fmr_b110_physical_forcing_t) :: base
    type(canonical_numerical_config_t) :: config
    type(fmr_surface_water_head_forcing_materializer_t) :: materializer
    type(fmr_b110_fixed_weir_surface_water_state_t) :: fixed_state
    integer :: status
    logical :: ok

    call initialize_case(committed,column,template,parameters,base,config,signed_rate)
    call materializer%initialize(base,parameters,status)
    call require(status==FMR_SW_HEAD_FORCING_OK,'owner xor materializer')
    call require(fmr_surface_water_external_profile_admitted(template,parameters,committed,materializer), &
         'external owner base profile admitted')

    fixed_template=template
    fixed_template%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_FIXED_WEIR_SURFACE_WATER
    call require(.not. fmr_surface_water_external_profile_admitted(fixed_template,parameters,committed,materializer), &
         'fixed-weir template rejected under external owner')

    call build_fixed_state(parameters,fixed_state)
    fixed_state%surface_water%storage=1.0_real64
    call fmr_new_b110_fixed_weir_surface_water_committed_state(fixed_committed,column_id,fixed_state,t0,ok)
    call require(ok,'fixed-weir committed fixture initialized')
    call require(.not. fmr_surface_water_external_profile_admitted(template,parameters,fixed_committed,materializer), &
         'fixed-weir committed state rejected under external owner')
    write(*,'(A)') 'FAPP09_SURFACE_WATER_STATE_OWNER_XOR=PASS'
  end subroutine verify_owner_xor

  subroutine verify_positive_recomposition_and_commit()
    type(kernel_committed_state_t) :: committed
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    type(fmr_b110_physical_parameters_t) :: parameters
    type(fmr_b110_physical_forcing_t) :: base
    type(canonical_numerical_config_t) :: config
    type(fmr_surface_water_head_forcing_materializer_t) :: materializer
    type(fmr_surface_water_swap_participant_t) :: participant
    type(fmr_surface_water_trial_t) :: trial1,trial2
    type(fmr_serialized_reference_backend_t) :: backend
    type(fmr_surface_water_component_receipt_t) :: component_receipt
    type(fmr04_fixed_flux_top_provider_t), target :: top
    class(transaction_state_t), allocatable :: snapshot
    real(real64) :: heads(1),expected
    logical :: did_commit, available
    integer :: status

    call initialize_case(committed,column,template,parameters,base,config,signed_rate)
    call materializer%initialize(base,parameters,status)
    call require(status==FMR_SW_HEAD_FORCING_OK,'positive materializer')
    call backend%initialize(top)
    call participant%capture_origin(committed,status)
    call require(status==FMR_SW_PARTICIPANT_OK .and. participant%captured_revision()==0_int64,'positive origin capture')

    heads(1)=-12.25_real64
    call participant%trial_from_origin(backend,column,template,parameters,committed,materializer,config,t0,t1,heads,trial1,status)
    expected=signed_rate*duration
    if (status /= FMR_SW_PARTICIPANT_OK .or. .not. trial1%valid) then
      write(*,'(A,I0)') 'FAPP09_DIAG_POSITIVE_TRIAL_STATUS=',status
      write(*,'(A,L1)') 'FAPP09_DIAG_POSITIVE_TRIAL_VALID=',trial1%valid
      write(*,'(A,I0)') 'FAPP09_DIAG_POSITIVE_TRIAL_SUBSTEPS=',trial1%accepted_substeps
    end if
    call require(status==FMR_SW_PARTICIPANT_OK .and. trial1%valid,'positive candidate trial')
    call require(trial1%accepted_substeps==1,'single accepted substep profile')
    call require(abs(trial1%signed_soil_to_surface_exchange_cm-expected)<=exchange_tol,'positive requested exchange')
    call require(committed%current_revision()==0_int64,'trial does not mutate accepted state')

    component_receipt%valid=.true.
    component_receipt%subsurface_swap_to_surface_cm=trial1%signed_soil_to_surface_exchange_cm
    component_receipt%top_swap_to_surface_cm=0.125_real64
    call require(.not.participant%component_publication_ready(committed,t0,t1,0.0_real64,component_receipt,exchange_tol), &
         'wrong top component blocks publication')
    call require(committed%current_revision()==0_int64 .and. participant%has_live_candidate(), &
         'component mismatch preserves live candidate and origin')
    call participant%commit_component_candidate(backend,committed,t0,t1,0.0_real64,component_receipt,exchange_tol, &
         did_commit,status)
    call require(.not.did_commit .and. status==FMR_SW_PARTICIPANT_EXCHANGE_MISMATCH, &
         'wrong top component cannot bypass commit')
    call require(committed%current_revision()==0_int64 .and. participant%has_live_candidate(), &
         'failed component commit preserves candidate')
    component_receipt%top_swap_to_surface_cm=0.0_real64
    call require(participant%component_publication_ready(committed,t0,t1,0.0_real64,component_receipt,exchange_tol), &
         'matched component receipt publication ready')

    call participant%commit_candidate(backend,committed,t0,t1,0.0_real64,exchange_tol,did_commit,status)
    call require(.not.did_commit .and. status==FMR_SW_PARTICIPANT_EXCHANGE_MISMATCH,'availability mismatch blocks commit')
    call require(committed%current_revision()==0_int64 .and. participant%has_live_candidate(),'mismatch preserves origin and candidate')
    call participant%discard_candidate(backend)
    call require(.not.participant%has_live_candidate() .and. participant%has_origin(),'discard retains accepted origin')

    call participant%trial_from_origin(backend,column,template,parameters,committed,materializer,config,t0,t1,heads,trial2,status)
    call require(status==FMR_SW_PARTICIPANT_OK .and. trial2%valid,'positive replay candidate')
    call require(abs(trial2%signed_soil_to_surface_exchange_cm-trial1%signed_soil_to_surface_exchange_cm)<=exchange_tol, &
         'same-origin exchange replay')
    call require(participant%publication_ready(committed,t0,t1,trial2%signed_soil_to_surface_exchange_cm,exchange_tol), &
         'matched realized exchange publication ready')
    call participant%commit_candidate(backend,committed,t0,t1,trial2%signed_soil_to_surface_exchange_cm,exchange_tol, &
         did_commit,status)
    call require(did_commit .and. status==FMR_SW_PARTICIPANT_OK,'positive candidate committed')
    call require(committed%current_revision()==1_int64,'positive sole kernel commit')
    call committed%snapshot(snapshot,available)
    call require(available .and. allocated(snapshot),'committed base-state snapshot available')
    select type (state => snapshot)
    type is (fmr_b110_physical_state_t)
      call require(.not. allocated(state%snow) .and. .not. allocated(state%soil_temperature), &
           'external-owner commit adds no optional persistent state')
    class default
      call require(.false.,'external-owner committed carrier remains base physical state')
    end select
    write(*,'(A)') 'FAPP09_NO_PERSISTENT_SURFACE_WATER_STATE=PASS'
    write(*,'(A)') 'FAPP09_RECOMPOSITION_DISCARD_REPLAY=PASS'
    write(*,'(A)') 'FAPP09_POSITIVE_DRAINAGE_TRANSACTION=PASS'
  end subroutine verify_positive_recomposition_and_commit


  subroutine verify_external_top_observation()
    type(kernel_committed_state_t) :: committed
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    type(fmr_b110_physical_parameters_t) :: parameters
    type(fmr_b110_physical_forcing_t) :: base
    type(canonical_numerical_config_t) :: config
    type(fmr_serialized_reference_backend_t) :: backend
    type(fmr04_fixed_flux_top_provider_t), target :: top
    type(kernel_checkpoint_t) :: checkpoint
    type(kernel_candidate_state_t) :: candidate
    type(kernel_result_t) :: result
    type(kernel_diagnostics_t) :: diagnostics
    type(fmr_serialized_physical_observation_t) :: observation
    real(real64) :: trial_t1,trial_duration
    logical :: available
    integer :: status

    call initialize_case(committed,column,template,parameters,base,config,0.0_real64)
    trial_t1=t1
    if(trim(mode)=='unified-cv')trial_t1=t0+0.03125_real64
    trial_duration=trial_t1-t0
    parameters%external_top_surface_water_capable=.true.
    parameters%max_iterations=80
    parameters%max_backtracking=16
    ! Surface/transaction fixture, no temporal accuracy claim. Mass gate unchanged.
    config%transaction%temporal_tolerance=1.0e3_real64
    parameters%drainage_response_active=.false.
    if(allocated(parameters%drainage_response_levels))deallocate(parameters%drainage_response_levels)
    base%external_top_surface_water_supplied=.true.
    allocate(base%drainage_flux_by_level(1,parameters%active_nodes))
    base%drainage_flux_by_level=0.0_real64
    base%top_flux=0.0_real64
    base%external_top_surface_water_head_cm=0.02_real64
    base%external_top_surface_water_sill_cm=0.01_real64
    base%top_ponding_max_cm=1.0_real64
    base%top_runoff_resistance_day=1.0_real64
    base%top_runoff_exponent=1.0_real64
    if(trim(mode)=='unified-cv')then
      config%transaction%temporal_tolerance=1.0e15_real64
      base%external_top_surface_formulation=FMR_TOP_SURFACE_FORMULATION_UNIFIED_CV
      parameters%external_top_surface_microrelief_depth_cm=0.05_real64
      parameters%external_top_surface_contact_conductance_scale=1.0_real64
      base%top_ponding_max_cm=0.0_real64
      base%top_runoff_resistance_day=0.0_real64
    end if
    call backend%initialize(top)
    call committed%capture_checkpoint(checkpoint,available)
    call require(available,'external top checkpoint')
    call backend%run_trial(column,template,parameters,committed,base,config,t0,trial_t1,checkpoint,result,candidate,diagnostics)
    if(.not.result%completed.or..not.candidate%ready())then
      write(*,'(A,L1)')'TOP03_DIAG_COMPLETED=',result%completed
      write(*,'(A,I0)')'TOP03_DIAG_RESULT_STATUS=',result%status
      write(*,'(A,I0)')'TOP03_DIAG_SUBSTEPS=',diagnostics%accepted_substeps
      write(*,'(A,I0)')'TOP03_DIAG_MASS_REJECTIONS=',diagnostics%mass_rejections
      write(*,'(A,I0)')'TOP03_DIAG_SOLVER_REJECTIONS=',diagnostics%solver_rejections
      write(*,'(A,I0)')'TOP03_DIAG_TEMPORAL_REJECTIONS=',diagnostics%temporal_rejections
      write(*,'(A,I0)')'TOP03_DIAG_ADMISSION_REJECTIONS=',diagnostics%admission_rejections
      observation=backend%observation()
      write(*,'(A,L1)')'TOP03_DIAG_STATE_PROFILE=',observation%state_profile_prepared
      write(*,'(A,L1)')'TOP03_DIAG_ADMISSION_PREVIEW=',observation%execution_admission_preview
      write(*,'(A,L1)')'TOP03_DIAG_FORCING_PREPARED=',observation%forcing_prepared
      write(*,'(A,L1)')'TOP03_DIAG_STATE_PROFILE=',observation%state_profile_prepared
      write(*,'(A,L1)')'TOP03_DIAG_EXEC_ADMITTED=',observation%execution_admission_preview
      write(*,'(A,L1)')'TOP03_DIAG_SOLVER_EXECUTED=',observation%solver_executed
      write(*,'(A,I0)')'TOP03_DIAG_SOLVER_STATUS=',observation%solver_status
      write(*,'(A,I0)')'TOP03_DIAG_ITERATIONS=',observation%solver_diagnostics%nonlinear_iterations
      write(*,'(A,ES24.16)')'TOP03_DIAG_QTOP=',observation%top_flux
      write(*,'(A,L1)')'TOP03_DIAG_STATE_PROFILE=',observation%state_profile_prepared
      write(*,'(A,L1)')'TOP03_DIAG_EXEC_PREVIEW=',observation%execution_admission_preview
    end if
    if (trim(mode)=='characterize'.or.trim(mode)=='transition-characterize'.or.trim(mode)=='unified-cv') then
      observation=backend%observation()
      call require(.not.result%completed.and..not.candidate%ready(),'identity policy rejects transient candidate')
      call require(observation%solver_status==1,'characterization Richards converged')
      call require(diagnostics%mass_rejections==0.and.diagnostics%solver_rejections==0,'characterization solver and mass accepted')
      call require(diagnostics%temporal_rejections==3,'characterization isolated temporal rejection')
      call require(committed%current_revision()==0_int64,'characterization rejects without commit')
      call require(.not.observation%top_surface_exchange_available,'rejected interval publishes no top carrier')
      if(trim(mode)=='unified-cv')then
        call require(observation%solver_executed.and.diagnostics%accepted_substeps==0, &
             'unified CV reaches Richards but no substep passes temporal acceptance')
        call require(ieee_is_finite(observation%top_flux),'unified CV finite converged top flux')
        write(*,'(A,I0,A,I0,A,ES24.16)')'FAPP09_UNIFIED_CV_SOLVER=',observation%solver_status, &
             ',iterations=',observation%solver_diagnostics%nonlinear_iterations,',qtop=',observation%top_flux
        write(*,'(A)')'FAPP09_UNIFIED_SURFACE_CV_TEMPORAL_BLOCKER=PASS'
      end if
      if (trim(mode)=='transition-characterize') &
           write(*,'(A)')'FAPP09_NEARSATURATION_TRANSIENT_REJECTED_WITHOUT_PUBLICATION=PASS'
      write(*,'(A)')'FAPP09_TOP03_TRANSIENT_TEMPORAL_BLOCKER=PASS'
      return
    end if
    call require(result%completed.and.candidate%ready(),'external top trial completed')
    observation=backend%observation()
    call require(observation%solver_status==1,'external top Richards converged')
    call require(result%mass%complete,'external top ledger complete')
    call require(abs(result%mass%residual)<=config%transaction%mass_tolerance,'external top ledger closure')
    call require(abs(observation%top_surface_signed_swap_to_external_cm + &
         result%mass%total_in-result%mass%total_out-base%bottom_flux*trial_duration)<=1.0e-10_real64, &
         'selected whole-window transfer matches independent ledger')
    call require(observation%top_surface_exchange_available,'external top observation available')
    call require(observation%top_surface_signed_swap_to_external_cm<0.0_real64,'external top inundation signed negative')
    call require(abs(observation%top_surface_closure_residual_cm)<=exchange_tol,'external top surface closure')
    call backend%discard_trial_candidate(candidate,diagnostics)
    write(*,'(A)')'TOP03_ACCEPTED_TOP_OBSERVATION=PASS'
  end subroutine verify_external_top_observation


  subroutine verify_default_off_capability()
    type(kernel_committed_state_t) :: committed
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    type(fmr_b110_physical_parameters_t) :: parameters
    type(fmr_b110_physical_forcing_t) :: base,forcing
    type(canonical_numerical_config_t) :: config
    type(fmr_serialized_reference_backend_t) :: backend
    type(fmr04_fixed_flux_top_provider_t), target :: top
    type(fmr_surface_water_head_forcing_materializer_t) :: materializer
    type(kernel_checkpoint_t) :: checkpoint
    type(kernel_candidate_state_t) :: candidate
    type(kernel_result_t) :: a,b
    type(kernel_diagnostics_t) :: diagnostics
    class(transaction_state_t),allocatable :: sa,sb
    real(real64) :: heads(1)
    logical :: ok
    integer :: status
    call initialize_case(committed,column,template,parameters,base,config,signed_rate)
    call materializer%initialize(base,parameters,status)
    heads(1)=-12.25_real64
    call materializer%materialize(heads,forcing,status)
    call backend%initialize(top)
    call committed%capture_checkpoint(checkpoint,ok)
    call backend%run_trial(column,template,parameters,committed,forcing,config,t0,t1,checkpoint,a,candidate,diagnostics)
    call require(a%completed,'default-off baseline completed')
    call candidate%snapshot(sa,ok)
    call require(ok,'default-off baseline snapshot')
    call backend%discard_trial_candidate(candidate,diagnostics)
    parameters%external_top_surface_water_capable=.true.
    call backend%run_trial(column,template,parameters,committed,forcing,config,t0,t1,checkpoint,b,candidate,diagnostics)
    call require(b%completed,'capability-on forcing-off completed')
    call candidate%snapshot(sb,ok)
    call require(ok,'capability-on forcing-off snapshot')
    call require(a%mass%total_in==b%mass%total_in.and.a%mass%total_out==b%mass%total_out,'default-off identical mass')
    select type(sa)
    type is(fmr_b110_physical_state_t)
      select type(sb)
      type is(fmr_b110_physical_state_t)
        call require(all(sa%pressure_head==sb%pressure_head).and.all(sa%water_content==sb%water_content).and. &
             sa%ponding_depth==sb%ponding_depth,'default-off identical physical state')
      class default
        call require(.false.,'default-off candidate type')
      end select
    class default
      call require(.false.,'default-off baseline type')
    end select
    call backend%discard_trial_candidate(candidate,diagnostics)
    write(*,'(A)')'FAPP09_TOP03_DEFAULT_OFF_PRESERVATION=PASS'
  end subroutine verify_default_off_capability

  subroutine verify_external_top_component_transaction()
    type(kernel_committed_state_t) :: committed,other
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    type(fmr_b110_physical_parameters_t) :: parameters
    type(fmr_b110_physical_forcing_t) :: base,forcing
    type(canonical_numerical_config_t) :: config
    type(fmr_serialized_reference_backend_t) :: backend
    type(fmr04_fixed_flux_top_provider_t), target :: top
    type(fmr_surface_water_head_forcing_materializer_t) :: materializer
    type(fmr_surface_water_swap_participant_t) :: participant
    type(fmr_surface_water_trial_t) :: trial
    type(fmr_surface_water_component_receipt_t) :: receipt
    type(fmr_serialized_physical_observation_t) :: observation
    type(kernel_checkpoint_t) :: checkpoint
    type(kernel_candidate_state_t) :: candidate
    type(kernel_result_t) :: result0,result1
    type(kernel_diagnostics_t) :: diagnostics
    type(fmr_b110_physical_state_t) :: state
    real(real64) :: heads(1),expected,replayed
    logical :: did_commit,ok
    integer :: status

    call initialize_case(committed,column,template,parameters,base,config,0.0_real64)
    call backend%initialize(top)
    call materializer%initialize(base,parameters,status)
    heads(1)=-12.25_real64
    call materializer%materialize(heads,forcing,status)
    call committed%capture_checkpoint(checkpoint,ok)
    call backend%run_trial(column,template,parameters,committed,forcing,config,t0,t1,checkpoint,result0,candidate,diagnostics)
    call require(result0%completed,'preservation baseline completed')
    call backend%discard_trial_candidate(candidate,diagnostics)
    parameters%external_top_surface_water_capable=.true.
    call backend%run_trial(column,template,parameters,committed,forcing,config,t0,t1,checkpoint,result1,candidate,diagnostics)
    call require(result1%completed,'capability-on forcing-off preservation completed')
    call require(result0%mass%total_in==result1%mass%total_in.and.result0%mass%total_out==result1%mass%total_out, &
         'capability-on forcing-off identical ledger')
    call backend%discard_trial_candidate(candidate,diagnostics)
    write(*,'(A)')'TOP03_CAPABILITY_ON_FORCING_OFF_PRESERVATION=PASS'

    parameters%max_iterations=80
    parameters%max_backtracking=16
    ! Surface/transaction fixture, no temporal accuracy claim. Mass gate unchanged.
    config%transaction%temporal_tolerance=1.0e3_real64
    base%top_flux=0.0_real64
    base%external_top_surface_water_supplied=.true.
    base%external_top_surface_water_head_cm=0.02_real64
    base%external_top_surface_water_sill_cm=0.01_real64
    base%top_ponding_max_cm=1.0_real64
    base%top_runoff_resistance_day=1.0_real64
    base%top_runoff_exponent=1.0_real64
    call materializer%initialize(base,parameters,status)
    call require(status==FMR_SW_HEAD_FORCING_OK,'top component materializer initialized')
    heads(1)=0.02_real64
    call participant%capture_origin(committed,status)
    call participant%trial_from_origin(backend,column,template,parameters,committed,materializer,config,t0,t1,heads,trial,status)
    call require(status==FMR_SW_PARTICIPANT_OK.and.trial%valid,'top component real trial completed')
    observation=backend%observation()
    expected=observation%top_surface_signed_swap_to_external_cm
    call require(observation%top_surface_exchange_available.and.expected<0.0_real64,'top component negative inundation')
    call require(committed%current_revision()==0_int64,'top trial remains tentative')
    call require(.not.participant%publication_ready(committed,t0,t1,trial%signed_soil_to_surface_exchange_cm,exchange_tol), &
         'top-active scalar publication rejected')
    call participant%commit_candidate(backend,committed,t0,t1,trial%signed_soil_to_surface_exchange_cm,exchange_tol,did_commit,status)
    call require(.not.did_commit.and.participant%has_live_candidate().and.participant%has_origin(),'scalar bypass preserves candidate')
    receipt%valid=.true.
    receipt%top_swap_to_surface_cm=expected+0.01_real64
    receipt%subsurface_swap_to_surface_cm=trial%signed_soil_to_surface_exchange_cm-0.01_real64
    call participant%commit_component_candidate(backend,committed,t0,t1,expected,receipt,exchange_tol,did_commit,status)
    call require(.not.did_commit.and.committed%current_revision()==0_int64,'scalar-total masking rejected')
    receipt%subsurface_swap_to_surface_cm=trial%signed_soil_to_surface_exchange_cm
    call participant%commit_component_candidate(backend,committed,t0,t1,expected,receipt,exchange_tol,did_commit,status)
    call require(.not.did_commit.and.participant%has_live_candidate().and.participant%has_origin(),'wrong top receipt preserves live origin')

    call participant%discard_candidate(backend)
    heads(1)=0.03_real64
    call participant%trial_from_origin(backend,column,template,parameters,committed,materializer,config,t0,t1,heads,trial,status)
    call require(status==FMR_SW_PARTICIPANT_OK.and.trial%valid,'same-origin changed head replay')
    observation=backend%observation()
    replayed=observation%top_surface_signed_swap_to_external_cm
    call require(abs(replayed-expected)>exchange_tol,'resolved head changes accepted top transfer')
    call build_base_state(parameters,state)
    call fmr_new_b110_committed_state(other,column_id+1_int64,state,t0,ok)
    receipt%top_swap_to_surface_cm=replayed
    receipt%subsurface_swap_to_surface_cm=trial%signed_soil_to_surface_exchange_cm
    call participant%commit_component_candidate(backend,other,t0,t1,replayed,receipt,exchange_tol,did_commit,status)
    call require(.not.did_commit.and.other%current_revision()==0_int64.and.participant%has_live_candidate(),'top stale origin rejected')
    call participant%commit_component_candidate(backend,committed,t0,t1,replayed,receipt,exchange_tol,did_commit,status)
    call require(did_commit.and.status==FMR_SW_PARTICIPANT_OK.and.committed%current_revision()==1_int64,'top correct exactly-once commit')
    call participant%commit_component_candidate(backend,committed,t0,t1,replayed,receipt,exchange_tol,did_commit,status)
    call require(.not.did_commit.and.committed%current_revision()==1_int64,'top duplicate commit rejected')
    write(*,'(A)')'TOP03_REAL_COMPONENT_TRANSACTION=PASS'
  end subroutine verify_external_top_component_transaction

  subroutine verify_negative_commit()
    type(kernel_committed_state_t) :: committed
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    type(fmr_b110_physical_parameters_t) :: parameters
    type(fmr_b110_physical_forcing_t) :: base
    type(canonical_numerical_config_t) :: config
    type(fmr_surface_water_head_forcing_materializer_t) :: materializer
    type(fmr_surface_water_swap_participant_t) :: participant
    type(fmr_surface_water_trial_t) :: trial
    type(fmr_serialized_reference_backend_t) :: backend
    type(fmr04_fixed_flux_top_provider_t), target :: top
    real(real64) :: heads(1),expected
    logical :: did_commit
    integer :: status

    call initialize_case(committed,column,template,parameters,base,config,-signed_rate)
    call materializer%initialize(base,parameters,status)
    call backend%initialize(top)
    call participant%capture_origin(committed,status)
    heads(1)=7.75_real64
    call participant%trial_from_origin(backend,column,template,parameters,committed,materializer,config,t0,t1,heads,trial,status)
    expected=-signed_rate*duration
    call require(status==FMR_SW_PARTICIPANT_OK .and. trial%valid,'negative candidate trial')
    call require(abs(trial%signed_soil_to_surface_exchange_cm-expected)<=exchange_tol,'negative requested exchange')
    call participant%commit_candidate(backend,committed,t0,t1,trial%signed_soil_to_surface_exchange_cm,exchange_tol, &
         did_commit,status)
    call require(did_commit .and. status==FMR_SW_PARTICIPANT_OK,'negative candidate committed')
    call require(committed%current_revision()==1_int64,'negative sole kernel commit')
    write(*,'(A)') 'FAPP09_NEGATIVE_INFILTRATION_TRANSACTION=PASS'
  end subroutine verify_negative_commit

  subroutine verify_stale_origin()
    type(kernel_committed_state_t) :: committed,other_committed
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    type(fmr_b110_physical_parameters_t) :: parameters
    type(fmr_b110_physical_forcing_t) :: base
    type(canonical_numerical_config_t) :: config
    type(fmr_surface_water_head_forcing_materializer_t) :: materializer
    type(fmr_surface_water_swap_participant_t) :: participant
    type(fmr_surface_water_trial_t) :: trial
    type(fmr_serialized_reference_backend_t) :: backend
    type(fmr04_fixed_flux_top_provider_t), target :: top
    type(fmr_b110_physical_state_t) :: state
    real(real64) :: heads(1)
    integer :: status
    logical :: ok

    call initialize_case(committed,column,template,parameters,base,config,signed_rate)
    call materializer%initialize(base,parameters,status)
    call build_base_state(parameters,state)
    call fmr_new_b110_committed_state(other_committed,column_id+1_int64,state,t0,ok)
    call require(ok,'stale-origin alternate committed initialized')
    call backend%initialize(top)
    call participant%capture_origin(committed,status)
    heads(1)=-12.25_real64
    call participant%trial_from_origin(backend,column,template,parameters,other_committed,materializer,config,t0,t1,heads,trial,status)
    call require(status==FMR_SW_PARTICIPANT_ORIGIN_DRIFT .and. .not.trial%valid,'stale origin rejected')
    call require(committed%current_revision()==0_int64 .and. other_committed%current_revision()==0_int64, &
         'stale-origin rejection nonmutating')
    write(*,'(A)') 'FAPP09_STALE_ORIGIN_FAIL_CLOSED=PASS'
  end subroutine verify_stale_origin

  subroutine initialize_case(committed,column,template,parameters,base,config,balancing_qssdi)
    type(kernel_committed_state_t), intent(out) :: committed
    type(fmr_logical_column_t), intent(out) :: column
    type(fmr_template_t), intent(out) :: template
    type(fmr_b110_physical_parameters_t), intent(out) :: parameters
    type(fmr_b110_physical_forcing_t), intent(out) :: base
    type(canonical_numerical_config_t), intent(out) :: config
    real(real64), intent(in) :: balancing_qssdi
    type(fmr_b110_physical_state_t) :: state
    type(b110_default_mvg_parameters_t), target :: hp
    type(b110_default_mvg_provider_t) :: provider
    real(real64) :: heads(numnod),water(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod),k0
    logical :: ok, prepared
    integer :: k

    parameters%parameter_set_id=49009_int64
    parameters%active_nodes=numnod
    allocate(parameters%z(numnod),parameters%dz(numnod),parameters%node_distance(numnod),parameters%cofgen(24,numnod))
    parameters%z=z; parameters%dz=dz; parameters%node_distance=disnod(1:numnod); parameters%cofgen=0.0_real64
    do k=1,numnod
      parameters%cofgen(1,k)=0.032_real64; parameters%cofgen(2,k)=0.423_real64; parameters%cofgen(3,k)=4.75_real64
      parameters%cofgen(4,k)=0.0135_real64; parameters%cofgen(5,k)=0.365_real64; parameters%cofgen(6,k)=1.455_real64
      parameters%cofgen(7,k)=1.0_real64-1.0_real64/parameters%cofgen(6,k); parameters%cofgen(8,k)=parameters%cofgen(4,k)
      parameters%cofgen(9,k)=0.0_real64; parameters%cofgen(10,k)=parameters%cofgen(3,k); parameters%cofgen(11,k)=0.999_real64
      parameters%cofgen(12,k)=0.99_real64*parameters%cofgen(3,k); parameters%cofgen(22,k)=-1.0e6_real64
      parameters%cofgen(23,k)=1.0e-12_real64
    end do
    parameters%bottom_mode=7; parameters%swkimpl=0; parameters%swkmean=1; parameters%swsophy=0
    parameters%near_saturation_transition_width_cm=0.0_real64
    if (trim(mode)=='transition'.or.trim(mode)=='transition-characterize') then
      parameters%near_saturation_transition_width_cm=0.2_real64
      parameters%max_iterations=80
      parameters%max_backtracking=16
      call prepare_fmr_b110_default_mvg(parameters,prepared)
      call require(prepared,'FMR prepares opt-in near-saturation constitutive law')
      call require(parameters%prepared_default_mvg%near_saturation_transition_width_cm==0.2_real64, &
           'prepared FMR provider retains configured transition width')
    end if
    parameters%root_extraction_active=.false.; parameters%macropore_active=.false.; parameters%snow_active=.false.
    parameters%hysteresis_active=.false.; parameters%tabulated_hydraulics_active=.false.
    parameters%elasticity_active=.false.; parameters%frost_active=.false.; parameters%soil_temperature_active=.false.
    parameters%black_evaporation_active=.false.; parameters%boesten_evaporation_active=.false.
    parameters%drainage_response_active=.true.; parameters%drainage_qbot_smooth_freatic_projection=.false.
    allocate(parameters%drainage_response_levels(1))
    parameters%drainage_response_levels(1)%variant=FMR_DRAIN_VARIANT_EXTENDED_SIGNED
    parameters%drainage_response_levels(1)%extended%zbotdr_cm=-100.0_real64
    parameters%drainage_response_levels(1)%extended%drain_type=EXT_DRAIN_TUBE
    parameters%drainage_response_levels(1)%extended%spacing_cm=1000.0_real64
    parameters%drainage_response_levels(1)%extended%rdrain_day=1000.0_real64
    parameters%drainage_response_levels(1)%extended%rinfi_day=1000.0_real64
    parameters%drainage_response_levels(1)%extended%rentry_day=0.0_real64
    parameters%drainage_response_levels(1)%extended%rexit_day=0.0_real64
    parameters%drainage_response_levels(1)%extended%gwlinf_cm=-200.0_real64
    parameters%drainage_response_levels(1)%extended%pondmx_cm=1000.0_real64
    parameters%drainage_response_levels(1)%extended%highest_level=.false.
    parameters%drainage_response_levels(1)%extended%highest_surface_mode=EXT_DRAIN_TOP_NONE

    call initialize_b110_default_mvg_parameters(hp,parameters%cofgen, &
         near_saturation_transition_width_cm=parameters%near_saturation_transition_width_cm)
    call bind_b110_default_mvg_provider(provider,hp,duration)
    call build_heads(heads)
    call provider%evaluate(heads,water,conductivity,capacity,dkdh)
    k0=conductivity(1)
    state%active_nodes=numnod
    allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head=heads; state%water_content=water; state%ponding_depth=0.0_real64; state%groundwater_level=initial_gwl
    call fmr_new_b110_committed_state(committed,column_id,state,t0,ok)
    call require(ok,'base committed state initialized')

    template%template_id=490091_int64; template%physics_topology_id=490092_int64
    template%vertical_layout_id=490093_int64; template%state_layout_id=490094_int64
    template%solver_interface_id=490095_int64; template%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_BASE
    template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
    template%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    column%column_id=column_id; column%template_id=template%template_id; column%parameter_ref=1_int64
    column%state_handle=1_int64; column%forcing_handle=1_int64; column%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE

    base%top_flux=-k0; base%top_head=initial_head; base%bottom_flux=-k0; base%bottom_head=-321.0_real64
    allocate(base%subsurface_irrigation_source(numnod),base%root_extraction_sink(numnod))
    base%subsurface_irrigation_source=0.0_real64
    base%subsurface_irrigation_source(numnod)=balancing_qssdi
    base%root_extraction_sink=0.0_real64

    config%transaction%temporal_mode=TX_TEMPORAL_EXTERNAL_FULL_HALF
    config%transaction%temporal_tolerance=1.0e3_real64
    config%transaction%mass_tolerance=1.0e-10_real64
    config%transaction%retry_scale=0.5_real64; config%transaction%max_retries=2
    config%max_committed_substeps=8; config%progress_tolerance=0.0_real64
  end subroutine initialize_case

  subroutine build_base_state(parameters,state)
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters
    type(fmr_b110_physical_state_t), intent(out) :: state
    type(b110_default_mvg_parameters_t), target :: hp
    type(b110_default_mvg_provider_t) :: provider
    real(real64) :: heads(numnod),water(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod)
    call initialize_b110_default_mvg_parameters(hp,parameters%cofgen, &
         near_saturation_transition_width_cm=parameters%near_saturation_transition_width_cm)
    call bind_b110_default_mvg_provider(provider,hp,duration)
    call build_heads(heads)
    call provider%evaluate(heads,water,conductivity,capacity,dkdh)
    state%active_nodes=numnod
    allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head=heads; state%water_content=water; state%ponding_depth=0.0_real64; state%groundwater_level=initial_gwl
  end subroutine build_base_state

  subroutine build_fixed_state(parameters,state)
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters
    type(fmr_b110_fixed_weir_surface_water_state_t), intent(out) :: state
    type(b110_default_mvg_parameters_t), target :: hp
    type(b110_default_mvg_provider_t) :: provider
    real(real64) :: heads(numnod),water(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod)
    call initialize_b110_default_mvg_parameters(hp,parameters%cofgen, &
         near_saturation_transition_width_cm=parameters%near_saturation_transition_width_cm)
    call bind_b110_default_mvg_provider(provider,hp,duration)
    call build_heads(heads)
    call provider%evaluate(heads,water,conductivity,capacity,dkdh)
    state%active_nodes=numnod
    allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head=heads; state%water_content=water; state%ponding_depth=0.0_real64; state%groundwater_level=initial_gwl
  end subroutine build_fixed_state

  subroutine build_heads(heads)
    real(real64), intent(out) :: heads(numnod)
    ! Exact Q4B qualified fixture: uniform initial pressure head.
    heads = initial_head
  end subroutine build_heads

  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition)then
      write(*,'(A,1X,A)')'FAPP09_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fapp09_ribasim_external_surface_water_profile
