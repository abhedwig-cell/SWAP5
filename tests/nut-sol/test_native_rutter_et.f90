program test_native_rutter_et
 use iso_fortran_env,only:real64,int64
 use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
 use mod_reference_et_demand_process
 use legacy_etpot_oracle,only:ETpot,swmetdetail,swetr,etr,cfevappond,peva,epond,ptra_dry,ptra_wet,eintc
 use plant_interface,only:fl_cropemergence,vcover,cf,fco2tra
 use variables,only:swcfbs,cfbs
 implicit none
 type(reference_et_demand_parameters_t)::p
 type(reference_et_demand_forcing_t)::f
 type(reference_et_demand_canopy_view_t)::c
 type(traditional_pm_daily_result_t)::r
 type(reference_et_demand_result_t)::dry
 type(reference_et_demand_diagnostics_t)::d,dd
 real(real64),parameter::et(4)=[0._real64,.2_real64,3._real64,12._real64],cover(3)=[0._real64,.25_real64,1._real64], &
  factor(3)=[0._real64,.7_real64,1.5_real64],co2(4)=[0._real64,.5_real64,1._real64,1.5_real64],pond(3)=[0._real64,.7_real64,1.2_real64]
 real(real64)::actual(5),expected(5)
 integer::a,b,h,i,j,k,n
 n=0;swmetdetail=0;swetr=1;swcfbs=0;cfbs=1._real64
 do a=0,1
 do b=1,4
 do h=1,3
 do i=1,3
 do j=1,4
 do k=1,3
  fl_cropemergence=a==1;etr=et(b);vcover=cover(h);cf=factor(i);fco2tra=co2(j);cfevappond=pond(k)
  c%crop_emerged=fl_cropemergence;c%vegetation_cover_fraction=vcover;c%crop_factor=cf;c%co2_transpiration_factor=fco2tra
  f%reference_et_mm_per_day=etr;p%pond_evaporation_factor=cfevappond
  call ETpot
  call evaluate_reference_et_rutter_demand(p,f,c,r,d)
  if(d%status/=0.or..not.d%result_produced)error stop 'valid Rutter ETref rejected'
  expected=[peva,epond,ptra_dry,ptra_wet,eintc]
  actual=[r%potential_soil_evaporation_cm_per_day,r%potential_pond_evaporation_cm_per_day, &
   r%potential_transpiration_dry_cm_per_day,r%potential_transpiration_wet_cm_per_day,r%interception_evaporation_capacity_cm_per_day]
  if(any(transfer(actual,[0_int64],5)/=transfer(expected,[0_int64],5)))then
   print *,a,b,h,i,j,k,actual,expected;error stop 'original ETpot bit mismatch'
  end if
  call evaluate_restricted_reference_et_demand(p,f,c,dry,dd)
  if(dry%potential_transpiration_cm_per_day/=r%potential_transpiration_dry_cm_per_day.or. &
    dry%potential_soil_evaporation_cm_per_day/=r%potential_soil_evaporation_cm_per_day.or. &
    dry%potential_pond_evaporation_cm_per_day/=r%potential_pond_evaporation_cm_per_day)error stop 'dry owner drift'
  n=n+1
 end do
 end do
 end do
 end do
 end do
 end do
 f%reference_et_mm_per_day=-1._real64
 call evaluate_reference_et_rutter_demand(p,f,c,r,d)
 if(d%result_produced.or.d%status==0.or.r%potential_transpiration_dry_cm_per_day/=0._real64)error stop 'invalid ET accepted'
 f%reference_et_mm_per_day=1._real64;c%vegetation_cover_fraction=ieee_value(0._real64,ieee_quiet_nan)
 call evaluate_reference_et_rutter_demand(p,f,c,r,d)
 if(d%result_produced.or.d%status==0)error stop 'invalid canopy accepted'
 write(*,'(a,i0)')'ORIGINAL_ETPOT_RUTTER_BIT_EXACT_CASES=',n
 print '(a)','NATIVE_RUTTER_ET_ORIGINAL_AND_DRY_PRESERVATION_PASS'
end program
