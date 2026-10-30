program root_extension_oracle
 use iso_fortran_env,only:real64
 use MOD_cropdevelopment,only:update_rootextension,rdm,rdpot,rri,swdmi2rd
 use plant_interface,only:rd,swrd,swwrtnonox,aeratecrit,croptype,icrop,grrt,grrtpot,noddrz
 use MOD_integral,only:iptra_day,iqrot_day,ialpwet_day
 use MOD_grid,only:zbotcp
 use mod_crop_root_depth_rate_owner
 implicit none
 type(crop_root_depth_rate_parameters_t)::p
 type(crop_root_depth_rate_state_t)::base,candidate
 type(crop_root_depth_rate_daily_forcing_t)::f
 type(crop_root_depth_rate_diagnostics_t)::d
 real(real64)::depths(3)=[20d0,29.8d0,30d0],ratios(3)=[0d0,.7d0,1d0]
 real(real64)::growth(4)=[0d0,.0009d0,.001d0,.1d0],oxygen(3)=[.49d0,.5d0,1d0],err,maximum
 integer::a,b,c,e,i,code,count
 p%initial_root_depth_cm=20d0;p%maximum_root_depth_cm=30d0;p%maximum_daily_extension_cm=1d0
 p%actual_extension_mode=CROP_ROOT_RATE_WATER_SCALED;p%anaerobic_extension_gate_enabled=.true.
 p%aeration_critical_factor=.5d0;p%negligible_transpiration=1d-10
 p%negligible_root_growth=1d-3;p%negligible_extension=1d-6
 swrd=2;swwrtnonox=1;aeratecrit=.5d0;swdmi2rd=1;rdm=30d0;rri=1d0
 icrop=1;croptype(1)=2
 do i=1,size(zbotcp)
  zbotcp(i)=-real(i,real64)
 end do
 maximum=0d0;count=0
 do a=1,3
 do b=1,3
 do c=1,4
 do e=1,3
  base%actual_root_depth_cm=depths(a);base%potential_root_depth_cm=depths(a)
  f%potential_transpiration=.3d0;f%actual_root_uptake=.3d0*ratios(b)
  f%actual_root_growth=growth(c);f%potential_root_growth=.1d0
  f%deepest_root_oxygen_factor_available=.true.;f%deepest_root_oxygen_factor_integral=oxygen(e)
  rd=depths(a);rdpot=depths(a);grrt=growth(c);grrtpot=.1d0;noddrz=ceiling(rd)
  iptra_day=f%potential_transpiration;iqrot_day=f%actual_root_uptake;ialpwet_day=oxygen(e)
  call update_rootextension()
  call evaluate_crop_root_depth_rate_candidate(p,base,f,candidate,d,code)
  if(code/=0)error stop 'native root candidate'
  err=max(abs(rd-candidate%actual_root_depth_cm),abs(rdpot-candidate%potential_root_depth_cm));maximum=max(maximum,err)
  if(err>1d-13)error stop 'original root mismatch'
  if(base%actual_root_depth_cm/=depths(a).or.base%potential_root_depth_cm/=depths(a))error stop 'root rollback base'
  count=count+1
 end do
 end do
 end do
 end do
 print *,'ORIGINAL_SWRD2_ACTIVE_ROOT_PASS',count,maximum
end program
