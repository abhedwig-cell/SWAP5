! Source: B1.11 wofost.f90 update_dvs_rate/update_wofost, SWWOFOST=3.
! This process proposes one source day. The enclosing crop/water transaction
! owns publication. TSUM and DVS remain in the existing crop state owner.
module mod_wofost_grass_development
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_is_finite
 implicit none
 private
 integer,parameter,public::GRASS_DEVELOPMENT_OK=0,GRASS_DEVELOPMENT_INVALID=1
 type,public::grass_development_parameters_t
  integer::temperature_start_mode=1
  real(real64)::soil_temperature_threshold_c=0d0
  integer::required_warm_days=0
 end type
 type,public::grass_management_continuation_t
  integer::warm_days=0
  integer::regrowth_delay_days=0
 end type
 type,public::grass_development_candidate_t
  logical::valid=.false.,temperature_start_reached=.false.,growth_enabled=.false.
  real(real64)::temperature_sum_increment=0d0,development_rate=0d0
  type(grass_management_continuation_t)::management
 end type
 public::prepare_grass_development_candidate
contains
 pure subroutine prepare_grass_development_candidate(p,base,temperature_sum,air_temperature_c, &
      soil_temperature_c,candidate,status)
  type(grass_development_parameters_t),intent(in)::p
  type(grass_management_continuation_t),intent(in)::base
  real(real64),intent(in)::temperature_sum,air_temperature_c,soil_temperature_c
  type(grass_development_candidate_t),intent(out)::candidate
  integer,intent(out)::status
  candidate=grass_development_candidate_t();status=GRASS_DEVELOPMENT_INVALID
  if(p%temperature_start_mode<0.or.p%temperature_start_mode>2)return
  if(.not.ieee_is_finite(temperature_sum).or.temperature_sum<0d0)return
  if(.not.ieee_is_finite(air_temperature_c))return
  if(base%warm_days<0.or.base%regrowth_delay_days<0)return
  candidate%management=base
  candidate%temperature_sum_increment=max(0d0,air_temperature_c)
  candidate%development_rate=2d0/366d0
  select case(p%temperature_start_mode)
  case(0)
   candidate%temperature_start_reached=.true.
  case(1)
   candidate%temperature_start_reached=temperature_sum+candidate%temperature_sum_increment>=200d0
  case(2)
   if(.not.ieee_is_finite(soil_temperature_c).or. &
      .not.ieee_is_finite(p%soil_temperature_threshold_c).or.p%required_warm_days<1)return
   if(soil_temperature_c>=p%soil_temperature_threshold_c)then
    if(base%warm_days==huge(base%warm_days))return
    candidate%management%warm_days=base%warm_days+1
   end if
   candidate%temperature_start_reached=candidate%management%warm_days>=p%required_warm_days
  end select
  candidate%management%regrowth_delay_days=max(0,base%regrowth_delay_days-1)
  candidate%growth_enabled=candidate%temperature_start_reached.and.candidate%management%regrowth_delay_days==0
  candidate%valid=.true.;status=GRASS_DEVELOPMENT_OK
 end subroutine
end module
