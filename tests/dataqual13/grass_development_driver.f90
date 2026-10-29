program grass_development_driver
 use iso_fortran_env,only:real64
 use mod_wofost_grass_development
 implicit none
 type(grass_development_parameters_t)::p
 type(grass_management_continuation_t)::base
 type(grass_development_candidate_t)::candidate
 real(real64)::tsum,tav,soil
 integer::mode,warm,delay,required,status,ios
 do
  read(*,*,iostat=ios)mode,tsum,tav,soil,warm,delay,required
  if(ios/=0)exit
  p%temperature_start_mode=mode;p%soil_temperature_threshold_c=5d0;p%required_warm_days=required
  base%warm_days=warm;base%regrowth_delay_days=delay
  call prepare_grass_development_candidate(p,base,tsum,tav,soil,candidate,status)
  if(status/=GRASS_DEVELOPMENT_OK)then
   write(*,*)'INVALID';cycle
  end if
  if(base%warm_days/=warm.or.base%regrowth_delay_days/=delay)error stop 'committed state mutated'
  write(*,'(2(es25.16e3,1x),2(l1,1x),2(i0,1x))')candidate%temperature_sum_increment,candidate%development_rate, &
   candidate%temperature_start_reached,candidate%growth_enabled,candidate%management%warm_days, &
   candidate%management%regrowth_delay_days
 end do
end program
