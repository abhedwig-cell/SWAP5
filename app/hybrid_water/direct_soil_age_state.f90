module hybrid_direct_soil_age_state
  use,intrinsic::ieee_arithmetic,only:ieee_is_finite
  use MOD_grid,only:numnod
  implicit none
  private
  real(8),save,public::direct_soil_age_input_total=0d0
  public::direct_soil_age_checkpoint
contains
  subroutine direct_soil_age_checkpoint(unit,restoring)
    integer,intent(in)::unit
    logical,intent(in)::restoring
    integer::header(2),witness(2),ios
    real(8)::pending
    if(numnod<1)error stop 'Invalid direct soil age node domain'
    if(restoring)then
      read(unit,iostat=ios)header,pending,witness
      if(ios/=0)error stop 'Incomplete direct soil age state'
      if(any(header/=[1,numnod]).or.any(witness/=header))error stop 'Foreign direct soil age state'
      if(.not.ieee_is_finite(pending))error stop 'Nonfinite direct soil age input'
      if(pending<0d0)error stop 'Negative direct soil age input'
      direct_soil_age_input_total=pending
    else
      if(.not.ieee_is_finite(direct_soil_age_input_total))error stop 'Nonfinite direct soil age input'
      if(direct_soil_age_input_total<0d0)error stop 'Negative direct soil age input'
      write(unit)[1,numnod],direct_soil_age_input_total,[1,numnod]
    end if
  end subroutine
end module
