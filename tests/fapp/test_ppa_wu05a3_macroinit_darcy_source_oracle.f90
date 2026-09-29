program test_ppa_wu05a3_macroinit_darcy_source_oracle
  use, intrinsic :: iso_fortran_env, only: real64, int32
  use mod_ppa_wu05a3_macroinit_darcy
  implicit none
  real(real64) :: cdarcy, scaled, base
  integer(int32) :: status

  call ppa_wu05a3_macroinit_darcy(0.75_real64,0.25_real64,10.0_real64, &
      0.3_real64,1.5_real64,cdarcy,status)
  call require(status==PPA_WU05A3_MACROINIT_DARCY_OK,1)
  call require(abs(cdarcy-2.0_real64)<1.0e-12_real64,2)
  base=cdarcy

  call ppa_wu05a3_macroinit_darcy(0.75_real64,0.0_real64,10.0_real64, &
      0.3_real64,1.5_real64,cdarcy,status)
  call require(status==PPA_WU05A3_MACROINIT_DARCY_OK .and. abs(cdarcy)<1.0e-12_real64,3)

  call ppa_wu05a3_macroinit_darcy(0.75_real64,0.25_real64,10.0_real64, &
      0.3_real64,3.0_real64,scaled,status)
  call require(status==PPA_WU05A3_MACROINIT_DARCY_OK,4)
  call require(abs(4.0_real64*scaled-base)<1.0e-12_real64,5)

  call ppa_wu05a3_macroinit_darcy(0.75_real64,0.25_real64,10.0_real64, &
      0.3_real64,0.0_real64,cdarcy,status)
  call require(status==PPA_WU05A3_MACROINIT_DARCY_INVALID,6)
  call require(abs(cdarcy)<1.0e-12_real64,7)

  print '(A)','PPA_WU05A3_MACROINIT_DARCY_SOURCE_ORACLE=PASS'
  print '(A)','PPA_WU05A3_MACROINIT_DARCY_DOMAIN_AND_HYDRAULIC_SCALING=PASS'
  print '(A)','PPA_WU05A3_MACROINIT_DARCY_INVERSE_DIAMETER_SQUARED=PASS'
  print '(A)','PPA_WU05A3_MACROINIT_DARCY_INVALID_DIAMETER_FAIL_CLOSED=PASS'
contains
  subroutine require(ok,code)
    logical,intent(in)::ok
    integer,intent(in)::code
    if(.not.ok)then
      write(*,'(A,I0)')'PPA_WU05A3_MACROINIT_DARCY_FAIL=',code
      error stop 1
    end if
  end subroutine
end program test_ppa_wu05a3_macroinit_darcy_source_oracle
