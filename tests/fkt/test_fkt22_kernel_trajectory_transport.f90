module test_fkt22_kernel_transport_fixture
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t, trial_outcome_t, &
       TX_MASS_MISSING_NONE, TX_MASS_MISSING_UNSPECIFIED
  use mod_accepted_trajectory_directional_publication, only: accepted_trajectory_direction_result_t
  use mod_canonical_contracts, only: canonical_state_t, canonical_forcing_t, canonical_interval_t, &
       canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_parameters_t, kernel_model_t
  implicit none

  type, extends(canonical_state_t) :: transport_state_t
    real(real64) :: storage_value = 0.0_real64
  contains
    procedure :: clone => clone_transport_state
  end type transport_state_t

  type, extends(canonical_forcing_t) :: transport_forcing_t
  end type transport_forcing_t

  type, extends(kernel_parameters_t) :: transport_parameters_t
  end type transport_parameters_t

  type, extends(kernel_model_t) :: transport_model_t
    logical :: trajectory_requested = .false.
    integer :: control_coordinate = 0
    real(real64) :: requested_t0 = 0.0_real64
    real(real64) :: requested_t1 = 0.0_real64
  contains
    procedure :: configure_parameters => configure_transport_parameters
    procedure :: execution_admitted => transport_execution_admitted
    procedure :: prepare_interval => prepare_transport_interval
    procedure :: advance => advance_transport_model
    procedure :: storage => storage_transport_model
    procedure :: storage_accounting_status => storage_status_transport_model
    procedure :: temporal_error => temporal_error_transport_model
    procedure :: accepted_trajectory_direction_snapshot => snapshot_transport_trajectory
  end type transport_model_t

contains

  subroutine make_transport_state(state, value)
    class(transaction_state_t), allocatable, intent(out) :: state
    real(real64), intent(in) :: value
    allocate(transport_state_t :: state)
    select type (typed => state)
    type is (transport_state_t)
      typed%storage_value = value
    end select
  end subroutine make_transport_state

  subroutine clone_transport_state(self, copy)
    class(transport_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(transport_state_t :: copy)
    select type (typed => copy)
    type is (transport_state_t)
      typed%storage_value = self%storage_value
    end select
  end subroutine clone_transport_state

  subroutine configure_transport_parameters(self, parameters)
    class(transport_model_t), intent(inout) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    if (.not. same_type_as(self, self) .or. .not. same_type_as(parameters, parameters)) &
      error stop 'unreachable parameter types'
  end subroutine configure_transport_parameters

  logical function transport_execution_admitted(self, parameters, numerical_config) result(admitted)
    class(transport_model_t), intent(in) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    type(canonical_numerical_config_t), intent(in) :: numerical_config
    admitted = same_type_as(self, self) .and. same_type_as(parameters, parameters) .and. &
         numerical_config%max_committed_substeps > 0
  end function transport_execution_admitted

  subroutine prepare_transport_interval(self, forcing, interval, config)
    class(transport_model_t), intent(inout) :: self
    class(canonical_forcing_t), intent(in) :: forcing
    type(canonical_interval_t), intent(in) :: interval
    type(canonical_numerical_config_t), intent(in) :: config
    self%trajectory_requested = config%accepted_trajectory_direction%requested
    self%control_coordinate = config%accepted_trajectory_direction%control_coordinate
    self%requested_t0 = interval%t0
    self%requested_t1 = interval%t1
    if (.not. same_type_as(forcing, forcing)) error stop 'unreachable forcing type'
  end subroutine prepare_transport_interval

  subroutine advance_transport_model(self, state, t0, t1, outcome)
    class(transport_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    real(real64) :: dt

    outcome = trial_outcome_t()
    dt = t1-t0
    select type (typed => state)
    type is (transport_state_t)
      typed%storage_value = typed%storage_value + dt
    class default
      return
    end select
    outcome%solver_ok = .true.
    outcome%mass_in = dt
    outcome%mass_out = 0.0_real64
    outcome%mass_accounting_complete = .true.
    outcome%missing_mass_contribution_mask = TX_MASS_MISSING_NONE
    if (.not. same_type_as(self, self)) error stop 'unreachable model type'
  end subroutine advance_transport_model

  function storage_transport_model(self, state) result(value)
    class(transport_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    real(real64) :: value
    value = huge(0.0_real64)
    select type (typed => state)
    type is (transport_state_t)
      value = typed%storage_value
    end select
    if (.not. same_type_as(self, self)) error stop 'unreachable model type'
  end function storage_transport_model

  subroutine storage_status_transport_model(self, state, complete, missing_mask)
    class(transport_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    logical, intent(out) :: complete
    integer(int64), intent(out) :: missing_mask

    complete = .false.
    missing_mask = TX_MASS_MISSING_UNSPECIFIED
    select type (typed => state)
    type is (transport_state_t)
      complete = .true.
      missing_mask = TX_MASS_MISSING_NONE
    end select
    if (.not. same_type_as(self, self)) error stop 'unreachable model type'
  end subroutine storage_status_transport_model

  function temporal_error_transport_model(self, full_state, half_state) result(value)
    class(transport_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state
    real(real64) :: value
    value = 0.0_real64
    if (.not. same_type_as(self, self) .or. .not. same_type_as(full_state, full_state) .or. &
        .not. same_type_as(half_state, half_state)) error stop 'unreachable temporal types'
  end function temporal_error_transport_model

  subroutine snapshot_transport_trajectory(self, interval, result)
    class(transport_model_t), intent(inout) :: self
    type(canonical_interval_t), intent(in) :: interval
    type(accepted_trajectory_direction_result_t), intent(out) :: result

    result = accepted_trajectory_direction_result_t()
    if (.not. self%trajectory_requested) return
    if (interval%t0 /= self%requested_t0 .or. interval%t1 /= self%requested_t1) return
    result%requested = .true.
    result%available = .true.
    result%worker_id = 17
    result%generation = 23_int64
    result%control_coordinate = self%control_coordinate
    result%accepted_steps = 2
    result%origin_t0 = interval%t0
    result%accepted_t1 = interval%t1
    result%accepted_bottom_exchange_derivative = 4.25_real64
    result%method = 'kernel-transport-fixture'
    result%route = 'accepted-trajectory'
  end subroutine snapshot_transport_trajectory

  subroutine assert_true(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      print '(A)', 'FAIL: '//trim(label)
      error stop 1
    end if
  end subroutine assert_true

end module test_fkt22_kernel_transport_fixture

program test_fkt22_kernel_trajectory_transport
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_canonical_contracts, only: canonical_numerical_config_t, CANONICAL_STATUS_COMPLETED
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_candidate_state_t, kernel_executor_t, &
       kernel_result_t, kernel_diagnostics_t
  use test_fkt22_kernel_transport_fixture, only: transport_model_t, transport_parameters_t, transport_forcing_t, &
       make_transport_state, assert_true
  implicit none

  type(transport_model_t), target :: model
  type(transport_parameters_t) :: parameters
  type(transport_forcing_t) :: forcing
  type(kernel_committed_state_t) :: committed
  type(kernel_candidate_state_t) :: candidate
  type(kernel_executor_t) :: executor
  type(kernel_result_t) :: result
  type(kernel_diagnostics_t) :: diagnostics
  type(canonical_numerical_config_t) :: config
  class(transaction_state_t), allocatable :: initial_state
  logical :: initialized

  call make_transport_state(initial_state, 0.0_real64)
  call committed%initialize(101_int64, initial_state, initialized, 0.0_real64)
  call assert_true(initialized, 'committed state initialized')
  call executor%bind_model(model)

  config%transaction%mass_tolerance = 1.0e-12_real64
  config%transaction%temporal_tolerance = 1.0e-12_real64
  config%transaction%max_retries = 1
  config%max_committed_substeps = 4
  config%accepted_trajectory_direction%requested = .true.
  config%accepted_trajectory_direction%control_coordinate = 5

  call executor%advance_interval(parameters, committed, forcing, config, 0.0_real64, 1.0_real64, &
       result, candidate, diagnostics)
  call assert_true(result%status == CANONICAL_STATUS_COMPLETED .and. result%completed, 'kernel interval completed')
  call assert_true(candidate%ready(), 'kernel candidate materialized')
  call assert_true(result%accepted_trajectory_direction%requested, 'kernel result keeps request provenance')
  call assert_true(result%accepted_trajectory_direction%available, 'kernel result keeps availability')
  call assert_true(result%accepted_trajectory_direction%worker_id == 17, 'kernel result keeps worker provenance')
  call assert_true(result%accepted_trajectory_direction%generation == 23_int64, 'kernel result keeps generation')
  call assert_true(result%accepted_trajectory_direction%control_coordinate == 5, 'kernel result keeps control coordinate')
  call assert_true(result%accepted_trajectory_direction%origin_t0 == 0.0_real64 .and. &
       result%accepted_trajectory_direction%accepted_t1 == 1.0_real64, 'kernel result keeps whole-window interval')
  call assert_true(result%accepted_trajectory_direction%accepted_bottom_exchange_derivative == 4.25_real64, &
       'kernel result keeps whole-window derivative')
  call assert_true(trim(result%accepted_trajectory_direction%route) == 'accepted-trajectory', 'kernel result keeps route')

  config%accepted_trajectory_direction%requested = .false.
  call executor%advance_interval(parameters, committed, forcing, config, 0.0_real64, 1.0_real64, &
       result, candidate, diagnostics)
  call assert_true(result%status == CANONICAL_STATUS_COMPLETED .and. result%completed, 'default-off kernel interval completed')
  call assert_true(.not. result%accepted_trajectory_direction%requested .and. &
       .not. result%accepted_trajectory_direction%available, 'default-off kernel result remains empty')

  print '(A)', 'FKT22_KERNEL_TRAJECTORY_TRANSPORT=PASS'
  print '(A)', 'FKT22_KERNEL_TYPED_PROVENANCE=PASS'
  print '(A)', 'FKT22_KERNEL_DEFAULT_OFF=PASS'
end program test_fkt22_kernel_trajectory_transport
