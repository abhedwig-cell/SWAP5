program test_ppa_wu05a3_macrostate_aggregate_source_oracle
  use, intrinsic :: iso_fortran_env, only: real64,int32
  use mod_ppa_wu05a3_macrostate_aggregate_candidate
  implicit none
  real(real64)::level(3),volume(3),storage(3),cells(3,4)
  real(real64)::level1,volume1,storage1,cells1(4),volume2,storage2,cells2(4)
  integer(int32)::status

  call check_main_and_internal_aggregates()
  call check_single_domain_empty_internal_aggregate()
  call check_invalid_negative_input()
  print '(A)','PPA_WU05A3_MACROSTATE_AGGREGATE_SOURCE_ORACLE=PASS'
  print '(A)','PPA_WU05A3_MACROSTATE_AGGREGATE_MAIN_DOMAIN_ALIAS=PASS'
  print '(A)','PPA_WU05A3_MACROSTATE_AGGREGATE_INTERNAL_DOMAIN_SUM=PASS'
  print '(A)','PPA_WU05A3_MACROSTATE_AGGREGATE_SINGLE_DOMAIN_EMPTY_RANGE=PASS'
  print '(A)','PPA_WU05A3_MACROSTATE_AGGREGATE_INVALID_INPUT_FAIL_CLOSED=PASS'
contains
  subroutine require(ok,code)
    logical,intent(in)::ok
    integer,intent(in)::code
    if(.not.ok)then
      write(*,'(A,I0)')'PPA_WU05A3_MACROSTATE_AGGREGATE_FAIL=',code
      error stop 1
    end if
  end subroutine

  subroutine invoke(nd)
    integer(int32),intent(in)::nd
    call ppa_wu05a3_macrostate_aggregate_candidate(4_int32,nd,level,volume,storage,cells, &
        level1,volume1,storage1,cells1,volume2,storage2,cells2,status)
  end subroutine

  subroutine initialize()
    level=[-10.0_real64,-20.0_real64,-30.0_real64]
    volume=[1.0_real64,2.0_real64,3.0_real64]
    storage=[0.1_real64,0.2_real64,0.3_real64]
    cells(1,:)=[0.1_real64,0.2_real64,0.3_real64,0.4_real64]
    cells(2,:)=[0.2_real64,0.3_real64,0.4_real64,0.5_real64]
    cells(3,:)=[0.3_real64,0.4_real64,0.5_real64,0.6_real64]
  end subroutine

  subroutine check_main_and_internal_aggregates()
    call initialize()
    call invoke(3_int32)
    call require(status==PPA_WU05A3_MACROSTATE_AGGREGATE_OK,1)
    call require(abs(level1-level(1))<1.0e-12_real64 .and. &
        abs(volume1-volume(1))<1.0e-12_real64 .and. &
        abs(storage1-storage(1))<1.0e-12_real64,2)
    call require(maxval(abs(cells1-cells(1,:)))<1.0e-12_real64,3)
    call require(abs(volume2-5.0_real64)<1.0e-12_real64 .and. &
        abs(storage2-0.5_real64)<1.0e-12_real64,4)
    call require(maxval(abs(cells2-[0.5_real64,0.7_real64,0.9_real64,1.1_real64]))<1.0e-12_real64,5)
  end subroutine

  subroutine check_single_domain_empty_internal_aggregate()
    call initialize()
    call invoke(1_int32)
    call require(status==PPA_WU05A3_MACROSTATE_AGGREGATE_OK,6)
    call require(abs(volume2)<1.0e-12_real64 .and. abs(storage2)<1.0e-12_real64 .and. &
        maxval(abs(cells2))<1.0e-12_real64,7)
  end subroutine

  subroutine check_invalid_negative_input()
    call initialize()
    cells(2,3)=-0.1_real64
    call invoke(3_int32)
    call require(status==PPA_WU05A3_MACROSTATE_AGGREGATE_INVALID,8)
    call require(abs(volume2)<1.0e-12_real64 .and. maxval(abs(cells2))<1.0e-12_real64,9)
  end subroutine
end program test_ppa_wu05a3_macrostate_aggregate_source_oracle
