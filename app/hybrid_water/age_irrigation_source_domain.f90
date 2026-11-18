module hybrid_age_irrigation_source_domain
  use,intrinsic::ieee_arithmetic,only:ieee_is_finite
  use MOD_grid,only:numnod
  use MOD_swap_base,only:swmacro,swsolu,swirfix,swhyst
  implicit none
  private
  public::hybrid_age_irrigation_source_assert,hybrid_age_irrigation_source_checkpoint
contains
  subroutine hybrid_age_irrigation_source_assert(age_day)
    real(8),intent(in)::age_day
    if(.not.ieee_is_finite(age_day))error stop 'Nonfinite original fixed irrigation age'
    if(age_day<0d0.or.age_day>1000d0)error stop 'Invalid original fixed irrigation age'
  end subroutine
  subroutine hybrid_age_irrigation_source_checkpoint(unit,restoring,layout)
    integer,intent(in)::unit,layout
    logical,intent(in)::restoring
    integer::header(7),witness(7),expected(7),ios
    if(numnod<1.or.swmacro/=0.or.swsolu/=2.or.swirfix/=1.or. &
       swhyst<0.or.swhyst>2.or.layout<2.or.layout>7) &
       error stop 'Invalid original irrigation age domain'
    expected=[1,numnod,swmacro,swsolu,swirfix,swhyst,layout]
    if(restoring)then
      read(unit,iostat=ios)header,witness
      if(ios/=0)error stop 'Incomplete original irrigation age domain'
      if(any(header/=expected).or.any(witness/=expected)) &
         error stop 'Foreign original irrigation age domain/witness'
    else
      write(unit)expected,expected
    end if
  end subroutine
end module hybrid_age_irrigation_source_domain
