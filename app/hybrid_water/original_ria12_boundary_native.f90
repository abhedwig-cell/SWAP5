module hybrid_original_ria12_boundary
  use MOD_grid,only:numnod,numlay
  use MOD_swap_base,only:swmacro,swsolu,swsnow,swfrost,swhyst,swdra,swhea,swcalt
  use MOD_MvG,only:iHWCKmodel,swsophy
  use variables,only:swkimpl,swbotb
  use DoublePrec,only:dp
  use SHPvariables,only:nLayer,SWRCpars,UHCCpars,HeatOn
  use KVapor,only:VaporCond
  use,intrinsic::ieee_arithmetic,only:ieee_is_finite
  implicit none
  private
  public::ria12_boundary_checkpoint
contains
  subroutine ria12_boundary_checkpoint(unit,restoring)
    integer,intent(in)::unit
    logical,intent(in)::restoring
    integer,allocatable::expected(:),header(:),witness(:)
    real(dp),allocatable::parameters(:,:),parameter_header(:,:),parameter_witness(:,:)
    integer::n,ios
    if(numnod<1.or.numlay<1.or.numlay>size(iHWCKmodel).or.swmacro/=0.or.swsolu<0.or.swsolu>1.or. &
       swsnow/=0.or.swfrost/=0.or.swhyst/=0.or.(swdra<0.or.swdra>1).or.swhea/=0.or.swcalt/=0.or. &
       swsophy/=0.or.swkimpl/=0.or.(swbotb/=5.and.swbotb/=6.and.swbotb/=8).or.(swdra==1.and.swbotb==6).or.HeatOn.or.VaporCond) &
       error stop 'Foreign original RIA12 native domain'
    if(any(iHWCKmodel(1:numlay)/=12).or.nLayer/=numlay) &
       error stop 'Foreign original RIA12 native constitutive models'
    if(.not.allocated(SWRCpars).or..not.allocated(UHCCpars))error stop 'Missing original RIA12 constitutive parameters'
    if(size(SWRCpars,1)/=numlay.or.size(SWRCpars,2)/=5.or. &
       size(UHCCpars,1)/=numlay.or.size(UHCCpars,2)/=6)error stop 'Foreign original RIA12 parameter shape'
    n=9+numlay
    allocate(expected(n),header(n),witness(n))
    allocate(parameters(11,numlay),parameter_header(11,numlay),parameter_witness(11,numlay))
    expected(1:9)=[1,numnod,numlay,swsolu,swbotb,swdra,swhea,swcalt,storage_size(0.0_dp)/8]
    expected(10:n)=iHWCKmodel(1:numlay)
    parameters(1:5,:)=transpose(SWRCpars)
    parameters(6:11,:)=transpose(UHCCpars)
    if(.not.all(ieee_is_finite(parameters)))error stop 'Nonfinite original RIA12 constitutive parameters'
    if(restoring)then
      read(unit,iostat=ios)parameter_header,parameter_witness,header,witness
      if(ios/=0)error stop 'Incomplete original RIA12 native constitutive domain'
      if(.not.all(ieee_is_finite(parameter_header)).or..not.all(ieee_is_finite(parameter_witness))) &
         error stop 'Nonfinite original RIA12 native parameter witness'
      if(any(header/=expected).or.any(witness/=expected))error stop 'Foreign original RIA12 native model witness'
      if(any(parameter_header/=parameters).or.any(parameter_witness/=parameters)) &
         error stop 'Foreign original RIA12 native parameter witness'
    else
      write(unit)parameters,parameters,expected,expected
    end if
  end subroutine
end module
