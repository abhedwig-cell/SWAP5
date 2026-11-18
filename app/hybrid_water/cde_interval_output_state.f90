module hybrid_original_cde_output_state
  use iso_fortran_env,only:int64
  use ieee_arithmetic,only:ieee_is_finite
  use MOD_grid,only:numnod
  use MOD_solute,only:samini,sqprec,sqirrig,sqbot,dectot,rottot,sqdra, &
    imsqbot,imsqdra,imsqirrig,imsqprec,imdectot,imrottot,sbaldev,sdstor, &
    isqtop,isqbot,imqsol
  use MOD_swap_base,only:swmacro,swsolu
  use MOD_solute,only:sampro,hybrid_cde_interval_get,hybrid_cde_interval_set
  implicit none
  private
  real(8),allocatable,save::pending(:)
  logical,save::restore_pending=.false.
  public::hybrid_cde_output_checkpoint,hybrid_cde_output_apply
contains
  subroutine pack(values)
    real(8),intent(out)::values(20+numnod)
    real(8)::actual_private(2)
    call hybrid_cde_interval_get(actual_private)
    values=[samini,sqprec,sqirrig,sqbot,dectot,rottot,sqdra, &
      imsqbot,imsqdra,imsqirrig,imsqprec,imdectot,imrottot,sbaldev,sdstor, &
      isqtop,isqbot,imqsol(1:numnod+1),actual_private]
  end subroutine

  subroutine hybrid_cde_output_checkpoint(unit,restoring)
    integer,intent(in)::unit
    logical,intent(in)::restoring
    integer::header(3),witness_header(3),ios,n
    real(8),allocatable::values(:),witness(:)
    if(numnod<1.or.swmacro/=0.or.swsolu/=1)error stop 'Invalid original CDE interval domain'
    n=20+numnod
    allocate(values(n),witness(n))
    if(restoring)then
      if(restore_pending)error stop 'Original CDE output restore already pending'
      read(unit,iostat=ios)header,witness_header
      if(ios/=0)error stop 'Incomplete original CDE output header'
      if(any(header/=[2,numnod,n]).or.any(header/=witness_header))error stop 'Foreign original CDE output shape/witness'
      read(unit,iostat=ios)values,witness
      if(ios/=0)error stop 'Incomplete original CDE output values'
      if(.not.all(ieee_is_finite(values)))error stop 'Nonfinite original CDE output values'
      if(any(transfer(values,0_int64,n)/=transfer(witness,0_int64,n)))error stop 'Original CDE output witness mismatch'
      if(values(1)<0d0.or.values(n-1)<0d0)error stop 'Negative original CDE interval stock anchor'
      if(allocated(pending))deallocate(pending)
      call move_alloc(values,pending)
      restore_pending=.true.
    else
      if(restore_pending)error stop 'Cannot publish pending original CDE output restore'
      call pack(values)
      if(.not.all(ieee_is_finite(values)))error stop 'Nonfinite original CDE interval publication'
      if(values(1)<0d0.or.values(n-1)<0d0)error stop 'Negative original CDE interval publication'
      header=[2,numnod,n]
      write(unit)header,header,values,values
    end if
  end subroutine

  subroutine hybrid_cde_output_apply()
    if(.not.restore_pending)return
    if(.not.allocated(pending))error stop 'Missing pending original CDE output values'
    if(size(pending)/=20+numnod)error stop 'Changed pending original CDE output shape'
    if(sampro-pending(19+numnod)/=pending(15))error stop 'Inconsistent actual CDE interval stock anchor'
    samini=pending(1);sqprec=pending(2);sqirrig=pending(3);sqbot=pending(4)
    dectot=pending(5);rottot=pending(6);sqdra=pending(7)
    imsqbot=pending(8);imsqdra=pending(9);imsqirrig=pending(10);imsqprec=pending(11)
    imdectot=pending(12);imrottot=pending(13);sbaldev=pending(14);sdstor=pending(15)
    isqtop=pending(16);isqbot=pending(17);imqsol(1:numnod+1)=pending(18:18+numnod)
    call hybrid_cde_interval_set(pending(19+numnod:20+numnod))
    restore_pending=.false.
    deallocate(pending)
  end subroutine
end module
