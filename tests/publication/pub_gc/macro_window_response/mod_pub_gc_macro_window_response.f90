module mod_pub_gc_macro_window_response
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_transaction_reference, only: transaction_state_t
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_result_t, &
       kernel_candidate_state_t, kernel_diagnostics_t, kernel_executor_t
  use mod_fmr_checkpoint_orchestrator, only: fmr_capture_checkpoint, fmr_discard_candidate
  use mod_fmr_accepted_commit_receipt, only: fmr_accepted_commit_receipt_t, fmr_commit_candidate_with_receipt, &
       FMR_COMMIT_RECEIPT_OK
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_serialized_reference_backend_t
  implicit none
  private

  integer, parameter, public :: PUB_GC_MACRO_OK = 0
  integer, parameter, public :: PUB_GC_MACRO_INVALID = 1
  integer, parameter, public :: PUB_GC_MACRO_SNAPSHOT_FAILED = 2
  integer, parameter, public :: PUB_GC_MACRO_TRIAL_FAILED = 3
  integer, parameter, public :: PUB_GC_MACRO_COMMIT_FAILED = 4
  integer, parameter, public :: PUB_GC_MACRO_ORIGIN_MUTATED = 5

  real(real64), parameter :: macro_time_tolerance_day = 1.0e-12_real64

  type, public :: pub_gc_macro_window_response_t
    logical :: completed = .false.
    integer :: status = PUB_GC_MACRO_INVALID
    real(real64) :: macro_t0 = 0.0_real64
    real(real64) :: macro_t1 = 0.0_real64
    real(real64) :: macro_duration_day = 0.0_real64
    integer :: native_contribution_count = 0
    real(real64), allocatable :: native_dt_day(:)
    real(real64), allocatable :: q_contribution_cm(:)
    real(real64), allocatable :: terminal_flux_cm_per_day(:)
    integer, allocatable :: transaction_retries(:)
    integer, allocatable :: accepted_substeps(:)
    real(real64) :: q_whole_cm = 0.0_real64
    real(real64) :: q_terminal_cm_per_day = 0.0_real64
    real(real64) :: q_terminal_rectangle_cm = 0.0_real64
    real(real64) :: whole_minus_terminal_cm = 0.0_real64
    real(real64) :: candidate_bottom_head_cm = 0.0_real64
    integer(int64) :: authoritative_lineage_before = 0_int64
    integer(int64) :: authoritative_lineage_after = 0_int64
    integer(int64) :: authoritative_revision_before = -1_int64
    integer(int64) :: authoritative_revision_after = -1_int64
    real(real64) :: authoritative_time_before = 0.0_real64
    real(real64) :: authoritative_time_after = 0.0_real64
    integer(int64) :: disposable_lineage = 0_int64
    integer(int64) :: disposable_final_revision = -1_int64
    class(transaction_state_t), allocatable :: endpoint_state
  end type pub_gc_macro_window_response_t

  public :: pub_gc_run_macro_window_response

contains

  subroutine pub_gc_run_macro_window_response(column, template, parameters, backend, config, authoritative_origin, &
       forcing_by_interval, native_dt_day, macro_t0, macro_t1, candidate_bottom_head_cm, disposable_lineage, &
       response, status)
    type(fmr_logical_column_t), intent(in) :: column
    type(fmr_template_t), intent(in) :: template
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters
    type(fmr_serialized_reference_backend_t), intent(inout) :: backend
    type(canonical_numerical_config_t), intent(in) :: config
    type(kernel_committed_state_t), intent(in) :: authoritative_origin
    type(fmr_b110_physical_forcing_t), intent(in) :: forcing_by_interval(:)
    real(real64), intent(in) :: native_dt_day(:)
    real(real64), intent(in) :: macro_t0, macro_t1, candidate_bottom_head_cm
    integer(int64), intent(in) :: disposable_lineage
    type(pub_gc_macro_window_response_t), intent(out) :: response
    integer, intent(out) :: status

    type(kernel_committed_state_t) :: disposable
    type(kernel_checkpoint_t) :: checkpoint
    type(kernel_result_t) :: result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics, discard_diagnostics
    type(kernel_executor_t) :: commit_kernel, discard_kernel
    type(fmr_accepted_commit_receipt_t) :: receipt
    type(fmr_b110_physical_forcing_t) :: forcing
    class(transaction_state_t), allocatable :: origin_snapshot
    real(real64) :: t0, t1, origin_time_before, origin_time_after
    logical :: available, initialized, did_commit
    integer :: i, receipt_status, commit_status

    response = pub_gc_macro_window_response_t()
    status = PUB_GC_MACRO_INVALID

    if (.not. authoritative_origin%ready()) return
    if (.not. ieee_is_finite(macro_t0) .or. .not. ieee_is_finite(macro_t1) .or. macro_t1 <= macro_t0) return
    if (.not. ieee_is_finite(candidate_bottom_head_cm)) return
    if (disposable_lineage <= 0_int64 .or. disposable_lineage == authoritative_origin%current_lineage_id()) return
    if (size(native_dt_day) <= 0 .or. size(forcing_by_interval) /= size(native_dt_day)) return
    if (any(.not. ieee_is_finite(native_dt_day)) .or. any(native_dt_day <= 0.0_real64)) return
    if (abs(sum(native_dt_day) - (macro_t1-macro_t0)) > macro_time_tolerance_day) return

    call authoritative_origin%current_time(origin_time_before, available)
    if (.not. available .or. abs(origin_time_before-macro_t0) > macro_time_tolerance_day) return

    response%macro_t0 = macro_t0
    response%macro_t1 = macro_t1
    response%macro_duration_day = macro_t1-macro_t0
    response%candidate_bottom_head_cm = candidate_bottom_head_cm
    response%native_contribution_count = size(native_dt_day)
    response%authoritative_lineage_before = authoritative_origin%current_lineage_id()
    response%authoritative_revision_before = authoritative_origin%current_revision()
    response%authoritative_time_before = origin_time_before
    response%disposable_lineage = disposable_lineage
    allocate(response%native_dt_day(size(native_dt_day)))
    allocate(response%q_contribution_cm(size(native_dt_day)))
    allocate(response%terminal_flux_cm_per_day(size(native_dt_day)))
    allocate(response%transaction_retries(size(native_dt_day)))
    allocate(response%accepted_substeps(size(native_dt_day)))
    response%native_dt_day = native_dt_day
    response%q_contribution_cm = 0.0_real64
    response%terminal_flux_cm_per_day = 0.0_real64
    response%transaction_retries = 0
    response%accepted_substeps = 0

    call authoritative_origin%snapshot(origin_snapshot, available)
    if (.not. available .or. .not. allocated(origin_snapshot)) then
      status = PUB_GC_MACRO_SNAPSHOT_FAILED
      response%status = status
      return
    end if
    call disposable%initialize(disposable_lineage, origin_snapshot, initialized, macro_t0)
    if (.not. initialized .or. .not. disposable%ready()) then
      status = PUB_GC_MACRO_SNAPSHOT_FAILED
      response%status = status
      return
    end if

    t0 = macro_t0
    do i = 1, size(native_dt_day)
      t1 = t0 + native_dt_day(i)
      call fmr_capture_checkpoint(disposable, checkpoint, available)
      if (.not. available .or. .not. checkpoint%ready()) then
        status = PUB_GC_MACRO_SNAPSHOT_FAILED
        response%status = status
        return
      end if

      forcing = forcing_by_interval(i)
      forcing%bottom_head = candidate_bottom_head_cm
      call backend%run_trial(column, template, parameters, disposable, forcing, config, t0, t1, checkpoint, &
           result, candidate, diagnostics)
      if (.not. result%completed .or. .not. candidate%ready() .or. &
          .not. result%bottom_interface_exchange_available .or. &
          .not. ieee_is_finite(result%bottom_outward_exchange_native) .or. &
          .not. ieee_is_finite(result%terminal_bottom_outward_flux_native)) then
        if (candidate%ready()) then
          discard_diagnostics = diagnostics
          call fmr_discard_candidate(discard_kernel, candidate, discard_diagnostics)
        end if
        status = PUB_GC_MACRO_TRIAL_FAILED
        response%status = status
        return
      end if

      response%q_contribution_cm(i) = result%bottom_outward_exchange_native
      response%terminal_flux_cm_per_day(i) = result%terminal_bottom_outward_flux_native
      response%transaction_retries(i) = diagnostics%retries + diagnostics%internal_retries
      response%accepted_substeps(i) = diagnostics%accepted_substeps

      call fmr_commit_candidate_with_receipt(commit_kernel, checkpoint, disposable, candidate, diagnostics, &
           did_commit, receipt, receipt_status, commit_status)
      if (.not. did_commit .or. receipt_status /= FMR_COMMIT_RECEIPT_OK .or. .not. receipt%ready()) then
        if (candidate%ready()) then
          discard_diagnostics = diagnostics
          call fmr_discard_candidate(discard_kernel, candidate, discard_diagnostics)
        end if
        status = PUB_GC_MACRO_COMMIT_FAILED
        response%status = status
        return
      end if
      if (disposable%current_revision() /= int(i,int64)) then
        status = PUB_GC_MACRO_COMMIT_FAILED
        response%status = status
        return
      end if
      t0 = t1
    end do

    if (abs(t0-macro_t1) > macro_time_tolerance_day) then
      status = PUB_GC_MACRO_INVALID
      response%status = status
      return
    end if

    call disposable%snapshot(response%endpoint_state, available)
    if (.not. available .or. .not. allocated(response%endpoint_state)) then
      status = PUB_GC_MACRO_SNAPSHOT_FAILED
      response%status = status
      return
    end if

    response%q_whole_cm = sum(response%q_contribution_cm)
    response%q_terminal_cm_per_day = response%terminal_flux_cm_per_day(size(native_dt_day))
    response%q_terminal_rectangle_cm = response%q_terminal_cm_per_day * response%macro_duration_day
    response%whole_minus_terminal_cm = response%q_whole_cm - response%q_terminal_rectangle_cm
    response%disposable_final_revision = disposable%current_revision()

    response%authoritative_lineage_after = authoritative_origin%current_lineage_id()
    response%authoritative_revision_after = authoritative_origin%current_revision()
    call authoritative_origin%current_time(origin_time_after, available)
    if (.not. available) then
      status = PUB_GC_MACRO_ORIGIN_MUTATED
      response%status = status
      return
    end if
    response%authoritative_time_after = origin_time_after

    if (response%authoritative_lineage_after /= response%authoritative_lineage_before .or. &
        response%authoritative_revision_after /= response%authoritative_revision_before .or. &
        abs(response%authoritative_time_after-response%authoritative_time_before) > macro_time_tolerance_day) then
      status = PUB_GC_MACRO_ORIGIN_MUTATED
      response%status = status
      return
    end if

    response%completed = .true.
    response%status = PUB_GC_MACRO_OK
    status = PUB_GC_MACRO_OK
  end subroutine pub_gc_run_macro_window_response

end module mod_pub_gc_macro_window_response
