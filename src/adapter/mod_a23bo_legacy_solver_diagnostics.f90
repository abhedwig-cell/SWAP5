module mod_a23bo_legacy_solver_diagnostics
  implicit none
  private
  integer :: internal_retry_count = 0
  public :: a23bo_reset_solver_diagnostics, a23bo_record_internal_retry, a23bo_internal_retry_count
contains
  subroutine a23bo_reset_solver_diagnostics()
    internal_retry_count = 0
  end subroutine a23bo_reset_solver_diagnostics

  subroutine a23bo_record_internal_retry()
    internal_retry_count = internal_retry_count + 1
  end subroutine a23bo_record_internal_retry

  integer function a23bo_internal_retry_count()
    a23bo_internal_retry_count = internal_retry_count
  end function a23bo_internal_retry_count
end module mod_a23bo_legacy_solver_diagnostics
