program test_ppa_wu05a3_macrogeom_volume_source_oracle
  use, intrinsic :: iso_fortran_env, only: real64, int32
  use mod_ppa_wu05a3_macrogeom_volume
  implicit none
  call check_main_bypass_and_static_cutoff()
  call check_internal_catchment_surface_segment()
  call check_internal_catchment_power_branches()
  call check_below_static_depth()
  call check_invalid_exponent()
  print '(A)', 'PPA_WU05A3_MACROGEOM_VOLUME_SOURCE_ORACLE=PASS'
  print '(A)', 'PPA_WU05A3_MACROGEOM_MB_DOMAIN_STATIC_CUTOFF=PASS'
  print '(A)', 'PPA_WU05A3_MACROGEOM_IC_SURFACE_LINEAR_BRANCH=PASS'
  print '(A)', 'PPA_WU05A3_MACROGEOM_IC_SPOINT_POWER_BRANCHES=PASS'
  print '(A)', 'PPA_WU05A3_MACROGEOM_BELOW_STATIC_DEPTH_ZERO=PASS'
  print '(A)', 'PPA_WU05A3_MACROGEOM_INVALID_EXPONENT_FAIL_CLOSED=PASS'
contains
  subroutine require(ok, code)
    logical, intent(in) :: ok
    integer, intent(in) :: code
    if (.not. ok) then
      write(*,'(A,I0)') 'PPA_WU05A3_MACROGEOM_VOLUME_FAIL=', code
      error stop 1
    end if
  end subroutine

  subroutine eval(top, bottom, ah, ic, st, zsp, rz, p, sw, orig, pp, mb, mbs, icv, ics, status)
    real(real64), intent(in) :: top,bottom,ah,ic,st,zsp,rz,p,orig,pp
    integer(int32), intent(in) :: sw
    real(real64), intent(out) :: mb,mbs,icv,ics
    integer(int32), intent(out) :: status
    real(real64) :: spoint
    spoint = (ah-zsp)/(ah-ic)
    call ppa_wu05a3_macrogeom_volume(top,bottom,ah,ic,st,zsp,rz,spoint,p,sw,2.0_real64, &
        orig,pp,mb,mbs,icv,ics,status)
  end subroutine

  subroutine check_main_bypass_and_static_cutoff()
    real(real64) :: mb,mbs,icv,ics
    integer(int32) :: status
    call eval(-5.0_real64,-15.0_real64,-5.0_real64,-20.0_real64,-25.0_real64, &
        -10.0_real64,0.0_real64,2.0_real64,0_int32,-10.0_real64,0.0_real64,mb,mbs,icv,ics,status)
    call require(status==PPA_WU05A3_MACROGEOM_OK,1)
    call require(abs(mb-10.0_real64)<1.0e-12_real64 .and. abs(mbs-10.0_real64)<1.0e-12_real64,2)
    call require(abs(icv)<1.0e-12_real64 .and. abs(ics)<1.0e-12_real64,3)
    call eval(-17.0_real64,-23.0_real64,-5.0_real64,-15.0_real64,-25.0_real64, &
        -10.0_real64,0.0_real64,2.0_real64,0_int32,-30.0_real64,0.25_real64,mb,mbs,icv,ics,status)
    call require(status==PPA_WU05A3_MACROGEOM_OK,4)
    call require(abs(mb-1.26_real64)<1.0e-12_real64 .and. abs(mbs)<1.0e-12_real64,5)
  end subroutine

  subroutine check_internal_catchment_surface_segment()
    real(real64) :: mb,mbs,icv,ics
    integer(int32) :: status
    call eval(-2.0_real64,-4.0_real64,-5.0_real64,-15.0_real64,-25.0_real64, &
        -10.0_real64,0.0_real64,2.0_real64,0_int32,-3.0_real64,0.25_real64,mb,mbs,icv,ics,status)
    call require(status==PPA_WU05A3_MACROGEOM_OK,6)
    call require(abs(mb-1.5_real64)<1.0e-12_real64 .and. abs(mbs-1.5_real64)<1.0e-12_real64,7)
    call require(abs(icv-0.5_real64)<1.0e-12_real64 .and. abs(ics-0.5_real64)<1.0e-12_real64,8)
  end subroutine

  subroutine check_internal_catchment_power_branches()
    real(real64) :: mb,mbs,icv,ics, expected
    integer(int32) :: status
    call eval(-6.0_real64,-8.0_real64,-5.0_real64,-15.0_real64,-25.0_real64, &
        -10.0_real64,0.0_real64,2.0_real64,0_int32,-7.0_real64,1.0_real64,mb,mbs,icv,ics,status)
    expected = 2.0_real64 + 10.0_real64*(0.5_real64**(-1.0_real64))/3.0_real64 * &
        (0.1_real64**3-0.3_real64**3)
    call require(status==PPA_WU05A3_MACROGEOM_OK .and. abs(icv-expected)<1.0e-12_real64,9)
    call eval(-11.0_real64,-13.0_real64,-5.0_real64,-15.0_real64,-25.0_real64, &
        -10.0_real64,0.0_real64,2.0_real64,1_int32,-12.0_real64,1.0_real64,mb,mbs,icv,ics,status)
    expected = 10.0_real64*((1.0_real64-0.5_real64)**0.5_real64)/1.5_real64 * &
        ((1.0_real64-0.6_real64)**1.5_real64-(1.0_real64-0.8_real64)**1.5_real64)
    call require(status==PPA_WU05A3_MACROGEOM_OK .and. abs(icv-expected)<1.0e-12_real64,10)
  end subroutine

  subroutine check_below_static_depth()
    real(real64) :: mb,mbs,icv,ics
    integer(int32) :: status
    call eval(-30.0_real64,-40.0_real64,-5.0_real64,-15.0_real64,-25.0_real64, &
        -10.0_real64,0.0_real64,2.0_real64,0_int32,-35.0_real64,0.25_real64,mb,mbs,icv,ics,status)
    call require(status==PPA_WU05A3_MACROGEOM_OK,11)
    call require(abs(mb)<1.0e-12_real64 .and. abs(mbs)<1.0e-12_real64 .and. &
        abs(icv)<1.0e-12_real64 .and. abs(ics)<1.0e-12_real64,12)
  end subroutine

  subroutine check_invalid_exponent()
    real(real64) :: mb,mbs,icv,ics
    integer(int32) :: status
    call eval(-6.0_real64,-8.0_real64,-5.0_real64,-15.0_real64,-25.0_real64, &
        -10.0_real64,0.0_real64,0.0_real64,0_int32,-7.0_real64,0.25_real64,mb,mbs,icv,ics,status)
    call require(status==PPA_WU05A3_MACROGEOM_INVALID,13)
    call require(maxval(abs([mb,mbs,icv,ics]))<1.0e-12_real64,14)
  end subroutine
end program test_ppa_wu05a3_macrogeom_volume_source_oracle
