module hybrid_output_thermal_domain
  use MOD_grid,only:numnod
  use MOD_swap_base,only:swmacro,swsolu,swhyst,swsnow,swfrost,swdra,swhea,swcalt
  implicit none
  private
  public::hybrid_output_thermal_checkpoint
contains
  subroutine hybrid_output_thermal_checkpoint(unit,restoring)
    integer,intent(in)::unit
    logical,intent(in)::restoring
    integer::expected(10),header(10),witness(10),ios
    if(numnod<1.or.swmacro/=0.or.swsolu<0.or.swsolu>1.or.swhyst<0.or.swhyst>2.or. &
       swsnow/=1.or.swhea/=1.or.swcalt/=2.or.swfrost<0.or.swfrost>1.or.swdra<0.or.swdra>1) &
      error stop 'Invalid original thermal output domain'
    expected=[1,numnod,swmacro,swsolu,swhyst,swsnow,swfrost,swdra,swhea,swcalt]
    if(restoring)then
      read(unit,iostat=ios)header,witness
      if(ios/=0)error stop 'Incomplete original thermal output domain'
      if(any(header/=witness).or.any(header/=expected)) &
        error stop 'Foreign original thermal output domain/witness'
    else
      write(unit)expected,expected
    end if
  end subroutine
end module
