program test_ppa_wu05a3_macrogeom_aggregate_source_oracle
  use, intrinsic :: iso_fortran_env, only: real64, int32
  use mod_ppa_wu05a3_macrogeom_aggregate
  implicit none
  call check_no_internal_catchment()
  call check_positive_internal_catchment()
  call check_source_unclamped_matrix_remainder()
  call check_invalid_inputs()
  print '(A)', 'PPA_WU05A3_MACROGEOM_AGGREGATE_SOURCE_ORACLE=PASS'
  print '(A)', 'PPA_WU05A3_MACROGEOM_IC_ZERO_BRANCH=PASS'
  print '(A)', 'PPA_WU05A3_MACROGEOM_IC_POSITIVE_RATIO=PASS'
  print '(A)', 'PPA_WU05A3_MACROGEOM_STATIC_VOLUME_AND_MATRIX_FRACTION=PASS'
  print '(A)', 'PPA_WU05A3_MACROGEOM_STATIC_OVERFULL_SOURCE_RESULT_PRESERVED=PASS'
  print '(A)', 'PPA_WU05A3_MACROGEOM_AGGREGATE_INVALID_FAIL_CLOSED=PASS'
contains
  subroutine require(ok, code)
    logical, intent(in) :: ok
    integer, intent(in) :: code
    if (.not. ok) then
      write(*,'(A,I0)') 'PPA_WU05A3_MACROGEOM_AGGREGATE_FAIL=', code
      error stop 1
    end if
  end subroutine

  subroutine eval(mb,ic,mbs,ics,vlm,dz,pp,static,frac,status)
    real(real64), intent(in) :: mb,ic,mbs,ics,vlm,dz
    real(real64), intent(out) :: pp,static,frac
    integer(int32), intent(out) :: status
    call ppa_wu05a3_macrogeom_aggregate(mb,ic,mbs,ics,vlm,dz,pp,static,frac,status)
  end subroutine

  subroutine check_no_internal_catchment()
    real(real64) :: pp,static,frac
    integer(int32) :: status
    call eval(10.0_real64,0.0_real64,1.0_real64,0.0_real64,0.5_real64, &
        10.0_real64,pp,static,frac,status)
    call require(status==PPA_WU05A3_MACROGEOM_AGGREGATE_OK,1)
    call require(abs(pp)<1.0e-12_real64 .and. abs(static-0.5_real64)<1.0e-12_real64,2)
    call require(abs(frac-0.95_real64)<1.0e-12_real64,3)
    call eval(0.0_real64,0.0_real64,0.0_real64,0.0_real64,0.5_real64, &
        10.0_real64,pp,static,frac,status)
    call require(status==PPA_WU05A3_MACROGEOM_AGGREGATE_OK .and. abs(pp)<1.0e-12_real64,4)
  end subroutine

  subroutine check_positive_internal_catchment()
    real(real64) :: pp,static,frac
    integer(int32) :: status
    call eval(6.0_real64,4.0_real64,1.0_real64,2.0_real64,0.5_real64, &
        10.0_real64,pp,static,frac,status)
    call require(status==PPA_WU05A3_MACROGEOM_AGGREGATE_OK,5)
    call require(abs(pp-0.4_real64)<1.0e-12_real64,6)
    call require(abs(static-1.5_real64)<1.0e-12_real64 .and. &
        abs(frac-0.85_real64)<1.0e-12_real64,7)
  end subroutine

  subroutine check_source_unclamped_matrix_remainder()
    real(real64) :: pp,static,frac
    integer(int32) :: status
    call eval(2.0_real64,0.0_real64,20.0_real64,0.0_real64,1.0_real64, &
        10.0_real64,pp,static,frac,status)
    call require(status==PPA_WU05A3_MACROGEOM_AGGREGATE_OK,8)
    call require(abs(static-20.0_real64)<1.0e-12_real64 .and. &
        abs(frac+1.0_real64)<1.0e-12_real64,9)
  end subroutine

  subroutine check_invalid_inputs()
    real(real64) :: pp,static,frac
    integer(int32) :: status
    call eval(-1.0_real64,1.0_real64,0.0_real64,0.0_real64,0.5_real64, &
        10.0_real64,pp,static,frac,status)
    call require(status==PPA_WU05A3_MACROGEOM_AGGREGATE_INVALID,10)
    call require(maxval(abs([pp,static,frac]))<1.0e-12_real64,11)
    call eval(1.0_real64,1.0_real64,0.0_real64,0.0_real64,0.5_real64, &
        0.0_real64,pp,static,frac,status)
    call require(status==PPA_WU05A3_MACROGEOM_AGGREGATE_INVALID,12)
  end subroutine
end program test_ppa_wu05a3_macrogeom_aggregate_source_oracle
