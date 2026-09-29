program test_ppa_wu05a3_macrogeom_top_suppression_source_oracle
  use, intrinsic :: iso_fortran_env, only: real64, int32
  use mod_ppa_wu05a3_macrogeom_top_suppression
  implicit none
  call check_suppression_range()
  call check_top_is_first()
  call check_invalid_top()
  print '(A)', 'PPA_WU05A3_MACROGEOM_TOP_SUPPRESSION_SOURCE_ORACLE=PASS'
  print '(A)', 'PPA_WU05A3_MACROGEOM_TOP_FREE_CELLS_ZEROED=PASS'
  print '(A)', 'PPA_WU05A3_MACROGEOM_TOP_FREE_MATRIX_AREA_ONE=PASS'
  print '(A)', 'PPA_WU05A3_MACROGEOM_IC_TOP_AND_DEEPER_CELLS_PRESERVED=PASS'
  print '(A)', 'PPA_WU05A3_MACROGEOM_TOP_SUPPRESSION_INVALID_FAIL_CLOSED=PASS'
contains
  subroutine require(ok,code)
    logical,intent(in) :: ok
    integer,intent(in) :: code
    if (.not.ok) then
      write(*,'(A,I0)') 'PPA_WU05A3_MACROGEOM_TOP_SUPPRESSION_FAIL=',code
      error stop 1
    end if
  end subroutine

  subroutine check_suppression_range()
    real(real64) :: ppic(4),v1(4),v2(4),vc(4),fm(4),pdom(3,4)
    integer(int32) :: status
    ppic=[0.1_real64,0.2_real64,0.3_real64,0.4_real64]
    v1=[1.0_real64,2.0_real64,3.0_real64,4.0_real64]
    v2=[0.5_real64,0.6_real64,0.7_real64,0.8_real64]
    vc=[1.5_real64,2.6_real64,3.7_real64,4.8_real64]
    fm=[0.8_real64,0.7_real64,0.6_real64,0.5_real64]
    pdom(1,:)=[0.5_real64,0.5_real64,0.5_real64,0.5_real64]
    pdom(2,:)=[0.3_real64,0.3_real64,0.3_real64,0.3_real64]
    pdom(3,:)=[0.2_real64,0.2_real64,0.2_real64,0.2_real64]
    call ppa_wu05a3_macrogeom_top_suppression(3_int32,4_int32,3_int32, &
        ppic,v1,v2,vc,fm,pdom,status)
    call require(status==PPA_WU05A3_TOP_SUPPRESSION_OK,1)
    call require(maxval(abs(ppic(1:2)))<1.0e-12_real64 .and. &
        maxval(abs(v1(1:2)))<1.0e-12_real64 .and. &
        maxval(abs(v2(1:2)))<1.0e-12_real64 .and. &
        maxval(abs(vc(1:2)))<1.0e-12_real64,2)
    call require(maxval(abs(pdom(:,1:2)))<1.0e-12_real64,3)
    call require(maxval(abs(fm(1:2)-1.0_real64))<1.0e-12_real64,4)
    call require(maxval(abs(ppic(3:4)-[0.3_real64,0.4_real64]))<1.0e-12_real64 .and. &
        maxval(abs(v1(3:4)-[3.0_real64,4.0_real64]))<1.0e-12_real64,5)
    call require(maxval(abs(v2(3:4)-[0.7_real64,0.8_real64]))<1.0e-12_real64 .and. &
        maxval(abs(vc(3:4)-[3.7_real64,4.8_real64]))<1.0e-12_real64,6)
    call require(maxval(abs(pdom(:,3:4)-reshape([0.5_real64,0.3_real64,0.2_real64, &
        0.5_real64,0.3_real64,0.2_real64],[3,2])))<1.0e-12_real64,7)
  end subroutine

  subroutine check_top_is_first()
    real(real64) :: ppic(4),v1(4),v2(4),vc(4),fm(4),pdom(3,4)
    integer(int32) :: status
    ppic=0.5_real64; v1=1.0_real64; v2=2.0_real64; vc=3.0_real64
    fm=0.25_real64; pdom=0.2_real64
    call ppa_wu05a3_macrogeom_top_suppression(1_int32,4_int32,3_int32, &
        ppic,v1,v2,vc,fm,pdom,status)
    call require(status==PPA_WU05A3_TOP_SUPPRESSION_OK,8)
    call require(all(abs(ppic-0.5_real64)<1.0e-12_real64) .and. &
        all(abs(fm-0.25_real64)<1.0e-12_real64),9)
  end subroutine

  subroutine check_invalid_top()
    real(real64) :: ppic(4),v1(4),v2(4),vc(4),fm(4),pdom(3,4)
    integer(int32) :: status
    ppic=0.5_real64; v1=1.0_real64; v2=2.0_real64; vc=3.0_real64
    fm=0.25_real64; pdom=0.2_real64
    call ppa_wu05a3_macrogeom_top_suppression(5_int32,4_int32,3_int32, &
        ppic,v1,v2,vc,fm,pdom,status)
    call require(status==PPA_WU05A3_TOP_SUPPRESSION_INVALID,10)
    call require(all(abs(ppic-0.5_real64)<1.0e-12_real64),11)
  end subroutine
end program test_ppa_wu05a3_macrogeom_top_suppression_source_oracle
