module mod_eb_i13_retry_fixture
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_transaction_reference, only: transaction_state_t, transaction_attempt_context_t, transaction_model_t, &
       trial_outcome_t, TX_MASS_MISSING_NONE
  use mod_fmr_bottom_thermal_carrier, only: fmr_bottom_thermal_carrier_t
  implicit none
  private

  type, extends(transaction_state_t), public :: retry_state_t
    real(real64) :: storage_value = 1.0_real64
  contains
    procedure :: clone => retry_state_clone
  end type retry_state_t

  type, extends(transaction_attempt_context_t) :: retry_context_t
    type(fmr_bottom_thermal_carrier_t) :: carrier
  end type retry_context_t

  type, extends(transaction_model_t), public :: retry_model_t
    type(fmr_bottom_thermal_carrier_t) :: carrier
  contains
    procedure :: advance => retry_advance
    procedure :: storage => retry_storage
    procedure :: temporal_error => retry_temporal_error
    procedure :: storage_accounting_status => retry_storage_status
    procedure :: capture_attempt_context => retry_capture
    procedure :: restore_attempt_context => retry_restore
  end type retry_model_t

contains

  subroutine retry_state_clone(self, copy)
    class(retry_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(retry_state_t :: copy)
    select type (typed => copy)
    type is (retry_state_t)
      typed%storage_value = self%storage_value
    end select
  end subroutine retry_state_clone

  subroutine retry_capture(self, context)
    class(retry_model_t), intent(inout) :: self
    class(transaction_attempt_context_t), allocatable, intent(out) :: context
    allocate(retry_context_t :: context)
    select type (typed => context)
    type is (retry_context_t)
      call self%carrier%copy_to(typed%carrier)
    class default
      error stop 'EB-I13 retry fixture context allocation mismatch'
    end select
  end subroutine retry_capture

  subroutine retry_restore(self, context)
    class(retry_model_t), intent(inout) :: self
    class(transaction_attempt_context_t), intent(in) :: context
    select type (typed => context)
    type is (retry_context_t)
      call self%carrier%restore_from(typed%carrier)
    class default
      error stop 'EB-I13 retry fixture context type mismatch'
    end select
  end subroutine retry_restore

  subroutine retry_advance(self, state, t0, t1, outcome)
    class(retry_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    logical :: appended
    real(real64) :: dt

    outcome = trial_outcome_t()
    dt = t1 - t0
    select type (typed => state)
    type is (retry_state_t)
      if (typed%storage_value < 0.0_real64) return
    class default
      return
    end select

    call self%carrier%append_local(t0, t1, dt, 10.0_real64+t0, 10.0_real64+t1, appended)
    if (.not. appended) return
    outcome%headcalc_calls = 1

    ! Deliberately fail only the first full-size attempt. The transaction core
    ! must restore the carrier before retrying at half the interval.
    if (dt > 0.5_real64) return

    outcome%solver_ok = .true.
    outcome%mass_accounting_complete = .true.
    outcome%missing_mass_contribution_mask = TX_MASS_MISSING_NONE
  end subroutine retry_advance

  real(real64) function retry_storage(self, state) result(value)
    class(retry_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    if (self%carrier%sample_count() < -huge(0)) error stop 'unreachable EB-I13 retry carrier count'
    select type (typed => state)
    type is (retry_state_t)
      value = typed%storage_value
    class default
      value = huge(0.0_real64)
    end select
  end function retry_storage

  real(real64) function retry_temporal_error(self, full_state, half_state) result(value)
    class(retry_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state
    if (.not. same_type_as(self,self) .or. .not. same_type_as(full_state,full_state) .or. &
        .not. same_type_as(half_state,half_state)) error stop 'unreachable EB-I13 temporal types'
    value = 0.0_real64
  end function retry_temporal_error

  subroutine retry_storage_status(self, state, complete, missing_mask)
    class(retry_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    logical, intent(out) :: complete
    integer(int64), intent(out) :: missing_mask
    if (.not. same_type_as(self,self) .or. .not. same_type_as(state,state)) error stop 'unreachable EB-I13 storage types'
    complete = .true.
    missing_mask = TX_MASS_MISSING_NONE
  end subroutine retry_storage_status

end module mod_eb_i13_retry_fixture

program test_eb_i13_bottom_thermal_carrier
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: transaction_state_t, transaction_policy_t, transaction_result_t, &
       execute_reference_interval, TX_STATUS_ACCEPTED, TX_ROUTE_TWO_HALF, TX_TEMPORAL_EXTERNAL_FULL_HALF
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_result_t, &
       kernel_candidate_state_t, kernel_diagnostics_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_NUMERICAL_CONTINUATION_NONE, FMR_OPTIONAL_STATE_LAYOUT_RESTRICTED_SOIL_TEMPERATURE
  use mod_fmr_bottom_thermal_carrier, only: fmr_bottom_thermal_carrier_t, fmr_bottom_thermal_candidate_t, &
       fmr_bottom_thermal_sample_t, FMR_BOTTOM_THERMAL_DONOR_NONE, FMR_BOTTOM_THERMAL_DONOR_LOCAL_SWAP, &
       FMR_BOTTOM_THERMAL_DONOR_EXTERNAL
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_serialized_reference_backend_t, fmr_new_b110_committed_state
  use mod_restricted_soil_temperature, only: SOIL_TEMP_OK, initialize_soil_temperature_parameters, &
       initialize_soil_temperature_state, copy_soil_temperature_profile
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_fmr04_fixed_top_provider, only: fmr04_fixed_flux_top_provider_t
  use mod_eb_i13_retry_fixture, only: retry_state_t, retry_model_t
  implicit none

  real(real64), parameter :: test_t0 = 8123.125_real64
  real(real64), parameter :: test_t1 = 8123.375_real64
  real(real64), parameter :: tol = 1.0e-10_real64

  call verify_primitive_contract()
  call verify_retry_rollback_contract()
  call verify_serialized_backend_carrier_and_parity()
  write(*,'(A)') 'EB_I13_BOTTOM_THERMAL_CARRIER_GATE PASS'

contains

  subroutine verify_primitive_contract()
    type(fmr_bottom_thermal_carrier_t) :: carrier, checkpoint
    type(fmr_bottom_thermal_candidate_t) :: candidate
    type(fmr_bottom_thermal_sample_t) :: sample
    logical :: ok, available

    call require(carrier%sample_count() == 0, 'inactive carrier not empty')
    call carrier%initialize(3, ok)
    call require(ok, 'bounded carrier initialization')
    call carrier%append_local(0.0_real64, 1.0_real64, 0.25_real64, 9.0_real64, 9.5_real64, ok)
    call require(ok, 'local sample append')
    call carrier%copy_to(checkpoint)
    call carrier%append_external_incomplete(1.0_real64, 2.0_real64, -0.10_real64, ok)
    call require(ok, 'external sample append')
    call carrier%append_zero(2.0_real64, 3.0_real64, ok)
    call require(ok, 'zero sample append')
    call require(carrier%sample_count() == 3, 'primitive sample count')
    call carrier%append_zero(3.0_real64, 4.0_real64, ok)
    call require(.not. ok .and. carrier%sample_count() == 3, 'bounded carrier overflow')

    call carrier%materialize_candidate(0.0_real64, 3.0_real64, candidate, ok)
    call require(ok .and. candidate%ready() .and. candidate%sample_count() == 3, 'candidate materialization')
    call require(.not. candidate%thermal_complete(), 'external donor incompleteness propagated')
    call candidate%sample_at(1, sample, available)
    call require(available .and. sample%donor_class == FMR_BOTTOM_THERMAL_DONOR_LOCAL_SWAP, 'local donor class')
    call require(sample%donor_thermal_complete .and. sample%bottom_outward_exchange_native > 0.0_real64, &
         'local donor thermal support')
    call candidate%sample_at(2, sample, available)
    call require(available .and. sample%donor_class == FMR_BOTTOM_THERMAL_DONOR_EXTERNAL, 'external donor class')
    call require(.not. sample%donor_thermal_complete .and. sample%bottom_outward_exchange_native < 0.0_real64, &
         'external donor explicitly incomplete')
    call candidate%sample_at(3, sample, available)
    call require(available .and. sample%donor_class == FMR_BOTTOM_THERMAL_DONOR_NONE, 'zero donor class')
    call require(sample%bottom_outward_exchange_native == 0.0_real64, 'zero transfer has no donor water')

    call carrier%restore_from(checkpoint)
    call require(carrier%sample_count() == 1, 'carrier rollback restores exact prefix')
    write(*,'(A)') 'EB_I13_PRIMITIVE_LOCAL_EXTERNAL_ZERO_BOUNDED=PASS'
  end subroutine verify_primitive_contract

  subroutine verify_retry_rollback_contract()
    class(transaction_state_t), allocatable :: state
    type(retry_model_t) :: model
    type(transaction_policy_t) :: policy
    type(transaction_result_t) :: result
    type(fmr_bottom_thermal_candidate_t) :: candidate
    type(fmr_bottom_thermal_sample_t) :: first, second
    logical :: ok, available

    allocate(retry_state_t :: state)
    call model%carrier%initialize(8, ok)
    call require(ok, 'retry carrier initialization')
    policy%temporal_mode = TX_TEMPORAL_EXTERNAL_FULL_HALF
    policy%temporal_tolerance = 1.0_real64
    policy%mass_tolerance = 1.0e-12_real64
    policy%retry_scale = 0.5_real64
    policy%max_retries = 2

    call execute_reference_interval(model, state, 0.0_real64, 1.0_real64, policy, result)
    call require(result%status == TX_STATUS_ACCEPTED .and. result%accepted_route == TX_ROUTE_TWO_HALF, &
         'retry fixture accepted two-half route')
    call require(result%retries == 1 .and. result%attempts == 2, 'retry fixture exercised exactly one retry')
    call require(abs(result%accepted_t1-0.5_real64) <= tol, 'retry accepted reduced interval')
    call require(model%carrier%sample_count() == 2, 'rejected full/retry samples did not leak')
    call model%carrier%materialize_candidate(0.0_real64, 0.5_real64, candidate, ok)
    call require(ok .and. candidate%sample_count() == 2, 'retry candidate exact accepted sequence')
    call candidate%sample_at(1, first, available)
    call require(available, 'retry first sample available')
    call candidate%sample_at(2, second, available)
    call require(available, 'retry second sample available')
    call require(abs(first%t0-0.0_real64) <= tol .and. abs(first%t1-0.25_real64) <= tol, 'retry first half interval')
    call require(abs(second%t0-0.25_real64) <= tol .and. abs(second%t1-0.5_real64) <= tol, 'retry second half interval')
    write(*,'(A)') 'EB_I13_REJECT_RETRY_ROLLBACK_EXACT_PREFIX=PASS'
  end subroutine verify_retry_rollback_contract

  subroutine verify_serialized_backend_carrier_and_parity()
    type(fmr_serialized_reference_backend_t) :: enabled_backend, disabled_backend
    type(fmr04_fixed_flux_top_provider_t), target :: enabled_top, disabled_top
    type(kernel_committed_state_t) :: enabled_committed, disabled_committed
    type(kernel_checkpoint_t) :: enabled_checkpoint, disabled_checkpoint
    type(fmr_logical_column_t) :: enabled_column, disabled_column
    type(fmr_template_t) :: enabled_template, disabled_template
    type(fmr_b110_physical_parameters_t) :: enabled_parameters, disabled_parameters
    type(fmr_b110_physical_forcing_t) :: enabled_forcing, disabled_forcing
    type(canonical_numerical_config_t) :: enabled_config, disabled_config
    type(kernel_result_t) :: enabled_result, disabled_result
    type(kernel_candidate_state_t) :: enabled_candidate, disabled_candidate
    type(kernel_diagnostics_t) :: enabled_diag, disabled_diag
    type(fmr_bottom_thermal_candidate_t) :: thermal, disabled_thermal
    type(fmr_bottom_thermal_sample_t) :: sample, previous
    logical :: available, previous_available
    integer :: i
    real(real64) :: sample_sum, candidate_t0, candidate_t1

    call initialize_backend_case(enabled_committed, enabled_column, enabled_template, enabled_parameters, enabled_forcing, enabled_config)
    call initialize_backend_case(disabled_committed, disabled_column, disabled_template, disabled_parameters, disabled_forcing, disabled_config)
    call enabled_committed%capture_checkpoint(enabled_checkpoint, available)
    call require(available, 'enabled checkpoint')
    call disabled_committed%capture_checkpoint(disabled_checkpoint, available)
    call require(available, 'disabled checkpoint')

    call enabled_backend%initialize(enabled_top)
    call disabled_backend%initialize(disabled_top)
    call enabled_backend%set_bottom_thermal_carrier_enabled(.true.)
    call disabled_backend%set_bottom_thermal_carrier_enabled(.false.)

    call enabled_backend%run_trial(enabled_column, enabled_template, enabled_parameters, enabled_committed, enabled_forcing, &
         enabled_config, test_t0, test_t1, enabled_checkpoint, enabled_result, enabled_candidate, enabled_diag)
    call disabled_backend%run_trial(disabled_column, disabled_template, disabled_parameters, disabled_committed, disabled_forcing, &
         disabled_config, test_t0, test_t1, disabled_checkpoint, disabled_result, disabled_candidate, disabled_diag)

    call require(enabled_result%completed .and. enabled_candidate%ready(), 'enabled backend completed')
    call require(disabled_result%completed .and. disabled_candidate%ready(), 'disabled backend completed')
    thermal = enabled_backend%bottom_thermal_snapshot()
    disabled_thermal = disabled_backend%bottom_thermal_snapshot()
    call require(thermal%ready(), 'enabled thermal candidate available')
    call require(.not. disabled_thermal%ready(), 'inactive carrier remains empty')
    call require(enabled_result%mass%accepted_transaction_count > 0, 'accepted transaction count positive')
    call require(thermal%sample_count() == 2 * enabled_result%mass%accepted_transaction_count, &
         'accepted full/half route retains only exact two-half samples')
    call thermal%interval(candidate_t0, candidate_t1, available)
    call require(available .and. abs(candidate_t0-test_t0) <= tol .and. abs(candidate_t1-test_t1) <= tol, &
         'thermal candidate covers requested interval')

    sample_sum = 0.0_real64
    previous_available = .false.
    do i = 1, thermal%sample_count()
      call thermal%sample_at(i, sample, available)
      call require(available, 'thermal sample available')
      call require(sample%bottom_outward_exchange_native > 0.0_real64, 'backend fixture produces outward transfer')
      call require(sample%donor_class == FMR_BOTTOM_THERMAL_DONOR_LOCAL_SWAP .and. sample%donor_thermal_complete, &
           'outward transfer carries local thermal support')
      call require(ieee_is_finite(sample%local_start_temperature_c) .and. &
           ieee_is_finite(sample%local_end_temperature_c), 'local temperatures finite')
      if (.not. previous_available) then
        call require(abs(sample%t0-test_t0) <= tol, 'first accepted sample starts at request origin')
        call require(abs(sample%local_start_temperature_c-9.0_real64) <= tol, 'first local donor temperature is committed bottom T')
      else
        call require(abs(sample%t0-previous%t1) <= tol, 'accepted sample sequence time-contiguous')
        call require(abs(sample%local_start_temperature_c-previous%local_end_temperature_c) <= tol, &
             'accepted thermal state sequence continuous')
      end if
      sample_sum = sample_sum + sample%bottom_outward_exchange_native
      previous = sample
      previous_available = .true.
    end do
    call require(abs(previous%t1-test_t1) <= tol, 'last accepted sample ends at request end')
    call require(abs(sample_sum-enabled_result%bottom_outward_exchange_native) <= tol, &
         'carrier water exchange equals accepted bottom exchange')

    call require_results_equal(enabled_result, disabled_result)
    call require_diagnostics_equal(enabled_diag, disabled_diag)
    call require_candidates_equal(enabled_candidate, disabled_candidate)
    write(*,'(A)') 'EB_I13_SERIALIZED_ACCEPTED_ROUTE_AND_LOCAL_TEMPERATURE=PASS'
    write(*,'(A)') 'EB_I13_HYDROLOGIC_LEDGER_AND_CANDIDATE_PARITY=PASS'
    write(*,'(A)') 'EB_I13_NO_EXTRA_PHYSICAL_SOLVE_PARITY=PASS'
  end subroutine verify_serialized_backend_carrier_and_parity

  subroutine initialize_backend_case(committed, column, template, parameters, forcing, config)
    type(kernel_committed_state_t), intent(out) :: committed
    type(fmr_logical_column_t), intent(out) :: column
    type(fmr_template_t), intent(out) :: template
    type(fmr_b110_physical_parameters_t), intent(out) :: parameters
    type(fmr_b110_physical_forcing_t), intent(out) :: forcing
    type(canonical_numerical_config_t), intent(out) :: config
    type(fmr_b110_physical_state_t) :: state
    type(b110_default_mvg_parameters_t), target :: hp
    type(b110_default_mvg_provider_t) :: provider
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod), k0
    real(real64) :: dz_cm(numnod), distance_above_cm(numnod), theta_sat(numnod)
    real(real64) :: f_quartz(numnod), f_clay(numnod), f_organic(numnod), initial_temperature(numnod)
    integer :: k, status
    logical :: ok

    parameters%parameter_set_id = 131301_int64
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
    parameters%bottom_mode = 7
    parameters%swkimpl = 0
    parameters%swkmean = 1
    parameters%swsophy = 0
    parameters%root_extraction_active = .false.
    parameters%macropore_active = .false.
    parameters%snow_active = .false.
    parameters%hysteresis_active = .false.
    parameters%tabulated_hydraulics_active = .false.
    parameters%elasticity_active = .false.
    parameters%frost_active = .false.
    parameters%soil_temperature_active = .true.

    dz_cm = 100.0_real64 * abs(dz)
    distance_above_cm = 0.5_real64 * dz_cm
    theta_sat = 0.423_real64
    f_quartz = 0.40_real64
    f_clay = 0.40_real64
    f_organic = 0.10_real64
    allocate(parameters%soil_temperature)
    call initialize_soil_temperature_parameters(dz_cm, distance_above_cm, theta_sat, f_quartz, f_clay, f_organic, &
         parameters%soil_temperature, status)
    call require(status == SOIL_TEMP_OK, 'soil temperature parameter initialization')

    call initialize_b110_default_mvg_parameters(hp, parameters%cofgen)
    call bind_b110_default_mvg_provider(provider, hp, test_t1-test_t0)
    heads = -123.0_real64
    call provider%evaluate(heads, water, conductivity, capacity, dkdh)
    k0 = conductivity(1)

    state%active_nodes = numnod
    allocate(state%pressure_head(numnod), state%water_content(numnod), state%soil_temperature)
    state%pressure_head = heads
    state%water_content = water
    state%ponding_depth = 0.0_real64
    state%groundwater_level = -2.25_real64
    initial_temperature = [12.0_real64, 11.0_real64, 10.0_real64, 9.0_real64]
    call initialize_soil_temperature_state(initial_temperature, state%soil_temperature, status)
    call require(status == SOIL_TEMP_OK, 'soil temperature state initialization')
    call fmr_new_b110_committed_state(committed, 1313001_int64, state, test_t0, ok)
    call require(ok, 'committed state initialization')

    template%template_id = 1313_int64
    template%physics_topology_id = 13131_int64
    template%vertical_layout_id = 13132_int64
    template%state_layout_id = 13133_int64
    template%solver_interface_id = 13134_int64
    template%optional_state_layout_id = FMR_OPTIONAL_STATE_LAYOUT_RESTRICTED_SOIL_TEMPERATURE
    template%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_NONE
    template%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
    column%column_id = 1313001_int64
    column%template_id = template%template_id
    column%parameter_ref = 1_int64
    column%state_handle = 1_int64
    column%forcing_handle = 1_int64
    column%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE

    forcing%top_flux = -k0
    forcing%top_head = -123.0_real64
    forcing%bottom_flux = -k0
    forcing%bottom_head = -321.0_real64
    allocate(forcing%drainage_flux_by_level(1,numnod), forcing%subsurface_irrigation_source(numnod), &
         forcing%root_extraction_sink(numnod), forcing%soil_temperature)
    forcing%drainage_flux_by_level = 0.0_real64
    forcing%subsurface_irrigation_source = 0.0_real64
    forcing%root_extraction_sink = 0.0_real64
    forcing%soil_temperature%prescribed_surface_temperature_c = 15.0_real64

    config%transaction%temporal_mode = TX_TEMPORAL_EXTERNAL_FULL_HALF
    config%transaction%temporal_tolerance = 1.0e6_real64
    config%transaction%mass_tolerance = 1.0e-8_real64
    config%transaction%retry_scale = 0.5_real64
    config%transaction%max_retries = 4
    config%max_committed_substeps = 8
    config%progress_tolerance = 0.0_real64
  end subroutine initialize_backend_case

  subroutine require_results_equal(a, b)
    type(kernel_result_t), intent(in) :: a, b
    call require(a%status == b%status .and. a%completed .eqv. b%completed, 'result status parity')
    call require(same_bits(a%requested_t0,b%requested_t0) .and. same_bits(a%requested_t1,b%requested_t1) .and. &
         same_bits(a%completed_t,b%completed_t), 'result time parity')
    call require(a%mass%complete .eqv. b%mass%complete, 'mass complete parity')
    call require(a%mass%accepted_transaction_count == b%mass%accepted_transaction_count .and. &
         a%mass%missing_contribution_mask == b%mass%missing_contribution_mask, 'mass provenance parity')
    call require(same_bits(a%mass%storage_start,b%mass%storage_start) .and. &
         same_bits(a%mass%storage_end,b%mass%storage_end) .and. &
         same_bits(a%mass%storage_change,b%mass%storage_change) .and. &
         same_bits(a%mass%total_in,b%mass%total_in) .and. same_bits(a%mass%total_out,b%mass%total_out) .and. &
         same_bits(a%mass%residual,b%mass%residual), 'mass ledger bit parity')
    call require(a%bottom_interface_exchange_available .eqv. b%bottom_interface_exchange_available, &
         'bottom exchange availability parity')
    call require(same_bits(a%bottom_outward_exchange_native,b%bottom_outward_exchange_native) .and. &
         same_bits(a%terminal_bottom_outward_flux_native,b%terminal_bottom_outward_flux_native), 'bottom exchange bit parity')
  end subroutine require_results_equal

  subroutine require_diagnostics_equal(a, b)
    type(kernel_diagnostics_t), intent(in) :: a, b
    call require(a%transaction_calls == b%transaction_calls .and. a%accepted_substeps == b%accepted_substeps .and. &
         a%attempts == b%attempts .and. a%retries == b%retries .and. a%trial_rollbacks == b%trial_rollbacks, &
         'transaction diagnostic parity')
    call require(a%solver_rejections == b%solver_rejections .and. a%temporal_rejections == b%temporal_rejections .and. &
         a%mass_rejections == b%mass_rejections, 'rejection diagnostic parity')
    call require(a%nonlinear_iterations == b%nonlinear_iterations .and. a%internal_retries == b%internal_retries .and. &
         a%headcalc_calls == b%headcalc_calls .and. a%jacobian_builds == b%jacobian_builds .and. &
         a%linear_solves == b%linear_solves .and. a%backtracking_attempts == b%backtracking_attempts .and. &
         a%alternative_solver_calls == b%alternative_solver_calls, 'physical solve-count parity')
    call require(same_bits(a%max_abs_step_mass_residual,b%max_abs_step_mass_residual) .and. &
         same_bits(a%max_temporal_indicator,b%max_temporal_indicator) .and. &
         same_bits(a%min_accepted_substep_duration,b%min_accepted_substep_duration) .and. &
         same_bits(a%max_accepted_substep_duration,b%max_accepted_substep_duration), 'diagnostic real parity')
  end subroutine require_diagnostics_equal

  subroutine require_candidates_equal(a, b)
    type(kernel_candidate_state_t), intent(in) :: a, b
    class(transaction_state_t), allocatable :: sa, sb
    real(real64), allocatable :: ta(:), tb(:)
    logical :: aa, ab
    integer :: status_a, status_b

    call a%snapshot(sa, aa)
    call b%snapshot(sb, ab)
    call require(aa .and. ab, 'candidate snapshots available')
    select type (pa => sa)
    type is (fmr_b110_physical_state_t)
      select type (pb => sb)
      type is (fmr_b110_physical_state_t)
        call require(pa%active_nodes == pb%active_nodes, 'candidate node parity')
        call require(all(pa%pressure_head == pb%pressure_head) .and. all(pa%water_content == pb%water_content), &
             'candidate hydraulic state parity')
        call require(same_bits(pa%ponding_depth,pb%ponding_depth) .and. &
             same_bits(pa%groundwater_level,pb%groundwater_level), 'candidate scalar state parity')
        call require(allocated(pa%soil_temperature) .and. allocated(pb%soil_temperature), 'candidate thermal states allocated')
        call copy_soil_temperature_profile(pa%soil_temperature, ta, status_a)
        call copy_soil_temperature_profile(pb%soil_temperature, tb, status_b)
        call require(status_a == SOIL_TEMP_OK .and. status_b == SOIL_TEMP_OK, 'candidate thermal profile access')
        call require(size(ta) == size(tb) .and. all(ta == tb), 'candidate thermal state parity')
      class default
        error stop 'EB-I13 disabled candidate type mismatch'
      end select
    class default
      error stop 'EB-I13 enabled candidate type mismatch'
    end select
  end subroutine require_candidates_equal

  logical function same_bits(a, b) result(equal)
    real(real64), intent(in) :: a, b
    integer(int64) :: ia, ib
    ia = transfer(a, ia)
    ib = transfer(b, ib)
    equal = ia == ib
  end function same_bits

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'EB_I13_TEST_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_eb_i13_bottom_thermal_carrier