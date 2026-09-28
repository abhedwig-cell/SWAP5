program test_ppa_wu05a3_macrostate_flux_source_oracle
  use, intrinsic :: iso_fortran_env, only: real64,int32
  use mod_ppa_wu05a3_macrostate_flux_candidate
  implicit none
  real(real64)::qlat(2),qvrt(2),exchange(2,5),water(2,5),water_m1(2,5)
  real(real64)::volume(2,5),volume_m1(2,5),q0(2,5),q(2,5)
  integer(int32)::bottom(2),bottom_m1(2),watertop(2),status

  call check_unsaturated_and_saturated_recurrence()
  call check_shallower_bottom_recurrence()
  call check_swmbf_domain_gate()
  call check_empty_domain_top()
  call check_invalid_previous_bottom()
  call check_missing_lower_boundary()
  print '(A)','PPA_WU05A3_MACROSTATE_FLUX_SOURCE_ORACLE=PASS'
  print '(A)','PPA_WU05A3_MACROSTATE_FLUX_UNSATURATED_SATURATED=PASS'
  print '(A)','PPA_WU05A3_MACROSTATE_FLUX_SHALLOWER_BOTTOM=PASS'
  print '(A)','PPA_WU05A3_MACROSTATE_FLUX_SWMBF_DOMAIN_GATE=PASS'
  print '(A)','PPA_WU05A3_MACROSTATE_FLUX_EMPTY_DOMAIN_TOP=PASS'
  print '(A)','PPA_WU05A3_MACROSTATE_FLUX_INVALID_PREVIOUS_BOTTOM_FAIL_CLOSED=PASS'
  print '(A)','PPA_WU05A3_MACROSTATE_FLUX_MISSING_LOWER_BOUNDARY=PASS'
contains
  subroutine require(ok,code)
    logical,intent(in)::ok
    integer,intent(in)::code
    if(.not.ok)then
      write(*,'(A,I0)')'PPA_WU05A3_MACROSTATE_FLUX_FAIL=',code
      error stop 1
    end if
  end subroutine

  subroutine invoke(mode)
    integer(int32),intent(in)::mode
    call ppa_wu05a3_macrostate_flux_candidate(5_int32,2_int32,2_int32,mode,bottom,bottom_m1, &
        watertop,0.5_real64,qlat,qvrt,exchange,water,water_m1,volume,volume_m1,q0,q,status)
  end subroutine

  subroutine initialize()
    qlat=[0.7_real64,-0.2_real64]; qvrt=[0.1_real64,0.3_real64]
    exchange=0.0_real64; water=0.0_real64; water_m1=0.0_real64
    volume=0.0_real64; volume_m1=0.0_real64; q0=0.0_real64; q=0.0_real64
    bottom=[4_int32,3_int32]; bottom_m1=bottom; watertop=[3_int32,2_int32]
  end subroutine

  subroutine check_unsaturated_and_saturated_recurrence()
    call initialize()
    water(1,2)=0.2_real64; water_m1(1,2)=0.1_real64
    exchange(1,2)=0.1_real64; q0(1,5)=0.9_real64
    exchange(1,4)=0.05_real64; volume(1,4)=0.6_real64; volume_m1(1,4)=0.4_real64
    q0(2,4)=0.2_real64; exchange(2,3)=0.05_real64
    volume(2,3)=0.7_real64; volume_m1(2,3)=0.6_real64
    call invoke(1_int32)
    call require(status==PPA_WU05A3_MACROSTATE_FLUX_OK,1)
    call require(abs(q(1,2)-0.8_real64)<1.0e-12_real64 .and. &
        abs(q(1,3)-0.5_real64)<1.0e-12_real64,2)
    call require(abs(q(1,4)-1.35_real64)<1.0e-12_real64,3)
    call require(abs(q(2,2)-0.1_real64)<1.0e-12_real64 .and. &
        abs(q(2,3)-0.45_real64)<1.0e-12_real64,4)
  end subroutine

  subroutine check_shallower_bottom_recurrence()
    call initialize()
    bottom(1)=3_int32; bottom_m1(1)=4_int32; watertop(1)=2_int32
    q0(1,4)=0.8_real64; water_m1(1,3)=0.25_real64; water_m1(1,4)=0.1_real64
    exchange(1,3)=0.1_real64; volume(1,3)=0.7_real64; volume_m1(1,3)=0.5_real64
    call invoke(1_int32)
    call require(status==PPA_WU05A3_MACROSTATE_FLUX_OK,5)
    call require(abs(q(1,3)-0.3_real64)<1.0e-12_real64,6)
    call require(abs(q(1,4)+0.2_real64)<1.0e-12_real64,7)
    call require(abs(q(1,2)-0.8_real64)<1.0e-12_real64,8)
  end subroutine

  subroutine check_swmbf_domain_gate()
    call initialize()
    q0(1,:)=[1.0_real64,2.0_real64,3.0_real64,4.0_real64,5.0_real64]
    q0(2,:)=[0.1_real64,0.2_real64,0.3_real64,0.4_real64,0.5_real64]
    watertop=bottom
    call invoke(2_int32)
    call require(status==PPA_WU05A3_MACROSTATE_FLUX_OK,9)
    call require(maxval(abs(q(1,:)-q0(1,:)))<1.0e-12_real64,10)
    call require(abs(q(2,2)-0.1_real64)<1.0e-12_real64,11)
  end subroutine

  subroutine check_empty_domain_top()
    call initialize()
    bottom=[0_int32,0_int32]; bottom_m1=bottom; watertop=[1_int32,1_int32]
    call invoke(1_int32)
    call require(status==PPA_WU05A3_MACROSTATE_FLUX_OK,12)
    call require(maxval(abs(q))<1.0e-12_real64,13)
  end subroutine

  subroutine check_missing_lower_boundary()
    call initialize()
    bottom(1)=5_int32; bottom_m1(1)=5_int32; watertop(1)=2_int32
    call invoke(1_int32)
    call require(status==PPA_WU05A3_MACROSTATE_FLUX_INVALID,16)
    call require(maxval(abs(q))<1.0e-12_real64,17)
    ! The excluded main domain does not consume a lower boundary flux.
    call invoke(2_int32)
    call require(status==PPA_WU05A3_MACROSTATE_FLUX_OK,18)
    ! A wholly unsaturated recurrence does not read below the last node either.
    watertop(1)=5_int32
    call invoke(1_int32)
    call require(status==PPA_WU05A3_MACROSTATE_FLUX_OK,19)
  end subroutine

  subroutine check_invalid_previous_bottom()
    call initialize()
    bottom(1)=3_int32; bottom_m1(1)=5_int32; watertop(1)=2_int32
    call invoke(1_int32)
    call require(status==PPA_WU05A3_MACROSTATE_FLUX_INVALID,14)
    call require(maxval(abs(q))<1.0e-12_real64,15)
  end subroutine
end program test_ppa_wu05a3_macrostate_flux_source_oracle
