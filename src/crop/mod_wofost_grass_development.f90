! Source: B1.11 wofost.f90 update_dvs_rate/update_wofost, SWWOFOST=3.
! This process proposes one source day. The enclosing crop/water transaction
! owns publication. TSUM and DVS remain in the existing crop state owner.
module mod_wofost_grass_development
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_is_finite
 use mod_wofost_rate_table,only:wofost_rate_table_t
 implicit none
 private
 integer,parameter,public::GRASS_DEVELOPMENT_OK=0,GRASS_DEVELOPMENT_INVALID=1
 type,public::grass_development_parameters_t
  integer::temperature_start_mode=1
  real(real64)::soil_temperature_threshold_c=0d0
  integer::required_warm_days=0
 end type
 type,public::grass_management_continuation_t
  integer::cut_index=1,potential_cut_index=1
  integer::potential_regrowth_delay_days=0
  real(real64)::harvested_dry_matter=0d0,potential_harvested_dry_matter=0d0
  integer::warm_days=0
  integer::regrowth_delay_days=0
  integer::actual_cut_age=0,potential_cut_age=0
 contains
  procedure::ready=>grass_management_ready
 end type
 type,public::grass_management_parameters_t
  type(grass_development_parameters_t)::development
  type(wofost_rate_table_t)::mowing_threshold,regrowth_delay
  integer::max_growing_days=0,sequence_length=0
  real(real64)::mowing_residual=0d0
 contains
  procedure::ready=>grass_management_parameters_ready
 end type
 type,public::grass_development_candidate_t
  logical::valid=.false.,temperature_start_reached=.false.,growth_enabled=.false.
  real(real64)::temperature_sum_increment=0d0,development_rate=0d0
  type(grass_management_continuation_t)::management
 end type
 public::prepare_grass_development_candidate
contains
 logical function grass_management_ready(self)result(ok)
  class(grass_management_continuation_t),intent(in)::self
  ok=.false.
  if(min(self%cut_index,self%potential_cut_index)<1)return
  if(min(self%warm_days,self%regrowth_delay_days,self%potential_regrowth_delay_days, &
       self%actual_cut_age,self%potential_cut_age)<0)return
  if(.not.all(ieee_is_finite([self%harvested_dry_matter,self%potential_harvested_dry_matter])))return
  if(min(self%harvested_dry_matter,self%potential_harvested_dry_matter)<0d0)return
  ok=.true.
 end function
 logical function grass_management_parameters_ready(self)result(ok)
  class(grass_management_parameters_t),intent(in)::self
  real(real64),allocatable::x(:),y(:)
  logical::available
  ok=.false.
  if(self%development%temperature_start_mode<0.or.self%development%temperature_start_mode>2)return
  if(self%development%temperature_start_mode==2)then
   if(.not.ieee_is_finite(self%development%soil_temperature_threshold_c))return
   if(self%development%required_warm_days<1)return
  end if
  if(self%max_growing_days<1.or.self%max_growing_days>366.or.self%sequence_length<1)return
  if(.not.ieee_is_finite(self%mowing_residual))return
  if(self%mowing_residual<0d0.or.self%mowing_residual>5000d0)return
  call self%mowing_threshold%snapshot_values(x,y,available);if(.not.available)return
  if(any(x<0d0).or.any(x>366d0).or.any(y<0d0).or.any(y>30000d0))return
  call self%regrowth_delay%snapshot_values(x,y,available);if(.not.available)return
  if(any(x<0d0).or.any(x>300000d0).or.any(y<0d0).or.any(y>366d0))return
  ok=.true.
 end function

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
