program test_ppa_wu05a3_macrostate_storage_source_oracle
  use, intrinsic :: iso_fortran_env, only: real64,int32
  use, intrinsic :: ieee_arithmetic, only: ieee_value,ieee_quiet_nan
  use mod_ppa_wu05a3_macrostate_storage_candidate
  implicit none
  real(real64)::previous(2),qlat(2),qvrt(2),exchange(2,3),drain(3)
  real(real64)::profile_water(2,3),profile_volume(2,3),waunsat(2)
  real(real64)::wasr(2),waun(2),total
  integer(int32)::bottom(2),gwl_top(2),status

  call check_flux_owned_storage()
  call check_source_rounding_order()
  call check_swmbf2_profile_storage()
  call check_partial_saturation_scan()
  call check_empty_domain_profile()
  call check_invalid_profile_volume()
  call check_profile_above_top()
  print '(A)','PPA_WU05A3_MACROSTATE_STORAGE_SOURCE_ORACLE=PASS'
  print '(A)','PPA_WU05A3_MACROSTATE_STORAGE_FLUX_AND_DRAINAGE=PASS'
  print '(A)','PPA_WU05A3_MACROSTATE_STORAGE_ROUNDING_ORDER=PASS'
  print '(A)','PPA_WU05A3_MACROSTATE_STORAGE_SWMBF2_PROFILE=PASS'
  print '(A)','PPA_WU05A3_MACROSTATE_STORAGE_PARTIAL_SATURATION_SCAN=PASS'
  print '(A)','PPA_WU05A3_MACROSTATE_STORAGE_EMPTY_DOMAIN=PASS'
  print '(A)','PPA_WU05A3_MACROSTATE_STORAGE_ZERO_VOLUME_FAIL_CLOSED=PASS'
  print '(A)','PPA_WU05A3_MACROSTATE_STORAGE_PROFILE_ABOVE_TOP=PASS'
contains
  subroutine require(ok,code)
    logical,intent(in)::ok
    integer,intent(in)::code
    if(.not.ok)then
      write(*,'(A,I0)')'PPA_WU05A3_MACROSTATE_STORAGE_FAIL=',code
      error stop 1
    end if
  end subroutine

  subroutine invoke(mode)
    integer(int32),intent(in)::mode
    call ppa_wu05a3_macrostate_storage_candidate(3_int32,2_int32,1_int32,mode,bottom, &
        0.5_real64,previous,qlat,qvrt,exchange,drain,profile_water,profile_volume, &
        waunsat,wasr,waun,gwl_top,total,status)
  end subroutine

  subroutine initialize()
    previous=0.0_real64; qlat=0.0_real64; qvrt=0.0_real64
    exchange=0.0_real64; drain=0.0_real64; profile_water=0.0_real64
    profile_volume=1.0_real64; waunsat=0.0_real64; bottom=[2_int32,3_int32]
  end subroutine

  subroutine check_flux_owned_storage()
    call initialize()
    previous=[1.0_real64,0.5_real64]; qlat=[2.0_real64,-1.0_real64]
    qvrt=[1.0_real64,0.0_real64]; exchange(1,:)=[0.5_real64,0.25_real64,0.0_real64]
    exchange(2,:)=[0.25_real64,0.25_real64,0.0_real64]
    drain=[0.5_real64,0.5_real64,0.0_real64]
    call invoke(1_int32)
    call require(status==PPA_WU05A3_MACROSTATE_STORAGE_OK,1)
    call require(abs(wasr(1)-1.625_real64)<1.0e-12_real64 .and. &
        abs(wasr(2))<1.0e-12_real64,2)
    call require(maxval(abs(waun-wasr))<1.0e-12_real64 .and. &
        abs(total-1.625_real64)<1.0e-12_real64,3)
  end subroutine

  subroutine check_source_rounding_order()
    ! Half an ulp rounds away at 1, then drainage moves to its predecessor.
    ! Combining equal inflow/drainage before adding storage incorrectly gives 1.
    call initialize()
    previous(1)=1.0_real64
    qlat(1)=epsilon(1.0_real64)
    drain(1)=epsilon(1.0_real64)
    call invoke(1_int32)
    call require(status==PPA_WU05A3_MACROSTATE_STORAGE_OK,16)
    call require(abs(wasr(1)-nearest(1.0_real64,-1.0_real64))<tiny(1.0_real64),17)
  end subroutine

  subroutine check_swmbf2_profile_storage()
    call initialize()
    bottom=[3_int32,3_int32]; previous=[0.3_real64,0.2_real64]
    profile_water(1,:)=[0.4_real64,0.5_real64,0.2_real64]
    profile_volume(1,:)=[0.4_real64,0.5_real64,0.2_real64]
    waunsat(1)=0.3_real64
    call invoke(2_int32)
    call require(status==PPA_WU05A3_MACROSTATE_STORAGE_OK,4)
    call require(abs(waun(1)-1.1_real64)<1.0e-12_real64 .and. &
        abs(wasr(1)-0.8_real64)<1.0e-12_real64,5)
    call require(gwl_top(1)==1 .and. abs(wasr(2)-0.2_real64)<1.0e-12_real64,6)
    call require(abs(total-1.3_real64)<1.0e-12_real64,7)
  end subroutine

  subroutine check_partial_saturation_scan()
    call initialize()
    bottom=[3_int32,0_int32]
    profile_water(1,:)=[0.5_real64,0.25_real64,0.1_real64]
    profile_volume(1,:)=[0.5_real64,0.5_real64,0.2_real64]
    waunsat(1)=0.2_real64
    call invoke(2_int32)
    call require(status==PPA_WU05A3_MACROSTATE_STORAGE_OK,8)
    call require(gwl_top(1)==3 .and. abs(waun(1)-0.85_real64)<1.0e-12_real64,9)
    call require(abs(wasr(1))<1.0e-12_real64,10)
  end subroutine

  subroutine check_empty_domain_profile()
    call initialize()
    bottom=[0_int32,0_int32]; waunsat(1)=0.7_real64
    call invoke(2_int32)
    call require(status==PPA_WU05A3_MACROSTATE_STORAGE_OK,11)
    call require(gwl_top(1)==1 .and. abs(waun(1))<1.0e-12_real64 .and. &
        abs(wasr(1))<1.0e-12_real64,12)
    call require(abs(total)<1.0e-12_real64,13)
  end subroutine

  subroutine check_profile_above_top()
    call initialize()
    bottom=[3_int32,0_int32]
    profile_water(1,:)=[0.25_real64,1.0_real64,1.0_real64]
    call ppa_wu05a3_macrostate_storage_candidate(3_int32,2_int32,2_int32,2_int32,bottom, &
        0.5_real64,previous,qlat,qvrt,exchange,drain,profile_water,profile_volume, &
        waunsat,wasr,waun,gwl_top,total,status)
    call require(status==PPA_WU05A3_MACROSTATE_STORAGE_OK,18)
    call require(abs(wasr(1)-2.25_real64)<1.0e-12_real64 .and. &
        abs(waun(1)-2.0_real64)<1.0e-12_real64,19)
    profile_water(1,1)=ieee_value(0.0_real64,ieee_quiet_nan)
    call ppa_wu05a3_macrostate_storage_candidate(3_int32,2_int32,2_int32,2_int32,bottom, &
        0.5_real64,previous,qlat,qvrt,exchange,drain,profile_water,profile_volume, &
        waunsat,wasr,waun,gwl_top,total,status)
    call require(status==PPA_WU05A3_MACROSTATE_STORAGE_INVALID,20)
    call require(maxval(abs(wasr))+maxval(abs(waun))+abs(total)<tiny(1.0_real64),21)
  end subroutine

  subroutine check_invalid_profile_volume()
    call initialize()
    bottom=[2_int32,0_int32]; profile_volume(1,2)=0.0_real64
    call invoke(2_int32)
    call require(status==PPA_WU05A3_MACROSTATE_STORAGE_INVALID,14)
    call require(abs(total)<1.0e-12_real64 .and. maxval(abs(wasr))<1.0e-12_real64,15)
  end subroutine
end program test_ppa_wu05a3_macrostate_storage_source_oracle
