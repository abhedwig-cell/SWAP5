module hybrid_output_hysteresis_domain
  use MOD_grid,only:numnod
  use MOD_swap_base,only:swmacro,swhyst,swsolu
  implicit none
  private
  public::hybrid_output_hysteresis_checkpoint
contains
  subroutine hybrid_output_hysteresis_checkpoint(unit,restoring)
    integer,intent(in)::unit
    logical,intent(in)::restoring
    integer::expected(5),header(5),witness(5),ios
    if(numnod<1.or.swmacro/=0.or.swhyst<1.or.swhyst>2.or.swsolu<0.or.swsolu>2) &
      error stop 'Invalid original output hysteresis domain'
    expected=[1,numnod,swmacro,swhyst,swsolu]
    if(restoring)then
      read(unit,iostat=ios)header,witness
      if(ios/=0)error stop 'Incomplete original output hysteresis domain'
      if(any(header/=witness).or.any(header/=expected)) &
        error stop 'Foreign original output hysteresis domain/witness'
    else
      write(unit)expected,expected
    end if
  end subroutine
end module
