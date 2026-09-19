program test_hydro_memory_acc02_interface_accuracy_binding
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_coupling_application_accuracy_contract, only: coupling_application_accuracy_contract_t, &
       COUPLING_QOI_GROUNDWATER_HEAD
  use mod_coupling_application_accuracy_adapter, only: coupling_application_accuracy_packet_view_t, &
       coupling_application_accuracy_adapter_diagnostics_t, adapt_verified_project_accuracy_view, &
       FGC14_EVIDENCE_SCHEMA_V1, FGC14_ADAPTER_OK
  use mod_groundwater_coupling_policy, only: groundwater_head_convergence_policy_t, GW_HEAD_POLICY_OK
  use mod_groundwater_accuracy_binding, only: groundwater_accuracy_binding_receipt_t, &
       bind_groundwater_head_accuracy, GW_ACCURACY_BIND_OK
  implicit none

  real(real64), parameter :: H_APP_CM = 0.4_real64
  real(real64), parameter :: A_TEMPORAL = 0.25_real64
  real(real64), parameter :: A_INTERFACE = 0.25_real64
  real(real64), parameter :: EXPECTED_M = 0.001_real64

  type(coupling_application_accuracy_packet_view_t) :: view
  type(coupling_application_accuracy_contract_t) :: accuracy
  type(coupling_application_accuracy_adapter_diagnostics_t) :: adapter_diag
  type(groundwater_head_convergence_policy_t) :: policy
  type(groundwater_accuracy_binding_receipt_t) :: receipt
  type(canonical_numerical_config_t) :: numerical
  real(real64) :: h_app_m, temporal_budget_m, interface_tolerance_m
  real(real64) :: temporal_fraction, interface_fraction
  logical :: materialized, available, converged
  integer :: status
  integer(int64) :: contract_id, app_id, temporal_id, binding_id

  view%evidence_schema_version = FGC14_EVIDENCE_SCHEMA_V1
  view%fgc13_packet_validated = .true.
  view%application_source_digest_content_verified = .true.
  view%temporal_source_digest_content_verified = .true.
  view%contract_id = 590200_int64
  view%contract_version = 1
  view%qoi_kind = COUPLING_QOI_GROUNDWATER_HEAD
  view%h_app_cm = H_APP_CM
  view%application_provenance_id = 590201_int64
  view%a_temporal = A_TEMPORAL
  view%temporal_allocation_provenance_id = 590202_int64

  call adapt_verified_project_accuracy_view(view, accuracy, adapter_diag)
  call require(adapter_diag%status == FGC14_ADAPTER_OK .and. adapter_diag%materialized, &
       'ACC01 parent contract did not materialize')

  numerical%model_temporal_indicator_budget_available = .false.
  numerical%model_temporal_indicator_budget = 0.0_real64
  call accuracy%materialize_model_temporal_budget(numerical, materialized)
  call require(materialized .and. numerical%model_temporal_indicator_budget_available, &
       'temporal budget did not materialize')
  call require(close_real(numerical%model_temporal_indicator_budget, 0.1_real64), &
       'parent temporal budget drift')

  call bind_groundwater_head_accuracy(accuracy, 590210_int64, 1, 590203_int64, A_INTERFACE, &
       policy, receipt, status)
  call require(status == GW_ACCURACY_BIND_OK, 'groundwater accuracy binding rejected ACC02 policy')
  call require(policy%valid(), 'bound groundwater policy invalid')
  call require(close_real(policy%head_tolerance_m, EXPECTED_M), 'interface tolerance is not 0.001 m')
  call require(receipt%ready(), 'groundwater accuracy receipt not ready')

  call receipt%provenance(contract_id, app_id, temporal_id, binding_id, available)
  call require(available, 'receipt provenance unavailable')
  call require(contract_id == 590200_int64 .and. app_id == 590201_int64 .and. &
       temporal_id == 590202_int64 .and. binding_id == 590203_int64, 'receipt provenance identity drift')
  call require(app_id /= temporal_id .and. app_id /= binding_id .and. temporal_id /= binding_id, &
       'provenance identities not distinct')

  call receipt%budgets(h_app_m, temporal_budget_m, interface_tolerance_m, temporal_fraction, interface_fraction, available)
  call require(available, 'receipt budgets unavailable')
  call require(close_real(h_app_m, 0.004_real64), 'H_app m conversion')
  call require(close_real(temporal_budget_m, EXPECTED_M), 'temporal budget m conversion')
  call require(close_real(interface_tolerance_m, EXPECTED_M), 'interface tolerance receipt')
  call require(close_real(temporal_fraction, A_TEMPORAL), 'temporal fraction drift')
  call require(close_real(interface_fraction, A_INTERFACE), 'interface fraction drift')
  call require(close_real(temporal_fraction + interface_fraction, 0.5_real64), 'allocated fraction not 0.50')

  call policy%evaluate(EXPECTED_M, converged, status)
  call require(status == GW_HEAD_POLICY_OK .and. converged, 'positive boundary residual rejected')
  call policy%evaluate(-EXPECTED_M, converged, status)
  call require(status == GW_HEAD_POLICY_OK .and. converged, 'negative boundary residual rejected')
  call policy%evaluate(1.0001_real64*EXPECTED_M, converged, status)
  call require(status == GW_HEAD_POLICY_OK .and. .not. converged, 'above-budget residual accepted')

  write(*,'(a,es24.16)') 'HYDRO_MEMORY_ACC02_H_APP_M=', h_app_m
  write(*,'(a,es24.16)') 'HYDRO_MEMORY_ACC02_TEMPORAL_BUDGET_M=', temporal_budget_m
  write(*,'(a,es24.16)') 'HYDRO_MEMORY_ACC02_INTERFACE_TOLERANCE_M=', interface_tolerance_m
  write(*,'(a,es24.16)') 'HYDRO_MEMORY_ACC02_TEMPORAL_FRACTION=', temporal_fraction
  write(*,'(a,es24.16)') 'HYDRO_MEMORY_ACC02_INTERFACE_FRACTION=', interface_fraction
  write(*,'(a,es24.16)') 'HYDRO_MEMORY_ACC02_UNALLOCATED_FRACTION=', 1.0_real64-temporal_fraction-interface_fraction
  write(*,'(a)') 'HYDRO_MEMORY_ACC02_TYPED_INTERFACE_BINDING=PASS'
  write(*,'(a)') 'HYDRO_MEMORY_ACC02_BOUNDARY_POLICY=PASS'
  write(*,'(a)') 'HYDRO_MEMORY_ACC02_GOVERNANCE_QUALIFIED'

contains

  pure logical function close_real(a, b) result(close)
    real(real64), intent(in) :: a, b
    real(real64) :: scale
    scale = max(1.0_real64, abs(a), abs(b))
    close = abs(a-b) <= 64.0_real64*epsilon(1.0_real64)*scale
  end function close_real

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(a,1x,a)') 'HYDRO_MEMORY_ACC02_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require
end program test_hydro_memory_acc02_interface_accuracy_binding
