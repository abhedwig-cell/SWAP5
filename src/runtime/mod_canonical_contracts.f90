module mod_canonical_contracts
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_transaction_reference, only: transaction_state_t, transaction_model_t, transaction_policy_t, &
       transaction_interface_sensitivity_t, TX_MASS_MISSING_UNSPECIFIED, TX_TEMPORAL_NONE
  implicit none
  private

  integer, parameter, public :: CANONICAL_STATUS_COMPLETED = 0
  integer, parameter, public :: CANONICAL_STATUS_INVALID_REQUEST = 1
  integer, parameter, public :: CANONICAL_STATUS_TRANSACTION_FAILED = 2
  integer, parameter, public :: CANONICAL_STATUS_NO_PROGRESS = 3
  integer, parameter, public :: CANONICAL_STATUS_SUBSTEP_LIMIT = 4

  type, abstract, extends(transaction_state_t), public :: canonical_state_t
  end type canonical_state_t

  type, abstract, public :: canonical_forcing_t
  end type canonical_forcing_t

  type, public :: canonical_interval_t
    real(real64) :: t0 = 0.0_real64
    real(real64) :: t1 = 0.0_real64
  end type canonical_interval_t

  type, public :: canonical_numerical_config_t
    type(transaction_policy_t) :: transaction
    integer :: max_committed_substeps = 10000
    real(real64) :: progress_tolerance = 0.0_real64
    ! Generic carrier for a model-owned temporal-indicator budget.  The
    ! canonical runtime and F-KT transaction core deliberately do not attach
    ! physical units or estimator semantics to this scalar.  The selected
    ! model owns that interpretation and must normalize its native indicator
    ! into the dimensionless F-KT09 certificate surface.  Absence is the
    ! default; zero is never an implicit budget.
    logical :: model_temporal_indicator_budget_available = .false.
    real(real64) :: model_temporal_indicator_budget = 0.0_real64
  end type canonical_numerical_config_t

  ! Optional generic request for one directional response over the complete
  ! canonical [t0,t1] interval.  The control coordinate is model-owned; F-KT
  ! only preserves request/provenance and never assigns physical meaning to it.
  type, public :: canonical_directional_response_request_t
    logical :: requested = .false.
    integer :: control_coordinate = 0
  end type canonical_directional_response_request_t

  ! Generic whole-window publication carrier.  It intentionally exposes only
  ! the interface quantity needed by coupling owners.  Model-internal state
  ! direction vectors remain private to the numerical implementation.
  type, public :: canonical_directional_response_t
    logical :: requested = .false.
    logical :: available = .false.
    integer :: control_coordinate = 0
    integer :: accepted_steps = 0
    real(real64) :: origin_t0 = 0.0_real64
    real(real64) :: accepted_t1 = 0.0_real64
    real(real64) :: accepted_bottom_exchange_derivative = 0.0_real64
    character(len=48) :: method = 'not-requested'
    character(len=64) :: route = 'not-requested'
    integer :: additional_tridiagonal_backsolves = 0
    integer :: additional_jacobian_builds = 0
    integer :: additional_full_nonlinear_solves = 0
  end type canonical_directional_response_t

  type, public :: canonical_mass_accounting_t
    logical :: complete = .false.
    real(real64) :: interval_t0 = 0.0_real64
    real(real64) :: interval_t1 = 0.0_real64
    integer(int64) :: origin_lineage_id = 0_int64
    integer(int64) :: origin_revision = -1_int64
    integer :: accepted_transaction_count = 0
    integer(int64) :: missing_contribution_mask = TX_MASS_MISSING_UNSPECIFIED
    real(real64) :: storage_start = 0.0_real64
    real(real64) :: storage_end = 0.0_real64
    real(real64) :: storage_change = 0.0_real64
    real(real64) :: total_in = 0.0_real64
    real(real64) :: total_out = 0.0_real64
    real(real64) :: residual = 0.0_real64
  end type canonical_mass_accounting_t

  type, public :: canonical_run_diagnostics_t
    integer :: transaction_calls = 0
    integer :: committed_substeps = 0
    integer :: external_commits = 0
    integer :: attempts = 0
    integer :: retries = 0
    integer :: rollbacks = 0
    integer :: solver_rejections = 0
    integer :: temporal_rejections = 0
    integer :: temporal_certificate_unavailable_rejections = 0
    integer :: temporal_acceptance_source = TX_TEMPORAL_NONE
    integer :: mass_rejections = 0
    integer :: nonlinear_iterations = 0
    integer :: internal_retries = 0
    integer :: headcalc_calls = 0
    integer :: jacobian_builds = 0
    integer :: linear_solves = 0
    integer :: backtracking_attempts = 0
    integer :: alternative_solver_calls = 0
    real(real64) :: max_abs_step_mass_residual = 0.0_real64
    real(real64) :: max_temporal_indicator = 0.0_real64
    real(real64) :: min_accepted_substep_duration = huge(0.0_real64)
    real(real64) :: max_accepted_substep_duration = 0.0_real64
  end type canonical_run_diagnostics_t

  type, public :: canonical_result_t
    integer :: status = CANONICAL_STATUS_INVALID_REQUEST
    logical :: completed = .false.
    real(real64) :: requested_t0 = 0.0_real64
    real(real64) :: requested_t1 = 0.0_real64
    real(real64) :: completed_t = 0.0_real64
    type(canonical_mass_accounting_t) :: mass
    type(canonical_run_diagnostics_t) :: diagnostics
    type(transaction_interface_sensitivity_t) :: interface_sensitivity
    type(canonical_directional_response_t) :: directional_response
    logical :: bottom_interface_exchange_available = .false.
    real(real64) :: bottom_outward_exchange_native = 0.0_real64
    real(real64) :: terminal_bottom_outward_flux_native = 0.0_real64
  end type canonical_result_t

  type, abstract, extends(transaction_model_t), public :: canonical_physical_model_t
  contains
    procedure(prepare_interval_iface), deferred :: prepare_interval
    procedure :: begin_directional_response => canonical_begin_directional_response_default
    procedure :: finish_directional_response => canonical_finish_directional_response_default
  end type canonical_physical_model_t

  abstract interface
    subroutine prepare_interval_iface(self, forcing, interval, config)
      import :: canonical_physical_model_t, canonical_forcing_t, canonical_interval_t, &
                canonical_numerical_config_t
      class(canonical_physical_model_t), intent(inout) :: self
      class(canonical_forcing_t), intent(in) :: forcing
      type(canonical_interval_t), intent(in) :: interval
      type(canonical_numerical_config_t), intent(in) :: config
    end subroutine prepare_interval_iface
  end interface

contains

  subroutine canonical_begin_directional_response_default(self, request, interval, active)
    class(canonical_physical_model_t), intent(inout) :: self
    type(canonical_directional_response_request_t), intent(in) :: request
    type(canonical_interval_t), intent(in) :: interval
    logical, intent(out) :: active

    active = .false.
    if (.not. request%requested) return
    if (interval%t1 <= interval%t0) return
    if (.not. same_type_as(self, self)) return
  end subroutine canonical_begin_directional_response_default

  subroutine canonical_finish_directional_response_default(self, interval, completed, response)
    class(canonical_physical_model_t), intent(inout) :: self
    type(canonical_interval_t), intent(in) :: interval
    logical, intent(in) :: completed
    type(canonical_directional_response_t), intent(out) :: response

    response = canonical_directional_response_t()
    response%requested = .true.
    response%origin_t0 = interval%t0
    response%accepted_t1 = interval%t0
    response%method = 'unavailable'
    response%route = 'model-directional-response-unavailable'
    if (completed) response%accepted_t1 = interval%t1
    if (.not. same_type_as(self, self)) return
  end subroutine canonical_finish_directional_response_default

end module mod_canonical_contracts
