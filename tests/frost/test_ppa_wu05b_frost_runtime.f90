program test_fmr44r_serialized_prescribed_qbot_runtime
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_EXTERNAL_FULL_HALF, TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_executor_t, kernel_committed_state_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       FMR_BACKEND_SERIALIZED_REFERENCE, FMR_NUMERICAL_CONTINUATION_NONE, &
       FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY, &
       FMR_OPTIONAL_STATE_LAYOUT_RESTRICTED_SOIL_TEMPERATURE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, fmr_serialized_physical_observation_t, &
       fmr_new_b110_committed_state, fmr_new_b110_temporal_indicator_committed_state
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, &
       fmr_serialized_batch_diagnostics_t, fmr_execute_serialized_resolved_physical_column
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_soil_temperature_contract, only: initialize_soil_temperature_state
  use mod_restricted_soil_temperature, only: initialize_soil_temperature_parameters
  use mod_soil_temperature_contract, only: copy_soil_temperature_profile
  use mod_fmr_committed_restart, only: fmr_committed_restart_bundle_t, fmr_export_committed_restart, &
       fmr_restore_committed_restart, FMR_RESTART_OK
  use mod_fmr_committed_restart, only: fmr_restart_template_identity_matches
  use mod_frost_hydraulic_effect, only: frost_hydraulic_parameters_t, evaluate_frost_hydraulic_factor
  implicit none

  real(real64), parameter :: h0 = -75.0_real64
  real(real64), parameter :: equilibrium_dt = 0.25_real64
  real(real64), parameter :: upward_dt = 1.0e-4_real64
  real(real64), parameter :: hard_mass_gate = 1.0e-12_real64
  real(real64), parameter :: qualification_head_budget = 2.5e-11_real64
  real(real64), parameter :: expected_upward_binf = 1.23628846478342984e-11_real64
  integer(int64), parameter :: column_id = 440044_int64
  real(real64) :: k0, qeq

  call determine_initial_conductivity(k0)
  qeq = -k0
  call require(k0 > 0.0_real64 .and. ieee_is_finite(k0), 'initial conductivity finite positive')

  call verify_equilibrium_mode2(qeq)
  call verify_positive_bottom_inflow(1.0e-10_real64)
  call verify_unowned_mode_rejected(qeq)
  call verify_bounded_frost_case()
  call verify_frost_backend_regimes()

  write(*,'(A,ES26.17E3)') 'FMR44R_QEQ=', qeq
  write(*,'(A,ES26.17E3)') 'FMR44R_POSITIVE_QBOT=', 1.0e-10_real64
  write(*,'(A,ES26.17E3)') 'FMR44R_QUALIFICATION_HEAD_BUDGET_CM=', qualification_head_budget
  write(*,'(A)') 'FMR44R_SERIALIZED_PRESCRIBED_QBOT_RUNTIME_GATE=PASS'

contains

  subroutine verify_bounded_frost_case()
    type(fmr_serialized_column_result_t) :: output
    type(fmr_serialized_physical_observation_t) :: observation
    call execute_case(2, 0.0_real64, 0.0_real64, -999999.0_real64, equilibrium_dt, .false., .true., &
         output, observation, .true.)
    call require(output%completed .and. output%committed, 'bounded frost case committed')
    call require(output%mass%complete .and. abs(output%mass%residual) <= hard_mass_gate, &
         'bounded frost conserves water mass')
    call require(observation%frost_hydraulic_active .and. observation%frost_hydraulic_executed, &
         'bounded frost provider executed')
    call require(observation%frost_hydraulic_status == 0, 'bounded frost factor status')
    call require(observation%frost_factor_min == 0.0_real64 .and. observation%frost_factor_max == 0.0_real64, &
         'strong freeze factor oracle')
    call require(observation%soil_temperature_executed .and. observation%soil_temperature_energy_accounting_complete, &
         'existing sensible temperature route executes with frost')
    call verify_committed_frost_restart()
    write(*,'(A)') 'PPA-WU05B_BOUNDED_FROST_TRANSACTION=PASS'
    call execute_case(2, 0.0_real64, 0.0_real64, -999999.0_real64, equilibrium_dt, .true., .true., &
         output, observation, .true.)
    call require(.not. output%committed .and. output%final_revision == 0_int64, &
         'unsupported frost plus temporal certificate has no commit')
    call require(.not. observation%solver_executed, 'frost certificate incompatibility rejected before Richards')
    write(*,'(A)') 'PPA-WU05B_FROST_TEMPORAL_CERTIFICATE_FAIL_CLOSED=PASS'
    call execute_case(2, 0.0_real64, 1.0e-10_real64, -999999.0_real64, equilibrium_dt, .false., .true., &
         output, observation, .true.)
    call require(.not. output%committed .and. output%final_revision == 0_int64, &
         'nonzero prescribed bottom flux outside bounded frost admission')
    call require(.not. observation%solver_executed, 'unsupported frozen boundary rejected before Richards')
    write(*,'(A)') 'PPA-WU05B_UNSUPPORTED_FROZEN_BOUNDARY_FAIL_CLOSED=PASS'
  end subroutine verify_bounded_frost_case

  subroutine verify_frost_backend_regimes()
    real(real64), parameter :: temperatures(4) = [1.0_real64, 0.0_real64, -1.0_real64, -4.0_real64]
    real(real64), parameter :: expected(4) = [1.0_real64, 1.0_real64, 0.5_real64, 0.0_real64]
    character(len=16), parameter :: labels(4) = ['unfrozen        ', 'onset           ', &
                                                'partial freeze  ', 'strong freeze   ']
    type(fmr_serialized_column_result_t) :: output
    type(fmr_serialized_physical_observation_t) :: observation
    type(fmr_column_diagnostics_t) :: retry_diagnostic
    type(fmr_b110_physical_state_t) :: retried_physical, direct_physical, direct_next
    type(fmr_serialized_column_result_t) :: direct_output
    type(fmr_serialized_physical_observation_t) :: direct_observation
    real(real64), allocatable :: retried_temperature(:), direct_temperature(:)
    real(real64), allocatable :: thaw_factor(:), thaw_temperature(:)
    type(fmr_b110_physical_state_t) :: thawed_physical
    type(fmr_b110_physical_state_t) :: refrozen_physical
    type(fmr_serialized_column_result_t) :: thaw_output
    type(fmr_serialized_physical_observation_t) :: thaw_observation
    type(fmr_serialized_column_result_t) :: refreeze_output
    type(fmr_serialized_physical_observation_t) :: refreeze_observation
    type(frost_hydraulic_parameters_t) :: frost_parameters
    integer :: status
    integer :: i, j
    real(real64) :: direct_dt
    do i = 1, size(temperatures)
      call execute_case(2, 0.0_real64, 0.0_real64, -999999.0_real64, equilibrium_dt, .false., .true., &
           output, observation, .true., temperatures(i))
      call require(output%completed .and. output%committed, trim(labels(i))//' backend transaction committed')
      call require(output%mass%complete .and. abs(output%mass%residual) <= hard_mass_gate, &
           trim(labels(i))//' backend mass balance')
      call require(observation%frost_hydraulic_executed .and. observation%frost_hydraulic_status == 0, &
           trim(labels(i))//' frost decorator executed')
      call require(abs(observation%frost_factor_min-expected(i)) <= 2.0e-12_real64 .and. &
           abs(observation%frost_factor_max-expected(i)) <= 2.0e-12_real64, &
           trim(labels(i))//' independent backend frost-factor oracle')
      write(*,'(A,A,A,ES14.6)') 'PPA-WU05B_BACKEND_REGIME=',trim(labels(i)),' factor=',observation%frost_factor_min
    end do
    call execute_case(2, 1.0e-10_real64, 0.0_real64, -999999.0_real64, upward_dt, .false., .true., &
         output, observation, .true., -1.0_real64, retried_physical, retry_diagnostic)
    write(*,'(A,I0,A,I0,A,I0)') 'PPA-WU05B_TRANSACTION_RETRY_METRICS attempts=',retry_diagnostic%attempts, &
         ' retries=',retry_diagnostic%retries,' rejected_outer_requests=',retry_diagnostic%rejected
    call require(output%completed .and. output%committed .and. output%accepted_substeps == 8, &
         'partial-frost gravity redistribution Richards trial commits')
    call require(retry_diagnostic%retries > 0 .and. retry_diagnostic%attempts > retry_diagnostic%accepted, &
         'failed full or half trials replay at smaller steps from the committed checkpoint')
    call require(observation%solver_executed .and. observation%frost_factor_min > 0.0_real64 .and. &
         observation%frost_factor_min < 1.0_real64, 'non-trivial Richards run executes partial frost')
    call require(output%mass%complete .and. abs(output%mass%residual) <= hard_mass_gate, &
         'partial-frost gravity redistribution conserves mass')
    direct_dt = upward_dt/8.0_real64
    do j = 1, 8
      if (j == 1) then
        call execute_case(2, 1.0e-10_real64, 0.0_real64, -999999.0_real64, direct_dt, .false., .true., &
             direct_output, direct_observation, .true., -1.0_real64, direct_physical, &
             start_time=real(j-1,real64)*direct_dt)
      else
        call execute_case(2, 1.0e-10_real64, 0.0_real64, -999999.0_real64, direct_dt, .false., .true., &
             direct_output, direct_observation, .true., -1.0_real64, direct_next, &
             start_time=real(j-1,real64)*direct_dt, initial_physical_state=direct_physical)
        direct_physical = direct_next
      end if
      if (.not. direct_output%committed) write(*,'(A,I0,A,L1,A,I0,A,ES14.6)') &
           'PPA-WU05B_DIRECT_FAIL step=',j,' completed=',direct_output%completed,' status=', &
           direct_output%kernel_status,' final_time=',direct_output%final_committed_time
      call require(direct_output%committed, 'direct frost retry-sized continuation commits')
    end do
    call require(maxval(abs(retried_physical%pressure_head-direct_physical%pressure_head)) <= 2.0e-10_real64 .and. &
         maxval(abs(retried_physical%water_content-direct_physical%water_content)) <= 2.0e-12_real64, &
         'retried frost trial matches direct smaller-step hydraulic continuation')
    call copy_soil_temperature_profile(retried_physical%soil_temperature, retried_temperature, status)
    call require(status == 0, 'retried frost temperature profile available')
    call copy_soil_temperature_profile(direct_physical%soil_temperature, direct_temperature, status)
    call require(status == 0 .and. maxval(abs(retried_temperature-direct_temperature)) <= 2.0e-10_real64, &
         'retried frost trial matches direct smaller-step thermal continuation')
    write(*,'(A,I0,A,I0)') 'PPA-WU05B_FROST_REJECT_RETRY attempts=',retry_diagnostic%attempts, &
         ' retries=',retry_diagnostic%retries
    write(*,'(A,ES14.6,A,I0)') 'PPA-WU05B_PARTIAL_FROST_RICHARDS residual=',output%mass%residual, &
         ' accepted_substeps=',output%accepted_substeps
    call execute_case(2, 0.0_real64, 0.0_real64, -999999.0_real64, 1.0_real64, .false., .true., &
         thaw_output, thaw_observation, .true., -4.0_real64, thawed_physical, &
         frost_surface_temperature=5.0_real64)
    if (.not. thaw_output%committed) write(*,'(A,L1,A,I0,A,I0,A,I0,A,A)') &
         'PPA-WU05B_THAW_PROBE completed=',thaw_output%completed,' status=',thaw_output%kernel_status, &
         ' attempts=',thaw_output%accepted_substeps,' revision=',thaw_output%final_revision, &
         ' admission=',trim(thaw_output%admission_status)
    call require(thaw_output%committed .and. thaw_observation%frost_hydraulic_executed, &
         'frozen backend state executes warming interval through frost Richards path')
    write(*,'(A,ES14.6,A,ES14.6)') 'PPA-WU05B_THAW_RUNTIME_FACTOR_MIN=',thaw_observation%frost_factor_min, &
         ' max=',thaw_observation%frost_factor_max
    call copy_soil_temperature_profile(thawed_physical%soil_temperature, thaw_temperature, status)
    call require(status == 0, 'thawed backend profile available')
    allocate(thaw_factor(size(thaw_temperature)))
    frost_parameters%active = .true.
    frost_parameters%reduction_start_c = 0.0_real64
    frost_parameters%reduction_end_c = -2.0_real64
    call evaluate_frost_hydraulic_factor(frost_parameters, thaw_temperature, thaw_factor, status)
    call require(status == 0 .and. maxval(thaw_factor) > 0.0_real64, &
         'warming interval recomputes a thawed frost factor from committed thermal profile')
    write(*,'(A,ES14.6)') 'PPA-WU05B_THAWED_PROFILE_FACTOR_MAX=',maxval(thaw_factor)
    call execute_case(2, 0.0_real64, 0.0_real64, -999999.0_real64, 5.0_real64, .false., .true., &
         refreeze_output, refreeze_observation, .true., -4.0_real64, refrozen_physical, &
         start_time=1.0_real64, initial_physical_state=thawed_physical, frost_surface_temperature=-5.0_real64)
    call require(refreeze_output%committed .and. refreeze_observation%frost_hydraulic_executed, &
         'thawed committed backend state executes subsequent freezing interval')
    call copy_soil_temperature_profile(refrozen_physical%soil_temperature, thaw_temperature, status)
    call require(status == 0, 'refrozen backend profile available')
    call evaluate_frost_hydraulic_factor(frost_parameters, thaw_temperature, thaw_factor, status)
    call require(status == 0 .and. maxval(thaw_factor) < 1.0_real64, &
         'freeze-thaw cycle recomputes a reduced factor from refrozen committed temperature')
    write(*,'(A,ES14.6)') 'PPA-WU05B_REFROZEN_PROFILE_FACTOR_MAX=',maxval(thaw_factor)
    write(*,'(A)') 'PPA-WU05B_BACKEND_FREEZE_THAW_CYCLE=PASS'
    write(*,'(A)') 'PPA-WU05B_BACKEND_FROST_REGIMES=PASS'
  end subroutine verify_frost_backend_regimes

  subroutine verify_committed_frost_restart()
    type(fmr_serialized_reference_backend_t) :: backend
    type(kernel_executor_t) :: transaction_control
    type(kernel_committed_state_t) :: committed, source_registry(1), restored_registry(1)
    type(fmr_logical_column_t) :: column, columns(1)
    type(fmr_template_t) :: template, templates(1)
    type(fmr_b110_physical_parameters_t) :: parameters
    type(fmr_b110_physical_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fmr_column_diagnostics_t) :: diagnostic
    type(fmr_serialized_batch_diagnostics_t) :: runtime
    type(fmr_serialized_column_result_t) :: output
    type(fmr_serialized_physical_observation_t) :: observation
    type(fixed_flux_top_boundary_provider_t), target :: top
    type(fmr_committed_restart_bundle_t) :: before, after
    real(real64), allocatable :: original_profile(:), restored_profile(:)
    real(real64), allocatable :: original_factor(:), restored_factor(:)
    real(real64) :: restored_time
    integer :: status, active_physical_calls
    logical :: ok, exported, restored

    call initialize_parameters(parameters, 2)
    call enable_bounded_frost(parameters)
    call initialize_committed(committed, parameters, .true., ok)
    call require(ok, 'restart fixture committed-state initialization')
    call initialize_forcing(forcing, 0.0_real64, 0.0_real64, -999999.0_real64)
    allocate(forcing%soil_temperature)
    forcing%soil_temperature%prescribed_surface_temperature_c = -1.0_real64
    template%template_id = 440001_int64
    template%physics_topology_id = 440002_int64
    template%vertical_layout_id = 440003_int64
    template%state_layout_id = 440004_int64
    template%solver_interface_id = 440005_int64
    template%optional_state_layout_id = FMR_OPTIONAL_STATE_LAYOUT_RESTRICTED_SOIL_TEMPERATURE
    template%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
    column%column_id = column_id
    column%template_id = template%template_id
    column%parameter_ref = 1_int64
    column%state_handle = 1_int64
    column%forcing_handle = 1_int64
    column%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
    config%transaction%temporal_mode = TX_TEMPORAL_EXTERNAL_FULL_HALF
    config%transaction%temporal_tolerance = 1.0e-6_real64
    config%transaction%max_retries = 8
    config%transaction%mass_tolerance = hard_mass_gate
    config%transaction%retry_scale = 0.5_real64
    config%max_committed_substeps = 32
    output = fmr_serialized_column_result_t()
    output%column_id = column_id
    output%requested_t0 = 0.0_real64
    output%requested_t1 = equilibrium_dt
    diagnostic = fmr_column_diagnostics_t()
    diagnostic%column_id = column_id
    runtime = fmr_serialized_batch_diagnostics_t()
    active_physical_calls = 0
    call backend%initialize(top)
    call fmr_execute_serialized_resolved_physical_column(backend, transaction_control, column, template, parameters, &
         forcing, committed, config, 0.0_real64, equilibrium_dt, output, diagnostic, runtime, active_physical_calls)
    call require(output%committed, 'restart source frost runtime committed')
    observation = backend%observation()
    call require(observation%frost_hydraulic_executed, 'restart source executes frost decorator')
    source_registry(1) = committed
    columns(1) = column
    templates(1) = template
    call fmr_export_committed_restart(columns, templates, source_registry, parameters%parameter_set_id, &
         before, exported, status)
    call require(exported .and. status == FMR_RESTART_OK, 'backend committed frost restart export')
    call require(before%records(1)%revision == output%final_revision .and. &
         abs(before%records(1)%committed_time-equilibrium_dt) <= 8.0_real64*epsilon(1.0_real64), &
         'restart exports committed revision and time')
    call require(fmr_restart_template_identity_matches(before%records(1)%template_identity, templates(1)), &
         'restart template and optional frost temperature layout identity')
    call require(before%records(1)%lineage_id > 0_int64 .and. before%records(1)%time_bound, &
         'restart exports lineage and bound-time identity')
    call extract_frost_profile(before, original_profile)
    call require(size(original_profile) == numnod, 'restart source optional temperature layout preserved')
    allocate(original_factor(numnod), restored_factor(numnod))
    call evaluate_frost_hydraulic_factor(parameters%frost_hydraulic, original_profile, original_factor, status)
    call require(status == 0, 'restart source frost factor recomputed')
    call fmr_restore_committed_restart(before, parameters%parameter_set_id, columns, templates, &
         restored_registry, restored, status)
    call require(restored .and. status == FMR_RESTART_OK .and. restored_registry(1)%ready(), &
         'restore frost restart into empty registry')
    call require(restored_registry(1)%current_lineage_id() == before%records(1)%lineage_id .and. &
         restored_registry(1)%current_revision() == before%records(1)%revision, 'restored lineage and revision')
    call restored_registry(1)%current_time(restored_time, ok)
    call require(ok .and. abs(restored_time-before%records(1)%committed_time) <= &
         8.0_real64*epsilon(1.0_real64), 'restored committed time')
    call fmr_export_committed_restart(columns, templates, restored_registry, parameters%parameter_set_id, &
         after, exported, status)
    call require(exported .and. status == FMR_RESTART_OK, 're-export restored committed state')
    call extract_frost_profile(after, restored_profile)
    call require(all(original_profile == restored_profile), 'restored temperature profile matches committed profile')
    call evaluate_frost_hydraulic_factor(parameters%frost_hydraulic, restored_profile, restored_factor, status)
    call require(status == 0 .and. all(original_factor == restored_factor), &
         'restart frost factor is recomputed from restored temperature profile')
    write(*,'(A)') 'PPA-WU05B_BACKEND_COMMITTED_FROST_RESTART=PASS'
  end subroutine verify_committed_frost_restart

  subroutine extract_frost_profile(bundle, profile)
    type(fmr_committed_restart_bundle_t), intent(in) :: bundle
    real(real64), allocatable, intent(out) :: profile(:)
    integer :: status
    select type (physical => bundle%records(1)%physical_state)
    type is (fmr_b110_physical_state_t)
      call require(allocated(physical%soil_temperature), 'restart carries optional sensible-temperature state')
      call copy_soil_temperature_profile(physical%soil_temperature, profile, status)
      call require(status == 0, 'restart temperature profile decodes')
    class default
      call require(.false., 'restart physical state has bounded frost runtime type')
    end select
  end subroutine extract_frost_profile

  subroutine verify_equilibrium_mode2(q)
    real(real64), intent(in) :: q
    type(fmr_serialized_column_result_t) :: output
    type(fmr_serialized_physical_observation_t) :: observation
    call execute_case(2, q, q, -999999.0_real64, equilibrium_dt, .false., .false., output, observation)
    call require(output%completed .and. output%committed, 'mode2 equilibrium committed')
    call require(output%mass%complete, 'mode2 equilibrium mass complete')
    call require(abs(output%mass%residual) <= hard_mass_gate, 'mode2 equilibrium hard mass gate')
    call require(observation%solver_executed, 'mode2 equilibrium solver executed')
    call require(same_bits(observation%bottom_flux, q), 'mode2 equilibrium qbot request identity')
    call require(output%final_revision == 1_int64, 'mode2 equilibrium exactly one external commit')
    call require(output%accepted_substeps == 1, 'mode2 equilibrium one accepted substep')
    write(*,'(A,ES26.17E3)') 'FMR44R_MODE2_EQUILIBRIUM_MASS_RESIDUAL=', output%mass%residual
    write(*,'(A)') 'FMR44R_MODE2_EQUILIBRIUM_TRANSACTION=PASS'
  end subroutine verify_equilibrium_mode2

  subroutine verify_positive_bottom_inflow(q)
    real(real64), intent(in) :: q
    type(fmr_serialized_column_result_t) :: output
    type(fmr_serialized_physical_observation_t) :: observation
    real(real64) :: scale
    call execute_case(2, q, q, 777777.0_real64, upward_dt, .true., .true., output, observation)
    if (.not. output%committed) then
      write(*,'(A,L1,A,L1,A,I0,A,I0,A,A)') 'FMR44R_UPWARD_DEBUG completed=',output%completed, &
           ' committed=',output%committed,' kernel_status=',output%kernel_status,' accepted_substeps=', &
           output%accepted_substeps,' admission=',trim(output%admission_status)
      write(*,'(A,L1,A,L1,A,L1,A,ES26.17E3,A,ES26.17E3,A,A)') 'FMR44R_CERT_DEBUG enabled=', &
           observation%temporal_indicator_enabled, ' budget_valid=', observation%temporal_head_budget_valid, &
           ' available=', observation%temporal_certificate_available, ' Binf=', observation%temporal_head_inf_bound, &
           ' Ch=', observation%temporal_normalized_indicator, ' reason=', &
           trim(observation%temporal_certificate_unavailable_reason)
    end if
    call require(output%completed .and. output%committed, 'positive qbot transaction committed')
    call require(output%mass%complete, 'positive qbot mass complete')
    call require(abs(output%mass%residual) <= hard_mass_gate, 'positive qbot hard mass gate')
    call require(observation%solver_executed, 'positive qbot solver executed')
    call require(same_bits(observation%bottom_flux, q), 'positive qbot solver result equals requested flux')
    call require(observation%bottom_flux > 0.0_real64, 'positive qbot is lower-boundary inflow')
    call require(output%mass%total_in > 0.0_real64 .and. output%mass%total_out > 0.0_real64, &
         'positive qbot throughflow has explicit in and out')
    call require(output%accepted_substeps == 1, 'positive qbot accepted without retry subdivision')
    call require(output%final_revision == 1_int64, 'positive qbot exactly one external commit')
    call require(output%solver_headcalc_calls == 1, 'positive qbot one principal HeadCalc trajectory')

    call require(observation%temporal_indicator_enabled, 'positive qbot temporal history service enabled')
    call require(observation%temporal_previous_derivative_available, 'positive qbot predecessor history available')
    call require(observation%temporal_current_derivative_available, 'positive qbot current derivative materialized')
    call require(observation%temporal_head_budget_supplied .and. observation%temporal_head_budget_valid, &
         'positive qbot explicit head budget supplied and valid')
    call require(same_bits(observation%temporal_head_budget, qualification_head_budget), &
         'positive qbot qualification budget exact')
    call require(observation%temporal_certificate_available, 'positive qbot temporal certificate available')
    call require(trim(observation%temporal_certificate_unavailable_reason) == 'available', &
         'positive qbot certificate reason available')
    call require(ieee_is_finite(observation%temporal_head_inf_bound) .and. &
         observation%temporal_head_inf_bound >= 0.0_real64 .and. &
         observation%temporal_head_inf_bound <= qualification_head_budget, &
         'positive qbot Binf within explicit qualification budget')
    scale = max(1.0_real64,abs(expected_upward_binf),abs(observation%temporal_head_inf_bound))
    call require(abs(observation%temporal_head_inf_bound-expected_upward_binf) <= &
         65536.0_real64*epsilon(1.0_real64)*scale, 'serialized Binf matches F-SI38 production oracle')
    call require(ieee_is_finite(observation%temporal_normalized_indicator) .and. &
         observation%temporal_normalized_indicator > 0.0_real64 .and. &
         observation%temporal_normalized_indicator < 1.0_real64, 'positive qbot normalized certificate accepted')
    call require(observation%temporal_additional_tridiagonal_solves == 1, &
         'positive qbot certificate one defect tridiagonal solve')
    call require(observation%temporal_additional_full_nonlinear_solves == 0, &
         'positive qbot certificate no extra full nonlinear trajectory')

    write(*,'(A,ES26.17E3,A,ES26.17E3,A,ES26.17E3)') 'FMR44R_POSITIVE_QBOT_MASS residual=', &
         output%mass%residual, ' total_in=', output%mass%total_in, ' total_out=', output%mass%total_out
    write(*,'(A,ES26.17E3,A,ES26.17E3)') 'FMR44R_POSITIVE_QBOT_CERTIFICATE Binf=', &
         observation%temporal_head_inf_bound, ' Ch=', observation%temporal_normalized_indicator
    write(*,'(A)') 'FMR44R_POSITIVE_QBOT_ACCEPTED_INFLOW=PASS'
  end subroutine verify_positive_bottom_inflow

  subroutine verify_unowned_mode_rejected(q)
    real(real64), intent(in) :: q
    type(fmr_serialized_column_result_t) :: output
    type(fmr_serialized_physical_observation_t) :: observation
    call execute_case(6, q, q, 0.0_real64, equilibrium_dt, .false., .false., output, observation)
    call require(.not. output%committed, 'unowned mode no commit')
    call require(output%final_revision == 0_int64, 'unowned mode revision unchanged')
    call require(.not. observation%solver_executed, 'unowned mode solver not executed')
    write(*,'(A)') 'FMR44R_NEARBY_BOTTOM_MODE_FAIL_CLOSED=PASS'
  end subroutine verify_unowned_mode_rejected

  subroutine execute_case(bottom_mode, top_flux, bottom_flux, bottom_head, duration, use_certificate, hydrostatic, &
                          output, observation, frost_case, frost_temperature, final_physical_state, final_diagnostic, &
                          start_time, initial_physical_state, frost_surface_temperature)
    integer, intent(in) :: bottom_mode
    real(real64), intent(in) :: top_flux, bottom_flux, bottom_head, duration
    logical, intent(in) :: use_certificate, hydrostatic
    type(fmr_serialized_column_result_t), intent(out) :: output
    type(fmr_serialized_physical_observation_t), intent(out) :: observation
    logical, intent(in), optional :: frost_case
    real(real64), intent(in), optional :: frost_temperature
    type(fmr_b110_physical_state_t), intent(out), optional :: final_physical_state
    type(fmr_column_diagnostics_t), intent(out), optional :: final_diagnostic
    real(real64), intent(in), optional :: start_time
    type(fmr_b110_physical_state_t), intent(in), optional :: initial_physical_state
    real(real64), intent(in), optional :: frost_surface_temperature
    class(transaction_state_t), allocatable :: snapshot
    type(fmr_serialized_reference_backend_t) :: backend
    type(kernel_executor_t) :: transaction_control
    type(kernel_committed_state_t) :: committed
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    type(fmr_b110_physical_parameters_t) :: parameters
    type(fmr_b110_physical_forcing_t) :: forcing
    type(canonical_numerical_config_t) :: config
    type(fmr_column_diagnostics_t) :: diagnostic
    type(fmr_serialized_batch_diagnostics_t) :: runtime
    type(fixed_flux_top_boundary_provider_t), target :: top
    integer :: active_physical_calls
    logical :: ok
    real(real64) :: t0

    call initialize_parameters(parameters, bottom_mode)
    if (present(frost_case)) then
      if (frost_case) call enable_bounded_frost(parameters)
    end if
    if (use_certificate) then
      call initialize_temporal_committed(committed, parameters, hydrostatic, ok)
    else
    t0 = 0.0_real64
    if (present(start_time)) t0 = start_time
    if (present(initial_physical_state)) then
      call fmr_new_b110_committed_state(committed, column_id, initial_physical_state, t0, ok)
    else
      call initialize_committed(committed, parameters, hydrostatic, ok, frost_temperature, t0)
    end if
    end if
    call require(ok, 'committed state initialization')
    call initialize_forcing(forcing, top_flux, bottom_flux, bottom_head)
    if (parameters%soil_temperature_active) then
      allocate(forcing%soil_temperature)
      forcing%soil_temperature%prescribed_surface_temperature_c = -4.0_real64
      if (present(frost_temperature)) forcing%soil_temperature%prescribed_surface_temperature_c = frost_temperature
      if (present(frost_surface_temperature)) &
           forcing%soil_temperature%prescribed_surface_temperature_c = frost_surface_temperature
    end if

    template%template_id = 440001_int64
    template%physics_topology_id = 440002_int64
    template%vertical_layout_id = 440003_int64
    template%state_layout_id = 440004_int64
    template%solver_interface_id = 440005_int64
    template%optional_state_layout_id = 0_int64
    if (parameters%soil_temperature_active) &
         template%optional_state_layout_id = FMR_OPTIONAL_STATE_LAYOUT_RESTRICTED_SOIL_TEMPERATURE
    if (use_certificate) then
      template%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
    else
      template%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_NONE
    end if
    template%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE

    column%column_id = column_id
    column%template_id = template%template_id
    column%parameter_ref = 1_int64
    column%state_handle = 1_int64
    column%forcing_handle = 1_int64
    column%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE

    if (use_certificate) then
      config%transaction%temporal_mode = TX_TEMPORAL_MODEL_CERTIFICATE
      config%transaction%temporal_tolerance = 0.0_real64
      config%transaction%max_retries = 8
      config%model_temporal_indicator_budget_available = .true.
      config%model_temporal_indicator_budget = qualification_head_budget
    else
      config%transaction%temporal_mode = TX_TEMPORAL_EXTERNAL_FULL_HALF
      config%transaction%temporal_tolerance = 1.0e-6_real64
      config%transaction%max_retries = 8
      config%model_temporal_indicator_budget_available = .false.
      config%model_temporal_indicator_budget = 0.0_real64
    end if
    config%transaction%mass_tolerance = hard_mass_gate
    config%transaction%retry_scale = 0.5_real64
    config%max_committed_substeps = 32
    config%progress_tolerance = 0.0_real64

    output = fmr_serialized_column_result_t()
    output%column_id = column_id
    output%requested_t0 = t0
    output%requested_t1 = t0 + duration
    diagnostic = fmr_column_diagnostics_t()
    diagnostic%column_id = column_id
    runtime = fmr_serialized_batch_diagnostics_t()
    active_physical_calls = 0

    call backend%initialize(top)
    call fmr_execute_serialized_resolved_physical_column(backend, transaction_control, column, template, parameters, &
         forcing, committed, config, t0, t0+duration, output, diagnostic, runtime, active_physical_calls)
    observation = backend%observation()
    if (present(final_diagnostic)) final_diagnostic = diagnostic
    if (present(final_physical_state)) then
      call committed%snapshot(snapshot, ok)
      call require(ok, 'capture final committed physical state')
      select type (state => snapshot)
      type is (fmr_b110_physical_state_t)
        final_physical_state = state
      class default
        call require(.false., 'final committed state has base physical layout')
      end select
    end if
  end subroutine execute_case

  subroutine initialize_parameters(parameters, bottom_mode)
    type(fmr_b110_physical_parameters_t), intent(out) :: parameters
    integer, intent(in) :: bottom_mode
    integer :: k
    parameters%parameter_set_id = 440044_int64
    parameters%active_nodes = numnod
    allocate(parameters%z(numnod), parameters%dz(numnod), parameters%node_distance(numnod), parameters%cofgen(24,numnod))
    parameters%z = z
    parameters%dz = dz
    parameters%node_distance = disnod(1:numnod)
    parameters%cofgen = 0.0_real64
    do k = 1, numnod
      parameters%cofgen(1,k)=0.032_real64; parameters%cofgen(2,k)=0.423_real64; parameters%cofgen(3,k)=4.75_real64
      parameters%cofgen(4,k)=0.0135_real64; parameters%cofgen(5,k)=0.365_real64; parameters%cofgen(6,k)=1.455_real64
      parameters%cofgen(7,k)=1.0_real64-1.0_real64/parameters%cofgen(6,k); parameters%cofgen(8,k)=parameters%cofgen(4,k)
      parameters%cofgen(9,k)=0.0_real64; parameters%cofgen(10,k)=parameters%cofgen(3,k); parameters%cofgen(11,k)=0.999_real64
      parameters%cofgen(12,k)=0.99_real64*parameters%cofgen(3,k); parameters%cofgen(22,k)=-1.0e6_real64
      parameters%cofgen(23,k)=1.0e-12_real64
    end do
    parameters%bottom_mode = bottom_mode
    parameters%swkimpl = 0
    parameters%swkmean = 1
    parameters%swsophy = 0
    parameters%max_iterations = 16
    parameters%max_backtracking = 8
    parameters%min_step_duration = 1.0e-8_real64
    parameters%compartment_balance_tolerance = 1.0e-12_real64
    parameters%total_balance_tolerance = 1.0e-12_real64
    parameters%head_abs_tolerance = 1.0e-12_real64
    parameters%head_rel_tolerance = 1.0e-12_real64
    parameters%ponding_tolerance = 1.0e-12_real64
    parameters%root_extraction_active = .false.
    parameters%macropore_active = .false.
    parameters%snow_active = .false.
    parameters%hysteresis_active = .false.
    parameters%tabulated_hydraulics_active = .false.
    parameters%elasticity_active = .false.
    parameters%frost_active = .false.
    parameters%soil_temperature_active = .false.
  end subroutine initialize_parameters

  subroutine enable_bounded_frost(parameters)
    type(fmr_b110_physical_parameters_t), intent(inout) :: parameters
    real(real64) :: theta_sat(numnod), quartz(numnod), clay(numnod), organic(numnod)
    integer :: status
    parameters%frost_active = .true.
    parameters%frost_hydraulic%active = .true.
    parameters%frost_hydraulic%reduction_start_c = 0.0_real64
    parameters%frost_hydraulic%reduction_end_c = -2.0_real64
    parameters%soil_temperature_active = .true.
    allocate(parameters%soil_temperature)
    theta_sat = 0.45_real64
    quartz = 0.60_real64
    clay = 0.20_real64
    organic = 0.05_real64
    call initialize_soil_temperature_parameters(parameters%dz, parameters%node_distance, theta_sat, quartz, clay, &
         organic, parameters%soil_temperature, status)
    call require(status == 0, 'sensible-temperature parameter fixture')
  end subroutine enable_bounded_frost

  subroutine initialize_committed(committed, parameters, hydrostatic, ok, frost_temperature, initial_time)
    type(kernel_committed_state_t), intent(out) :: committed
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters
    logical, intent(in) :: hydrostatic
    logical, intent(out) :: ok
    real(real64), intent(in), optional :: frost_temperature
    real(real64), intent(in), optional :: initial_time
    type(fmr_b110_physical_state_t) :: state
    call initialize_physical_state(parameters, hydrostatic, state, frost_temperature)
    if (present(initial_time)) then
      call fmr_new_b110_committed_state(committed, column_id, state, initial_time, ok)
    else
      call fmr_new_b110_committed_state(committed, column_id, state, 0.0_real64, ok)
    end if
  end subroutine initialize_committed

  subroutine initialize_temporal_committed(committed, parameters, hydrostatic, ok)
    type(kernel_committed_state_t), intent(out) :: committed
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters
    logical, intent(in) :: hydrostatic
    logical, intent(out) :: ok
    type(fmr_b110_physical_state_t) :: state
    real(real64) :: accepted_predecessor_right_derivative(numnod)
    call initialize_physical_state(parameters, hydrostatic, state)
    call require(hydrostatic, 'certificate fixture must use hydrostatic predecessor')
    accepted_predecessor_right_derivative = 0.0_real64
    call fmr_new_b110_temporal_indicator_committed_state(committed, column_id, state, 0.0_real64, ok, &
         accepted_predecessor_right_derivative)
  end subroutine initialize_temporal_committed

  subroutine initialize_physical_state(parameters, hydrostatic, state, frost_temperature)
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters
    logical, intent(in) :: hydrostatic
    type(fmr_b110_physical_state_t), intent(out) :: state
    real(real64), intent(in), optional :: frost_temperature
    type(b110_default_mvg_parameters_t), target :: hp
    type(b110_default_mvg_provider_t) :: provider
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    real(real64) :: gradient
    integer :: i
    real(real64) :: initial_temperature

    call initialize_b110_default_mvg_parameters(hp, parameters%cofgen)
    call bind_b110_default_mvg_provider(provider, hp, merge(upward_dt,equilibrium_dt,hydrostatic))
    if (hydrostatic) then
      heads(1) = h0
      do i = 2, numnod
        heads(i) = heads(i-1) + parameters%node_distance(i)
        gradient = (heads(i-1)-heads(i))/parameters%node_distance(i) + 1.0_real64
        call require(abs(gradient) <= 16.0_real64*epsilon(1.0_real64), 'hydrostatic zero internal gradient')
      end do
    else
      heads = h0
    end if
    call provider%evaluate(heads, water, conductivity, capacity, dkdh)
    state%active_nodes = numnod
    allocate(state%pressure_head(numnod), state%water_content(numnod))
    state%pressure_head = heads
    state%water_content = water
    state%ponding_depth = 0.0_real64
    state%groundwater_level = -2.0_real64
    if (parameters%soil_temperature_active) then
      initial_temperature = -4.0_real64
      if (present(frost_temperature)) initial_temperature = frost_temperature
      allocate(state%soil_temperature)
      call initialize_soil_temperature_state([initial_temperature,initial_temperature,initial_temperature,initial_temperature], &
           state%soil_temperature, i)
      call require(i == 0, 'initial soil-temperature state')
    end if
  end subroutine initialize_physical_state

  subroutine initialize_forcing(forcing, top_flux, bottom_flux, bottom_head)
    type(fmr_b110_physical_forcing_t), intent(out) :: forcing
    real(real64), intent(in) :: top_flux, bottom_flux, bottom_head
    forcing%top_flux = top_flux
    forcing%top_head = h0
    forcing%bottom_flux = bottom_flux
    forcing%bottom_head = bottom_head
    allocate(forcing%drainage_flux_by_level(1,numnod), forcing%subsurface_irrigation_source(numnod), &
         forcing%root_extraction_sink(numnod))
    forcing%drainage_flux_by_level = 0.0_real64
    forcing%subsurface_irrigation_source = 0.0_real64
    forcing%root_extraction_sink = 0.0_real64
  end subroutine initialize_forcing

  subroutine determine_initial_conductivity(k)
    real(real64), intent(out) :: k
    type(fmr_b110_physical_parameters_t) :: parameters
    type(b110_default_mvg_parameters_t), target :: hp
    type(b110_default_mvg_provider_t) :: provider
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    call initialize_parameters(parameters, 2)
    call initialize_b110_default_mvg_parameters(hp, parameters%cofgen)
    call bind_b110_default_mvg_provider(provider, hp, equilibrium_dt)
    heads = h0
    call provider%evaluate(heads, water, conductivity, capacity, dkdh)
    k = conductivity(1)
  end subroutine determine_initial_conductivity

  pure logical function same_bits(a, b)
    real(real64), intent(in) :: a, b
    same_bits = transfer(a, 0_int64) == transfer(b, 0_int64)
  end function same_bits

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FMR44R_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fmr44r_serialized_prescribed_qbot_runtime
