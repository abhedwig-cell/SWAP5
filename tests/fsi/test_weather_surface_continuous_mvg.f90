program test_weather_surface_continuous_mvg
 use iso_fortran_env,only:real64
 use mod_b110_default_mvg_provider
 use mod_soil_water_solver_contract,only:CONSTITUTIVE_DEMAND_CONDUCTIVITY
 implicit none
 type(b110_default_mvg_parameters_t),target::legacy,continuous
 type(b110_default_mvg_provider_t)::provider
 real(real64)::cof(24,1),h(1),theta(1),k(1),cap(1),dk(1),point,old,bulk,km,kp,previous_head(1),previous_water(1),increment(1),expected
 real(real64),parameter::heads(12)=[-75d0,-1d0,-.02d0,-.01238605d0,-.01238604d0,-.01d0,-.005d0,-.001d0,-1d-6,-1d-9,0d0,1d0]
 logical::ok
 integer::i
 cof=0d0;cof(1,1)=.032d0;cof(2,1)=.423d0;cof(3,1)=4.75d0;cof(4,1)=.0135d0;cof(5,1)=.365d0;cof(6,1)=1.455d0;cof(7,1)=1d0-1d0/cof(6,1)
 call initialize_b110_default_mvg_parameters(legacy,cof)
 continuous=legacy;continuous%continuous_saturation_conductivity=.true.
 call bind_b110_default_mvg_provider(provider,continuous,1d-3)
 write(*,'(a,4(1x,es25.17e3))')'MVG_COEFS',continuous%cofgen(1,1),continuous%cofgen(25,1),continuous%cofgen(27,1),continuous%cofgen(7,1)
 do i=1,size(heads)
  h=heads(i);call provider%evaluate(h,theta,k,cap,dk);bulk=k(1)
  call evaluate_b110_default_mvg_conductivity(continuous,1,h(1),point,ok)
  if(.not.ok.or.point/=bulk)error stop 'bulk/scalar drift'
  call provider%evaluate_demand(h,CONSTITUTIVE_DEMAND_CONDUCTIVITY,theta,k,cap,dk)
  if(k(1)/=bulk)error stop 'demand drift'
  call evaluate_b110_default_mvg_conductivity(legacy,1,h(1),old,ok)
  if(.not.ok)error stop 'legacy unavailable'
  if(h(1)<=-.02d0.and.old/=bulk)error stop 'outside band drift'
  if(h(1)>=0d0.and.bulk/=4.75d0)error stop 'saturated endpoint drift'
  write(*,'(a,4(1x,es25.17e3))')'MVG_ROW',h(1),theta(1),bulk,old
 end do
 call evaluate_b110_default_mvg_conductivity(continuous,1,-.01238605d0,km,ok)
 call evaluate_b110_default_mvg_conductivity(continuous,1,-.01238604d0,kp,ok)
 if(kp<km.or.kp-km>1d-6)error stop 'conductivity jump'
 previous_head=-1d-12;call provider%evaluate(previous_head,previous_water,k,cap,dk)
 h=1d-12;call provider%evaluate(h,theta,k,cap,dk)
 call provider%evaluate_water_content_increment(h,previous_head,theta,previous_water,increment)
 expected=continuous%cofgen(27,1)*1d-12
 if(increment(1)/=expected.or.increment(1)<=0d0)error stop 'wetting storage cancelled'
 call provider%evaluate_water_content_increment(previous_head,h,previous_water,theta,increment)
 if(increment(1)/=-expected)error stop 'drying storage cancelled'
 print *, 'WEATHER_SURFACE_CONTINUOUS_MVG_PASS'
end program
