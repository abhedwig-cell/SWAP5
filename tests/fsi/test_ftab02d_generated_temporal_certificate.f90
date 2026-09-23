program test_ftab02d_generated_temporal_certificate
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_executor_t, kernel_committed_state_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       FMR_BACKEND_SERIALIZED_REFERENCE, FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, fmr_serialized_physical_observation_t, &
       fmr_new_b110_temporal_indicator_committed_state
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, &
       fmr_serialized_batch_diagnostics_t, fmr_execute_serialized_resolved_physical_column
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_generated_mvg_table_state, only: b110_generated_mvg_table_state_t, &
       initialize_b110_generated_mvg_table_state, F_TAB02_STATE_OK
  use mod_b110_generated_mvg_provider, only: b110_generated_mvg_provider_t, &
       bind_b110_generated_mvg_provider, F_TAB02_PROVIDER_OK
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  real(real64), parameter :: h0 = -75.0_real64
  real(real64), parameter :: dt = 1.0e-4_real64
  real(real64), parameter :: qbot = 1.0e-10_real64
  real(real64), parameter :: hard_mass_gate = 1.0e-12_real64
  real(real64), parameter :: qualification_head_budget = 2.5e-11_real64
  integer(int64), parameter :: column_id = 9202401_int64

  type(fmr_serialized_column_result_t) :: analytic_output, generated_output
  type(fmr_serialized_physical_observation_t) :: analytic_obs, generated_obs

  call execute_case(.false., analytic_output, analytic_obs)
  call execute_case(.true., generated_output, generated_obs)

  call require(analytic_output%completed .and. analytic_output%committed, 'analytical transaction committed')
  call require(generated_output%completed .and. generated_output%committed, 'generated transaction committed')
  call require(analytic_output%mass%complete .and. generated_output%mass%complete, 'mass ledgers complete')
  call require(abs(analytic_output%mass%residual) <= hard_mass_gate, 'analytical hard mass')
  call require(abs(generated_output%mass%residual) <= hard_mass_gate, 'generated hard mass')
  call require(analytic_output%accepted_substeps == 1 .and. generated_output%accepted_substeps == 1, &
       'one accepted substep')
  call require(analytic_output%final_revision == 1_int64 .and. generated_output%final_revision == 1_int64, &
       'one committed revision')
  call require(analytic_output%solver_headcalc_calls == 1 .and. generated_output%solver_headcalc_calls == 1, &
       'one principal HeadCalc trajectory')
  call require(analytic_output%accepted_substeps == generated_output%accepted_substeps, 'accepted-step semantics equal')

  call require_certificate(analytic_obs, 'analytical')
  call require_certificate(generated_obs, 'generated')

  write(*,'(a,es26.17e3)') 'F_TAB02_D_ANALYTIC_MASS_RESIDUAL=',analytic_output%mass%residual
  write(*,'(a,es26.17e3)') 'F_TAB02_D_GENERATED_MASS_RESIDUAL=',generated_output%mass%residual
  write(*,'(a,es26.17e3)') 'F_TAB02_D_ANALYTIC_BINF=',analytic_obs%temporal_head_inf_bound
  write(*,'(a,es26.17e3)') 'F_TAB02_D_GENERATED_BINF=',generated_obs%temporal_head_inf_bound
  write(*,'(a,es26.17e3)') 'F_TAB02_D_BINF_ABS_DIFFERENCE=', &
       abs(generated_obs%temporal_head_inf_bound-analytic_obs%temporal_head_inf_bound)
  write(*,'(a,es26.17e3)') 'F_TAB02_D_ANALYTIC_CH=',analytic_obs%temporal_normalized_indicator
  write(*,'(a,es26.17e3)') 'F_TAB02_D_GENERATED_CH=',generated_obs%temporal_normalized_indicator
  write(*,'(a)') 'F_TAB02_D_GENERATED_TEMPORAL_CERTIFICATE=PASS'
  write(*,'(a)') 'F_TAB02_D_DYNAMIC_TRANSACTION_SEMANTICS=PASS'
  write(*,'(a)') 'F-TAB02-D DYNAMIC CERTIFICATE GATE PASS'

contains

  subroutine execute_case(generated, output, observation)
    logical, intent(in) :: generated
    type(fmr_serialized_column_result_t), intent(out) :: output
    type(fmr_serialized_physical_observation_t), intent(out) :: observation
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

    call initialize_parameters(parameters, generated)
    call initialize_temporal_committed(committed, parameters, generated, ok)
    call require(ok, 'temporal committed state initialization')
    call initialize_forcing(forcing)
    call initialize_column_template(column, template)
    call initialize_config(config)

    output = fmr_serialized_column_result_t()
    output%column_id = column_id
    output%requested_t0 = 0.0_real64
    output%requested_t1 = dt
    diagnostic = fmr_column_diagnostics_t()
    diagnostic%column_id = column_id
    runtime = fmr_serialized_batch_diagnostics_t()
    active_physical_calls = 0

    call backend%initialize(top)
    call fmr_execute_serialized_resolved_physical_column(backend, transaction_control, column, template, parameters, &
         forcing, committed, config, 0.0_real64, dt, output, diagnostic, runtime, active_physical_calls)
    observation = backend%observation()

    call require(diagnostic%retries == 0, 'no transaction retry')
    call require(diagnostic%rejected == 0, 'no rejected external attempt')
  end subroutine execute_case

  subroutine initialize_parameters(parameters, generated)
    type(fmr_b110_physical_parameters_t), intent(out) :: parameters
    logical, intent(in) :: generated
    integer :: k

    parameters%parameter_set_id = 9202402_int64
    parameters%active_nodes = numnod
    allocate(parameters%z(numnod), parameters%dz(numnod), parameters%node_distance(numnod), &
         parameters%cofgen(24,numnod))
    parameters%z = z
    parameters%dz = dz
    parameters%node_distance = disnod(1:numnod)
    parameters%cofgen = 0.0_real64
    do k = 1, numnod
      parameters%cofgen(1,k)=0.032_real64
      parameters%cofgen(2,k)=0.423_real64
      parameters%cofgen(3,k)=4.75_real64
      parameters%cofgen(4,k)=0.0135_real64
      parameters%cofgen(5,k)=0.365_real64
      parameters%cofgen(6,k)=1.455_real64
      parameters%cofgen(7,k)=1.0_real64-1.0_real64/parameters%cofgen(6,k)
      parameters%cofgen(8,k)=parameters%cofgen(4,k)
      parameters%cofgen(9,k)=0.0_real64
      parameters%cofgen(10,k)=parameters%cofgen(3,k)
      parameters%cofgen(11,k)=0.999_real64
      parameters%cofgen(12,k)=0.99_real64*parameters%cofgen(3,k)
      parameters%cofgen(22,k)=-1.0e6_real64
      parameters%cofgen(23,k)=1.0e-12_real64
    end do
    parameters%bottom_mode = 2
    parameters%swkimpl = 0
    parameters%swkmean = 1
    parameters%swsophy = 0
    parameters%max_iterations = 16
    parameters%max_backtracking = 8
    parameters%min_step_duration = 1.0e-8_real64
    parameters%compartment_balance_tolerance = hard_mass_gate
    parameters%total_balance_tolerance = hard_mass_gate
    parameters%head_abs_tolerance = 1.0e-12_real64
    parameters%head_rel_tolerance = 1.0e-12_real64
    parameters%ponding_tolerance = 1.0e-12_real64
    parameters%generated_mvg_acceleration_active = generated
    parameters%tabulated_hydraulics_active = .false.
    parameters%root_extraction_active = .false.
    parameters%macropore_active = .false.
    parameters%snow_active = .false.
    parameters%hysteresis_active = .false.
    parameters%elasticity_active = .false.
    parameters%frost_active = .false.
    parameters%soil_temperature_active = .false.
  end subroutine initialize_parameters

  subroutine initialize_temporal_committed(committed, parameters, generated, ok)
    type(kernel_committed_state_t), intent(out) :: committed
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters
    logical, intent(in) :: generated
    logical, intent(out) :: ok
    type(fmr_b110_physical_state_t) :: state
    type(b110_default_mvg_parameters_t), target :: hp
    type(b110_default_mvg_provider_t) :: analytic
    type(b110_generated_mvg_table_state_t), target :: table_state
    type(b110_generated_mvg_provider_t) :: table_provider
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    real(real64) :: predecessor(numnod)
    integer :: i, status

    call initialize_b110_default_mvg_parameters(hp, parameters%cofgen)
    heads(1) = h0
    do i = 2, numnod
      heads(i) = heads(i-1) + parameters%node_distance(i)
      call require(abs((heads(i-1)-heads(i))/parameters%node_distance(i)+1.0_real64) <= &
           16.0_real64*epsilon(1.0_real64), 'hydrostatic zero internal gradient')
    end do

    if (generated) then
      call initialize_b110_generated_mvg_table_state(table_state, hp, status)
      call require(status == F_TAB02_STATE_OK .and. table_state%ready(), 'generated initial table state')
      call bind_b110_generated_mvg_provider(table_provider, table_state, dt, status)
      call require(status == F_TAB02_PROVIDER_OK .and. table_provider%ready(), 'generated initial table provider')
      call table_provider%evaluate(heads, water, conductivity, capacity, dkdh)
    else
      call bind_b110_default_mvg_provider(analytic, hp, dt)
      call analytic%evaluate(heads, water, conductivity, capacity, dkdh)
    end if

    call require(all(ieee_is_finite(water)), 'initial water finite')
    state%active_nodes = numnod
    allocate(state%pressure_head(numnod), state%water_content(numnod))
    state%pressure_head = heads
    state%water_content = water
    state%ponding_depth = 0.0_real64
    state%groundwater_level = -2.0_real64
    predecessor = 0.0_real64
    call fmr_new_b110_temporal_indicator_committed_state(committed, column_id, state, 0.0_real64, ok, predecessor)
  end subroutine initialize_temporal_committed

  subroutine initialize_forcing(forcing)
    type(fmr_b110_physical_forcing_t), intent(out) :: forcing
    forcing%top_flux = qbot
    forcing%top_head = h0
    forcing%bottom_flux = qbot
    forcing%bottom_head = 777777.0_real64
    allocate(forcing%drainage_flux_by_level(1,numnod), forcing%subsurface_irrigation_source(numnod), &
         forcing%root_extraction_sink(numnod))
    forcing%drainage_flux_by_level = 0.0_real64
    forcing%subsurface_irrigation_source = 0.0_real64
    forcing%root_extraction_sink = 0.0_real64
  end subroutine initialize_forcing

  subroutine initialize_column_template(column, template)
    type(fmr_logical_column_t), intent(out) :: column
    type(fmr_template_t), intent(out) :: template
    template%template_id = 9202410_int64
    template%physics_topology_id = 9202411_int64
    template%vertical_layout_id = 9202412_int64
    template%state_layout_id = 9202413_int64
    template%solver_interface_id = 9202414_int64
    template%optional_state_layout_id = 0_int64
    template%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
    template%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
    column%column_id = column_id
    column%template_id = template%template_id
    column%parameter_ref = 1_int64
    column%state_handle = 1_int64
    column%forcing_handle = 1_int64
    column%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine initialize_column_template

  subroutine initialize_config(config)
    type(canonical_numerical_config_t), intent(out) :: config
    config%transaction%temporal_mode = TX_TEMPORAL_MODEL_CERTIFICATE
    config%transaction%temporal_tolerance = 0.0_real64
    config%transaction%mass_tolerance = hard_mass_gate
    config%transaction%retry_scale = 0.5_real64
    config%transaction%max_retries = 8
    config%max_committed_substeps = 32
    config%progress_tolerance = 0.0_real64
    config%model_temporal_indicator_budget_available = .true.
    config%model_temporal_indicator_budget = qualification_head_budget
  end subroutine initialize_config

  subroutine require_certificate(observation, label)
    type(fmr_serialized_physical_observation_t), intent(in) :: observation
    character(len=*), intent(in) :: label
    call require(observation%solver_executed, trim(label)//' solver executed')
    call require(observation%temporal_indicator_enabled, trim(label)//' temporal indicator enabled')
    call require(observation%temporal_previous_derivative_available, trim(label)//' predecessor derivative')
    call require(observation%temporal_current_derivative_available, trim(label)//' current derivative')
    call require(observation%temporal_head_budget_supplied .and. observation%temporal_head_budget_valid, &
         trim(label)//' explicit head budget')
    call require(observation%temporal_head_budget == qualification_head_budget, trim(label)//' exact budget')
    call require(observation%temporal_certificate_available, trim(label)//' certificate available')
    call require(trim(observation%temporal_certificate_unavailable_reason) == 'available', &
         trim(label)//' certificate reason')
    call require(ieee_is_finite(observation%temporal_head_inf_bound) .and. &
         observation%temporal_head_inf_bound > 0.0_real64 .and. &
         observation%temporal_head_inf_bound <= qualification_head_budget, trim(label)//' Binf budget')
    call require(ieee_is_finite(observation%temporal_normalized_indicator) .and. &
         observation%temporal_normalized_indicator > 0.0_real64 .and. &
         observation%temporal_normalized_indicator < 1.0_real64, trim(label)//' normalized certificate')
    call require(observation%temporal_additional_tridiagonal_solves == 1, trim(label)//' one defect solve')
    call require(observation%temporal_additional_full_nonlinear_solves == 0, trim(label)//' no extra nonlinear solve')
  end subroutine require_certificate

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(a,1x,a)') 'F_TAB02_D_DYNAMIC_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_ftab02d_generated_temporal_certificate
