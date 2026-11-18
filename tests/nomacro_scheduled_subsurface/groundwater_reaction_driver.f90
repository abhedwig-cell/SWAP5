program groundwater_reaction_driver
  use mod_prescribed_groundwater_reaction, only: prescribed_groundwater_reaction
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan, ieee_positive_inf
  implicit none
  real(8) :: dz(7), trial(7), previous(7), saturated(7), rates(7), bottom, delta, nan, inf
  integer :: status, checks
  checks=0
  nan=ieee_value(0d0,ieee_quiet_nan)
  inf=ieee_value(0d0,ieee_positive_inf)
  dz=2d0; previous=.25d0; trial=.375d0; saturated=.5d0; rates=0d0
  ! Two prescribed cells contribute one cm of storage / half a day, plus
  ! their signed original rates. No unsaturated stock enters the reaction.
  rates(6)=.125d0; rates(7)=-.25d0
  call run(5,.5d0,-.5d0,0)
  call require(bottom==1.375d0.and.delta==2.25d0)
  trial(1:5)=.25d0
  call run(5,.5d0,-.5d0,0)
  call require(bottom==1.375d0.and.delta==1d0)
  trial(6:7)=.125d0
  call run(5,.5d0,-.5d0,0)
  call require(bottom==1.375d0.and.delta==1d0)
  call run(5,.5d0,.5d0,0)
  call require(bottom==2.375d0.and.delta==1d0)
  call run(7,.5d0,-.5d0,0)
  call require(bottom==-.5d0.and.delta==-.5d0)
  ! A rising/falling prescribed tail changes the reaction sign, using its
  ! actual previous stock; unsaturated root/drain rates do not leak into it.
  previous(6:7)=.75d0; rates(1:5)=17d0
  call run(5,.5d0,-.5d0,0)
  call require(bottom==-2.625d0.and.delta==-1d0)
  call run(0,.5d0,0d0,1)
  call run(8,.5d0,0d0,1)
  call run(5,0d0,0d0,1)
  call run(5,-1d0,0d0,1)
  call run(5,nan,0d0,1)
  call run(5,inf,0d0,1)
  call run(5,.5d0,nan,1)
  call run(5,.5d0,inf,1)
  dz(2)=0d0; call run(5,.5d0,0d0,1); dz(2)=2d0
  trial(2)=nan; call run(5,.5d0,0d0,1); trial(2)=.25d0
  previous(6)=-1d0; call run(5,.5d0,0d0,1); previous(6)=.75d0
  saturated(6)=inf; call run(5,.5d0,0d0,1); saturated(6)=.5d0
  rates(7)=nan; call run(5,.5d0,0d0,1); rates(7)=-.25d0
  bottom=19d0; delta=23d0
  call prescribed_groundwater_reaction(5,.5d0,dz,trial(:6),previous,saturated,rates,0d0,bottom,delta,status)
  call require(status==1.and.bottom==19d0.and.delta==23d0)
  write(*,'(a,i0)') 'PRESCRIBED_GROUNDWATER_REACTION_CONTRACT_PASS checks=',checks
contains
  subroutine require(condition)
    logical,intent(in)::condition
    if(.not.condition) error stop 'Groundwater reaction contract failed'
    checks=checks+1
  end subroutine
  subroutine run(active,step,darcy,expected)
    integer,intent(in)::active,expected
    real(8),intent(in)::step,darcy
    bottom=19d0; delta=23d0
    call prescribed_groundwater_reaction(active,step,dz,trial,previous,saturated,rates,darcy,bottom,delta,status)
    call require(status==expected)
    if(expected/=0) call require(bottom==19d0.and.delta==23d0)
  end subroutine
end program
