program test_fvq57_surface_result_candidate_binding
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_candidate_state_t, &
       kernel_executor_t, kernel_result_t, kernel_diagnostics_t, KERNEL_COMMIT_STATUS_COMMITTED
  use mod_restricted_surface_evaporation, only: surface_evaporation_result_t, SURFACE_EVAP_AVAILABLE
  use mod_fmr_accepted_commit_receipt, only: fmr_accepted_commit_receipt_t, fmr_commit_candidate_with_receipt, &
       FMR_COMMIT_RECEIPT_OK
  use mod_fmr_surface_evaporation_accepted_publication, only: &
       fmr_prepared_surface_evaporation_publication_t, fmr_surface_evaporation_publication_t, &
       fmr_prepare_surface_evaporation_publication, fmr_finalize_surface_evaporation_publication, &
       FMR_SURFACE_EVAP_PUBLICATION_OK
  use mod_fvq57_independent_publication_backend, only: fvq57_state_t, fvq57_parameters_t, fvq57_forcing_t, fvq57_model_t
  implicit none

  type(fvq57_parameters_t) :: parameters
  type(fvq57_forcing_t) :: forcing
  type(fvq57_model_t), target :: model
  type(kernel_executor_t) :: kernel
  type(kernel_committed_state_t) :: committed_a
  type(kernel_checkpoint_t) :: checkpoint_a
  type(kernel_candidate_state_t) :: candidate_a
  type(kernel_result_t) :: result_a_kernel
  type(kernel_diagnostics_t) :: diagnostics_a
  type(canonical_numerical_config_t) :: config
  type(surface_evaporation_result_t) :: surface_a, surface_b
  type(fmr_prepared_surface_evaporation_publication_t) :: prepared_a, prepared_b_as_a
  type(fmr_surface_evaporation_publication_t) :: publication_a, publication_b_as_a
  type(fmr_accepted_commit_receipt_t) :: receipt_a
  class(transaction_state_t), allocatable :: committed_snapshot
  logical :: ok, did_commit, snapshot_available
  integer :: status, receipt_status, commit_status
  real(real64), parameter :: t0 = 7.0_real64, t1 = 11.0_real64

  call initialize_case_a(committed_a)
  call kernel%bind_model(model)
  call committed_a%capture_checkpoint(checkpoint_a, ok)
  call require(ok, 'checkpoint A')
  call kernel%advance_interval(parameters, committed_a, forcing, config, t0, t1, result_a_kernel, candidate_a, &
       diagnostics_a, checkpoint_a)
  call require(result_a_kernel%completed, 'candidate A completed')
  call require(result_a_kernel%mass%complete, 'candidate A hard mass complete')
  call require(candidate_a%ready(), 'candidate A ready')
  write(*,'(A)') 'FVQ57_GENERIC_TRANSACTION_HARD_MASS_CONTROL=PASS'

  ! Independently constructed valid process outputs for mutually exclusive
  ! physical surface cases. A is dry. B is ponded. The publication contract
  ! must not permit B to acquire A's candidate/commit provenance merely because
  ! B is otherwise a structurally valid surface_evaporation_result_t.
  surface_a = surface_evaporation_result_t()
  surface_a%status = SURFACE_EVAP_AVAILABLE
  surface_a%bare_soil_evaporation = 0.11_real64
  surface_a%ponded_water_evaporation = 0.0_real64
  surface_a%route = 'dry'

  surface_b = surface_evaporation_result_t()
  surface_b%status = SURFACE_EVAP_AVAILABLE
  surface_b%bare_soil_evaporation = 0.0_real64
  surface_b%ponded_water_evaporation = 0.47_real64
  surface_b%route = 'ponded'

  call fmr_prepare_surface_evaporation_publication(surface_a, candidate_a, prepared_a, status)
  call require(status == FMR_SURFACE_EVAP_PUBLICATION_OK, 'matching A prepare')
  call require(prepared_a%ready(), 'matching A prepared ready')

  ! HN1: deliberately pair a physically incompatible B process result with
  ! candidate A before A is committed. Safe provenance binding must reject this
  ! pair either here or during accepted finalization.
  call fmr_prepare_surface_evaporation_publication(surface_b, candidate_a, prepared_b_as_a, status)
  if (status /= FMR_SURFACE_EVAP_PUBLICATION_OK .or. .not. prepared_b_as_a%ready()) then
    write(*,'(A)') 'FVQ57_HN1_MISMATCH_REJECTED_AT_PREPARE=PASS'
    write(*,'(A)') 'FVQ57_HN1_SURFACE_RESULT_CANDIDATE_BINDING=PASS'
    stop 0
  end if
  write(*,'(A)') 'FVQ57_HN1_MISMATCH_PREPARE_ACCEPTED=OBSERVED'

  call fmr_commit_candidate_with_receipt(kernel, checkpoint_a, committed_a, candidate_a, diagnostics_a, did_commit, &
       receipt_a, receipt_status, commit_status)
  call require(did_commit, 'candidate A committed')
  call require(receipt_status == FMR_COMMIT_RECEIPT_OK, 'receipt A status')
  call require(commit_status == KERNEL_COMMIT_STATUS_COMMITTED, 'commit A status')
  call require(receipt_a%ready(), 'receipt A ready')

  call fmr_finalize_surface_evaporation_publication(prepared_a, receipt_a, publication_a, status)
  call require(status == FMR_SURFACE_EVAP_PUBLICATION_OK, 'matching A finalize')
  call require(publication_a%ready(), 'matching A publication ready')
  call require(trim(publication_a%route()) == 'dry', 'matching A dry route')
  call require_close(publication_a%bare_soil_evaporation_rate(), 0.11_real64, 'matching A rate')
  write(*,'(A)') 'FVQ57_MATCHING_A_POSITIVE_CONTROL=PASS'

  call committed_a%snapshot(committed_snapshot, snapshot_available)
  call require(snapshot_available, 'committed snapshot A')
  select type (committed_snapshot)
  type is (fvq57_state_t)
    call require(committed_snapshot%physical_case_id == 1, 'committed physical case remains A')
  class default
    call require(.false., 'unexpected committed state type')
  end select
  write(*,'(A)') 'FVQ57_COMMITTED_PHYSICAL_CASE_A=PASS'

  call fmr_finalize_surface_evaporation_publication(prepared_b_as_a, receipt_a, publication_b_as_a, status)
  if (status /= FMR_SURFACE_EVAP_PUBLICATION_OK .or. .not. publication_b_as_a%ready()) then
    write(*,'(A)') 'FVQ57_HN1_MISMATCH_REJECTED_AT_FINALIZE=PASS'
    write(*,'(A)') 'FVQ57_HN1_SURFACE_RESULT_CANDIDATE_BINDING=PASS'
    stop 0
  end if

  call require(trim(publication_b_as_a%route()) == 'ponded', 'mismatched B route was published')
  call require_close(publication_b_as_a%ponded_water_evaporation_rate(), 0.47_real64, 'mismatched B rate was published')
  call require(publication_b_as_a%current_lineage_id() == receipt_a%current_lineage_id(), 'B inherited A lineage')
  call require(publication_b_as_a%origin_revision() == receipt_a%origin_revision(), 'B inherited A origin revision')
  call require(publication_b_as_a%committed_revision() == receipt_a%committed_revision(), 'B inherited A committed revision')

  write(*,'(A)') 'FVQ57_HN1_FAIL_OPEN=YES'
  write(*,'(A)') 'FVQ57_HN1_FINDING=PHYSICALLY_MISMATCHED_SURFACE_RESULT_B_PUBLISHED_WITH_CANDIDATE_A_RECEIPT'
  error stop 57

contains

  subroutine initialize_case_a(state)
    type(kernel_committed_state_t), intent(out) :: state
    class(transaction_state_t), allocatable :: physical
    logical :: initialized

    allocate(fvq57_state_t :: physical)
    select type (physical)
    type is (fvq57_state_t)
      physical%physical_case_id = 1
      physical%storage_value = 12.0_real64
    end select
    call state%initialize(5701_int64, physical, initialized, t0)
    call require(initialized, 'initialize A')
  end subroutine initialize_case_a

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FVQ57_CONTROL_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

  subroutine require_close(actual, expected, label)
    real(real64), intent(in) :: actual, expected
    character(len=*), intent(in) :: label
    real(real64) :: tol
    tol = 256.0_real64*epsilon(1.0_real64)*max(1.0_real64,abs(actual),abs(expected))
    call require(abs(actual-expected) <= tol, label)
  end subroutine require_close

end program test_fvq57_surface_result_candidate_binding
