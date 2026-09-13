module mod_coupling_application_accuracy_contract
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_canonical_contracts, only: canonical_numerical_config_t
  implicit none
  private

  integer, parameter, public :: COUPLING_QOI_GROUNDWATER_HEAD = 1
  integer, parameter, public :: COUPLING_QOI_GROUNDWATER_DRAWDOWN = 2

  type, public :: coupling_application_accuracy_contract_t
    integer(int64) :: contract_id = 0_int64
    integer :: contract_version = 0
    integer :: qoi_kind = 0

    logical :: h_app_available = .false.
    real(real64) :: h_app_cm = 0.0_real64
    logical :: h_app_externally_qualified = .false.
    integer(int64) :: application_provenance_id = 0_int64

    logical :: a_temporal_available = .false.
    real(real64) :: a_temporal = 0.0_real64
    logical :: a_temporal_externally_qualified = .false.
    integer(int64) :: temporal_allocation_provenance_id = 0_int64
  contains
    procedure :: application_requirement_valid
    procedure :: temporal_allocation_valid
    procedure :: temporal_budget_ready
    procedure :: evaluate_temporal_budget_cm
    procedure :: materialize_model_temporal_budget
  end type coupling_application_accuracy_contract_t

contains

  pure logical function identity_and_qoi_valid(self)
    class(coupling_application_accuracy_contract_t), intent(in) :: self

    identity_and_qoi_valid = self%contract_id > 0_int64 .and. self%contract_version > 0 .and. &
         (self%qoi_kind == COUPLING_QOI_GROUNDWATER_HEAD .or. &
          self%qoi_kind == COUPLING_QOI_GROUNDWATER_DRAWDOWN)
  end function identity_and_qoi_valid

  pure logical function application_requirement_valid(self)
    class(coupling_application_accuracy_contract_t), intent(in) :: self

    ! Use explicit guards rather than relying on logical-expression
    ! short-circuiting. Fortran does not require short-circuit evaluation, and
    ! comparing a NaN after a failed ieee_is_finite check can raise invalid
    ! when runtime floating-point traps are enabled.
    application_requirement_valid = .false.
    if (.not. identity_and_qoi_valid(self)) return
    if (.not. self%h_app_available) return
    if (.not. self%h_app_externally_qualified) return
    if (self%application_provenance_id <= 0_int64) return
    if (.not. ieee_is_finite(self%h_app_cm)) return
    if (self%h_app_cm <= 0.0_real64) return
    application_requirement_valid = .true.
  end function application_requirement_valid

  pure logical function temporal_allocation_valid(self)
    class(coupling_application_accuracy_contract_t), intent(in) :: self

    temporal_allocation_valid = .false.
    if (.not. identity_and_qoi_valid(self)) return
    if (.not. self%a_temporal_available) return
    if (.not. self%a_temporal_externally_qualified) return
    if (self%temporal_allocation_provenance_id <= 0_int64) return
    if (.not. ieee_is_finite(self%a_temporal)) return
    if (self%a_temporal <= 0.0_real64) return
    if (self%a_temporal > 1.0_real64) return
    temporal_allocation_valid = .true.
  end function temporal_allocation_valid

  pure logical function temporal_budget_ready(self)
    class(coupling_application_accuracy_contract_t), intent(in) :: self
    real(real64) :: budget_cm

    temporal_budget_ready = .false.
    if (.not. self%application_requirement_valid()) return
    if (.not. self%temporal_allocation_valid()) return

    budget_cm = self%h_app_cm * self%a_temporal
    if (.not. ieee_is_finite(budget_cm)) return
    if (budget_cm <= 0.0_real64) return
    temporal_budget_ready = .true.
  end function temporal_budget_ready

  pure subroutine evaluate_temporal_budget_cm(self, budget_cm, available)
    class(coupling_application_accuracy_contract_t), intent(in) :: self
    real(real64), intent(out) :: budget_cm
    logical, intent(out) :: available

    budget_cm = 0.0_real64
    available = self%temporal_budget_ready()
    if (available) budget_cm = self%h_app_cm * self%a_temporal
  end subroutine evaluate_temporal_budget_cm

  subroutine materialize_model_temporal_budget(self, config, materialized)
    class(coupling_application_accuracy_contract_t), intent(in) :: self
    type(canonical_numerical_config_t), intent(inout) :: config
    logical, intent(out) :: materialized
    real(real64) :: budget_cm

    ! Fail closed and clear any previous application-owned value first. The
    ! canonical field remains a generic model-owned carrier; application
    ! provenance and allocation semantics stay in this runtime/coupler contract.
    config%model_temporal_indicator_budget_available = .false.
    config%model_temporal_indicator_budget = 0.0_real64

    call self%evaluate_temporal_budget_cm(budget_cm, materialized)
    if (.not. materialized) return

    config%model_temporal_indicator_budget_available = .true.
    config%model_temporal_indicator_budget = budget_cm
  end subroutine materialize_model_temporal_budget

end module mod_coupling_application_accuracy_contract
