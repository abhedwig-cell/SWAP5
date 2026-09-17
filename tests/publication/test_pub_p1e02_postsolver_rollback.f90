program test_pub_p1e02_postsolver_rollback
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_EXTERNAL_FULL_HALF
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_executor_t, kernel_committed_state_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       FMR_BACKEND_SERIALIZED_REFERENCE, FMR_NUMERICAL_CONTINUATION_NONE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, fmr_serialized_physical_observation_t, &
       fmr_new_b110_committed_state
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, &
       fmr_serialized_batch_diagnostics_t, fmr_execute_serialized_resolved_physical_column
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use MOD_grid, only: numnod, z, dz, disnod
  implicit none

  integer(int64), parameter :: column_id = 910201_int64
  real(real64), parameter :: h0 = -75.0_real64
  real(real64), parameter :: duration = 0.25_real64
  real(real64), parameter :: hard_mass_gate = 1.0e-12_real64

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
  type(fmr_serialized_column_result_t) :: output
  type(fmr_serialized_physical_observation_t) :: observation
  type(fixed_flux_top_boundary_provider_t), target :: top
  class(transaction_state_t), allocatable :: before_state, after_state
  integer(int64) :: before_revision, after_revision
  real(real64) :: before_time, after_time
  integer :: active_physical_calls
  logical :: ok, before_time_available, after_time_available, before_available, after_available

  call initialize_parameters(parameters)
  call initialize_committed(committed, parameters, ok)
  call require(ok, 'committed state initialized')
  call initialize_forcing(forcing)
  call initialize_column_and_template(column, template)
  call initialize_rejecting_config(config)

  before_revision = committed%current_revision()
  call committed%current_time(before_time, before_time_available)
  call committed%snapshot(before_state, before_available)
  call require(before_available .and. before_time_available, 'pre-trial committed snapshot available')
  call require(before_revision == 0_int64 .and. same_bits(before_time, 0.0_real64), &
       'pre-trial provenance is initial committed state')

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

  call require(output%admission_assessed .and. output%admitted, &
       'physical profile admitted before transaction rejection')
  call require(.not. output%completed .and. .not. output%committed, &
       'post-solver temporal rejection publishes no completed commit')
  call require(diagnostic%rejected == 1 .and. trim(diagnostic%failure_classification) == 'KERNEL_REJECTED', &
       'runtime reports kernel rejection')
  call require(observation%solver_executed, 'Reference solver executed before rejection')
  call require(output%solver_headcalc_calls >= 3, &
       'full and two-half Reference trajectories executed before rejection')
  call require(output%accepted_substeps == 0, 'no transaction substep accepted')

  after_revision = committed%current_revision()
  call committed%current_time(after_time, after_time_available)
  call committed%snapshot(after_state, after_available)
  call require(after_available .and. after_time_available, 'post-rejection committed snapshot available')
  call require(after_revision == before_revision, 'post-solver rejection leaves committed revision unchanged')
  call require(same_bits(after_time, before_time), 'post-solver rejection leaves committed time unchanged')
  call require_physical_identity(before_state, after_state)

  call require(output%mass%accepted_transaction_count == 0, &
       'rejected physical trials produce no accepted mass transactions')
  call require(.not. output%mass%complete, 'rejected interval has no complete accepted mass publication')
  call require(same_bits(output%mass%total_in, 0.0_real64) .and. &
       same_bits(output%mass%total_out, 0.0_real64), &
       'rejected trial water transfers are absent from accepted mass totals')
  call require(output%final_revision == before_revision, 'published final revision remains unchanged')

  write(*,'(A,I0)') 'PUB_P1E02_HEADCALC_CALLS_BEFORE_REJECTION=', output%solver_headcalc_calls
  write(*,'(A,I0)') 'PUB_P1E02_ACCEPTED_TRANSACTION_COUNT=', output%mass%accepted_transaction_count
  write(*,'(A,ES26.17E3)') 'PUB_P1E02_ACCEPTED_TOTAL_IN=', output%mass%total_in
  write(*,'(A,ES26.17E3)') 'PUB_P1E02_ACCEPTED_TOTAL_OUT=', output%mass%total_out
  write(*,'(A)') 'PUB_P1E02_POSTSOLVER_COMMITTED_STATE_IDENTITY=PASS'
  write(*,'(A)') 'PUB_P1E02_REJECTED_TRANSFER_EXCLUSION=PASS'
  write(*,'(A)') 'PUB_P1E02_PRODUCTION_POSTSOLVER_ROLLBACK=PASS'

contains

  subroutine initialize_parameters(p)
    type(fmr_b110_physical_parameters_t), intent(out) :: p
    integer :: k

    p%parameter_set_id = 910201_int64
    p%active_nodes = numnod
    allocate(p%z(numnod), p%dz(numnod), p%node_distance(numnod), p%cofgen(24,numnod))
    p%z = z
    p%dz = dz
    p%node_distance = disnod(1:numnod)
    p%cofgen = 0.0_real64
    do k = 1, numnod
      p%cofgen(1,k) = 0.032_real64
      p%cofgen(2,k) = 0.423_real64
      p%cofgen(3,k) = 4.75_real64
      p%cofgen(4,k) = 0.0135_real64
      p%cofgen(5,k) = 0.365_real64
      p%cofgen(6,k) = 1.455_real64
      p%cofgen(7,k) = 1.0_real64 - 1.0_real64 / p%cofgen(6,k)
      p%cofgen(8,k) = p%cofgen(4,k)
      p%cofgen(9,k) = 0.0_real64
      p%cofgen(10,k) = p%cofgen(3,k)
      p%cofgen(11,k) = 0.999_real64
      p%cofgen(12,k) = 0.99_real64 * p%cofgen(3,k)
      p%cofgen(22,k) = -1.0e6_real64
      p%cofgen(23,k) = 1.0e-12_real64
    end do
    p%bottom_mode = 2
    p%swkimpl = 0
    p%swkmean = 1
    p%swsophy = 0
    p%max_iterations = 16
    p%max_backtracking = 8
    p%min_step_duration = 1.0e-8_real64
    p%compartment_balance_tolerance = hard_mass_gate
    p%total_balance_tolerance = hard_mass_gate
    p%head_abs_tolerance = hard_mass_gate
    p%head_rel_tolerance = hard_mass_gate
    p%ponding_tolerance = hard_mass_gate
    p%root_extraction_active = .false.
    p%macropore_active = .false.
    p%snow_active = .false.
    p%hysteresis_active = .false.
    p%tabulated_hydraulics_active = .false.
    p%elasticity_active = .false.
    p%frost_active = .false.
    p%soil_temperature_active = .false.
    p%drainage_response_active = .false.
  end subroutine initialize_parameters

  subroutine initialize_committed(state_carrier, p, initialized)
    type(kernel_committed_state_t), intent(out) :: state_carrier
    type(fmr_b110_physical_parameters_t), intent(in) :: p
    logical, intent(out) :: initialized
    type(fmr_b110_physical_state_t) :: physical
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    type(b110_default_mvg_parameters_t), target :: hp
    type(b110_default_mvg_provider_t) :: provider

    heads = h0
    call initialize_b110_default_mvg_parameters(hp, p%cofgen)
    call bind_b110_default_mvg_provider(provider, hp, duration)
    call provider%evaluate(heads, water, conductivity, capacity, dkdh)
    physical%active_nodes = numnod
    allocate(physical%pressure_head(numnod), physical%water_content(numnod))
    physical%pressure_head = heads
    physical%water_content = water
    physical%ponding_depth = 0.0_real64
    physical%groundwater_level = -2.0_real64
    call fmr_new_b110_committed_state(state_carrier, column_id, physical, 0.0_real64, initialized)
  end subroutine initialize_committed

  subroutine initialize_forcing(f)
    type(fmr_b110_physical_forcing_t), intent(out) :: f
    f%top_flux = 0.0_real64
    f%top_head = h0
    f%bottom_flux = 0.0_real64
    f%bottom_head = -999999.0_real64
    allocate(f%drainage_flux_by_level(1,numnod), f%subsurface_irrigation_source(numnod), &
         f%root_extraction_sink(numnod))
    f%drainage_flux_by_level = 0.0_real64
    f%subsurface_irrigation_source = 0.0_real64
    f%root_extraction_sink = 0.0_real64
  end subroutine initialize_forcing

  subroutine initialize_column_and_template(c, t)
    type(fmr_logical_column_t), intent(out) :: c
    type(fmr_template_t), intent(out) :: t

    t%template_id = 910201_int64
    t%physics_topology_id = 910202_int64
    t%vertical_layout_id = 910203_int64
    t%state_layout_id = 910204_int64
    t%solver_interface_id = 910205_int64
    t%optional_state_layout_id = 0_int64
    t%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_NONE
    t%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE

    c%column_id = column_id
    c%template_id = t%template_id
    c%parameter_ref = 1_int64
    c%state_handle = 1_int64
    c%forcing_handle = 1_int64
    c%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine initialize_column_and_template

  subroutine initialize_rejecting_config(cfg)
    type(canonical_numerical_config_t), intent(out) :: cfg
    cfg = canonical_numerical_config_t()
    cfg%transaction%temporal_mode = TX_TEMPORAL_EXTERNAL_FULL_HALF
    cfg%transaction%temporal_tolerance = 0.0_real64
    cfg%transaction%mass_tolerance = hard_mass_gate
    cfg%transaction%retry_scale = 0.5_real64
    cfg%transaction%max_retries = 0
    cfg%max_committed_substeps = 1
    cfg%progress_tolerance = 0.0_real64
  end subroutine initialize_rejecting_config

  subroutine require_physical_identity(left_state, right_state)
    class(transaction_state_t), allocatable, intent(in) :: left_state, right_state
    select type (left => left_state)
    type is (fmr_b110_physical_state_t)
      select type (right => right_state)
      type is (fmr_b110_physical_state_t)
        call require(left%active_nodes == right%active_nodes, 'rollback active-node identity')
        call require(allocated(left%pressure_head) .and. allocated(right%pressure_head), &
             'rollback head vectors allocated')
        call require(allocated(left%water_content) .and. allocated(right%water_content), &
             'rollback water vectors allocated')
        call require(size(left%pressure_head) == size(right%pressure_head) .and. &
             size(left%water_content) == size(right%water_content), 'rollback vector-shape identity')
        call require(all(transfer(left%pressure_head, [0_int64], size(left%pressure_head)) == &
             transfer(right%pressure_head, [0_int64], size(right%pressure_head))), 'rollback head bit identity')
        call require(all(transfer(left%water_content, [0_int64], size(left%water_content)) == &
             transfer(right%water_content, [0_int64], size(right%water_content))), 'rollback water bit identity')
        call require(same_bits(left%ponding_depth, right%ponding_depth), 'rollback ponding bit identity')
        call require(same_bits(left%groundwater_level, right%groundwater_level), 'rollback groundwater bit identity')
      class default
        call require(.false., 'post-rejection state type identity')
      end select
    class default
      call require(.false., 'pre-rejection state type identity')
    end select
  end subroutine require_physical_identity

  pure logical function same_bits(a, b)
    real(real64), intent(in) :: a, b
    same_bits = transfer(a, 0_int64) == transfer(b, 0_int64)
  end function same_bits

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'PUB_P1E02_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_pub_p1e02_postsolver_rollback
