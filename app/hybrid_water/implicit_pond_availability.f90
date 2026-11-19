module hybrid_implicit_pond_availability
  use, intrinsic::ieee_arithmetic,only:ieee_is_finite
  implicit none
  private
  public::close_implicit_pond_evaporation
contains
  subroutine close_implicit_pond_evaporation(step,old_pond,new_pond,evaporation,deficit,cap,changed)
    real(8),intent(in)::step,old_pond,new_pond,evaporation,deficit
    real(8),intent(inout)::cap
    logical,intent(out)::changed
    real(8)::available
    changed=.false.
    if(.not.all(ieee_is_finite([step,old_pond,new_pond,evaporation,deficit,cap]))) &
      error stop 'Nonfinite original implicit pond availability'
    if(step<=0d0.or.min(old_pond,new_pond,evaporation,cap)<0d0) &
      error stop 'Invalid original implicit pond availability'
    if(old_pond<=1d-10.or.new_pond/=0d0.or.deficit<=1d-10.or.evaporation==0d0)return
    available=evaporation-deficit/step
    ! An evaporation cap cannot repair a deficit requiring negative evaporation.
    if(available<0d0.or.available>=min(cap,evaporation))return
    cap=available;changed=.true.
  end subroutine
end module
