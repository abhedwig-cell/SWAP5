module hybrid_output_aquifer_domain
  use MOD_grid,only:numnod
  use MOD_swap_base,only:swmacro,swsolu,swhyst,swdra
  use MOD_solute,only:hybrid_aquifer_output_selector
  implicit none
  private
  public::hybrid_output_aquifer_checkpoint
contains
  subroutine hybrid_output_aquifer_checkpoint(unit,restoring)
    integer,intent(in)::unit
    logical,intent(in)::restoring
    integer::header(7),witness(7),expected(7),actual_swbr,ios
    call hybrid_aquifer_output_selector(actual_swbr)
    if(numnod<1.or.swmacro/=0.or.swsolu/=1.or.actual_swbr/=1.or.swdra/=1.or. &
       swhyst<0.or.swhyst>2)error stop 'Invalid original aquifer output domain'
    expected=[1,numnod,swmacro,swsolu,actual_swbr,swhyst,swdra]
    if(restoring)then
      read(unit,iostat=ios)header,witness
      if(ios/=0)error stop 'Incomplete original aquifer output domain'
      if(any(header/=expected).or.any(witness/=expected))error stop 'Foreign original aquifer output domain/witness'
    else
      write(unit)expected,expected
    end if
  end subroutine
end module
