program test_fvq108_fgc34_independent
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use, intrinsic :: iso_fortran_env, only: int32, int64, real64
  use mod_modflow6_linear_response_backend, only: modflow6_linear_boundary_term_t, MODFLOW6_LINEAR_BACKEND_OK
  use mod_modflow6_api_binding, only: modflow6_api_slot_binding_t, publish_modflow6_api_terms, &
       MODFLOW6_API_BINDING_OK, MODFLOW6_API_BINDING_INVALID_PACKAGE, MODFLOW6_API_BINDING_INVALID_BINDING, &
       MODFLOW6_API_BINDING_DUPLICATE_BINDING, MODFLOW6_API_BINDING_TERM_MATCH, MODFLOW6_API_BINDING_NONFINITE_TERM
  implicit none

  integer :: failures
  failures=0

  call permutation_shadow_oracle(failures)
  call atomic_rejection_oracle(failures)

  if(failures/=0) then
    write(*,'(A,I0)') 'FVQ108_FAILURE_COUNT=',failures
    error stop 1
  end if

  write(*,'(A)') 'FVQ108_THREE_BINDING_PERMUTATION_ORACLE=PASS'
  write(*,'(A)') 'FVQ108_EXPLICIT_IDENTITY_SHADOW_ORACLE=PASS'
  write(*,'(A)') 'FVQ108_N_TO_1_NODE_PRESERVATION=PASS'
  write(*,'(A)') 'FVQ108_ACTIVE_PREFIX_AND_TAIL_ORACLE=PASS'
  write(*,'(A)') 'FVQ108_ATOMIC_REJECTION_ORACLE=PASS'
  write(*,'(A)') 'FVQ108_INDEPENDENT_API_BINDING_GATE=PASS'

contains

  subroutine permutation_shadow_oracle(f)
    integer,intent(inout)::f
    type(modflow6_api_slot_binding_t)::b(3)
    type(modflow6_linear_boundary_term_t)::t(3)
    integer(int32)::nodes(5),nbound
    real(real64)::hcof(5),rhs(5)
    integer::status

    call fixture(b,t)
    nodes=[-101_int32,-102_int32,-103_int32,-104_int32,-105_int32]
    hcof=[-1.0_real64,-2.0_real64,-3.0_real64,-4.0_real64,-5.0_real64]
    rhs=[-11.0_real64,-12.0_real64,-13.0_real64,-14.0_real64,-15.0_real64]
    nbound=5_int32

    call publish_modflow6_api_terms(b,t,5_int32,nodes,hcof,rhs,nbound,status)
    call req(status==MODFLOW6_API_BINDING_OK,'valid publication rejected',f)
    call req(nbound==3_int32,'nbound not active prefix length',f)

    ! Shadow oracle is written from the explicit binding relation, not caller order.
    call req(nodes(1)==52_int32,'slot1 node',f)
    call close(hcof(1),220.0_real64,'slot1 hcof',f)
    call close(rhs(1),-22.0_real64,'slot1 rhs',f)

    call req(nodes(2)==51_int32,'slot2 node',f)
    call close(hcof(2),330.0_real64,'slot2 hcof',f)
    call close(rhs(2),33.0_real64,'slot2 rhs',f)

    call req(nodes(3)==51_int32,'slot3 node',f)
    call close(hcof(3),110.0_real64,'slot3 hcof',f)
    call close(rhs(3),11.0_real64,'slot3 rhs',f)

    call req(nodes(4)==-104_int32.and.nodes(5)==-105_int32,'node tail changed',f)
    call close(hcof(4),-4.0_real64,'hcof tail4',f)
    call close(hcof(5),-5.0_real64,'hcof tail5',f)
    call close(rhs(4),-14.0_real64,'rhs tail4',f)
    call close(rhs(5),-15.0_real64,'rhs tail5',f)

    call req(b(1)%groundwater_cell_id/=b(3)%groundwater_cell_id,'distinct coupling ids fixture',f)
    call req(b(1)%modflow_node_id==b(3)%modflow_node_id,'n:1 node fixture',f)
  end subroutine

  subroutine atomic_rejection_oracle(f)
    integer,intent(inout)::f
    type(modflow6_api_slot_binding_t)::b(3),badb(3)
    type(modflow6_linear_boundary_term_t)::t(3),badt(3)
    real(real64)::nanv
    call fixture(b,t)
    nanv=ieee_value(0.0_real64,ieee_quiet_nan)

    badb=b
    badb(1)%package_slot=4
    call rejected_unchanged(badb,t,5_int32,MODFLOW6_API_BINDING_INVALID_BINDING,'gap/out-of-prefix',f)

    badb=b
    badb(3)%groundwater_cell_id=badb(1)%groundwater_cell_id
    call rejected_unchanged(badb,t,5_int32,MODFLOW6_API_BINDING_DUPLICATE_BINDING,'duplicate coupling id',f)

    badt=t
    badt(2)%groundwater_cell_id=99999_int64
    call rejected_unchanged(b,badt,5_int32,MODFLOW6_API_BINDING_TERM_MATCH,'missing exact term',f)

    badt=t
    badt(1)%rhs_m3_per_day=nanv
    call rejected_unchanged(b,badt,5_int32,MODFLOW6_API_BINDING_NONFINITE_TERM,'nan rhs',f)

    call rejected_small_arrays(b,t,f)
  end subroutine

  subroutine rejected_unchanged(b,t,maxbound,expected,label,f)
    type(modflow6_api_slot_binding_t),intent(in)::b(:)
    type(modflow6_linear_boundary_term_t),intent(in)::t(:)
    integer(int32),intent(in)::maxbound
    integer,intent(in)::expected
    character(len=*),intent(in)::label
    integer,intent(inout)::f
    integer(int32)::nodes(5),before_nodes(5),nbound,before_nbound
    real(real64)::hcof(5),before_hcof(5),rhs(5),before_rhs(5)
    integer::status

    nodes=[101_int32,102_int32,103_int32,104_int32,105_int32]
    hcof=[1.0_real64,2.0_real64,3.0_real64,4.0_real64,5.0_real64]
    rhs=[11.0_real64,12.0_real64,13.0_real64,14.0_real64,15.0_real64]
    nbound=4_int32
    before_nodes=nodes; before_hcof=hcof; before_rhs=rhs; before_nbound=nbound

    call publish_modflow6_api_terms(b,t,maxbound,nodes,hcof,rhs,nbound,status)
    call req(status==expected,trim(label)//': status',f)
    call req(all(nodes==before_nodes),trim(label)//': nodes mutated',f)
    call req(all(hcof==before_hcof),trim(label)//': hcof mutated',f)
    call req(all(rhs==before_rhs),trim(label)//': rhs mutated',f)
    call req(nbound==before_nbound,trim(label)//': nbound mutated',f)
  end subroutine

  subroutine rejected_small_arrays(b,t,f)
    type(modflow6_api_slot_binding_t),intent(in)::b(:)
    type(modflow6_linear_boundary_term_t),intent(in)::t(:)
    integer,intent(inout)::f
    integer(int32)::nodes(2),before_nodes(2),nbound,before_nbound
    real(real64)::hcof(2),before_hcof(2),rhs(2),before_rhs(2)
    integer::status
    nodes=[7_int32,8_int32]; hcof=[7.0_real64,8.0_real64]; rhs=[17.0_real64,18.0_real64]; nbound=2_int32
    before_nodes=nodes; before_hcof=hcof; before_rhs=rhs; before_nbound=nbound
    call publish_modflow6_api_terms(b,t,3_int32,nodes,hcof,rhs,nbound,status)
    call req(status==MODFLOW6_API_BINDING_INVALID_PACKAGE,'small arrays status',f)
    call req(all(nodes==before_nodes).and.all(hcof==before_hcof).and.all(rhs==before_rhs).and.nbound==before_nbound, &
         'small arrays mutated',f)
  end subroutine

  subroutine fixture(b,t)
    type(modflow6_api_slot_binding_t),intent(out)::b(3)
    type(modflow6_linear_boundary_term_t),intent(out)::t(3)

    ! Caller order intentionally differs from package-slot order.
    b(1)%groundwater_cell_id=9101_int64; b(1)%package_slot=3; b(1)%modflow_node_id=51_int32
    b(2)%groundwater_cell_id=9202_int64; b(2)%package_slot=1; b(2)%modflow_node_id=52_int32
    b(3)%groundwater_cell_id=9303_int64; b(3)%package_slot=2; b(3)%modflow_node_id=51_int32

    t=modflow6_linear_boundary_term_t()
    ! Term order is a different permutation again.
    t(1)%valid=.true.; t(1)%status=MODFLOW6_LINEAR_BACKEND_OK; t(1)%groundwater_cell_id=9303_int64
    t(1)%hcof_m2_per_day=330.0_real64; t(1)%rhs_m3_per_day=33.0_real64
    t(2)%valid=.true.; t(2)%status=MODFLOW6_LINEAR_BACKEND_OK; t(2)%groundwater_cell_id=9101_int64
    t(2)%hcof_m2_per_day=110.0_real64; t(2)%rhs_m3_per_day=11.0_real64
    t(3)%valid=.true.; t(3)%status=MODFLOW6_LINEAR_BACKEND_OK; t(3)%groundwater_cell_id=9202_int64
    t(3)%hcof_m2_per_day=220.0_real64; t(3)%rhs_m3_per_day=-22.0_real64
  end subroutine

  subroutine req(ok,msg,f)
    logical,intent(in)::ok
    character(len=*),intent(in)::msg
    integer,intent(inout)::f
    if(.not.ok)then
      f=f+1
      write(*,'(A)') 'FVQ108_FAIL: '//trim(msg)
    end if
  end subroutine

  subroutine close(a,e,msg,f)
    real(real64),intent(in)::a,e
    character(len=*),intent(in)::msg
    integer,intent(inout)::f
    call req(abs(a-e)<=1e-12_real64,msg,f)
  end subroutine
end program
