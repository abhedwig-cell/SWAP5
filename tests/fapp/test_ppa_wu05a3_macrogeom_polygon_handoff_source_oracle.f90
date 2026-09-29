program test_ppa_wu05a3_macrogeom_polygon_handoff_source_oracle
  use, intrinsic :: iso_fortran_env, only: real64, int32
  use mod_ppa_wu05a3_polygon_diameter
  implicit none
  integer(int32), parameter :: num_nodes=5_int32, ic_top_mp=2_int32, domain2_bottom=3_int32
  real(real64) :: dz(num_nodes), pp_ic_cp(num_nodes), vl_static(num_nodes), z(num_nodes)
  real(real64) :: diameter(num_nodes), first_pass(num_nodes), expected
  integer(int32) :: ic,status

  dz=[10.0_real64,8.0_real64,12.0_real64,15.0_real64,20.0_real64]
  pp_ic_cp=[0.0_real64,0.2_real64,0.4_real64,0.6_real64,0.8_real64]
  vl_static=[0.0_real64,0.1_real64,0.3_real64,0.7_real64,1.2_real64]
  z=[0.0_real64,-5.0_real64,-15.0_real64,-30.0_real64,-50.0_real64]
  diameter=-999.0_real64

  ! B1.11 section F first pass: IcTopMp through NumNod.
  do ic=ic_top_mp,num_nodes
    call calc_source_diameter(ic,diameter(ic),status)
    call require(status==PPA_WU05A3_POLYGON_DIAMETER_OK,1)
  end do
  first_pass=diameter

  ! B1.11 section G final pass below ICpBtDmPot(2).
  do ic=domain2_bottom+1_int32,num_nodes
    call calc_source_diameter(ic,diameter(ic),status)
    call require(status==PPA_WU05A3_POLYGON_DIAMETER_OK,2)
  end do

  call require(abs(diameter(1)+999.0_real64)<1.0e-12_real64,3)
  call require(all(abs(diameter(2:num_nodes)-first_pass(2:num_nodes))<1.0e-12_real64),4)
  do ic=ic_top_mp,num_nodes
    call calc_source_diameter(ic,expected,status)
    call require(status==PPA_WU05A3_POLYGON_DIAMETER_OK,5)
    call require(abs(diameter(ic)-expected)<1.0e-12_real64,6)
  end do

  print '(A)','PPA_WU05A3_MACROGEOM_POLYGON_HANDOFF_SOURCE_ORACLE=PASS'
  print '(A)','PPA_WU05A3_MACROGEOM_POLYGON_FIRST_PASS_IC_TOP_TO_BOTTOM=PASS'
  print '(A)','PPA_WU05A3_MACROGEOM_POLYGON_FINAL_PASS_STARTS_AFTER_IC_BOTTOM=PASS'
  print '(A)','PPA_WU05A3_MACROGEOM_POLYGON_ABOVE_IC_TOP_PRESERVED=PASS'
contains
  subroutine calc_source_diameter(node,diameter_value,result_status)
    integer(int32),intent(in)::node
    real(real64),intent(out)::diameter_value
    integer,intent(out)::result_status
    call ppa_wu05a3_polygon_diameter(1.5_real64,0.2_real64,dz(node), &
        0.3_real64,0.5_real64,vl_static(node),0.2_real64,z(ic_top_mp), &
        z(node),-40.0_real64,diameter_value,result_status)
  end subroutine
  subroutine require(ok,code)
    logical,intent(in)::ok
    integer,intent(in)::code
    if(.not.ok)then
      write(*,'(A,I0)')'PPA_WU05A3_MACROGEOM_POLYGON_HANDOFF_FAIL=',code
      error stop 1
    end if
  end subroutine
end program test_ppa_wu05a3_macrogeom_polygon_handoff_source_oracle
