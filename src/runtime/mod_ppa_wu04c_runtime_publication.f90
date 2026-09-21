module mod_ppa_wu04c_runtime_publication
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_fmr_accepted_commit_receipt, only: fmr_accepted_commit_receipt_t
  use mod_fmr_vonhhbraden_source_window_progress, only: fmr_vonhhbraden_source_window_progress_t, &
       fmr_apply_vonhhbraden_accepted_receipt, FMR_VONHHBRADEN_PROGRESS_OK
  implicit none
  private
  integer, parameter, public :: PPA_WU04C_PUBLICATION_OK = 0
  integer, parameter, public :: PPA_WU04C_PUBLICATION_REJECTED = 1
  public :: publish_ppa_wu04c_accepted_progress
contains
  subroutine publish_ppa_wu04c_accepted_progress(progress, receipt, accepted_interception_cm, status)
    type(fmr_vonhhbraden_source_window_progress_t), intent(inout) :: progress
    type(fmr_accepted_commit_receipt_t), intent(in) :: receipt
    real(real64), intent(in) :: accepted_interception_cm
    integer, intent(out) :: status
    integer :: progress_status
    call fmr_apply_vonhhbraden_accepted_receipt(progress, receipt, accepted_interception_cm, progress_status)
    if (progress_status == FMR_VONHHBRADEN_PROGRESS_OK) then
      status = PPA_WU04C_PUBLICATION_OK
    else
      status = PPA_WU04C_PUBLICATION_REJECTED
    end if
  end subroutine publish_ppa_wu04c_accepted_progress
end module mod_ppa_wu04c_runtime_publication
