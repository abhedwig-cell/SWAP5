module mod_aquifer_solute_reservoir
  ! Original SWBR forward-Euler concentration equation, with explicit conserved
  ! reservoir/flux results. The caller owns storage-coefficient selection,
  ! state, time-step policy, boundary exchange and native persistence.
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private
  integer, parameter, public :: AQ_OK=0, AQ_INVALID=1, AQ_NEGATIVE=2, AQ_OVERFLOW=3
  real(real64), parameter :: LIMIT=huge(1.0_real64)
  type, public :: aquifer_solute_result
    real(real64) :: concentration_mg_cm3=0.0_real64
    real(real64) :: capacity_cm=0.0_real64
    real(real64) :: stock_before_mg_cm2=0.0_real64
    real(real64) :: stock_after_mg_cm2=0.0_real64
    real(real64) :: soil_input_mg_cm2=0.0_real64
    real(real64) :: surface_out_mg_cm2=0.0_real64
    real(real64) :: decayed_mg_cm2=0.0_real64
    real(real64) :: residual_mg_cm2=0.0_real64
  end type
  public :: evaluate_aquifer_solute_reservoir,evaluate_aquifer_loss_limit
contains
  pure subroutine evaluate_aquifer_loss_limit(capacity,outward_water_rate,decay_rate,safety,interval_limit,status)
    ! Positive-net surface export plus all soil return-flow water is a loss.
    ! Ignoring positive soil mass input gives a conservative Euler positivity
    ! bound. The caller records the safety factor as numerical policy.
    real(real64),intent(in)::capacity,outward_water_rate,decay_rate,safety
    real(real64),intent(inout)::interval_limit
    integer,intent(out)::status
    real(real64)::water_loss,total_loss,candidate
    logical::ok
    status=AQ_INVALID
    if(.not.all(ieee_is_finite([capacity,outward_water_rate,decay_rate,safety])))return
    if(capacity<=0.0_real64.or.outward_water_rate<0.0_real64.or.decay_rate<0.0_real64 &
       .or.safety<=0.0_real64.or.safety>1.0_real64)return
    call divide(outward_water_rate,capacity,water_loss,ok)
    if(.not.ok)then
      status=AQ_OVERFLOW;return
    end if
    call add(water_loss,decay_rate,total_loss,ok)
    if(.not.ok)then
      status=AQ_OVERFLOW;return
    end if
    candidate=LIMIT
    if(total_loss>0.0_real64)then
      call divide(safety,total_loss,candidate,ok)
      ! A mathematical limit above the largest finite value leaves every
      ! representable interval below the actual bound; use finite LIMIT.
      if(.not.ok)candidate=LIMIT
    end if
    if(candidate<=0.0_real64)return
    interval_limit=candidate;status=AQ_OK
  end subroutine

  pure subroutine evaluate_aquifer_solute_reservoir(concentration,storage_coefficient,thickness, &
      soil_mass_rate,net_drainage,decay_rate,interval,result,status)
    real(real64), intent(in) :: concentration,storage_coefficient,thickness
    real(real64), intent(in) :: soil_mass_rate,net_drainage,decay_rate,interval
    type(aquifer_solute_result), intent(inout) :: result
    integer, intent(out) :: status
    type(aquifer_solute_result) :: candidate
    real(real64) :: out_rate,net_mass_rate,transport_rate,decay_concentration_rate
    real(real64) :: total_rate,factor,increment,v1,v2
    logical :: ok
    status=AQ_INVALID
    candidate=aquifer_solute_result()
    if(.not.all(ieee_is_finite([concentration,storage_coefficient,thickness,soil_mass_rate, &
        net_drainage,decay_rate,interval])))return
    if(concentration<0.0_real64.or.storage_coefficient<=0.0_real64.or.thickness<=0.0_real64 &
        .or.decay_rate<0.0_real64.or.interval<0.0_real64)return
    call multiply(storage_coefficient,thickness,candidate%capacity_cm,ok)
    if(.not.ok)goto 900
    if(candidate%capacity_cm<=0.0_real64)return
    call multiply(concentration,candidate%capacity_cm,candidate%stock_before_mg_cm2,ok)
    if(.not.ok)goto 900
    if(interval==0.0_real64)then
      candidate%concentration_mg_cm3=concentration
      candidate%stock_after_mg_cm2=candidate%stock_before_mg_cm2
      result=candidate;status=AQ_OK;return
    end if
    ! Preserve the original concentration arithmetic and positive-net-drainage
    ! branch. Signed soil exchange includes return flow; it is not clipped.
    call multiply(max(net_drainage,0.0_real64),concentration,out_rate,ok)
    if(.not.ok)goto 900
    call add(soil_mass_rate,-out_rate,net_mass_rate,ok)
    if(.not.ok)goto 900
    call divide(net_mass_rate,thickness,transport_rate,ok)
    if(.not.ok)goto 900
    call multiply(decay_rate,concentration,v1,ok)
    if(.not.ok)goto 900
    call multiply(v1,storage_coefficient,decay_concentration_rate,ok)
    if(.not.ok)goto 900
    call add(transport_rate,-decay_concentration_rate,total_rate,ok)
    if(.not.ok)goto 900
    call divide(interval,storage_coefficient,factor,ok)
    if(.not.ok)goto 900
    call multiply(factor,total_rate,increment,ok)
    if(.not.ok)goto 900
    call add(concentration,increment,candidate%concentration_mg_cm3,ok)
    if(.not.ok)goto 900
    if(candidate%concentration_mg_cm3<0.0_real64)then
      status=AQ_NEGATIVE;return
    end if
    call multiply(candidate%concentration_mg_cm3,candidate%capacity_cm,candidate%stock_after_mg_cm2,ok)
    if(.not.ok)goto 900
    call multiply(soil_mass_rate,interval,candidate%soil_input_mg_cm2,ok)
    if(.not.ok)goto 900
    call multiply(out_rate,interval,candidate%surface_out_mg_cm2,ok)
    if(.not.ok)goto 900
    call multiply(decay_concentration_rate,thickness,v1,ok)
    if(.not.ok)goto 900
    call multiply(v1,interval,candidate%decayed_mg_cm2,ok)
    if(.not.ok)goto 900
    call add(candidate%stock_after_mg_cm2,-candidate%stock_before_mg_cm2,v1,ok)
    if(.not.ok)goto 900
    call add(v1,-candidate%soil_input_mg_cm2,v2,ok)
    if(.not.ok)goto 900
    call add(v2,candidate%surface_out_mg_cm2,v1,ok)
    if(.not.ok)goto 900
    call add(v1,candidate%decayed_mg_cm2,candidate%residual_mg_cm2,ok)
    if(.not.ok)goto 900
    result=candidate;status=AQ_OK;return
900 status=AQ_OVERFLOW
  end subroutine

  pure subroutine multiply(a,b,value,ok)
    real(real64), intent(in) :: a,b
    real(real64), intent(out) :: value
    logical, intent(out) :: ok
    ok=.false.;value=0.0_real64
    if(abs(a)>1.0_real64)then
      if(abs(b)>LIMIT/abs(a))return
    else if(abs(b)>1.0_real64)then
      if(abs(a)>LIMIT/abs(b))return
    end if
    value=a*b;ok=.true.
  end subroutine

  pure subroutine add(a,b,value,ok)
    real(real64), intent(in) :: a,b
    real(real64), intent(out) :: value
    logical, intent(out) :: ok
    ok=.false.;value=0.0_real64
    if(b>0.0_real64)then
      if(a>LIMIT-b)return
    else if(b<0.0_real64)then
      if(a< -LIMIT-b)return
    end if
    value=a+b;ok=.true.
  end subroutine

  pure subroutine divide(a,b,value,ok)
    real(real64), intent(in) :: a,b
    real(real64), intent(out) :: value
    logical, intent(out) :: ok
    ok=.false.;value=0.0_real64
    if(b==0.0_real64)return
    if(abs(b)<1.0_real64)then
      if(abs(a)>LIMIT*abs(b))return
    end if
    value=a/b;ok=.true.
  end subroutine
end module
