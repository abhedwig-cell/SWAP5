program test_fgc14_external_accuracy_adapter
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_coupling_application_accuracy_contract, only: coupling_application_accuracy_contract_t, &
       COUPLING_QOI_GROUNDWATER_HEAD, COUPLING_QOI_GROUNDWATER_DRAWDOWN
  use mod_coupling_application_accuracy_adapter, only: coupling_application_accuracy_packet_view_t, &
       coupling_application_accuracy_adapter_diagnostics_t, adapt_verified_project_accuracy_view, &
       FGC14_EVIDENCE_SCHEMA_V1, FGC14_ADAPTER_OK, FGC14_ADAPTER_UNSUPPORTED_SCHEMA, &
       FGC14_ADAPTER_PACKET_NOT_VALIDATED, FGC14_ADAPTER_APPLICATION_SOURCE_NOT_VERIFIED, &
       FGC14_ADAPTER_TEMPORAL_SOURCE_NOT_VERIFIED, FGC14_ADAPTER_PROVENANCE_REUSE, &
       FGC14_ADAPTER_INVALID_APPLICATION_REQUIREMENT, FGC14_ADAPTER_INVALID_TEMPORAL_ALLOCATION
  implicit none

  call positive_head_case()
  call positive_drawdown_case()
  call rejection_cases()
  print '(a)', 'FGC14_TYPED_ADAPTER_TESTS=PASS'

contains

  function base_view() result(view)
    type(coupling_application_accuracy_packet_view_t) :: view
    view%evidence_schema_version = FGC14_EVIDENCE_SCHEMA_V1
    view%fgc13_packet_validated = .true.
    view%application_source_digest_content_verified = .true.
    view%temporal_source_digest_content_verified = .true.
    view%contract_id = 1401_int64
    view%contract_version = 1
    view%qoi_kind = COUPLING_QOI_GROUNDWATER_HEAD
    view%h_app_cm = 8.0_real64
    view%application_provenance_id = 14001_int64
    view%a_temporal = 0.25_real64
    view%temporal_allocation_provenance_id = 14002_int64
  end function base_view

  subroutine positive_head_case()
    type(coupling_application_accuracy_packet_view_t) :: view
    type(coupling_application_accuracy_contract_t) :: contract
    type(coupling_application_accuracy_adapter_diagnostics_t) :: diagnostics
    real(real64) :: budget
    logical :: available
    view = base_view()
    call adapt_verified_project_accuracy_view(view, contract, diagnostics)
    call check(diagnostics%status == FGC14_ADAPTER_OK, 'head status')
    call check(diagnostics%materialized, 'head materialized')
    call check(contract%qoi_kind == COUPLING_QOI_GROUNDWATER_HEAD, 'head qoi')
    call contract%evaluate_temporal_budget_cm(budget, available)
    call check(available, 'head budget available')
    call check(abs(budget - 2.0_real64) <= 1.0e-12_real64, 'head budget')
    print '(a)', 'FGC14_HEAD_FRACTION_MAPPING=PASS'
  end subroutine positive_head_case

  subroutine positive_drawdown_case()
    type(coupling_application_accuracy_packet_view_t) :: view
    type(coupling_application_accuracy_contract_t) :: contract
    type(coupling_application_accuracy_adapter_diagnostics_t) :: diagnostics
    real(real64) :: budget
    logical :: available
    view = base_view()
    view%contract_id = 1411_int64
    view%qoi_kind = COUPLING_QOI_GROUNDWATER_DRAWDOWN
    view%h_app_cm = 10.0_real64
    view%application_provenance_id = 14101_int64
    view%a_temporal = 0.2_real64
    view%temporal_allocation_provenance_id = 14102_int64
    call adapt_verified_project_accuracy_view(view, contract, diagnostics)
    call check(diagnostics%status == FGC14_ADAPTER_OK, 'drawdown status')
    call check(diagnostics%materialized, 'drawdown materialized')
    call contract%evaluate_temporal_budget_cm(budget, available)
    call check(available, 'drawdown budget available')
    call check(abs(budget - 2.0_real64) <= 1.0e-12_real64, 'drawdown budget')
    print '(a)', 'FGC14_DRAWDOWN_CANONICALIZED_DIRECT_BUDGET_MAPPING=PASS'
  end subroutine positive_drawdown_case

  subroutine rejection_cases()
    type(coupling_application_accuracy_packet_view_t) :: view

    view = base_view(); view%evidence_schema_version = 2
    call expect_reject(view, FGC14_ADAPTER_UNSUPPORTED_SCHEMA, 'schema')
    view = base_view(); view%fgc13_packet_validated = .false.
    call expect_reject(view, FGC14_ADAPTER_PACKET_NOT_VALIDATED, 'validation')
    view = base_view(); view%application_source_digest_content_verified = .false.
    call expect_reject(view, FGC14_ADAPTER_APPLICATION_SOURCE_NOT_VERIFIED, 'application source')
    view = base_view(); view%temporal_source_digest_content_verified = .false.
    call expect_reject(view, FGC14_ADAPTER_TEMPORAL_SOURCE_NOT_VERIFIED, 'temporal source')
    view = base_view(); view%temporal_allocation_provenance_id = view%application_provenance_id
    call expect_reject(view, FGC14_ADAPTER_PROVENANCE_REUSE, 'provenance reuse')
    view = base_view(); view%contract_id = 0_int64
    call expect_reject(view, FGC14_ADAPTER_INVALID_APPLICATION_REQUIREMENT, 'contract id')
    view = base_view(); view%qoi_kind = 99
    call expect_reject(view, FGC14_ADAPTER_INVALID_APPLICATION_REQUIREMENT, 'qoi')
    view = base_view(); view%h_app_cm = 0.0_real64
    call expect_reject(view, FGC14_ADAPTER_INVALID_APPLICATION_REQUIREMENT, 'H_app')
    view = base_view(); view%application_provenance_id = 0_int64
    call expect_reject(view, FGC14_ADAPTER_INVALID_APPLICATION_REQUIREMENT, 'application provenance')
    view = base_view(); view%a_temporal = 0.0_real64
    call expect_reject(view, FGC14_ADAPTER_INVALID_TEMPORAL_ALLOCATION, 'A_temporal zero')
    view = base_view(); view%a_temporal = 1.01_real64
    call expect_reject(view, FGC14_ADAPTER_INVALID_TEMPORAL_ALLOCATION, 'A_temporal high')
    view = base_view(); view%temporal_allocation_provenance_id = 0_int64
    call expect_reject(view, FGC14_ADAPTER_INVALID_TEMPORAL_ALLOCATION, 'temporal provenance')
    print '(a)', 'FGC14_FAIL_CLOSED_REJECTION_MATRIX=PASS:12'
  end subroutine rejection_cases

  subroutine expect_reject(view, expected, label)
    type(coupling_application_accuracy_packet_view_t), intent(in) :: view
    integer, intent(in) :: expected
    character(len=*), intent(in) :: label
    type(coupling_application_accuracy_contract_t) :: contract
    type(coupling_application_accuracy_adapter_diagnostics_t) :: diagnostics
    call adapt_verified_project_accuracy_view(view, contract, diagnostics)
    call check(diagnostics%status == expected, trim(label)//' status')
    call check(.not. diagnostics%materialized, trim(label)//' materialized')
    call check(contract%contract_id == 0_int64, trim(label)//' default id')
    call check(.not. contract%h_app_available, trim(label)//' H_app unavailable')
    call check(.not. contract%a_temporal_available, trim(label)//' A_temporal unavailable')
  end subroutine expect_reject

  subroutine check(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      print '(a)', 'FGC14_TEST_FAIL: '//trim(label)
      stop 1
    end if
  end subroutine check

end program test_fgc14_external_accuracy_adapter
