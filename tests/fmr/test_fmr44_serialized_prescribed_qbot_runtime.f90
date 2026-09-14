program test_fmr44_serialized_prescribed_qbot_runtime
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: TX_TEMPORAL_EXTERNAL_FULL_HALF
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_executor_t, kernel_committed_state_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       FMR_BACKEND_SERIALIZED_REFERENCE, FMR_NUMERICAL_CONTINUATION_NONE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, fmr_serialized_physical_observation_t, &
       fmr_new_b110_committed_state
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, &
       fmr_serialized_batch_diagnostics_t, fmr_execute_serialized_resolved_physical_column
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_fmr04_fixed_top_provider, only: fmr04_fixed_flux_top_provider_t
  implicit none

  real(real64), parameter :: h0 = -75.0_real64
  real(real64), parameter :: equilibrium_dt = 0.25_real64
  real(real64), parameter :: upward_dt = 1.0e-4_real64
  real(real64), parameter :: hard_mass_gate = 1.0e-10_real64
  integer(int64), parameter :: column_id = 440044_int64
  real(real64) :: k0, qeq, qup

  call determine_initial_conductivity(k0)
  qeq = -k0
  qup = min(1.0e-10_real64, 1.0e-6_real64*k0)
  call require(k0 > 0.0_real64 .and. ieee_is_finite(k0), 'initial conductivity finite positive')
  call require(qup > 0.0_real64 .and. ieee_is_finite(qup), 'positive inflow fixture finite positive')

  call verify_equilibrium_mode2(qeq)
  call verify_positive_bottom_inflow(qup)
  call verify_unowned_mode_rejected(qeq)

  write(*,'(A,ES26.17E3)') 'FMR44_QEQ=', qeq
  write(*,'(A,ES26.17E3)') 'FMR44_POSITIVE_QBOT=', qup
  write(*,'(A)') 'FMR44_SERIALIZED_PRESCRIBED_QBOT_RUNTIME_GATE PASS'

contains

  subroutine verify_equilibrium_mode2(q)
    real(real64), intent(in) :: q
    type(fmr_serialized_column_result_t) :: output
    type(fmr_serialized_physical_observation_t) :: observation
    call execute_case(2, q, q, -999999.0_real64, equilibrium_dt, output, observation)
    call require(output%completed .and. output%committed, 'mode2 equilibrium committed')
    call require(output%mass%complete, 'mode2 equilibrium mass complete')
    call require(abs(output%mass%residual) <= hard_mass_gate, 'mode2 equilibrium hard mass gate')
    call require(observation%solver_executed, 'mode2 equilibrium solver executed')
    call require(same_bits(observation%bottom_flux, q), 'mode2 equilibrium qbot request identity')
    call require(output%final_revision == 1_int64, 'mode2 equilibrium exactly one external commit')
    write(*,'(A,ES26.17E3)') 'FMR44_MODE2_EQUILIBRIUM_MASS_RESIDUAL=', output%mass%residual
    write(*,'(A)') 'FMR44_MODE2_EQUILIBRIUM_TRANSACTION=PASS'
  end subroutine verify_equilibrium_mode2

  subroutine verify_positive_bottom_inflow(q)
    real(real64), intent(in) :: q
    type(fmr_serialized_column_result_t) :: output
    type(fmr_serialized_physical_observation_t) :: observation
    call execute_case(2, q, q, 777777.0_real64, upward_dt, output, observation)
    if (.not. output%committed) then
      write(*,'(A,L1,A,L1,A,I0,A,I0,A,A)') 'FMR44_UPWARD_DEBUG completed=',output%completed, &
           ' committed=',output%committed,' kernel_status=',output%kernel_status,' accepted_substeps=', &
           output%accepted_substeps,' failure=',trim(output%admission_status)
    end if
    call require(output%completed .and. output%committed, 'positive qbot transaction committed')
    call require(output%mass%complete, 'positive qbot mass complete')
    call require(abs(output%mass%residual) <= hard_mass_gate, 'positive qbot hard mass gate')
    call require(observation%solver_executed, 'positive qbot solver executed')
    call require(same_bits(observation%bottom_flux, q), 'positive qbot solver result equals requested flux')
    call require(observation%bottom_flux > 0.0_real64, 'positive qbot is lower-boundary inflow')
    call require(output%mass%total_in > 0.0_real64 .and. output%mass%total_out > 0.0_real64, &
         'positive qbot throughflow has explicit in and out')
    call require(output%final_revision == 1_int64, 'positive qbot exactly one external commit')
    write(*,'(A,ES26.17E3,A,ES26.17E3,A,ES26.17E3)') 'FMR44_POSITIVE_QBOT_MASS residual=', &
         output%mass%residual, ' total_in=', output%mass%total_in, ' total_out=', output%mass%total_out
    write(*,'(A)') 'FMR44_POSITIVE_QBOT_ACCEPTED_INFLOW=PASS'
  end subroutine verify_positive_bottom_inflow

  subroutine verify_unowned_mode_rejected(q)
    real(real64), intent(in) :: q
    type(fmr_serialized_column_result_t) :: output
    type(fmr_serialized_physical_observation_t) :: observation
    call execute_case(6, q, q, 0.0_real64, equilibrium_dt, output, observation)
    call require(.not. output%committed, 'unowned mode no commit')
    call require(output%final_revision == 0_int64, 'unowned mode revision unchanged')
    call require(.not. observation%solver_executed, 'unowned mode solver not executed')
    write(*,'(A)') 'FMR44_NEARBY_BOTTOM_MODE_FAIL_CLOSED=PASS'
  end subroutine verify_unowned_mode_rejected

  subroutine execute_case(bottom_mode, top_flux, bottom_flux, bottom_head, duration, output, observation)
    integer, intent(in) :: bottom_mode
    real(real64), intent(in) :: top_flux, bottom_flux, bottom_head, duration
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
    type(fmr04_fixed_flux_top_provider_t), target :: top
    integer :: active_physical_calls
    logical :: ok

    call initialize_parameters(parameters, bottom_mode)
    call initialize_committed(committed, parameters, ok)
    call require(ok, 'committed state initialization')
    call initialize_forcing(forcing, top_flux, bottom_flux, bottom_head)

    template%template_id = 440001_int64
    template%physics_topology_id = 440002_int64
    template%vertical_layout_id = 440003_int64
    template%state_layout_id = 440004_int64
    template%solver_interface_id = 440005_int64
    template%optional_state_layout_id = 0_int64
    template%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_NONE
    template%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE

    column%column_id = column_id
    column%template_id = template%template_id
    column%parameter_ref = 1_int64
    column%state_handle = 1_int64
    column%forcing_handle = 1_int64
    column%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE

    config%transaction%temporal_mode = TX_TEMPORAL_EXTERNAL_FULL_HALF
    config%transaction%temporal_tolerance = 1.0e-6_real64
    config%transaction%mass_tolerance = hard_mass_gate
    config%transaction%retry_scale = 0.5_real64
    config%transaction%max_retries = 8
    config%max_committed_substeps = 32
    config%progress_tolerance = 0.0_real64

    output = fmr_serialized_column_result_t()
    output%column_id = column_id
    output%requested_t0 = 0.0_real64
    output%requested_t1 = duration
    diagnostic = fmr_column_diagnostics_t()
    diagnostic%column_id = column_id
    runtime = fmr_serialized_batch_diagnostics_t()
    active_physical_calls = 0

    call backend%initialize(top)
    call fmr_execute_serialized_resolved_physical_column(backend, transaction_control, column, template, parameters, &
         forcing, committed, config, 0.0_real64, duration, output, diagnostic, runtime, active_physical_calls)
    observation = backend%observation()
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
    parameters%max_iterations = 8
    parameters%max_backtracking = 4
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

  subroutine initialize_committed(committed, parameters, ok)
    type(kernel_committed_state_t), intent(out) :: committed
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters
    logical, intent(out) :: ok
    type(fmr_b110_physical_state_t) :: state
    type(b110_default_mvg_parameters_t), target :: hp
    type(b110_default_mvg_provider_t) :: provider
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)

    call initialize_b110_default_mvg_parameters(hp, parameters%cofgen)
    call bind_b110_default_mvg_provider(provider, hp, equilibrium_dt)
    heads = h0
    call provider%evaluate(heads, water, conductivity, capacity, dkdh)
    state%active_nodes = numnod
    allocate(state%pressure_head(numnod), state%water_content(numnod))
    state%pressure_head = heads
    state%water_content = water
    state%ponding_depth = 0.0_real64
    state%groundwater_level = -2.0_real64
    call fmr_new_b110_committed_state(committed, column_id, state, 0.0_real64, ok)
  end subroutine initialize_committed

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
      write(*,'(A,1X,A)') 'FMR44_TEST_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fmr44_serialized_prescribed_qbot_runtime