program test_fkt22_fmr_serialized_trajectory_runtime
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_EXTERNAL_FULL_HALF
  use mod_canonical_contracts, only: canonical_numerical_config_t, CANONICAL_STATUS_COMPLETED
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_result_t, &
       kernel_candidate_state_t, kernel_diagnostics_t
  use mod_fmr_checkpoint_orchestrator, only: fmr_capture_checkpoint
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, &
       FMR_BACKEND_SERIALIZED_REFERENCE, FMR_NUMERICAL_CONTINUATION_NONE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, &
       fmr_new_b110_committed_state
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_soil_water_accepted_step_direction_contract, only: SW_STEP_CONTROL_BOTTOM_FLUX
  implicit none

  real(real64), parameter :: h0 = -75.0_real64
  real(real64), parameter :: duration = 0.25_real64
  real(real64), parameter :: mass_tolerance = 1.0e-12_real64
  integer(int64), parameter :: column_id = 440044_int64

  type(fmr_b110_physical_parameters_t) :: parameters
  type(fmr_b110_physical_forcing_t) :: forcing
  type(fmr_logical_column_t) :: column
  type(fmr_template_t) :: template
  type(canonical_numerical_config_t) :: config_off, config_on
  type(kernel_committed_state_t) :: committed_off, committed_on
  type(kernel_checkpoint_t) :: checkpoint_off, checkpoint_on
  type(kernel_result_t) :: result_off, result_on
  type(kernel_candidate_state_t) :: candidate_off, candidate_on
  type(kernel_diagnostics_t) :: diagnostics_off, diagnostics_on
  type(fmr_serialized_reference_backend_t) :: backend_off, backend_on
  type(fixed_flux_top_boundary_provider_t), target :: top
  class(transaction_state_t), allocatable :: snapshot_off, snapshot_on
  real(real64) :: k0, qeq
  logical :: ok, available_off, available_on

  call initialize_parameters(parameters)
  call determine_initial_conductivity(parameters, k0)
  qeq = -k0
  call initialize_forcing(forcing, qeq)
  call initialize_column_and_template(column, template)
  call initialize_config(config_off, .false.)
  call initialize_config(config_on, .true.)

  call initialize_committed(committed_off, parameters, ok)
  call require(ok, 'default-off committed state initialized')
  call initialize_committed(committed_on, parameters, ok)
  call require(ok, 'requested committed state initialized')
  call fmr_capture_checkpoint(committed_off, checkpoint_off, ok)
  call require(ok, 'default-off checkpoint captured')
  call fmr_capture_checkpoint(committed_on, checkpoint_on, ok)
  call require(ok, 'requested checkpoint captured')

  call backend_off%initialize(top)
  call backend_on%initialize(top)

  call backend_off%run_trial(column, template, parameters, committed_off, forcing, config_off, &
       0.0_real64, duration, checkpoint_off, result_off, candidate_off, diagnostics_off)
  call backend_on%run_trial(column, template, parameters, committed_on, forcing, config_on, &
       0.0_real64, duration, checkpoint_on, result_on, candidate_on, diagnostics_on)

  call require(result_off%status == CANONICAL_STATUS_COMPLETED .and. result_off%completed, &
       'default-off production interval completed')
  call require(result_on%status == CANONICAL_STATUS_COMPLETED .and. result_on%completed, &
       'requested production interval completed')
  call require(candidate_off%ready() .and. candidate_on%ready(), 'both candidates materialized')
  call require(diagnostics_off%retries == 0 .and. diagnostics_on%retries == 0, &
       'equilibrium fixture accepted without retry')
  call require(result_off%mass%complete .and. result_on%mass%complete, 'both mass ledgers complete')
  call require(abs(result_off%mass%residual) <= mass_tolerance .and. &
       abs(result_on%mass%residual) <= mass_tolerance, 'both hard mass gates pass')

  call require(.not. result_off%accepted_trajectory_direction%requested, &
       'default-off publication not requested')
  call require(.not. result_off%accepted_trajectory_direction%available, &
       'default-off publication unavailable')
  call require(.not. allocated(result_off%accepted_trajectory_direction%final_pressure_head_direction) .and. &
       .not. allocated(result_off%accepted_trajectory_direction%final_water_content_direction), &
       'default-off publication has no direction vectors')
  write(*,'(A)') 'FKT22_FMR_TRAJECTORY_DEFAULT_OFF=PASS'

  call require(result_on%accepted_trajectory_direction%requested, 'trajectory request provenance retained')
  call require(result_on%accepted_trajectory_direction%available, 'accepted trajectory publication available')
  call require(result_on%accepted_trajectory_direction%worker_id == int(column_id), 'worker provenance retained')
  call require(result_on%accepted_trajectory_direction%generation > 0_int64, 'positive trajectory generation')
  call require(result_on%accepted_trajectory_direction%control_coordinate == SW_STEP_CONTROL_BOTTOM_FLUX, &
       'bottom-flux control provenance retained')
  call require(same_bits(result_on%accepted_trajectory_direction%origin_t0, 0.0_real64) .and. &
       same_bits(result_on%accepted_trajectory_direction%accepted_t1, duration), &
       'whole-window interval provenance retained')
  call require(trim(result_on%accepted_trajectory_direction%route) == 'accepted-trajectory', &
       'whole-window route finalized')
  call require(result_on%accepted_trajectory_direction%accepted_steps == 2, &
       'two-half accepted route publishes exactly two physical accepted steps')
  call require(result_on%accepted_trajectory_direction%additional_tridiagonal_backsolves == 2, &
       'publication counts only accepted-route tangent backsolves')
  call require(result_on%accepted_trajectory_direction%additional_jacobian_builds == 0 .and. &
       result_on%accepted_trajectory_direction%additional_full_nonlinear_solves == 0, &
       'accepted derivative adds no jacobian or nonlinear solve')
  call require(allocated(result_on%accepted_trajectory_direction%final_pressure_head_direction) .and. &
       allocated(result_on%accepted_trajectory_direction%final_water_content_direction), &
       'published direction vectors allocated')
  call require(size(result_on%accepted_trajectory_direction%final_pressure_head_direction) == numnod .and. &
       size(result_on%accepted_trajectory_direction%final_water_content_direction) == numnod, &
       'published direction vectors have physical shape')
  call require(all(ieee_is_finite(result_on%accepted_trajectory_direction%final_pressure_head_direction)) .and. &
       all(ieee_is_finite(result_on%accepted_trajectory_direction%final_water_content_direction)) .and. &
       ieee_is_finite(result_on%accepted_trajectory_direction%final_ponding_direction) .and. &
       ieee_is_finite(result_on%accepted_trajectory_direction%accepted_bottom_exchange_derivative), &
       'published trajectory values finite')
  write(*,'(A)') 'FKT22_FMR_TRAJECTORY_ACCEPTED_ROUTE=PASS'
  write(*,'(A,I0)') 'FKT22_FMR_ACCEPTED_STEPS=', result_on%accepted_trajectory_direction%accepted_steps
  write(*,'(A,I0)') 'FKT22_FMR_ACCEPTED_BACKSOLVES=', &
       result_on%accepted_trajectory_direction%additional_tridiagonal_backsolves
  write(*,'(A,I0)') 'FKT22_FMR_GENERATION=', result_on%accepted_trajectory_direction%generation
  write(*,'(A,ES26.17E3)') 'FKT22_FMR_BOTTOM_EXCHANGE_DERIVATIVE=', &
       result_on%accepted_trajectory_direction%accepted_bottom_exchange_derivative
  write(*,'(A)') 'FKT22_FMR_TRAJECTORY_PROVENANCE=PASS'

  ! The full trial is deliberately discarded by TX_TEMPORAL_EXTERNAL_FULL_HALF.
  ! Its tangent backsolve is real work, but it must not enter accepted-route
  ! provenance. The requested run therefore performs three additional tangent
  ! backsolves in total while publishing only the two belonging to half1+half2.
  call require(diagnostics_on%linear_solves == diagnostics_off%linear_solves + 3, &
       'discarded full-trial tangent work remains diagnostic-only')
  call require(result_on%accepted_trajectory_direction%additional_tridiagonal_backsolves < &
       diagnostics_on%linear_solves - diagnostics_off%linear_solves, &
       'rejected full-trial tangent work absent from publication')
  write(*,'(A)') 'FKT22_FMR_REJECTED_TRIAL_ISOLATION=PASS'

  call candidate_off%snapshot(snapshot_off, available_off)
  call candidate_on%snapshot(snapshot_on, available_on)
  call require(available_off .and. available_on, 'candidate snapshots available')
  call require_physical_identity(snapshot_off, snapshot_on)
  call require(same_bits(result_off%mass%storage_start, result_on%mass%storage_start) .and. &
       same_bits(result_off%mass%storage_end, result_on%mass%storage_end) .and. &
       same_bits(result_off%mass%total_in, result_on%mass%total_in) .and. &
       same_bits(result_off%mass%total_out, result_on%mass%total_out) .and. &
       same_bits(result_off%mass%residual, result_on%mass%residual), &
       'trajectory request leaves accepted mass accounting bit-identical')
  write(*,'(A)') 'FKT22_FMR_TRAJECTORY_PHYSICAL_IDENTITY=PASS'
  write(*,'(A)') 'FKT22_FMR_SERIALIZED_RUNTIME_GATE=PASS'

contains

  subroutine initialize_parameters(parameters)
    type(fmr_b110_physical_parameters_t), intent(out) :: parameters
    integer :: k

    parameters%parameter_set_id = 440044_int64
    parameters%active_nodes = numnod
    allocate(parameters%z(numnod), parameters%dz(numnod), parameters%node_distance(numnod), &
         parameters%cofgen(24,numnod))
    parameters%z = z
    parameters%dz = dz
    parameters%node_distance = disnod(1:numnod)
    parameters%cofgen = 0.0_real64
    do k = 1, numnod
      parameters%cofgen(1,k) = 0.032_real64
      parameters%cofgen(2,k) = 0.423_real64
      parameters%cofgen(3,k) = 4.75_real64
      parameters%cofgen(4,k) = 0.0135_real64
      parameters%cofgen(5,k) = 0.365_real64
      parameters%cofgen(6,k) = 1.455_real64
      parameters%cofgen(7,k) = 1.0_real64 - 1.0_real64/parameters%cofgen(6,k)
      parameters%cofgen(8,k) = parameters%cofgen(4,k)
      parameters%cofgen(9,k) = 0.0_real64
      parameters%cofgen(10,k) = parameters%cofgen(3,k)
      parameters%cofgen(11,k) = 0.999_real64
      parameters%cofgen(12,k) = 0.99_real64*parameters%cofgen(3,k)
      parameters%cofgen(22,k) = -1.0e6_real64
      parameters%cofgen(23,k) = 1.0e-12_real64
    end do
    parameters%bottom_mode = SW_STEP_CONTROL_BOTTOM_FLUX
    parameters%swkimpl = 0
    parameters%swkmean = 1
    parameters%swsophy = 0
    parameters%max_iterations = 16
    parameters%max_backtracking = 8
    parameters%min_step_duration = 1.0e-8_real64
    parameters%compartment_balance_tolerance = mass_tolerance
    parameters%total_balance_tolerance = mass_tolerance
    parameters%head_abs_tolerance = mass_tolerance
    parameters%head_rel_tolerance = mass_tolerance
    parameters%ponding_tolerance = mass_tolerance
    parameters%root_extraction_active = .false.
    parameters%macropore_active = .false.
    parameters%snow_active = .false.
    parameters%hysteresis_active = .false.
    parameters%tabulated_hydraulics_active = .false.
    parameters%elasticity_active = .false.
    parameters%frost_active = .false.
    parameters%soil_temperature_active = .false.
    parameters%drainage_response_active = .false.
  end subroutine initialize_parameters

  subroutine determine_initial_conductivity(parameters, conductivity0)
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters
    real(real64), intent(out) :: conductivity0
    type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
    type(b110_default_mvg_provider_t) :: provider
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)

    call initialize_b110_default_mvg_parameters(hydraulic_parameters, parameters%cofgen)
    call bind_b110_default_mvg_provider(provider, hydraulic_parameters, duration)
    heads = h0
    call provider%evaluate(heads, water, conductivity, capacity, dkdh)
    conductivity0 = conductivity(1)
    call require(conductivity0 > 0.0_real64 .and. ieee_is_finite(conductivity0), &
         'initial conductivity finite positive')
  end subroutine determine_initial_conductivity

  subroutine initialize_forcing(forcing, equilibrium_flux)
    type(fmr_b110_physical_forcing_t), intent(out) :: forcing
    real(real64), intent(in) :: equilibrium_flux

    forcing%top_flux = equilibrium_flux
    forcing%top_head = h0
    forcing%bottom_flux = equilibrium_flux
    forcing%bottom_head = -999999.0_real64
    allocate(forcing%drainage_flux_by_level(1,numnod), forcing%subsurface_irrigation_source(numnod), &
         forcing%root_extraction_sink(numnod))
    forcing%drainage_flux_by_level = 0.0_real64
    forcing%subsurface_irrigation_source = 0.0_real64
    forcing%root_extraction_sink = 0.0_real64
  end subroutine initialize_forcing

  subroutine initialize_column_and_template(column, template)
    type(fmr_logical_column_t), intent(out) :: column
    type(fmr_template_t), intent(out) :: template

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
  end subroutine initialize_column_and_template

  subroutine initialize_config(config, request_trajectory)
    type(canonical_numerical_config_t), intent(out) :: config
    logical, intent(in) :: request_trajectory

    config%transaction%temporal_mode = TX_TEMPORAL_EXTERNAL_FULL_HALF
    config%transaction%temporal_tolerance = 1.0e-6_real64
    config%transaction%mass_tolerance = mass_tolerance
    config%transaction%retry_scale = 0.5_real64
    config%transaction%max_retries = 8
    config%max_committed_substeps = 32
    config%progress_tolerance = 0.0_real64
    config%model_temporal_indicator_budget_available = .false.
    config%model_temporal_indicator_budget = 0.0_real64
    config%accepted_trajectory_direction%requested = request_trajectory
    config%accepted_trajectory_direction%control_coordinate = SW_STEP_CONTROL_BOTTOM_FLUX
  end subroutine initialize_config

  subroutine initialize_committed(committed, parameters, initialized)
    type(kernel_committed_state_t), intent(out) :: committed
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters
    logical, intent(out) :: initialized
    type(fmr_b110_physical_state_t) :: state
    type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
    type(b110_default_mvg_provider_t) :: provider
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)

    heads = h0
    call initialize_b110_default_mvg_parameters(hydraulic_parameters, parameters%cofgen)
    call bind_b110_default_mvg_provider(provider, hydraulic_parameters, duration)
    call provider%evaluate(heads, water, conductivity, capacity, dkdh)

    state%active_nodes = numnod
    allocate(state%pressure_head(numnod), state%water_content(numnod))
    state%pressure_head = heads
    state%water_content = water
    state%ponding_depth = 0.0_real64
    state%groundwater_level = -2.0_real64
    call fmr_new_b110_committed_state(committed, column_id, state, 0.0_real64, initialized)
  end subroutine initialize_committed

  subroutine require_physical_identity(off_state, on_state)
    class(transaction_state_t), intent(in) :: off_state, on_state

    select type (off => off_state)
    type is (fmr_b110_physical_state_t)
      select type (on => on_state)
      type is (fmr_b110_physical_state_t)
        call require(off%active_nodes == on%active_nodes, 'active node count bit-identical')
        call require(allocated(off%pressure_head) .and. allocated(on%pressure_head) .and. &
             same_vector_bits(off%pressure_head, on%pressure_head), 'pressure head bit-identical')
        call require(allocated(off%water_content) .and. allocated(on%water_content) .and. &
             same_vector_bits(off%water_content, on%water_content), 'water content bit-identical')
        call require(same_bits(off%ponding_depth, on%ponding_depth), 'ponding depth bit-identical')
        call require(same_bits(off%groundwater_level, on%groundwater_level), 'groundwater level bit-identical')
        call require(.not. allocated(off%snow) .and. .not. allocated(on%snow), 'snow layout unchanged')
        call require(.not. allocated(off%soil_temperature) .and. .not. allocated(on%soil_temperature), &
             'soil-temperature layout unchanged')
      class default
        call require(.false., 'requested candidate has expected physical state type')
      end select
    class default
      call require(.false., 'default-off candidate has expected physical state type')
    end select
  end subroutine require_physical_identity

  pure logical function same_bits(a, b)
    real(real64), intent(in) :: a, b
    same_bits = transfer(a, 0_int64) == transfer(b, 0_int64)
  end function same_bits

  pure logical function same_vector_bits(a, b)
    real(real64), intent(in) :: a(:), b(:)
    integer :: i

    same_vector_bits = .false.
    if (size(a) /= size(b)) return
    do i = 1, size(a)
      if (.not. same_bits(a(i), b(i))) return
    end do
    same_vector_bits = .true.
  end function same_vector_bits

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FKT22_FMR_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fkt22_fmr_serialized_trajectory_runtime
