program test_ppa_wu05a3_macroinit_crack_node_source_oracle
  use, intrinsic :: iso_fortran_env, only: real64, int32
  use mod_ppa_wu05a3_macroinit_crack_node
  implicit none
  real(real64) :: z(3),dz(3)
  integer(int32) :: node,status
  z=[-5.0_real64,-15.0_real64,-25.0_real64]
  dz=[10.0_real64,10.0_real64,10.0_real64]

  call ppa_wu05a3_macroinit_crack_node(3_int32,1_int32,z,dz,-15.0_real64,node,status)
  call require(status==PPA_WU05A3_CRACK_NODE_OK .and. node==2,1)
  call ppa_wu05a3_macroinit_crack_node(3_int32,1_int32,z,dz,-9.99_real64,node,status)
  call require(status==PPA_WU05A3_CRACK_NODE_OK .and. node==1,2)
  call ppa_wu05a3_macroinit_crack_node(3_int32,2_int32,z,dz,-500.0_real64,node,status)
  call require(status==PPA_WU05A3_CRACK_NODE_OK .and. node==2,3)
  call ppa_wu05a3_macroinit_crack_node(3_int32,1_int32,z,dz,-50.0_real64,node,status)
  call require(status==PPA_WU05A3_CRACK_NODE_INVALID .and. node==0,4)
  dz(2)=0.0_real64
  call ppa_wu05a3_macroinit_crack_node(3_int32,1_int32,z,dz,-15.0_real64,node,status)
  call require(status==PPA_WU05A3_CRACK_NODE_INVALID .and. node==0,5)

  print '(A)','PPA_WU05A3_MACROINIT_CRACK_NODE_SOURCE_ORACLE=PASS'
  print '(A)','PPA_WU05A3_MACROINIT_CRACK_NODE_STRICT_DEPTH_THRESHOLD=PASS'
  print '(A)','PPA_WU05A3_MACROINIT_CRACK_NODE_IC_TOP_BYPASS=PASS'
  print '(A)','PPA_WU05A3_MACROINIT_CRACK_NODE_OUTSIDE_GRID_FAIL_CLOSED=PASS'
  print '(A)','PPA_WU05A3_MACROINIT_CRACK_NODE_INVALID_GEOMETRY_FAIL_CLOSED=PASS'
contains
  subroutine require(ok,code)
    logical,intent(in)::ok
    integer,intent(in)::code
    if(.not.ok)then
      write(*,'(A,I0)')'PPA_WU05A3_MACROINIT_CRACK_NODE_FAIL=',code
      error stop 1
    end if
  end subroutine
end program test_ppa_wu05a3_macroinit_crack_node_source_oracle
