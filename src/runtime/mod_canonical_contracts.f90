module mod_canonical_contracts
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_transaction_reference, only: transaction_state_t, transaction_model_t, transaction_policy_t, &
       transaction_interface_sensitivity_t, TX_MASS_MISSING_UNSPECIFIED, TX_TEMPORAL_NONE
  use mod_accepted_trajectory_directional_publication, only: accepted_trajectory_direction_result_t
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

  ! Optional F-KT-owned request carrier for a model-provided accepted-trajectory
  ! directional result.  Absence is the default and must leave existing
  ! physical, mass and temporal acceptance semantics unchanged.  The integer
  ! control coordinate is interpreted only by a model that explicitly admits
  ! this capability; the canonical runtime attaches no solver semantics to it.
  type, public :: canonical_accepted_trajectory_direction_request_t
    logical :: requested = .false.
    integer :: control_coordinate = 0
  end type canonical_accepted_trajectory_direction_request_t

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
    type(canonical_accepted_trajectory_direction_request_t) :: accepted_trajectory_direction
  end type canonical_numerical_config_t

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
    ! Legacy/local-terminal transaction sensitivity remains unchanged and is
    ! intentionally distinct from the accepted-trajectory whole-window result.
    type(transaction_interface_sensitivity_t) :: interface_sensitivity
    type(accepted_trajectory_direction_result_t) :: accepted_trajectory_direction
    logical :: bottom_interface_exchange_available = .false.
    real(real64) :: bottom_outward_exchange_native = 0.0_real64
    real(real64) :: terminal_bottom_outward_flux_native = 0.0_real64
  end type canonical_result_t

  type, abstract, extends(transaction_model_t), public :: canonical_physical_model_t
  contains
    procedure(prepare_interval_iface), deferred :: prepare_interval
    ! Default is fail-closed/not-requested. Models that own a qualified
    ! trajectory composer may override this publication hook. The canonical
    ! runtime invokes it only after the complete requested interval is accepted.
    procedure :: accepted_trajectory_direction_snapshot => canonical_default_trajectory_direction_snapshot
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

  subroutine canonical_default_trajectory_direction_snapshot(self, interval, result)
    class(canonical_physical_model_t), intent(inout) :: self
    type(canonical_interval_t), intent(in) :: interval
    type(accepted_trajectory_direction_result_t), intent(out) :: result

    result = accepted_trajectory_direction_result_t()
    ! Keep dummy arguments semantically live without inventing default model
    ! behavior. Unsupported models simply publish no trajectory sensitivity.
    if (interval%t1 < interval%t0 .and. same_type_as(self, self)) then
      result%route = 'invalid-canonical-interval'
    end if
  end subroutine canonical_default_trajectory_direction_snapshot

end module mod_canonical_contracts
