program test_ppa_wu05a3_mpvolume_hysteresis_source_oracle
  use, intrinsic :: iso_fortran_env, only: real64,int32
  use mod_ppa_wu05a3_mpvolume_hysteresis
  implicit none
  real(real64)::static(3),previous(2,3),current(2,3),volume(2),water(2)
  real(real64)::candidate(2,3),total_candidate(2),dynamic_candidate(3),total
  integer(int32)::bottom(2),status

  call check_shortage_redistribution()
  call check_swmbf_domain_gate()
  call check_no_shrink_recovery()
  call check_insufficient_previous_shrinkage()
  call check_potential_bottom_limits_recovery_scan()
  call check_invalid_mode()
  print '(A)','PPA_WU05A3_MPVOLUME_HYSTERESIS_SOURCE_ORACLE=PASS'
  print '(A)','PPA_WU05A3_MPVOLUME_HYSTERESIS_SHORTAGE_REDISTRIBUTION=PASS'
  print '(A)','PPA_WU05A3_MPVOLUME_HYSTERESIS_SWMBF_DOMAIN_GATE=PASS'
  print '(A)','PPA_WU05A3_MPVOLUME_HYSTERESIS_NO_SHRINK_RECOVERY=PASS'
  print '(A)','PPA_WU05A3_MPVOLUME_HYSTERESIS_INSUFFICIENT_SHRINKAGE_SOURCE_ORDER=PASS'
  print '(A)','PPA_WU05A3_MPVOLUME_HYSTERESIS_POTENTIAL_BOTTOM_SCAN_LIMIT=PASS'
  print '(A)','PPA_WU05A3_MPVOLUME_HYSTERESIS_INVALID_MODE_FAIL_CLOSED=PASS'
contains
  subroutine require(ok,code)
    logical,intent(in)::ok
    integer,intent(in)::code
    if(.not.ok)then
      write(*,'(A,I0)')'PPA_WU05A3_MPVOLUME_HYSTERESIS_FAIL=',code
      error stop 1
    end if
  end subroutine

  subroutine invoke(mode)
    integer(int32),intent(in)::mode
    call ppa_wu05a3_mpvolume_hysteresis(3_int32,2_int32,1_int32,mode,bottom,static, &
        previous,current,volume,water,candidate,total_candidate,dynamic_candidate,total,status)
  end subroutine

  subroutine check_shortage_redistribution()
    static=0.0_real64; previous=0.0_real64; current=0.0_real64
    previous(1,:)=[1.0_real64,1.0_real64,1.0_real64]
    current(1,:)=[0.2_real64,0.4_real64,0.4_real64]
    volume=[1.0_real64,0.0_real64]; water=[1.5_real64,0.0_real64]
    bottom=[3_int32,3_int32]
    call invoke(1_int32)
    call require(status==PPA_WU05A3_MPVOL_HYST_OK,1)
    call require(abs(candidate(1,1)-0.7_real64)<1.0e-12_real64 .and. &
        abs(candidate(1,2)-0.4_real64)<1.0e-12_real64,2)
    call require(abs(total_candidate(1)-1.5_real64)<1.0e-12_real64 .and. &
        abs(total-1.5_real64)<1.0e-12_real64,3)
    call require(maxval(abs(dynamic_candidate-candidate(1,:)))<1.0e-12_real64,4)
  end subroutine

  subroutine check_swmbf_domain_gate()
    static=0.0_real64; previous=0.0_real64; current=0.0_real64
    previous(1,:)=[1.0_real64,1.0_real64,1.0_real64]
    current(1,:)=[0.2_real64,0.2_real64,0.2_real64]
    previous(2,:)=[1.0_real64,1.0_real64,1.0_real64]
    current(2,:)=[0.2_real64,0.4_real64,0.4_real64]
    volume=[0.6_real64,1.0_real64]; water=[0.9_real64,1.5_real64]
    bottom=[3_int32,3_int32]
    call invoke(2_int32)
    call require(status==PPA_WU05A3_MPVOL_HYST_OK,5)
    call require(maxval(abs(candidate(1,:)-current(1,:)))<1.0e-12_real64,6)
    call require(abs(total_candidate(1)-0.6_real64)<1.0e-12_real64,7)
    call require(abs(total_candidate(2)-1.5_real64)<1.0e-12_real64,8)
  end subroutine

  subroutine check_no_shrink_recovery()
    static=0.0_real64; previous=0.0_real64; current=0.0_real64
    current(1,:)=[0.2_real64,0.2_real64,0.2_real64]
    previous(1,:)=current(1,:)
    volume=[0.6_real64,0.0_real64]; water=[1.0_real64,0.0_real64]
    bottom=[3_int32,3_int32]
    call invoke(1_int32)
    call require(status==PPA_WU05A3_MPVOL_HYST_OK,9)
    call require(maxval(abs(candidate(1,:)-current(1,:)))<1.0e-12_real64 .and. &
        abs(total_candidate(1)-0.6_real64)<1.0e-12_real64,10)
  end subroutine

  subroutine check_insufficient_previous_shrinkage()
    static=0.0_real64; previous=0.0_real64; current=0.0_real64
    previous(1,:)=[0.2_real64,0.2_real64,0.2_real64]
    current(1,:)=[0.1_real64,0.1_real64,0.1_real64]
    volume=[0.3_real64,0.0_real64]; water=[0.9_real64,0.0_real64]
    bottom=[3_int32,3_int32]
    call invoke(1_int32)
    call require(status==PPA_WU05A3_MPVOL_HYST_OK,11)
    call require(maxval(abs(candidate(1,:)-[0.3_real64,0.3_real64,0.3_real64]))<1.0e-12_real64,12)
    call require(abs(total_candidate(1)-0.9_real64)<1.0e-12_real64,13)
  end subroutine

  subroutine check_potential_bottom_limits_recovery_scan()
    static=0.0_real64; previous=0.0_real64; current=0.0_real64
    previous(1,:)=[1.0_real64,1.0_real64,1.0_real64]
    current(1,:)=[0.2_real64,0.2_real64,0.2_real64]
    previous(2,:)=[1.0_real64,1.0_real64,1.0_real64]
    current(2,:)=[0.2_real64,0.4_real64,0.4_real64]
    volume=[0.6_real64,1.0_real64]; water=[1.5_real64,0.5_real64]
    bottom=[1_int32,2_int32]
    call invoke(1_int32)
    call require(status==PPA_WU05A3_MPVOL_HYST_OK,14)
    call require(abs(total_candidate(1)-1.5_real64)<1.0e-12_real64,15)
    call require(maxval(abs(candidate(1,:)-[1.1_real64,0.2_real64,0.2_real64]))<1.0e-12_real64,16)
    call require(maxval(abs(candidate(2,:)-current(2,:)))<1.0e-12_real64,17)
  end subroutine

  subroutine check_invalid_mode()
    static=0.0_real64; previous=0.0_real64; current=0.0_real64
    volume=0.0_real64; water=0.0_real64; bottom=[3_int32,3_int32]
    call invoke(3_int32)
    call require(status==PPA_WU05A3_MPVOL_HYST_INVALID,18)
    call require(abs(total)<1.0e-12_real64 .and. maxval(abs(candidate))<1.0e-12_real64,19)
  end subroutine
end program test_ppa_wu05a3_mpvolume_hysteresis_source_oracle
