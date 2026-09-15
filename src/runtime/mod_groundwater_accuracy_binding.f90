module mod_groundwater_accuracy_binding
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_coupling_application_accuracy_contract, only: coupling_application_accuracy_contract_t, &
       COUPLING_QOI_GROUNDWATER_HEAD
  use mod_groundwater_coupling_policy, only: groundwater_head_convergence_policy_t, &
       GW_HEAD_TOLERANCE_PROVENANCE_GOVERNED_EXTERNAL
  implicit none
  private

  real(real64), parameter :: CM_TO_M = 0.01_real64

  integer, parameter, public :: GW_ACCURACY_BIND_OK = 0
  integer, parameter, public :: GW_ACCURACY_BIND_INVALID_APPLICATION = 1
  integer, parameter, public :: GW_ACCURACY_BIND_INVALID_TEMPORAL = 2
  integer, parameter, public :: GW_ACCURACY_BIND_UNSUPPORTED_QOI = 3
  integer, parameter, public :: GW_ACCURACY_BIND_INVALID_PROVENANCE = 4
  integer, parameter, public :: GW_ACCURACY_BIND_PROVENANCE_REUSE = 5
  integer, parameter, public :: GW_ACCURACY_BIND_INVALID_INTERFACE_ALLOCATION = 6
  integer, parameter, public :: GW_ACCURACY_BIND_BUDGET_OVERALLOCATED = 7
  integer, parameter, public :: GW_ACCURACY_BIND_POLICY_INVALID = 8

  type, public :: groundwater_accuracy_binding_receipt_t
    private
    logical :: initialized = .false.
    integer(int64) :: contract_id_value = 0_int64
    integer(int64) :: application_provenance_id_value = 0_int64
    integer(int64) :: temporal_provenance_id_value = 0_int64
    integer(int64) :: binding_provenance_id_value = 0_int64
    real(real64) :: h_app_m_value = 0.0_real64
    real(real64) :: temporal_budget_m_value = 0.0_real64
    real(real64) :: interface_tolerance_m_value = 0.0_real64
    real(real64) :: temporal_fraction_value = 0.0_real64
    real(real64) :: interface_fraction_value = 0.0_real64
  contains
    procedure, public :: ready => groundwater_accuracy_receipt_ready
    procedure, public :: provenance => groundwater_accuracy_receipt_provenance
    procedure, public :: budgets => groundwater_accuracy_receipt_budgets
  end type groundwater_accuracy_binding_receipt_t

  public :: bind_groundwater_head_accuracy

contains

  subroutine bind_groundwater_head_accuracy(accuracy, policy_id, policy_version, binding_provenance_id, &
                                             interface_allocation_fraction, policy, receipt, status)
    type(coupling_application_accuracy_contract_t), intent(in) :: accuracy
    integer(int64), intent(in) :: policy_id
    integer, intent(in) :: policy_version
    integer(int64), intent(in) :: binding_provenance_id
    real(real64), intent(in) :: interface_allocation_fraction
    type(groundwater_head_convergence_policy_t), intent(out) :: policy
    type(groundwater_accuracy_binding_receipt_t), intent(out) :: receipt
    integer, intent(out) :: status

    real(real64) :: allocation_sum, scale

    policy = groundwater_head_convergence_policy_t()
    receipt = groundwater_accuracy_binding_receipt_t()
    status = GW_ACCURACY_BIND_INVALID_APPLICATION

    if (.not. accuracy%application_requirement_valid()) return
    status = GW_ACCURACY_BIND_INVALID_TEMPORAL
    if (.not. accuracy%temporal_allocation_valid()) return

    status = GW_ACCURACY_BIND_UNSUPPORTED_QOI
    if (accuracy%qoi_kind /= COUPLING_QOI_GROUNDWATER_HEAD) return

    status = GW_ACCURACY_BIND_INVALID_PROVENANCE
    if (policy_id <= 0_int64 .or. policy_version <= 0) return
    if (binding_provenance_id <= 0_int64) return

    status = GW_ACCURACY_BIND_PROVENANCE_REUSE
    if (accuracy%application_provenance_id == accuracy%temporal_allocation_provenance_id) return
    if (binding_provenance_id == accuracy%application_provenance_id) return
    if (binding_provenance_id == accuracy%temporal_allocation_provenance_id) return

    status = GW_ACCURACY_BIND_INVALID_INTERFACE_ALLOCATION
    if (.not. ieee_is_finite(interface_allocation_fraction)) return
    if (interface_allocation_fraction <= 0.0_real64) return
    if (interface_allocation_fraction > 1.0_real64) return

    allocation_sum = accuracy%a_temporal + interface_allocation_fraction
    if (.not. ieee_is_finite(allocation_sum)) return
    scale = max(1.0_real64, abs(accuracy%a_temporal), abs(interface_allocation_fraction))
    status = GW_ACCURACY_BIND_BUDGET_OVERALLOCATED
    if (allocation_sum > 1.0_real64 + 64.0_real64*epsilon(1.0_real64)*scale) return

    policy%available = .true.
    policy%policy_id = policy_id
    policy%policy_version = policy_version
    policy%provenance_class = GW_HEAD_TOLERANCE_PROVENANCE_GOVERNED_EXTERNAL
    policy%provenance_id = binding_provenance_id
    policy%provenance_qualified = .true.
    policy%head_tolerance_m = accuracy%h_app_cm * CM_TO_M * interface_allocation_fraction

    status = GW_ACCURACY_BIND_POLICY_INVALID
    if (.not. policy%valid()) then
      policy = groundwater_head_convergence_policy_t()
      return
    end if

    receipt%contract_id_value = accuracy%contract_id
    receipt%application_provenance_id_value = accuracy%application_provenance_id
    receipt%temporal_provenance_id_value = accuracy%temporal_allocation_provenance_id
    receipt%binding_provenance_id_value = binding_provenance_id
    receipt%h_app_m_value = accuracy%h_app_cm * CM_TO_M
    receipt%temporal_budget_m_value = accuracy%h_app_cm * CM_TO_M * accuracy%a_temporal
    receipt%interface_tolerance_m_value = policy%head_tolerance_m
    receipt%temporal_fraction_value = accuracy%a_temporal
    receipt%interface_fraction_value = interface_allocation_fraction
    receipt%initialized = .true.
    status = GW_ACCURACY_BIND_OK
  end subroutine bind_groundwater_head_accuracy

  pure logical function groundwater_accuracy_receipt_ready(self) result(ready)
    class(groundwater_accuracy_binding_receipt_t), intent(in) :: self
    real(real64) :: scale

    ready = .false.
    if (.not. self%initialized) return
    if (self%contract_id_value <= 0_int64) return
    if (self%application_provenance_id_value <= 0_int64) return
    if (self%temporal_provenance_id_value <= 0_int64) return
    if (self%binding_provenance_id_value <= 0_int64) return
    if (self%application_provenance_id_value == self%temporal_provenance_id_value) return
    if (self%binding_provenance_id_value == self%application_provenance_id_value) return
    if (self%binding_provenance_id_value == self%temporal_provenance_id_value) return
    if (.not. ieee_is_finite(self%h_app_m_value) .or. self%h_app_m_value <= 0.0_real64) return
    if (.not. ieee_is_finite(self%temporal_budget_m_value) .or. self%temporal_budget_m_value <= 0.0_real64) return
    if (.not. ieee_is_finite(self%interface_tolerance_m_value) .or. self%interface_tolerance_m_value <= 0.0_real64) return
    if (.not. ieee_is_finite(self%temporal_fraction_value) .or. self%temporal_fraction_value <= 0.0_real64) return
    if (.not. ieee_is_finite(self%interface_fraction_value) .or. self%interface_fraction_value <= 0.0_real64) return
    scale = max(1.0_real64, abs(self%temporal_fraction_value), abs(self%interface_fraction_value))
    if (self%temporal_fraction_value + self%interface_fraction_value > &
        1.0_real64 + 64.0_real64*epsilon(1.0_real64)*scale) return
    ready = .true.
  end function groundwater_accuracy_receipt_ready

  subroutine groundwater_accuracy_receipt_provenance(self, contract_id, application_id, temporal_id, binding_id, available)
    class(groundwater_accuracy_binding_receipt_t), intent(in) :: self
    integer(int64), intent(out) :: contract_id, application_id, temporal_id, binding_id
    logical, intent(out) :: available

    available = self%ready()
    if (available) then
      contract_id = self%contract_id_value
      application_id = self%application_provenance_id_value
      temporal_id = self%temporal_provenance_id_value
      binding_id = self%binding_provenance_id_value
    else
      contract_id = 0_int64
      application_id = 0_int64
      temporal_id = 0_int64
      binding_id = 0_int64
    end if
  end subroutine groundwater_accuracy_receipt_provenance

  subroutine groundwater_accuracy_receipt_budgets(self, h_app_m, temporal_budget_m, interface_tolerance_m, &
                                                   temporal_fraction, interface_fraction, available)
    class(groundwater_accuracy_binding_receipt_t), intent(in) :: self
    real(real64), intent(out) :: h_app_m, temporal_budget_m, interface_tolerance_m
    real(real64), intent(out) :: temporal_fraction, interface_fraction
    logical, intent(out) :: available

    available = self%ready()
    if (available) then
      h_app_m = self%h_app_m_value
      temporal_budget_m = self%temporal_budget_m_value
      interface_tolerance_m = self%interface_tolerance_m_value
      temporal_fraction = self%temporal_fraction_value
      interface_fraction = self%interface_fraction_value
    else
      h_app_m = 0.0_real64
      temporal_budget_m = 0.0_real64
      interface_tolerance_m = 0.0_real64
      temporal_fraction = 0.0_real64
      interface_fraction = 0.0_real64
    end if
  end subroutine groundwater_accuracy_receipt_budgets

end module mod_groundwater_accuracy_binding
