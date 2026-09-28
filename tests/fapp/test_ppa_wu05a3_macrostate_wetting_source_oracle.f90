program test_ppa_wu05a3_macrostate_wetting_source_oracle
  use, intrinsic :: iso_fortran_env, only: real64,int32
  use mod_ppa_wu05a3_macrostate_wetting_candidate
  implicit none
  real(real64)::storage(2),zbottom(2),volume(2,4),dz(4),fraction0(2,4),water0(2,4)
  real(real64)::fraction(2,4),water(2,4),level(2)
  integer(int32)::bottom(2),top(2),status

  call check_partial_water_level()
  call check_full_storage_and_bottom_layer()
  call check_swmbf2_preserves_main_profile()
  call check_empty_domain()
  call check_small_volume_upper_interface()
  call check_invalid_bottom_extent()
  print '(A)','PPA_WU05A3_MACROSTATE_WETTING_SOURCE_ORACLE=PASS'
  print '(A)','PPA_WU05A3_MACROSTATE_WETTING_PARTIAL_LEVEL=PASS'
  print '(A)','PPA_WU05A3_MACROSTATE_WETTING_FULL_BOTTOM_CELL=PASS'
  print '(A)','PPA_WU05A3_MACROSTATE_WETTING_SWMBF2_PROFILE_PRESERVATION=PASS'
  print '(A)','PPA_WU05A3_MACROSTATE_WETTING_EMPTY_DOMAIN=PASS'
  print '(A)','PPA_WU05A3_MACROSTATE_WETTING_SMALL_VOLUME_UPPER_INTERFACE=PASS'
  print '(A)','PPA_WU05A3_MACROSTATE_WETTING_INVALID_BOTTOM_FAIL_CLOSED=PASS'
contains
  subroutine require(ok,code)
    logical,intent(in)::ok
    integer,intent(in)::code
    if(.not.ok)then
      write(*,'(A,I0)')'PPA_WU05A3_MACROSTATE_WETTING_FAIL=',code
      error stop 1
    end if
  end subroutine

  subroutine invoke(mode)
    integer(int32),intent(in)::mode
    call ppa_wu05a3_macrostate_wetting_candidate(4_int32,2_int32,2_int32,mode,bottom, &
        storage,zbottom,volume,dz,fraction0,water0,fraction,water,top,level,status)
  end subroutine

  subroutine initialize()
    storage=0.0_real64; zbottom=[-30.0_real64,-40.0_real64]
    volume=0.0_real64; volume(1,2:4)=[0.5_real64,0.5_real64,1.0_real64]
    volume(2,2:4)=[0.4_real64,0.6_real64,0.8_real64]
    dz=10.0_real64; fraction0=0.0_real64; water0=0.0_real64
    bottom=[4_int32,4_int32]
  end subroutine

  subroutine check_partial_water_level()
    call initialize()
    storage(1)=1.25_real64
    call invoke(1_int32)
    call require(status==PPA_WU05A3_MACROSTATE_WETTING_OK,1)
    call require(top(1)==3 .and. abs(fraction(1,3)-0.5_real64)<1.0e-12_real64,2)
    call require(abs(water(1,4)-1.0_real64)<1.0e-12_real64 .and. &
        abs(water(1,3)-0.25_real64)<1.0e-12_real64,3)
    call require(abs(level(1)-(-15.0_real64))<1.0e-12_real64,4)
  end subroutine

  subroutine check_full_storage_and_bottom_layer()
    call initialize()
    storage(1)=2.0_real64
    call invoke(1_int32)
    call require(status==PPA_WU05A3_MACROSTATE_WETTING_OK,5)
    call require(top(1)==2 .and. abs(fraction(1,2)-1.0_real64)<1.0e-12_real64,6)
    call require(abs(level(1)-0.0_real64)<1.0e-12_real64,7)
  end subroutine

  subroutine check_swmbf2_preserves_main_profile()
    call initialize()
    storage=[1.0_real64,0.5_real64]
    fraction0(1,:)=[0.1_real64,0.2_real64,0.3_real64,0.4_real64]
    water0(1,:)=[0.01_real64,0.02_real64,0.03_real64,0.04_real64]
    call invoke(2_int32)
    call require(status==PPA_WU05A3_MACROSTATE_WETTING_OK,8)
    call require(maxval(abs(water(1,:)-water0(1,:)))<1.0e-12_real64,9)
    call require(maxval(abs(water(2,1:3)))<1.0e-12_real64 .and. &
        abs(water(2,4)-0.5_real64)<1.0e-12_real64,10)
    call require(top(1)==4 .and. top(2)==4,11)
  end subroutine

  subroutine check_empty_domain()
    call initialize()
    bottom=[0_int32,0_int32]
    call invoke(1_int32)
    call require(status==PPA_WU05A3_MACROSTATE_WETTING_OK,12)
    call require(all(top==1) .and. maxval(abs(level))<1.0e-12_real64,13)
    call require(maxval(abs(fraction(:,2:4)))<1.0e-12_real64,14)
  end subroutine

  subroutine check_small_volume_upper_interface()
    call initialize()
    storage(1)=1.0_real64
    volume(1,2:4)=1.0e-9_real64
    call invoke(1_int32)
    call require(status==PPA_WU05A3_MACROSTATE_WETTING_OK,15)
    call require(top(1)==3 .and. abs(fraction(1,3)-1.0_real64)<1.0e-12_real64,16)
    call require(abs(level(1)-(-10.0_real64))<1.0e-12_real64,17)
  end subroutine

  subroutine check_invalid_bottom_extent()
    call initialize()
    bottom(1)=1_int32
    call invoke(1_int32)
    call require(status==PPA_WU05A3_MACROSTATE_WETTING_INVALID,18)
    call require(maxval(abs(water))<1.0e-12_real64 .and. &
        maxval(abs(fraction))<1.0e-12_real64,19)
  end subroutine
end program test_ppa_wu05a3_macrostate_wetting_source_oracle
