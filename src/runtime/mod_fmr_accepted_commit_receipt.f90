module mod_fmr_accepted_commit_receipt
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_kernel_transactions, only: kernel_checkpoint_t, kernel_candidate_state_t, kernel_committed_state_t, &
       kernel_executor_t, kernel_diagnostics_t
  implicit none
  private

  integer, parameter, public :: FMR_COMMIT_RECEIPT_OK = 0
  integer, parameter, public :: FMR_COMMIT_RECEIPT_INVALID_CHECKPOINT = 1
  integer, parameter, public :: FMR_COMMIT_RECEIPT_INVALID_CANDIDATE = 2
  integer, parameter, public :: FMR_COMMIT_RECEIPT_PROVENANCE_MISMATCH = 3
  integer, parameter, public :: FMR_COMMIT_RECEIPT_TIME_MISMATCH = 4
  integer, parameter, public :: FMR_COMMIT_RECEIPT_COMMIT_REJECTED = 5

  type, public :: fmr_accepted_commit_receipt_t
    private
    logical :: initialized = .false.
    integer(int64) :: lineage_id = 0_int64
    integer(int64) :: origin_revision_value = -1_int64
    integer(int64) :: committed_revision_value = -1_int64
    real(real64) :: t0_value = 0.0_real64
    real(real64) :: t1_value = 0.0_real64
  contains
    procedure, public :: ready => receipt_ready
    procedure, public :: current_lineage_id => receipt_lineage_id
    procedure, public :: origin_revision => receipt_origin_revision
    procedure, public :: committed_revision => receipt_committed_revision
    procedure, public :: origin_interval => receipt_origin_interval
  end type fmr_accepted_commit_receipt_t

  public :: fmr_commit_candidate_with_receipt

contains

  subroutine fmr_commit_candidate_with_receipt(kernel, checkpoint, committed_state, candidate_state, diagnostics, &
                                                did_commit, receipt, receipt_status, commit_status)
    type(kernel_executor_t), intent(inout) :: kernel
    type(kernel_checkpoint_t), intent(in) :: checkpoint
    type(kernel_committed_state_t), intent(inout) :: committed_state
    type(kernel_candidate_state_t), intent(inout) :: candidate_state
    type(kernel_diagnostics_t), intent(inout) :: diagnostics
    logical, intent(out) :: did_commit
    type(fmr_accepted_commit_receipt_t), intent(out) :: receipt
    integer, intent(out) :: receipt_status
    integer, intent(out), optional :: commit_status

    integer(int64) :: lineage_id, origin_revision
    real(real64) :: t0, t1, checkpoint_time
    logical :: interval_available, checkpoint_time_available
    integer :: local_commit_status

    receipt = fmr_accepted_commit_receipt_t()
    did_commit = .false.
    receipt_status = FMR_COMMIT_RECEIPT_INVALID_CHECKPOINT
    local_commit_status = -1
    if (present(commit_status)) commit_status = local_commit_status

    if (.not. checkpoint%ready()) return

    receipt_status = FMR_COMMIT_RECEIPT_INVALID_CANDIDATE
    if (.not. candidate_state%ready()) return
    call candidate_state%origin_interval(t0, t1, interval_available)
    if (.not. interval_available) return
    if (.not. ieee_is_finite(t0) .or. .not. ieee_is_finite(t1) .or. t1 <= t0) return

    lineage_id = candidate_state%current_lineage_id()
    origin_revision = candidate_state%origin_revision()
    receipt_status = FMR_COMMIT_RECEIPT_PROVENANCE_MISMATCH
    if (lineage_id <= 0_int64 .or. origin_revision < 0_int64) return
    if (checkpoint%current_lineage_id() /= lineage_id) return
    if (checkpoint%origin_revision() /= origin_revision) return

    if (checkpoint%time_is_bound()) then
      call checkpoint%current_time(checkpoint_time, checkpoint_time_available)
      receipt_status = FMR_COMMIT_RECEIPT_TIME_MISMATCH
      if (.not. checkpoint_time_available) return
      if (.not. same_fkt_time(checkpoint_time, t0)) return
    end if

    ! Every expected receipt failure has now occurred before physical publication.
    ! From this point F-KT remains the sole commit authority. A failed F-KT commit
    ! yields no receipt. A successful F-KT commit is followed only by scalar
    ! assignments from the already captured, validated candidate provenance.
    call kernel%commit_candidate(committed_state, candidate_state, diagnostics, did_commit, local_commit_status)
    if (present(commit_status)) commit_status = local_commit_status
    if (.not. did_commit) then
      receipt_status = FMR_COMMIT_RECEIPT_COMMIT_REJECTED
      return
    end if

    receipt%lineage_id = lineage_id
    receipt%origin_revision_value = origin_revision
    receipt%committed_revision_value = origin_revision + 1_int64
    receipt%t0_value = t0
    receipt%t1_value = t1
    receipt%initialized = .true.
    receipt_status = FMR_COMMIT_RECEIPT_OK
  end subroutine fmr_commit_candidate_with_receipt

  pure logical function receipt_ready(self) result(ready)
    class(fmr_accepted_commit_receipt_t), intent(in) :: self
    ready = self%initialized .and. self%lineage_id > 0_int64 .and. &
         self%origin_revision_value >= 0_int64 .and. &
         self%committed_revision_value == self%origin_revision_value + 1_int64 .and. &
         ieee_is_finite(self%t0_value) .and. ieee_is_finite(self%t1_value) .and. &
         self%t1_value > self%t0_value
  end function receipt_ready

  pure integer(int64) function receipt_lineage_id(self) result(value)
    class(fmr_accepted_commit_receipt_t), intent(in) :: self
    value = self%lineage_id
  end function receipt_lineage_id

  pure integer(int64) function receipt_origin_revision(self) result(value)
    class(fmr_accepted_commit_receipt_t), intent(in) :: self
    value = self%origin_revision_value
  end function receipt_origin_revision

  pure integer(int64) function receipt_committed_revision(self) result(value)
    class(fmr_accepted_commit_receipt_t), intent(in) :: self
    value = self%committed_revision_value
  end function receipt_committed_revision

  subroutine receipt_origin_interval(self, t0, t1, available)
    class(fmr_accepted_commit_receipt_t), intent(in) :: self
    real(real64), intent(out) :: t0, t1
    logical, intent(out) :: available

    available = self%ready()
    if (available) then
      t0 = self%t0_value
      t1 = self%t1_value
    else
      t0 = 0.0_real64
      t1 = 0.0_real64
    end if
  end subroutine receipt_origin_interval

  pure logical function same_fkt_time(a, b) result(matches)
    real(real64), intent(in) :: a, b
    real(real64) :: scale

    if (.not. ieee_is_finite(a) .or. .not. ieee_is_finite(b)) then
      matches = .false.
      return
    end if
    ! This is deliberately the same numeric time-identity rule currently used
    ! by F-KT for committed/candidate origin validation. It is not a calendar
    ! tolerance and introduces no new scheduling semantics.
    scale = max(1.0_real64, abs(a), abs(b))
    matches = abs(a-b) <= 64.0_real64 * epsilon(1.0_real64) * scale
  end function same_fkt_time

end module mod_fmr_accepted_commit_receipt
