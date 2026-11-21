module hydraulic_vapor_native
  use MOD_grid,only:numnod,numlay
  use MOD_swap_base,only:swmacro,swsolu,swsnow,swfrost,swhyst,swhea,swcalt,swdra
  use MOD_MvG,only:iHWCKmodel,swsophy
  use WC_K_models_04_11,only:NoVap
  use variables,only:swkimpl,swbotb
  implicit none
  private
  public::vapor_native_domain_checkpoint
contains
  subroutine vapor_native_domain_checkpoint(unit,restoring)
    integer,intent(in)::unit
    logical,intent(in)::restoring
    integer,allocatable::expected(:),header(:),witness(:)
    integer::ios,n
    if(numnod<1.or.numlay<1.or.numlay>size(iHWCKmodel).or.swmacro/=0.or.swsolu<0.or.swsolu>1.or. &
       swkimpl/=0.or.swsophy/=0.or.swsnow/=0.or.swfrost/=0.or.swhyst/=0.or.swhea/=1.or.swcalt/=2.or.swdra/=1.or.swbotb/=6) &
       error stop 'Invalid original vapor native3 domain'
    if(any(iHWCKmodel(1:numlay)<1).or.any(iHWCKmodel(1:numlay)>11).or. &
       .not.any((iHWCKmodel(1:numlay)>=8).and.(.not.NoVap(1:numlay)))) error stop 'Inactive or foreign vapor native3 layers'
    n=14+2*numlay;allocate(expected(n),header(n),witness(n))
    expected(1:14)=[3,numnod,numlay,swmacro,swsolu,swkimpl,swsophy,swsnow,swfrost,swhyst,swhea,swcalt,swdra,swbotb]
    expected(15:14+numlay)=iHWCKmodel(1:numlay)
    expected(15+numlay:n)=merge(0,1,NoVap(1:numlay))
    if(restoring)then
      read(unit,iostat=ios)header,witness
      if(ios/=0)error stop 'Incomplete original vapor native3 domain'
      if(any(header/=witness).or.any(header/=expected))error stop 'Foreign original vapor native3 domain witness'
    else
      write(unit)expected,expected
    end if
  end subroutine
end module
