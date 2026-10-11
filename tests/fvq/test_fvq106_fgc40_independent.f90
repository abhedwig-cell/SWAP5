program test_fvq106_fgc40_independent
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_groundwater_multiswap_types, only: groundwater_direct_tile_binding_t
  use mod_modflow6_swap_predictor_response, only: modflow6_swap_predictor_response_t, MODFLOW6_PREDICTOR_OK
  use mod_modflow6_multiswap_cell_response, only: modflow6_multiswap_cell_response_t, &
    compose_modflow6_multiswap_cell_response, evaluate_modflow6_multiswap_cell_response, &
    MODFLOW6_MULTI_CELL_OK, MODFLOW6_MULTI_CELL_WRONG_CELL, MODFLOW6_MULTI_CELL_ORIGIN_MISMATCH, &
    MODFLOW6_MULTI_CELL_DUPLICATE_SWAP_LINEAGE, MODFLOW6_MULTI_CELL_FRACTION_SUM
  implicit none
  integer :: failures
  failures=0
  call direct_oracle(failures)
  call permutation_oracle(failures)
  call negative_oracle(failures)
  if(failures/=0) error stop 1
  write(*,'(A)') 'FVQ106_THREE_TILE_DIRECT_SUM_ORACLE=PASS'
  write(*,'(A)') 'FVQ106_MULTIHEAD_AFFINE_ORACLE=PASS'
  write(*,'(A)') 'FVQ106_ALL_SIX_PERMUTATIONS=PASS'
  write(*,'(A)') 'FVQ106_CENTERED_HEAD_SLOPE_ORACLE=PASS'
  write(*,'(A)') 'FVQ106_PROVENANCE_NEGATIVE_ORACLE=PASS'
  write(*,'(A)') 'FVQ106_INDEPENDENT_CELL_RESPONSE_GATE=PASS'
contains
  subroutine direct_oracle(f)
    integer,intent(inout)::f
    type(groundwater_direct_tile_binding_t)::b(3)
    type(modflow6_swap_predictor_response_t)::r(3)
    type(modflow6_multiswap_cell_response_t)::c
    real(real64),parameter::hs(3)=[0.8_real64,1.0_real64,1.25_real64]
    real(real64)::q,qp,qm,fd
    integer::i,s
    call fixtures(b,r)
    call compose_modflow6_multiswap_cell_response(b,r,1.0_real64,c,s)
    call req(s==MODFLOW6_MULTI_CELL_OK.and.c%valid,'compose',f)
    call close(c%q_u_at_reference_m_per_s,direct_sum(b,r,1.0_real64),2e-18_real64,'href',f)
    do i=1,3
      call evaluate_modflow6_multiswap_cell_response(c,hs(i),q,s)
      call req(s==MODFLOW6_MULTI_CELL_OK,'eval',f)
      call close(q,direct_sum(b,r,hs(i)),2e-18_real64,'multihead',f)
    end do
    call evaluate_modflow6_multiswap_cell_response(c,1.0701_real64,qp,s)
    call evaluate_modflow6_multiswap_cell_response(c,1.0699_real64,qm,s)
    fd=(qp-qm)/(2e-4_real64)
    call close(fd,c%dq_u_dh_per_s,2e-15_real64,'slope',f)
  end subroutine

  subroutine permutation_oracle(f)
    integer,intent(inout)::f
    integer,parameter::p(3,6)=reshape([1,2,3,1,3,2,2,1,3,2,3,1,3,1,2,3,2,1],[3,6])
    type(groundwater_direct_tile_binding_t)::baseb(3),b(3)
    type(modflow6_swap_predictor_response_t)::baser(3),r(3)
    type(modflow6_multiswap_cell_response_t)::ref,c
    integer(int64)::qb,ub,sb
    integer::j,k,s
    call fixtures(baseb,baser)
    call compose_modflow6_multiswap_cell_response(baseb,baser,1.0_real64,ref,s)
    qb=transfer(ref%q_u_at_reference_m_per_s,qb)
    ub=transfer(ref%coupling_storage_coefficient_u,ub)
    sb=transfer(ref%dq_u_dh_per_s,sb)
    do j=1,6
      do k=1,3
        b(k)=baseb(p(k,j)); r(k)=baser(p(k,j))
      end do
      call compose_modflow6_multiswap_cell_response(b,r,1.0_real64,c,s)
      call req(s==MODFLOW6_MULTI_CELL_OK,'perm status',f)
      call req(transfer(c%q_u_at_reference_m_per_s,qb)==qb,'perm q',f)
      call req(transfer(c%coupling_storage_coefficient_u,ub)==ub,'perm u',f)
      call req(transfer(c%dq_u_dh_per_s,sb)==sb,'perm slope',f)
      call req(c%tiles(1)%binding%tile_id==10_int64.and.c%tiles(2)%binding%tile_id==20_int64.and. &
        c%tiles(3)%binding%tile_id==30_int64,'perm provenance',f)
    end do
  end subroutine

  subroutine negative_oracle(f)
    integer,intent(inout)::f
    type(groundwater_direct_tile_binding_t)::b(3),bb(3)
    type(modflow6_swap_predictor_response_t)::r(3),rr(3)
    type(modflow6_multiswap_cell_response_t)::c
    integer::s
    call fixtures(b,r)
    bb=b; bb(2)%groundwater_cell_id=9902_int64
    call compose_modflow6_multiswap_cell_response(bb,r,1.0_real64,c,s)
    call req(s==MODFLOW6_MULTI_CELL_WRONG_CELL.and..not.c%valid,'cell provenance',f)
    bb=b; bb(1)%area_fraction=0.21_real64
    call compose_modflow6_multiswap_cell_response(bb,r,1.0_real64,c,s)
    call req(s==MODFLOW6_MULTI_CELL_FRACTION_SUM.and..not.c%valid,'fraction',f)
    rr=r; rr(3)%lineage%groundwater_origin_revision=8_int64
    call compose_modflow6_multiswap_cell_response(b,rr,1.0_real64,c,s)
    call req(s==MODFLOW6_MULTI_CELL_ORIGIN_MISMATCH.and..not.c%valid,'origin',f)
    rr=r; rr(3)%lineage%swap_lineage_id=rr(1)%lineage%swap_lineage_id
    call compose_modflow6_multiswap_cell_response(b,rr,1.0_real64,c,s)
    call req(s==MODFLOW6_MULTI_CELL_DUPLICATE_SWAP_LINEAGE.and..not.c%valid,'lineage',f)
  end subroutine

  subroutine fixtures(b,r)
    type(groundwater_direct_tile_binding_t),intent(out)::b(3)
    type(modflow6_swap_predictor_response_t),intent(out)::r(3)
    integer::i
    b(1)%groundwater_cell_id=9901; b(1)%tile_id=30; b(1)%area_fraction=.50_real64
    b(2)%groundwater_cell_id=9901; b(2)%tile_id=10; b(2)%area_fraction=.20_real64
    b(3)%groundwater_cell_id=9901; b(3)%tile_id=20; b(3)%area_fraction=.30_real64
    do i=1,3
      r(i)%status=MODFLOW6_PREDICTOR_OK; r(i)%valid=.true.
      r(i)%window%t0=2._real64; r(i)%window%t1=2.25_real64
      r(i)%lineage%coupling_id=4001; r(i)%lineage%swap_lineage_id=5000+i
      r(i)%lineage%swap_origin_revision=6; r(i)%lineage%groundwater_service_id=6001
      r(i)%lineage%groundwater_lineage_id=6002; r(i)%lineage%groundwater_origin_revision=7
    end do
    r(1)%q_u_m_per_s=4e-7_real64; r(1)%coupling_storage_coefficient_u=-.2_real64; r(1)%h_bot_end_m=1.3_real64
    r(2)%q_u_m_per_s=2e-7_real64; r(2)%coupling_storage_coefficient_u=.1_real64; r(2)%h_bot_end_m=1.1_real64
    r(3)%q_u_m_per_s=-1e-7_real64; r(3)%coupling_storage_coefficient_u=.4_real64; r(3)%h_bot_end_m=.9_real64
  end subroutine

  pure real(real64) function direct_sum(b,r,h) result(q)
    type(groundwater_direct_tile_binding_t),intent(in)::b(:)
    type(modflow6_swap_predictor_response_t),intent(in)::r(:)
    real(real64),intent(in)::h
    real(real64)::dt
    integer::i
    dt=(r(1)%window%t1-r(1)%window%t0)*86400._real64; q=0
    do i=1,size(b)
      q=q+b(i)%area_fraction*(r(i)%q_u_m_per_s+(r(i)%coupling_storage_coefficient_u/dt)*(h-r(i)%h_bot_end_m))
    end do
  end function
  subroutine req(ok,msg,f)
    logical,intent(in)::ok; character(len=*),intent(in)::msg; integer,intent(inout)::f
    if(.not.ok)then; f=f+1; write(*,'(A)')'FVQ106_FAIL: '//trim(msg); end if
  end subroutine
  subroutine close(a,e,t,msg,f)
    real(real64),intent(in)::a,e,t; character(len=*),intent(in)::msg; integer,intent(inout)::f
    call req(abs(a-e)<=t,msg,f)
  end subroutine
end program
