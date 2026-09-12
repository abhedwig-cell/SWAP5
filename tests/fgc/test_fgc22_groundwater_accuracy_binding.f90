program test_fgc22_groundwater_accuracy_binding
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_coupling_application_accuracy_contract, only: coupling_application_accuracy_contract_t, &
       COUPLING_QOI_GROUNDWATER_HEAD, COUPLING_QOI_GROUNDWATER_DRAWDOWN
  use mod_groundwater_coupling_policy, only: groundwater_head_convergence_policy_t, &
       GW_HEAD_POLICY_OK
  use mod_groundwater_accuracy_binding, only: groundwater_accuracy_binding_receipt_t, &
       bind_groundwater_head_accuracy, GW_ACCURACY_BIND_OK, GW_ACCURACY_BIND_UNSUPPORTED_QOI, &
       GW_ACCURACY_BIND_PROVENANCE_REUSE, GW_ACCURACY_BIND_INVALID_INTERFACE_ALLOCATION, &
       GW_ACCURACY_BIND_BUDGET_OVERALLOCATED
  implicit none

  type(coupling_application_accuracy_contract_t) :: accuracy
  type(groundwater_head_convergence_policy_t) :: policy
  type(groundwater_accuracy_binding_receipt_t) :: receipt
  integer :: status, policy_status
  logical :: converged, available
  integer(int64) :: contract_id, app_id, temporal_id, binding_id
  real(real64) :: h_app_m, temporal_budget_m, interface_tolerance_m, temporal_fraction, interface_fraction
  real(real64) :: nan_value

  accuracy = coupling_application_accuracy_contract_t()
  accuracy%contract_id = 17_int64
  accuracy%contract_version = 2
  accuracy%qoi_kind = COUPLING_QOI_GROUNDWATER_HEAD
  accuracy%h_app_available = .true.
  accuracy%h_app_cm = 10.0_real64
  accuracy%h_app_externally_qualified = .true.
  accuracy%application_provenance_id = 101_int64
  accuracy%a_temporal_available = .true.
  accuracy%a_temporal = 0.2_real64
  accuracy%a_temporal_externally_qualified = .true.
  accuracy%temporal_allocation_provenance_id = 202_int64

  call bind_groundwater_head_accuracy(accuracy, 33_int64, 1, 303_int64, 0.3_real64, policy, receipt, status)
  call require(status == GW_ACCURACY_BIND_OK, 'valid binding status')
  call require(policy%valid(), 'valid materialized policy')
  call require(receipt%ready(), 'valid binding receipt')
  call require(abs(policy%head_tolerance_m-0.03_real64) < 1.0e-14_real64, 'interface tolerance from explicit fraction')

  call receipt%provenance(contract_id, app_id, temporal_id, binding_id, available)
  call require(available, 'receipt provenance available')
  call require(contract_id == 17_int64 .and. app_id == 101_int64 .and. temporal_id == 202_int64 .and. &
       binding_id == 303_int64, 'three provenance identities preserved')

  call receipt%budgets(h_app_m, temporal_budget_m, interface_tolerance_m, temporal_fraction, interface_fraction, available)
  call require(available, 'receipt budgets available')
  call require(abs(h_app_m-0.10_real64) < 1.0e-14_real64, 'H_app unit conversion')
  call require(abs(temporal_budget_m-0.02_real64) < 1.0e-14_real64, 'temporal budget remains H_app*A_temporal')
  call require(abs(interface_tolerance_m-0.03_real64) < 1.0e-14_real64, 'interface budget separate from temporal budget')
  call require(abs(temporal_fraction-0.2_real64) < 1.0e-14_real64, 'temporal fraction preserved')
  call require(abs(interface_fraction-0.3_real64) < 1.0e-14_real64, 'interface fraction preserved')

  call policy%evaluate(0.029_real64, converged, policy_status)
  call require(policy_status == GW_HEAD_POLICY_OK .and. converged, 'residual inside governed tolerance')
  call policy%evaluate(0.031_real64, converged, policy_status)
  call require(policy_status == GW_HEAD_POLICY_OK .and. .not. converged, 'residual outside governed tolerance')

  call bind_groundwater_head_accuracy(accuracy, 33_int64, 1, 303_int64, 0.81_real64, policy, receipt, status)
  call require(status == GW_ACCURACY_BIND_BUDGET_OVERALLOCATED, 'combined budget overallocation rejected')
  call require(.not. policy%valid() .and. .not. receipt%ready(), 'overallocation fails closed')

  call bind_groundwater_head_accuracy(accuracy, 33_int64, 1, 101_int64, 0.3_real64, policy, receipt, status)
  call require(status == GW_ACCURACY_BIND_PROVENANCE_REUSE, 'binding provenance reuse rejected')

  accuracy%qoi_kind = COUPLING_QOI_GROUNDWATER_DRAWDOWN
  call bind_groundwater_head_accuracy(accuracy, 33_int64, 1, 303_int64, 0.3_real64, policy, receipt, status)
  call require(status == GW_ACCURACY_BIND_UNSUPPORTED_QOI, 'drawdown is outside restricted direct-head binding')
  accuracy%qoi_kind = COUPLING_QOI_GROUNDWATER_HEAD

  nan_value = ieee_value(0.0_real64, ieee_quiet_nan)
  call bind_groundwater_head_accuracy(accuracy, 33_int64, 1, 303_int64, nan_value, policy, receipt, status)
  call require(status == GW_ACCURACY_BIND_INVALID_INTERFACE_ALLOCATION, 'NaN allocation fails closed')

  call bind_groundwater_head_accuracy(accuracy, 33_int64, 1, 303_int64, 0.8_real64, policy, receipt, status)
  call require(status == GW_ACCURACY_BIND_OK, 'full explicit application budget may be partitioned exactly')
  call require(abs(policy%head_tolerance_m-0.08_real64) < 1.0e-14_real64, 'exact partition tolerance')

  write(*,'(a)') 'FGC22_GROUNDWATER_ACCURACY_BINDING=PASS'
  write(*,'(a,f0.8)') 'FGC22_TEMPORAL_BUDGET_M=', 0.02_real64
  write(*,'(a,f0.8)') 'FGC22_INTERFACE_TOLERANCE_M=', 0.03_real64
  write(*,'(a)') 'FGC22_NO_PROJECT_NUMERIC_DEFAULT=PASS'
  write(*,'(a)') 'FGC22_NO_TEMPORAL_INTERFACE_TOLERANCE_ALIAS=PASS'

contains

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write(*,'(a,a)') 'FGC22_TEST_FAIL: ', trim(message)
      error stop 1
    end if
  end subroutine require

end program test_fgc22_groundwater_accuracy_binding
