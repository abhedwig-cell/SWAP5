program test_fapp02_legacy_swbotb6_zero_flux_binding
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_fmr_legacy_bottom_boundary_application_binding, only: &
       fmr_legacy_bottom_boundary_binding_t, fmr_resolve_legacy_bottom_boundary, &
       FMR_LEGACY_BOTTOM_BINDING_OK, FMR_LEGACY_BOTTOM_BINDING_UNSUPPORTED_MODE
  implicit none

  type(fmr_legacy_bottom_boundary_binding_t) :: binding, repeat_binding
  integer :: status, repeat_status, i
  integer, parameter :: unsupported(5) = [2, 5, 7, -2, 3]

  call fmr_resolve_legacy_bottom_boundary(6, binding, status)
  call require(status == FMR_LEGACY_BOTTOM_BINDING_OK, 'SWBOTB6 status')
  call require(binding%available, 'SWBOTB6 available')
  call require(binding%legacy_swbotb == 6, 'legacy selector preserved')
  call require(binding%typed_bottom_mode == 2, 'typed prescribed-qbot mode')
  call require(transfer(binding%typed_bottom_flux, 0_int64) == transfer(0.0_real64, 0_int64), &
               'typed qbot exact positive zero')

  call fmr_resolve_legacy_bottom_boundary(6, repeat_binding, repeat_status)
  call require(repeat_status == status, 'repeat status identity')
  call require(repeat_binding%available .eqv. binding%available, 'repeat availability identity')
  call require(repeat_binding%legacy_swbotb == binding%legacy_swbotb, 'repeat legacy selector identity')
  call require(repeat_binding%typed_bottom_mode == binding%typed_bottom_mode, 'repeat mode identity')
  call require(transfer(repeat_binding%typed_bottom_flux, 0_int64) == &
               transfer(binding%typed_bottom_flux, 0_int64), 'repeat flux identity')

  do i = 1, size(unsupported)
    call fmr_resolve_legacy_bottom_boundary(unsupported(i), repeat_binding, repeat_status)
    call require(repeat_status == FMR_LEGACY_BOTTOM_BINDING_UNSUPPORTED_MODE, 'unsupported mode status')
    call require(.not. repeat_binding%available, 'unsupported mode unavailable')
    call require(repeat_binding%legacy_swbotb == unsupported(i), 'unsupported selector preserved')
    call require(repeat_binding%typed_bottom_mode == 0, 'unsupported mode no typed route')
    call require(transfer(repeat_binding%typed_bottom_flux, 0_int64) == transfer(0.0_real64, 0_int64), &
                 'unsupported mode no invented flux')
  end do

  write(*,'(A)') 'FAPP02_SWBOTB6_TO_PRESCRIBED_QBOT_ZERO=PASS'
  write(*,'(A)') 'FAPP02_EXACT_POSITIVE_ZERO_BITS=PASS'
  write(*,'(A)') 'FAPP02_REPEAT_DETERMINISM=PASS'
  write(*,'(A)') 'FAPP02_UNSUPPORTED_MODES_FAIL_CLOSED=PASS'
  write(*,'(A)') 'FAPP02_OWNER_ORACLE=PASS'

contains

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,A)') 'FAPP02_FAIL ', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fapp02_legacy_swbotb6_zero_flux_binding
