program test_fpe_zero_waste01_capture_capacity
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_reference_richards_workspace, only: reference_richards_workspace_t, &
       ensure_reference_workspace_shape, prepare_reference_tridag_factorization_capture, &
       release_reference_tridag_factorization_capture
  implicit none

  integer, parameter :: n=60
  type(reference_richards_workspace_t) :: ws

  call ensure_reference_workspace_shape(ws,n)
  call require(size(ws%tridag_gamma)==n,'initial compact gamma capacity')
  call require(.not.ws%tridag_factorization_capture_active,'capture initially inactive')

  call prepare_reference_tridag_factorization_capture(ws)
  call require(size(ws%tridag_gamma)==2*n,'first capture expands to 2n')
  call require(ws%tridag_factorization_capture_active,'capture active after prepare')

  call release_reference_tridag_factorization_capture(ws)
  call require(size(ws%tridag_gamma)==2*n,'release retains 2n capacity')
  call require(.not.ws%tridag_factorization_capture_active,'capture inactive after release')

  call prepare_reference_tridag_factorization_capture(ws)
  call require(size(ws%tridag_gamma)==2*n,'second capture reuses retained capacity')
  call require(ws%tridag_factorization_capture_active,'capture active on second prepare')

  write(*,'(A)') 'FPE_ZERO_WASTE01_CAPTURE_CAPACITY_REUSE=PASS'

contains
  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if(.not.condition) then
      write(*,'(A,1X,A)') 'FPE_ZERO_WASTE01_CAPTURE_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_fpe_zero_waste01_capture_capacity
