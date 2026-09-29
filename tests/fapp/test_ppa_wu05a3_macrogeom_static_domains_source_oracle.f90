program test_ppa_wu05a3_macrogeom_static_domains_source_oracle
  use, intrinsic :: iso_fortran_env, only: real64, int32
  use mod_ppa_wu05a3_macrogeom_static_domains
  implicit none
  call check_main_and_ic_partition()
  call check_single_main_domain()
  call check_two_domain_scaling()
  call check_invalid_input()
  print '(A)', 'PPA_WU05A3_MACROGEOM_STATIC_DOMAINS_SOURCE_ORACLE=PASS'
  print '(A)', 'PPA_WU05A3_MACROGEOM_STATIC_MB_IC_SUM=PASS'
  print '(A)', 'PPA_WU05A3_MACROGEOM_STATIC_SINGLE_DOMAIN=PASS'
  print '(A)', 'PPA_WU05A3_MACROGEOM_STATIC_DOMAIN_SCALE=PASS'
  print '(A)', 'PPA_WU05A3_MACROGEOM_STATIC_DOMAIN_INVALID_FAIL_CLOSED=PASS'
contains
  subroutine require(ok,code)
    logical,intent(in) :: ok
    integer,intent(in) :: code
    if (.not.ok) then
      write(*,'(A,I0)') 'PPA_WU05A3_MACROGEOM_STATIC_DOMAINS_FAIL=',code
      error stop 1
    end if
  end subroutine

  subroutine check_main_and_ic_partition()
    real(real64) :: mb,ic
    integer(int32) :: status
    call ppa_wu05a3_macrogeom_static_domains(3_int32, &
        [0.2_real64,0.3_real64,0.5_real64],2.0_real64,mb,ic,status)
    call require(status==PPA_WU05A3_STATIC_DOMAINS_OK,1)
    call require(abs(mb-0.4_real64)<1.0e-12_real64 .and. &
        abs(ic-1.6_real64)<1.0e-12_real64,2)
    call require(abs(mb+ic-2.0_real64)<1.0e-12_real64,3)
  end subroutine

  subroutine check_single_main_domain()
    real(real64) :: mb,ic
    integer(int32) :: status
    call ppa_wu05a3_macrogeom_static_domains(1_int32,[1.0_real64],4.0_real64,mb,ic,status)
    call require(status==PPA_WU05A3_STATIC_DOMAINS_OK,4)
    call require(abs(mb-4.0_real64)<1.0e-12_real64 .and. abs(ic)<1.0e-12_real64,5)
  end subroutine

  subroutine check_two_domain_scaling()
    real(real64) :: mb,ic
    integer(int32) :: status
    call ppa_wu05a3_macrogeom_static_domains(2_int32, &
        [0.75_real64,0.25_real64],4.0_real64,mb,ic,status)
    call require(status==PPA_WU05A3_STATIC_DOMAINS_OK,6)
    call require(abs(mb-3.0_real64)<1.0e-12_real64 .and. &
        abs(ic-1.0_real64)<1.0e-12_real64,7)
  end subroutine

  subroutine check_invalid_input()
    real(real64) :: mb,ic
    integer(int32) :: status
    call ppa_wu05a3_macrogeom_static_domains(2_int32,[1.0_real64],2.0_real64,mb,ic,status)
    call require(status==PPA_WU05A3_STATIC_DOMAINS_INVALID,8)
    call require(abs(mb)<1.0e-12_real64 .and. abs(ic)<1.0e-12_real64,9)
  end subroutine
end program test_ppa_wu05a3_macrogeom_static_domains_source_oracle
