module hybrid_frost_analytical_native
  use MOD_grid,only:numnod,numlay
  use MOD_swap_base,only:swmacro,swsolu,swsnow,swfrost,swhyst,swdra,swhea,swcalt
  use MOD_MvG,only:iHWCKmodel,swsophy
  use WC_K_models_04_11,only:NoVap
  use variables,only:swkimpl,swbotb
  implicit none
  private
  public::frost_analytical_domain_checkpoint
contains
  subroutine frost_analytical_domain_checkpoint(unit,restoring)
    integer,intent(in)::unit
    logical,intent(in)::restoring
    integer,allocatable::expected(:),header(:),witness(:)
    integer::n,ios
    if(numnod<1.or.numlay<1.or.numlay>size(iHWCKmodel).or.swmacro/=0.or.swsolu<0.or.swsolu>1.or. &
       swsnow/=1.or.swfrost/=1.or.swhyst/=0.or.swdra/=0.or.swhea/=1.or.swcalt/=2.or. &
       swsophy/=0.or.swkimpl/=0.or.swbotb/=5)error stop 'Foreign analytical Frost native domain'
    if(any(iHWCKmodel(1:numlay)<1).or.any(iHWCKmodel(1:numlay)>11).or. &
       any(iHWCKmodel(1:numlay)==2).or.all(iHWCKmodel(1:numlay)==1)) &
       error stop 'Foreign analytical Frost native constitutive models'
    if(any((iHWCKmodel(1:numlay)>=8).and.(.not.NoVap(1:numlay)))) &
       error stop 'Active vapor cannot use analytical Frost native'
    n=5+numlay;allocate(expected(n),header(n),witness(n))
    expected(1:5)=[2,numnod,numlay,swsolu,swbotb]
    expected(6:n)=iHWCKmodel(1:numlay)
    if(restoring)then
      read(unit,iostat=ios)header,witness
      if(ios/=0)error stop 'Incomplete analytical Frost native model domain'
      if(any(header/=expected).or.any(witness/=expected)) &
        error stop 'Foreign analytical Frost native model witness'
    else
      write(unit)expected,expected
    end if
  end subroutine
end module
