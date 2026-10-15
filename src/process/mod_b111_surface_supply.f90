! Supply-limited surface boundary. Water ownership stays with Richards.
module mod_b111_surface_supply
 use iso_fortran_env,only:real64,int64
 use ieee_arithmetic,only:ieee_is_finite
 use mod_b111_pond_solute_exchange,only:b111_pond_solute_result_t,evaluate_b111_pond_solute_exchange,B111_POND_SOL_OK
 implicit none
 private
 type,public::surface_supply_t
  integer(int64)::source_id=0,revision=-1
  real(real64)::t0=0d0,t1=0d0,rain_rate=0d0,irrigation_rate=0d0,rain_c=0d0,irrigation_c=0d0
 end type
 public::surface_supply_valid,evaluate_surface_supply
contains
 pure logical function surface_supply_valid(s) result(ok)
  type(surface_supply_t),intent(in)::s
  real(real64)::rate
  ok=.false.
  if(s%source_id<=0.or.s%revision<0.or.s%revision>100000000_int64)return
  if(.not.all(ieee_is_finite([s%t0,s%t1,s%rain_rate,s%irrigation_rate,s%rain_c,s%irrigation_c])))return
  if(abs(s%t0)>1d8.or.abs(s%t1)>1d8.or.s%t1<=s%t0)return
  if(s%t1-s%t0>1d3.or.s%t1-s%t0<1d-100)return
  if(min(s%rain_rate,s%irrigation_rate,s%rain_c,s%irrigation_c)<0d0)return
  if(max(s%rain_rate,s%irrigation_rate)>5d5.or.max(s%rain_c,s%irrigation_c)>1d6)return
  rate=s%rain_rate+s%irrigation_rate
  if(rate>0d0.and.rate<=1d-6)return
  ok=.true.
 end function
 pure subroutine evaluate_surface_supply(s,t0,t1,qtop,mix,status)
  type(surface_supply_t),intent(in)::s
  real(real64),intent(in)::t0,t1,qtop
  type(b111_pond_solute_result_t),intent(out)::mix
  integer,intent(out)::status
  real(real64)::rate,scale
  status=1;mix=b111_pond_solute_result_t()
  if(.not.surface_supply_valid(s))return
  if(.not.all(ieee_is_finite([t0,t1,qtop])))return
  if(t0<s%t0.or.t1>s%t1.or.t1<=t0)return
  if(t1-t0<1d-100)return
  rate=s%rain_rate+s%irrigation_rate;scale=max(1d0,rate)
  if(abs(qtop)>1d6)return
  if(qtop>0d0.or.abs(qtop+rate)>0d0)return
  ! Require the actual source cutoff on the accepted flux as well.
  if(rate>0d0.and.qtop>=-1d-6)return
  if(rate<=0d0.and.abs(qtop)>0d0)return
  call evaluate_b111_pond_solute_exchange(0d0,s%rain_rate,s%rain_c,s%irrigation_rate,s%irrigation_c, &
    qtop,0d0,0d0,t1-t0,mix)
  if(mix%status/=B111_POND_SOL_OK)return
  scale=max(1d0,mix%rain_input+mix%irrigation_input)
  if(abs(mix%mass_after)>4096d0*epsilon(1d0)*scale)return
  if(abs(mix%soil_transfer-mix%rain_input-mix%irrigation_input)>4096d0*epsilon(1d0)*scale)return
  status=0
 end subroutine
end module
