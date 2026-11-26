module hybrid_frost_analytical_boundary_native
  use MOD_grid,only:numnod,numlay
  use MOD_swap_base,only:swmacro,swsolu,swsnow,swfrost,swhyst,swdra,swhea,swcalt
  use MOD_MvG,only:iHWCKmodel,swsophy
  use MOD_drain,only:swdivd
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
    integer::n,ios,i,partition_active
    if(numnod<1.or.numlay<1.or.numlay>size(iHWCKmodel).or.swmacro/=0.or.swsolu<0.or.swsolu>1.or. &
       swsnow/=1.or.swfrost/=1.or.swhyst/=0.or.(swdra/=0.and.swdra/=1).or.swhea/=1.or.swcalt/=2.or. &
       swsophy/=0.or.swkimpl/=0.or.swbotb/=5)error stop 'Foreign analytical Frost boundary native domain'
    partition_active=0
    if(swdra==1)then
      if(swdivd/=1)error stop 'Foreign original analytical Frost drainage partition'
      partition_active=1
    else
      if(swbotb/=6)error stop 'Foreign drainage-off analytical Frost boundary'
    end if
    if(any(iHWCKmodel(1:numlay)<1).or.any(iHWCKmodel(1:numlay)>11).or. &
       any(iHWCKmodel(1:numlay)==2))error stop 'Foreign analytical Frost boundary constitutive models'
    if(all(iHWCKmodel(1:numlay)==1))then
      if(swdra/=0.or.swbotb/=6)error stop 'Foreign original model1 Frost boundary owner'
    end if
    do i=1,numlay
      if(iHWCKmodel(i)>=8)then
        if(.not.NoVap(i))error stop 'Active vapor cannot use analytical Frost boundary native'
      end if
    end do
    n=7+numlay;allocate(expected(n),header(n),witness(n))
    expected(1:7)=[3,numnod,numlay,swsolu,swbotb,swdra,partition_active]
    expected(8:n)=iHWCKmodel(1:numlay)
    if(restoring)then
      read(unit,iostat=ios)header,witness
      if(ios/=0)error stop 'Incomplete analytical Frost boundary native model domain'
      if(any(header/=expected).or.any(witness/=expected)) &
        error stop 'Foreign analytical Frost boundary native model witness'
    else
      write(unit)expected,expected
    end if
  end subroutine
end module
