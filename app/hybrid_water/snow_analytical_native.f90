module hybrid_snow_analytical_native
  use MOD_grid,only:numnod,numlay
  use MOD_swap_base,only:swmacro,swsolu,swsnow,swfrost,swhyst,swdra,swhea,swcalt
  use MOD_MvG,only:iHWCKmodel,swsophy
  use WC_K_models_04_11,only:NoVap
  use variables,only:swkimpl,swbotb
  implicit none
  private
  public::snow_analytical_domain_checkpoint
contains
  subroutine snow_analytical_domain_checkpoint(unit,restoring)
    integer,intent(in)::unit
    logical,intent(in)::restoring
    integer,allocatable::expected(:),header(:),witness(:)
    integer::n,ios
    if(numnod<1.or.numlay<1.or.numlay>size(iHWCKmodel).or.swmacro/=0.or.swsolu<0.or.swsolu>1.or. &
       swsnow/=1.or.swfrost/=0.or.swhyst/=0.or.swdra/=0.or.swhea/=1.or.swcalt/=2.or. &
       swsophy/=0.or.swkimpl/=0.or.swbotb/=9)error stop 'Foreign analytical Snow native domain'
    if(any(iHWCKmodel(1:numlay)<1).or.any(iHWCKmodel(1:numlay)>11).or. &
       any(iHWCKmodel(1:numlay)==2).or.all(iHWCKmodel(1:numlay)==1)) &
       error stop 'Foreign analytical Snow native constitutive models'
    if(any((iHWCKmodel(1:numlay)>=8).and.(.not.NoVap(1:numlay)))) &
       error stop 'Active vapor cannot use analytical Snow native'
    n=4+numlay;allocate(expected(n),header(n),witness(n))
    expected(1:4)=[1,numnod,numlay,swsolu]
    expected(5:n)=iHWCKmodel(1:numlay)
    if(restoring)then
      read(unit,iostat=ios)header,witness
      if(ios/=0)error stop 'Incomplete analytical Snow native model domain'
      if(any(header/=expected).or.any(witness/=expected)) &
        error stop 'Foreign analytical Snow native model witness'
    else
      write(unit)expected,expected
    end if
  end subroutine
end module
