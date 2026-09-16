module mod_coupling_application_accuracy_adapter
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_coupling_application_accuracy_contract, only: coupling_application_accuracy_contract_t
  implicit none
  private

  integer, parameter, public :: FGC14_EVIDENCE_SCHEMA_V1 = 1

  integer, parameter, public :: FGC14_ADAPTER_OK = 0
  integer, parameter, public :: FGC14_ADAPTER_UNSUPPORTED_SCHEMA = 1
  integer, parameter, public :: FGC14_ADAPTER_PACKET_NOT_VALIDATED = 2
  integer, parameter, public :: FGC14_ADAPTER_APPLICATION_SOURCE_NOT_VERIFIED = 3
  integer, parameter, public :: FGC14_ADAPTER_TEMPORAL_SOURCE_NOT_VERIFIED = 4
  integer, parameter, public :: FGC14_ADAPTER_PROVENANCE_REUSE = 5
  integer, parameter, public :: FGC14_ADAPTER_INVALID_APPLICATION_REQUIREMENT = 6
  integer, parameter, public :: FGC14_ADAPTER_INVALID_TEMPORAL_ALLOCATION = 7
  integer, parameter, public :: FGC14_ADAPTER_INVALID_TEMPORAL_BUDGET = 8

  ! This is a typed boundary view, not a file or external-format representation.
  ! An external adapter/governance layer must first validate the F-GC13 packet
  ! and verify the recorded source digests against the exact governed source
  ! bytes. Only canonicalized values and verification attestations cross here.
  type, public :: coupling_application_accuracy_packet_view_t
    integer :: evidence_schema_version = 0
    logical :: fgc13_packet_validated = .false.
    logical :: application_source_digest_content_verified = .false.
    logical :: temporal_source_digest_content_verified = .false.

    integer(int64) :: contract_id = 0_int64
    integer :: contract_version = 0
    integer :: qoi_kind = 0

    real(real64) :: h_app_cm = 0.0_real64
    integer(int64) :: application_provenance_id = 0_int64

    real(real64) :: a_temporal = 0.0_real64
    integer(int64) :: temporal_allocation_provenance_id = 0_int64
  end type coupling_application_accuracy_packet_view_t

  type, public :: coupling_application_accuracy_adapter_diagnostics_t
    integer :: status = FGC14_ADAPTER_OK
    logical :: upstream_packet_validated = .false.
    logical :: source_content_verified = .false.
    logical :: canonical_contract_valid = .false.
    logical :: materialized = .false.
  end type coupling_application_accuracy_adapter_diagnostics_t

  public :: adapt_verified_project_accuracy_view

contains

  subroutine adapt_verified_project_accuracy_view(view, contract, diagnostics)
    type(coupling_application_accuracy_packet_view_t), intent(in) :: view
    type(coupling_application_accuracy_contract_t), intent(out) :: contract
    type(coupling_application_accuracy_adapter_diagnostics_t), intent(out) :: diagnostics

    type(coupling_application_accuracy_contract_t) :: candidate

    ! Fail closed first. Rejected input never exposes a partially populated
    ! application-accuracy contract to the runtime/coupler.
    contract = coupling_application_accuracy_contract_t()
    diagnostics = coupling_application_accuracy_adapter_diagnostics_t()

    if (view%evidence_schema_version /= FGC14_EVIDENCE_SCHEMA_V1) then
      diagnostics%status = FGC14_ADAPTER_UNSUPPORTED_SCHEMA
      return
    end if

    if (.not. view%fgc13_packet_validated) then
      diagnostics%status = FGC14_ADAPTER_PACKET_NOT_VALIDATED
      return
    end if
    diagnostics%upstream_packet_validated = .true.

    if (.not. view%application_source_digest_content_verified) then
      diagnostics%status = FGC14_ADAPTER_APPLICATION_SOURCE_NOT_VERIFIED
      return
    end if
    if (.not. view%temporal_source_digest_content_verified) then
      diagnostics%status = FGC14_ADAPTER_TEMPORAL_SOURCE_NOT_VERIFIED
      return
    end if
    diagnostics%source_content_verified = .true.

    ! F-GC13 requires separate clause-level application and temporal evidence.
    ! Preserve that governance separation even if this seam is called directly.
    if (view%application_provenance_id == view%temporal_allocation_provenance_id) then
      diagnostics%status = FGC14_ADAPTER_PROVENANCE_REUSE
      return
    end if

    candidate = coupling_application_accuracy_contract_t()
    candidate%contract_id = view%contract_id
    candidate%contract_version = view%contract_version
    candidate%qoi_kind = view%qoi_kind

    candidate%h_app_available = .true.
    candidate%h_app_cm = view%h_app_cm
    candidate%h_app_externally_qualified = .true.
    candidate%application_provenance_id = view%application_provenance_id

    candidate%a_temporal_available = .true.
    candidate%a_temporal = view%a_temporal
    candidate%a_temporal_externally_qualified = .true.
    candidate%temporal_allocation_provenance_id = view%temporal_allocation_provenance_id

    if (.not. candidate%application_requirement_valid()) then
      diagnostics%status = FGC14_ADAPTER_INVALID_APPLICATION_REQUIREMENT
      return
    end if
    if (.not. candidate%temporal_allocation_valid()) then
      diagnostics%status = FGC14_ADAPTER_INVALID_TEMPORAL_ALLOCATION
      return
    end if
    if (.not. candidate%temporal_budget_ready()) then
      diagnostics%status = FGC14_ADAPTER_INVALID_TEMPORAL_BUDGET
      return
    end if

    diagnostics%canonical_contract_valid = .true.
    contract = candidate
    diagnostics%materialized = .true.
    diagnostics%status = FGC14_ADAPTER_OK
  end subroutine adapt_verified_project_accuracy_view

end module mod_coupling_application_accuracy_adapter
