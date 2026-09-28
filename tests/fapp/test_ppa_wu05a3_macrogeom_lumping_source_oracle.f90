program test_ppa_wu05a3_macrogeom_lumping_source_oracle
  use, intrinsic :: iso_fortran_env, only: real64, int32
  use mod_ppa_wu05a3_macrogeom_lumping
  implicit none
  call check_chained_same_bottom_lumping()
  call check_distinct_bottoms()
  call check_ah_lumping_gate()
  call check_invalid_shape()
  print '(A)', 'PPA_WU05A3_MACROGEOM_LUMPING_SOURCE_ORACLE=PASS'
  print '(A)', 'PPA_WU05A3_MACROGEOM_DOMAIN_BOTTOM_DETECTION=PASS'
  print '(A)', 'PPA_WU05A3_MACROGEOM_SAME_BOTTOM_CHAIN_LUMPING=PASS'
  print '(A)', 'PPA_WU05A3_MACROGEOM_AH_RELATIVE_SIZE_LUMPING_GATE=PASS'
  print '(A)', 'PPA_WU05A3_MACROGEOM_DISTINCT_BOTTOMS_REMAIN_SEPARATE=PASS'
  print '(A)', 'PPA_WU05A3_MACROGEOM_LUMPING_INVALID_SHAPE_FAIL_CLOSED=PASS'
contains
  subroutine require(ok,code)
    logical,intent(in) :: ok
    integer,intent(in) :: code
    if (.not.ok) then
      write(*,'(A,I0)') 'PPA_WU05A3_MACROGEOM_LUMPING_FAIL=',code
      error stop 1
    end if
  end subroutine

  subroutine check_chained_same_bottom_lumping()
    real(real64) :: pp(6,4)
    integer(int32) :: bottoms(6),nd,status
    pp=0.0_real64
    pp(1,1:3)=[0.1_real64,0.1_real64,0.1_real64]
    pp(2,1)=0.2_real64; pp(3,1)=0.3_real64; pp(4,1)=0.4_real64
    nd=4
    call ppa_wu05a3_macrogeom_lumping(3_int32,3_int32,0.0_real64,nd,pp,bottoms,status)
    call require(status==PPA_WU05A3_MACROGEOM_LUMPING_OK,1)
    call require(nd==2 .and. all(bottoms(1:3)==[3_int32,1_int32,0_int32]),2)
    call require(abs(pp(2,1)-0.9_real64)<1.0e-12_real64,3)
    call require(abs(sum(pp(1:2,1))-1.0_real64)<1.0e-12_real64,4)
  end subroutine

  subroutine check_distinct_bottoms()
    real(real64) :: pp(6,4),before(6,4)
    integer(int32) :: bottoms(6),nd,status
    pp=0.0_real64
    pp(2,1)=0.3_real64
    pp(3,1:2)=[0.1_real64,0.2_real64]
    pp(4,1:3)=[0.2_real64,0.2_real64,0.1_real64]
    before=pp
    nd=4
    call ppa_wu05a3_macrogeom_lumping(3_int32,3_int32,0.0_real64,nd,pp,bottoms,status)
    call require(status==PPA_WU05A3_MACROGEOM_LUMPING_OK .and. nd==4,5)
    call require(all(bottoms(2:4)==[1_int32,2_int32,3_int32]),6)
    call require(maxval(abs(pp-before))<1.0e-12_real64,7)
  end subroutine

  subroutine check_ah_lumping_gate()
    real(real64) :: pp(5,3)
    integer(int32) :: bottoms(5),nd,status
    pp=0.0_real64
    pp(2,1)=0.3_real64; pp(3,1)=0.7_real64
    nd=3
    call ppa_wu05a3_macrogeom_lumping(2_int32,1_int32,0.2_real64,nd,pp,bottoms,status)
    call require(status==PPA_WU05A3_MACROGEOM_LUMPING_OK .and. nd==2,8)
    call require(all(bottoms(1:2)==[2_int32,1_int32]),9)
    call require(abs(pp(2,1)-1.0_real64)<1.0e-12_real64 .and. &
        abs(pp(3,1))<1.0e-12_real64,10)
    pp=0.0_real64
    pp(2,1)=0.4_real64; pp(3,1)=0.6_real64
    nd=3
    call ppa_wu05a3_macrogeom_lumping(2_int32,1_int32,0.2_real64,nd,pp,bottoms,status)
    call require(nd==3,11)
  end subroutine

  subroutine check_invalid_shape()
    real(real64) :: pp(2,2)
    integer(int32) :: bottoms(2),nd,status
    pp=0.0_real64; nd=3
    call ppa_wu05a3_macrogeom_lumping(2_int32,1_int32,0.2_real64,nd,pp,bottoms,status)
    call require(status==PPA_WU05A3_MACROGEOM_LUMPING_INVALID,12)
    call require(all(bottoms==0),13)
  end subroutine
end program test_ppa_wu05a3_macrogeom_lumping_source_oracle
