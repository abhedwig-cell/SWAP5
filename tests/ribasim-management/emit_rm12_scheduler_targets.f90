program emit_rm12_scheduler_targets
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_fmr_ribasim_management_scheduler
  implicit none

  real(real64), parameter :: product_targets(4) = [21600.0_real64,43200.0_real64,64800.0_real64,86400.0_real64]
  type(fmr_ribasim_management_clock_t) :: clock
  real(real64) :: target,planned
  logical :: reaches
  integer :: i,status

  call initialize_fmr_ribasim_management_clock(0.0_real64,18000.0_real64,clock,status)
  call require(status==FMR_RMS_OK,'initialize')

  do i=1,size(product_targets)
    target=product_targets(i)
    do while (clock%current_time() < target - 1.0e-9_real64)
      if(clock%boundary_is_pending())then
        write(*,'(A,F0.1)') 'RM12_SOLVE_BOUNDARY_S=',clock%current_time()
        call clock%mark_boundary_solved(status)
        call require(status==FMR_RMS_OK,'solve boundary')
      end if
      call clock%plan_advance(target,planned,reaches,status)
      call require(status==FMR_RMS_OK,'plan')
      write(*,'(A,F0.1)') 'RM12_UPDATE_TARGET_S=',planned
      call clock%accept_planned_advance(planned,status)
      call require(status==FMR_RMS_OK,'accept')
    end do
  end do

  write(*,'(A)') 'RM12_SCHEDULER_TARGET_EMISSION=PASS'

contains
  subroutine require(condition,message)
    logical,intent(in)::condition
    character(len=*),intent(in)::message
    if(.not.condition)then
      write(*,'(A,1X,A)') 'RM12_FAIL',trim(message)
      error stop 1
    end if
  end subroutine require
end program emit_rm12_scheduler_targets
