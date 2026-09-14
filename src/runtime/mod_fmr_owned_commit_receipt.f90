module mod_fmr_owned_commit_receipt
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_kernel_transactions, only: kernel_checkpoint_t, kernel_candidate_state_t, kernel_committed_state_t, &
       kernel_executor_t, kernel_diagnostics_t
  use mod_fmr_accepted_commit_receipt, only: fmr_accepted_commit_receipt_t, fmr_commit_candidate_with_receipt, &
       FMR_COMMIT_RECEIPT_OK, FMR_COMMIT_RECEIPT_PROVENANCE_MISMATCH
  implicit none
  private

  ! Runtime-owned accepted receipt. The generic F-KT/F-MR receipt remains
  ! column-agnostic; this wrapper binds it, at the physical commit callsite, to
  ! the logical runtime owner that actually requested the commit. There is
  ! deliberately no public routine that can bind an already-existing generic
  ! receipt after the fact.
  type, public :: fmr_owned_commit_receipt_t
    private
    logical :: initialized = .false.
    integer(int64) :: owner_instance_id_value = 0_int64
    type(fmr_accepted_commit_receipt_t) :: accepted_receipt
  contains
    procedure, public :: ready => owned_receipt_ready
    procedure, public :: owner_instance_id => owned_receipt_owner_instance_id
    procedure, public :: current_lineage_id => owned_receipt_lineage_id
    procedure, public :: origin_revision => owned_receipt_origin_revision
    procedure, public :: committed_revision => owned_receipt_committed_revision
    procedure, public :: origin_interval => owned_receipt_origin_interval
    procedure, public :: export_accepted_receipt => owned_receipt_export_accepted
  end type fmr_owned_commit_receipt_t

  public :: fmr_commit_candidate_with_owned_receipt

contains

  subroutine fmr_commit_candidate_with_owned_receipt(owner_instance_id, kernel, checkpoint, committed_state, &
       candidate_state, diagnostics, did_commit, owned_receipt, receipt_status, commit_status)
    integer(int64), intent(in) :: owner_instance_id
    type(kernel_executor_t), intent(inout) :: kernel
    type(kernel_checkpoint_t), intent(in) :: checkpoint
    type(kernel_committed_state_t), intent(inout) :: committed_state
    type(kernel_candidate_state_t), intent(inout) :: candidate_state
    type(kernel_diagnostics_t), intent(inout) :: diagnostics
    logical, intent(out) :: did_commit
    type(fmr_owned_commit_receipt_t), intent(out) :: owned_receipt
    integer, intent(out) :: receipt_status
    integer, intent(out), optional :: commit_status

    type(fmr_accepted_commit_receipt_t) :: accepted
    integer :: local_commit_status

    owned_receipt = fmr_owned_commit_receipt_t()
    did_commit = .false.
    local_commit_status = -1
    if (present(commit_status)) commit_status = local_commit_status

    ! Fail closed before physical publication when the runtime owner identity
    ! is invalid. Positive uniqueness is a runtime scheduling obligation; the
    ! serialized MultiSWAP runtime already validates column ids as positive and
    ! batch-unique and passes the selected column id at this exact callsite.
    if (owner_instance_id <= 0_int64) then
      receipt_status = FMR_COMMIT_RECEIPT_PROVENANCE_MISMATCH
      return
    end if

    call fmr_commit_candidate_with_receipt(kernel, checkpoint, committed_state, candidate_state, diagnostics, &
         did_commit, accepted, receipt_status, local_commit_status)
    if (present(commit_status)) commit_status = local_commit_status
    if (.not. did_commit) return
    if (receipt_status /= FMR_COMMIT_RECEIPT_OK .or. .not. accepted%ready()) then
      ! This postcondition is unreachable for a conforming generic receipt
      ! producer. Keep the owned result unavailable rather than fabricating an
      ! association if a future producer violates that contract.
      did_commit = .false.
      receipt_status = FMR_COMMIT_RECEIPT_PROVENANCE_MISMATCH
      return
    end if

    owned_receipt%owner_instance_id_value = owner_instance_id
    owned_receipt%accepted_receipt = accepted
    owned_receipt%initialized = .true.
  end subroutine fmr_commit_candidate_with_owned_receipt

  logical function owned_receipt_ready(self) result(ready)
    class(fmr_owned_commit_receipt_t), intent(in) :: self
    ready = self%initialized .and. self%owner_instance_id_value > 0_int64 .and. self%accepted_receipt%ready()
  end function owned_receipt_ready

  integer(int64) function owned_receipt_owner_instance_id(self) result(value)
    class(fmr_owned_commit_receipt_t), intent(in) :: self
    if (self%ready()) then
      value = self%owner_instance_id_value
    else
      value = 0_int64
    end if
  end function owned_receipt_owner_instance_id

  integer(int64) function owned_receipt_lineage_id(self) result(value)
    class(fmr_owned_commit_receipt_t), intent(in) :: self
    if (self%ready()) then
      value = self%accepted_receipt%current_lineage_id()
    else
      value = 0_int64
    end if
  end function owned_receipt_lineage_id

  integer(int64) function owned_receipt_origin_revision(self) result(value)
    class(fmr_owned_commit_receipt_t), intent(in) :: self
    if (self%ready()) then
      value = self%accepted_receipt%origin_revision()
    else
      value = -1_int64
    end if
  end function owned_receipt_origin_revision

  integer(int64) function owned_receipt_committed_revision(self) result(value)
    class(fmr_owned_commit_receipt_t), intent(in) :: self
    if (self%ready()) then
      value = self%accepted_receipt%committed_revision()
    else
      value = -1_int64
    end if
  end function owned_receipt_committed_revision

  subroutine owned_receipt_origin_interval(self, t0, t1, available)
    class(fmr_owned_commit_receipt_t), intent(in) :: self
    real(real64), intent(out) :: t0, t1
    logical, intent(out) :: available

    available = self%ready()
    if (available) then
      call self%accepted_receipt%origin_interval(t0, t1, available)
    else
      t0 = 0.0_real64
      t1 = 0.0_real64
    end if
  end subroutine owned_receipt_origin_interval

  subroutine owned_receipt_export_accepted(self, receipt, available)
    class(fmr_owned_commit_receipt_t), intent(in) :: self
    type(fmr_accepted_commit_receipt_t), intent(out) :: receipt
    logical, intent(out) :: available

    receipt = fmr_accepted_commit_receipt_t()
    available = self%ready()
    if (available) receipt = self%accepted_receipt
  end subroutine owned_receipt_export_accepted

end module mod_fmr_owned_commit_receipt
