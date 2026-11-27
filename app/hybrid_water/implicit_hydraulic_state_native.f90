module implicit_hydraulic_state_native
  use MOD_grid,only:numnod,numlay
  use MOD_swap_base,only:swmacro,swsolu,swsnow,swfrost,swhyst,swdra,swhea,swcalt
  use MOD_MvG,only:iHWCKmodel,swsophy
  use MOD_drain,only:swdivd
  use WC_K_models_04_11,only:NoVap
  use variables,only:swkimpl,swbotb
  implicit none
  private
  public::implicit_hydraulic_checkpoint
contains
  subroutine implicit_hydraulic_checkpoint(unit,restoring)
    integer,intent(in)::unit
    logical,intent(in)::restoring
    integer,allocatable::expected(:),header(:),witness(:)
    integer::n,ios,i
    character(len=8)::tag
    if(numnod<1.or.numlay<1.or.numlay>size(iHWCKmodel).or.swmacro/=0.or.swsolu<0.or.swsolu>1.or. &
       (swsnow/=0.and.swsnow/=1).or.swfrost/=0.or.swhyst/=0.or.swdra/=1.or.swhea/=1.or.swcalt/=2.or. &
       swsophy/=0.or.swkimpl/=1.or.(swbotb/=5.and.swbotb/=8))error stop 'Foreign implicit hydraulic native domain'
    if(swdivd<0.or.swdivd>1)error stop 'Foreign implicit hydraulic drainage partition'
    if(swsolu==1.and.swdivd==0)error stop 'Invalid original solute drainage partition'
    if(any(iHWCKmodel(1:numlay)<1).or.any(iHWCKmodel(1:numlay)>11).or.all(iHWCKmodel(1:numlay)==1)) &
       error stop 'Foreign implicit hydraulic constitutive models'
    do i=1,numlay
      if(iHWCKmodel(i)>=8)then
        if(.not.NoVap(i))error stop 'Active vapor cannot use implicit hydraulic native extension'
      end if
    end do
    n=13+numlay;allocate(expected(n),header(n),witness(n))
    expected(1:13)=[1,numnod,numlay,swsolu,swkimpl,swhyst,swsnow,swfrost,swhea,swcalt,swdra,swbotb,swdivd]
    expected(14:n)=iHWCKmodel(1:numlay)
    if(restoring)then
      read(unit,iostat=ios)tag,header,witness
      if(ios/=0)error stop 'Incomplete implicit hydraulic native extension'
      if(tag/='S5IHX001')error stop 'Foreign implicit hydraulic native extension tag'
      if(any(header/=expected).or.any(witness/=expected))error stop 'Foreign implicit hydraulic native witness'
    else
      write(unit)'S5IHX001',expected,expected
    end if
  end subroutine
end module
