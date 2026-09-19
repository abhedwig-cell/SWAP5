program test_hydro_memory_acc01_accuracy_binding
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_coupling_application_accuracy_contract, only: coupling_application_accuracy_contract_t, &
       COUPLING_QOI_GROUNDWATER_HEAD
  use mod_coupling_application_accuracy_adapter, only: coupling_application_accuracy_packet_view_t, &
       coupling_application_accuracy_adapter_diagnostics_t, adapt_verified_project_accuracy_view, &
       FGC14_EVIDENCE_SCHEMA_V1, FGC14_ADAPTER_OK
  implicit none

  type(coupling_application_accuracy_packet_view_t) :: view
  type(coupling_application_accuracy_contract_t) :: contract
  type(coupling_application_accuracy_adapter_diagnostics_t) :: diagnostics
  type(canonical_numerical_config_t) :: config
  real(real64) :: budget
  logical :: available, materialized
  integer :: status

  view%evidence_schema_version = FGC14_EVIDENCE_SCHEMA_V1
  view%fgc13_packet_validated = .true.
  view%application_source_digest_content_verified = .true.
  view%temporal_source_digest_content_verified = .true.
  view%contract_id = 590200_int64
  view%contract_version = 1
  view%qoi_kind = COUPLING_QOI_GROUNDWATER_HEAD
  view%h_app_cm = 0.4_real64
  view%application_provenance_id = 590201_int64
  view%a_temporal = 0.25_real64
  view%temporal_allocation_provenance_id = 590202_int64

  call adapt_verified_project_accuracy_view(view, contract, diagnostics)
  status = diagnostics%status
  call require(status == FGC14_ADAPTER_OK, 'F-GC14 adapter rejected governed ACC01 view')
  call require(diagnostics%upstream_packet_validated, 'packet validation attestation missing')
  call require(diagnostics%source_content_verified, 'source-content verification attestation missing')
  call require(diagnostics%canonical_contract_valid .and. diagnostics%materialized, 'contract not materialized')

  call require(contract%application_requirement_valid(), 'application requirement invalid')
  call require(contract%temporal_allocation_valid(), 'temporal allocation invalid')
  call require(contract%temporal_budget_ready(), 'temporal budget not ready')

  call contract%evaluate_temporal_budget_cm(budget, available)
  call require(available, 'temporal budget unavailable')
  call require(close_real(budget, 0.1_real64), 'temporal budget is not 0.1 cm')

  config%model_temporal_indicator_budget_available = .false.
  config%model_temporal_indicator_budget = 0.0_real64
  call contract%materialize_model_temporal_budget(config, materialized)
  call require(materialized, 'canonical temporal budget not materialized')
  call require(config%model_temporal_indicator_budget_available, 'canonical budget availability missing')
  call require(close_real(config%model_temporal_indicator_budget, 0.1_real64), 'canonical budget is not 0.1 cm')

  write(*,'(a,es24.16)') 'HYDRO_MEMORY_ACC01_H_APP_CM=', contract%h_app_cm
  write(*,'(a,es24.16)') 'HYDRO_MEMORY_ACC01_A_TEMPORAL=', contract%a_temporal
  write(*,'(a,es24.16)') 'HYDRO_MEMORY_ACC01_H_TEMPORAL_CM=', config%model_temporal_indicator_budget
  write(*,'(a)') 'HYDRO_MEMORY_ACC01_TYPED_BINDING=PASS'
  write(*,'(a)') 'HYDRO_MEMORY_ACC01_GOVERNANCE_QUALIFIED'

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
      write(*,'(a,1x,a)') 'HYDRO_MEMORY_ACC01_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_hydro_memory_acc01_accuracy_binding
