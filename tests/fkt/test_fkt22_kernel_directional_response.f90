module fkt22_kernel_test_support
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t, trial_outcome_t, TX_MASS_MISSING_NONE
  use mod_canonical_contracts, only: canonical_forcing_t, canonical_interval_t, canonical_numerical_config_t, &
       canonical_directional_response_request_t, canonical_directional_response_t
  use mod_kernel_transactions, only: kernel_model_t, kernel_parameters_t
  implicit none

  type, extends(transaction_state_t) :: probe_state_t
    real(real64) :: value = 0.0_real64
  contains
    procedure :: clone => probe_clone
  end type probe_state_t

  type, extends(canonical_forcing_t) :: probe_forcing_t
  end type probe_forcing_t

  type, extends(kernel_parameters_t) :: probe_parameters_t
  end type probe_parameters_t

  type, extends(kernel_model_t) :: probe_kernel_model_t
    integer :: begin_calls = 0
    integer :: finish_calls = 0
    integer :: control_coordinate = 0
  contains
    procedure :: configure_parameters => probe_configure_parameters
    procedure :: execution_admitted => probe_execution_admitted
    procedure :: advance => probe_advance
    procedure :: storage => probe_storage
    procedure :: temporal_error => probe_temporal_error
    procedure :: storage_accounting_status => probe_storage_status
    procedure :: prepare_interval => probe_prepare_interval
    procedure :: begin_directional_response => probe_begin_directional_response
    procedure :: finish_directional_response => probe_finish_directional_response
  end type probe_kernel_model_t

contains

  subroutine probe_clone(self, copy)
    class(probe_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(probe_state_t :: copy)
    select type (target => copy)
    type is (probe_state_t)
      target%value = self%value
    end select
  end subroutine probe_clone

  subroutine probe_configure_parameters(self, parameters)
    class(probe_kernel_model_t), intent(inout) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    if (.not. same_type_as(self, self) .or. .not. same_type_as(parameters, parameters)) &
      error stop 'F-KT22 kernel probe: unreachable configure'
  end subroutine probe_configure_parameters

  logical function probe_execution_admitted(self, parameters, numerical_config) result(admitted)
    class(probe_kernel_model_t), intent(in) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    type(canonical_numerical_config_t), intent(in) :: numerical_config
    admitted = numerical_config%max_committed_substeps > 0
    if (.not. same_type_as(self, self) .or. .not. same_type_as(parameters, parameters)) &
      error stop 'F-KT22 kernel probe: unreachable admission'
  end function probe_execution_admitted

  subroutine probe_advance(self, state, t0, t1, outcome)
    class(probe_kernel_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    real(real64) :: dt

    outcome = trial_outcome_t()
    dt = t1-t0
    select type (typed => state)
    type is (probe_state_t)
      typed%value = typed%value + dt
    class default
      error stop 'F-KT22 kernel probe: unexpected state'
    end select
    outcome%solver_ok = .true.
    outcome%mass_in = dt
    outcome%mass_out = 0.0_real64
    outcome%mass_accounting_complete = .true.
    outcome%missing_mass_contribution_mask = TX_MASS_MISSING_NONE
    outcome%temporal_certificate_available = .true.
    outcome%temporal_indicator = 0.0_real64
    outcome%bottom_interface_exchange_available = .true.
    outcome%bottom_outward_exchange_native = dt
    outcome%terminal_bottom_outward_flux_native = 1.0_real64
    if (.not. same_type_as(self, self)) error stop 'F-KT22 kernel probe: unreachable advance'
  end subroutine probe_advance

  real(real64) function probe_storage(self, state) result(value)
    class(probe_kernel_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    value = 0.0_real64
    select type (typed => state)
    type is (probe_state_t)
      value = typed%value
    class default
      error stop 'F-KT22 kernel probe: unexpected storage state'
    end select
    if (.not. same_type_as(self, self)) error stop 'F-KT22 kernel probe: unreachable storage'
  end function probe_storage

  real(real64) function probe_temporal_error(self, full_state, half_state) result(value)
    class(probe_kernel_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state
    value = 0.0_real64
    if (.not. same_type_as(self, self) .or. .not. same_type_as(full_state, full_state) .or. &
        .not. same_type_as(half_state, half_state)) error stop 'F-KT22 kernel probe: unreachable temporal'
  end function probe_temporal_error

  subroutine probe_storage_status(self, state, complete, missing_mask)
    class(probe_kernel_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    logical, intent(out) :: complete
    integer(int64), intent(out) :: missing_mask
    complete = .true.
    missing_mask = TX_MASS_MISSING_NONE
    if (.not. same_type_as(self, self) .or. .not. same_type_as(state, state)) &
      error stop 'F-KT22 kernel probe: unreachable storage status'
  end subroutine probe_storage_status

  subroutine probe_prepare_interval(self, forcing, interval, config)
    class(probe_kernel_model_t), intent(inout) :: self
    class(canonical_forcing_t), intent(in) :: forcing
    type(canonical_interval_t), intent(in) :: interval
    type(canonical_numerical_config_t), intent(in) :: config
    if (.not. same_type_as(self, self) .or. .not. same_type_as(forcing, forcing) .or. &
        interval%t1 <= interval%t0 .or. config%max_committed_substeps <= 0) &
      error stop 'F-KT22 kernel probe: invalid prepare'
  end subroutine probe_prepare_interval

  subroutine probe_begin_directional_response(self, request, interval, active)
    class(probe_kernel_model_t), intent(inout) :: self
    type(canonical_directional_response_request_t), intent(in) :: request
    type(canonical_interval_t), intent(in) :: interval
    logical, intent(out) :: active
    self%begin_calls = self%begin_calls + 1
    self%control_coordinate = request%control_coordinate
    active = request%requested .and. request%control_coordinate > 0 .and. interval%t1 > interval%t0
  end subroutine probe_begin_directional_response

  subroutine probe_finish_directional_response(self, interval, completed, response)
    class(probe_kernel_model_t), intent(inout) :: self
    type(canonical_interval_t), intent(in) :: interval
    logical, intent(in) :: completed
    type(canonical_directional_response_t), intent(out) :: response
    self%finish_calls = self%finish_calls + 1
    response = canonical_directional_response_t()
    response%requested = .true.
    response%control_coordinate = self%control_coordinate
    response%origin_t0 = interval%t0
    response%accepted_t1 = interval%t0
    response%method = 'probe-kernel'
    response%route = 'not-completed'
    if (completed) then
      response%available = .true.
      response%accepted_steps = 1
      response%accepted_t1 = interval%t1
      response%accepted_bottom_exchange_derivative = 3.0_real64*(interval%t1-interval%t0)
      response%route = 'whole-window'
    end if
  end subroutine probe_finish_directional_response

end module fkt22_kernel_test_support

program test_fkt22_kernel_directional_response
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_numerical_config_t, canonical_directional_response_request_t
  use mod_kernel_transactions, only: kernel_executor_t, kernel_committed_state_t, kernel_candidate_state_t, &
       kernel_result_t, kernel_diagnostics_t
  use fkt22_kernel_test_support, only: probe_state_t, probe_forcing_t, probe_parameters_t, probe_kernel_model_t
  implicit none

  type(kernel_executor_t) :: executor
  type(kernel_committed_state_t) :: committed
  type(kernel_candidate_state_t) :: candidate
  type(kernel_result_t) :: result
  type(kernel_diagnostics_t) :: diagnostics
  type(probe_kernel_model_t), target :: model
  type(probe_forcing_t) :: forcing
  type(probe_parameters_t) :: parameters
  type(probe_state_t) :: seed
  class(transaction_state_t), allocatable :: initial
  type(canonical_numerical_config_t) :: config
  type(canonical_directional_response_request_t) :: request
  logical :: initialized

  call seed%clone(initial)
  call committed%initialize(91_int64, initial, initialized, initial_time=0.0_real64)
  call assert_true(initialized, 'committed state initialized')
  call executor%bind_model(model)

  config%transaction%temporal_mode = TX_TEMPORAL_MODEL_CERTIFICATE
  config%transaction%temporal_tolerance = 1.0_real64
  config%transaction%mass_tolerance = 1.0e-12_real64
  config%transaction%max_retries = 0
  config%max_committed_substeps = 4
  request%requested = .true.
  request%control_coordinate = 2

  call executor%advance_interval(parameters, committed, forcing, config, 0.0_real64, 1.0_real64, &
       result, candidate, diagnostics, directional_request=request)

  call assert_true(result%completed, 'kernel physical interval completed')
  call assert_true(result%directional_response%requested, 'kernel request carried')
  call assert_true(result%directional_response%available, 'kernel response available')
  call assert_true(result%directional_response%control_coordinate == 2, 'kernel control coordinate carried')
  call assert_true(result%directional_response%origin_t0 == 0.0_real64 .and. &
       result%directional_response%accepted_t1 == 1.0_real64, 'kernel whole-window provenance')
  call assert_true(abs(result%directional_response%accepted_bottom_exchange_derivative-3.0_real64) < 1.0e-14_real64, &
       'kernel derivative carried')
  call assert_true(model%begin_calls == 1 .and. model%finish_calls == 1, 'kernel invokes one lifecycle')

  print '(A)', 'FKT22_KERNEL_DIRECTIONAL_RESPONSE PASS'
  print '(A)', 'FKT22_KERNEL_REQUEST_FORWARDING=PASS'
  print '(A)', 'FKT22_KERNEL_RESULT_MAPPING=PASS'

contains

  subroutine assert_true(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'ASSERTION FAILED:', trim(label)
      error stop 1
    end if
  end subroutine assert_true

end program test_fkt22_kernel_directional_response
