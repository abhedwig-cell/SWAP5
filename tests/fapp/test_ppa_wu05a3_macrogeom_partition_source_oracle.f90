program test_ppa_wu05a3_macrogeom_partition_source_oracle
  use, intrinsic :: iso_fortran_env, only: real64, int32
  use mod_ppa_wu05a3_macrogeom_partition
  implicit none
  call check_full_internal_partition()
  call check_partial_internal_partition()
  call check_low_fraction_and_special_modes()
  call check_invalid_divisor()
  print '(A)', 'PPA_WU05A3_MACROGEOM_PARTITION_SOURCE_ORACLE=PASS'
  print '(A)', 'PPA_WU05A3_MACROGEOM_PARTITION_EQUAL_SUBDOMAINS_AND_RESIDUAL=PASS'
  print '(A)', 'PPA_WU05A3_MACROGEOM_PARTITION_FLOOR_AND_CAP=PASS'
  print '(A)', 'PPA_WU05A3_MACROGEOM_PARTITION_LOW_IC_THRESHOLD=PASS'
  print '(A)', 'PPA_WU05A3_MACROGEOM_PARTITION_RZAH_BRANCHES=PASS'
  print '(A)', 'PPA_WU05A3_MACROGEOM_PARTITION_INVALID_DIVISOR_FAIL_CLOSED=PASS'
contains
  subroutine require(ok, code)
    logical, intent(in) :: ok
    integer, intent(in) :: code
    if (.not. ok) then
      write(*,'(A,I0)') 'PPA_WU05A3_MACROGEOM_PARTITION_FAIL=', code
      error stop 1
    end if
  end subroutine

  subroutine check_full_internal_partition()
    real(real64) :: pp(8)
    integer(int32) :: nd,ncell,status
    call ppa_wu05a3_macrogeom_partition(0.8_real64,4.8_real64,10.0_real64, &
        0.4_real64,0.2_real64,2_int32,8_int32,nd,ncell,pp,status)
    call require(status==PPA_WU05A3_MACROGEOM_PARTITION_OK,1)
    call require(nd==4 .and. ncell==2,2)
    call require(maxval(abs(pp(1:4)-[0.2_real64,0.2666666666666667_real64, &
        0.2666666666666667_real64,0.2666666666666667_real64]))<1.0e-12_real64,3)
    call require(abs(sum(pp(1:nd))-1.0_real64)<1.0e-12_real64,4)
  end subroutine

  subroutine check_partial_internal_partition()
    real(real64) :: pp(8)
    integer(int32) :: nd,ncell,status
    call ppa_wu05a3_macrogeom_partition(0.8_real64,2.4_real64,10.0_real64, &
        0.4_real64,0.2_real64,2_int32,8_int32,nd,ncell,pp,status)
    call require(status==PPA_WU05A3_MACROGEOM_PARTITION_OK,5)
    call require(nd==4 .and. ncell==1,6)
    call require(abs(pp(1)-0.2_real64)<1.0e-12_real64 .and. &
        abs(pp(2)-0.5333333333333333_real64)<1.0e-12_real64 .and. &
        abs(pp(3)-0.2666666666666667_real64)<1.0e-12_real64 .and. &
        abs(pp(4))<1.0e-12_real64,7)
    call require(abs(sum(pp(1:nd))-1.0_real64)<1.0e-12_real64,8)
  end subroutine

  subroutine check_low_fraction_and_special_modes()
    real(real64) :: pp(8)
    integer(int32) :: nd,ncell,status
    call ppa_wu05a3_macrogeom_partition(5.0e-4_real64,0.1_real64,10.0_real64, &
        0.4_real64,0.2_real64,2_int32,8_int32,nd,ncell,pp,status)
    call require(status==PPA_WU05A3_MACROGEOM_PARTITION_OK .and. nd==4,9)
    call require(abs(pp(1)-1.0_real64)<1.0e-12_real64 .and. &
        maxval(abs(pp(2:4)))<1.0e-12_real64,10)
    call ppa_wu05a3_macrogeom_partition(0.8_real64,4.8_real64,10.0_real64, &
        0.4_real64,0.995_real64,2_int32,8_int32,nd,ncell,pp,status)
    call require(status==PPA_WU05A3_MACROGEOM_PARTITION_OK .and. nd==2,11)
    call require(abs(pp(1)-0.2_real64)<1.0e-12_real64 .and. &
        abs(pp(2)-0.8_real64)<1.0e-12_real64,12)
    call ppa_wu05a3_macrogeom_partition(0.8_real64,4.8_real64,10.0_real64, &
        0.0_real64,0.2_real64,0_int32,8_int32,nd,ncell,pp,status)
    call require(status==PPA_WU05A3_MACROGEOM_PARTITION_OK .and. nd==1,13)
    call require(abs(pp(1)-1.0_real64)<1.0e-12_real64 .and. &
        abs(sum(pp(1:nd))-1.0_real64)<1.0e-12_real64,14)
  end subroutine

  subroutine check_invalid_divisor()
    real(real64) :: pp(8)
    integer(int32) :: nd,ncell,status
    call ppa_wu05a3_macrogeom_partition(0.8_real64,4.8_real64,10.0_real64, &
        0.4_real64,0.2_real64,0_int32,8_int32,nd,ncell,pp,status)
    call require(status==PPA_WU05A3_MACROGEOM_PARTITION_INVALID,15)
    call require(nd==0 .and. ncell==0 .and. maxval(abs(pp))<1.0e-12_real64,16)
  end subroutine
end program test_ppa_wu05a3_macrogeom_partition_source_oracle
