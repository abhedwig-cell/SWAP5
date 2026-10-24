program organic_first_day
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
 use mod_soil_n_pool_state
 use mod_b111_soil_organic_turnover
 use mod_b111_soil_n_daily_candidate,only:b111_soil_n_rate_environment_t
 use mod_b111_soil_n_daily_exchange
 use mod_organic_first_day
 implicit none
 type(soil_n_inventory_parameters_t)::p
 type(soil_n_pool_state_t)::s,c,good
 type(b111_organic_turnover_parameters_t)::k
 type(b111_soil_n_rate_environment_t)::e,bad
 type(b111_soil_n_exchange_forcing_t)::f
 type(organic_first_receipt_t)::r
 real(real64)::stocks(3),nitrates(2),demands(2),before,after
 integer::i,j,l,chem,id,day,code
 stocks=[0d0,.005d0,.05d0];nitrates=[1d-5,.03d0];demands=[.001d0,.1d0];id=0
 p%depth_m=.3d0;p%nfrac_fom=[.001d0,.025d0];p%nfrac_biomass=.08d0;p%nfrac_humus=.02d0
 k%ratecon_fom=[10d0,.3d0];k%ratecon_bio=5d0;k%ratecon_hum=.1d0
 k%asfa_fom_bio=[.5d0,.2d0];k%asfa_fom_hum=[.1d0,.1d0];k%asfa_bio=.3d0;k%asfa_hum=.2d0
 do i=1,3
 do j=1,2
 do l=1,2
 do chem=0,1
  id=id+1
  call initialize_soil_n_pool_state(p,[1d0,.5d0],.03d0,.1d0,stocks(i),nitrates(j),s,code)
  call require(code==0,'initial')
  f=b111_soil_n_exchange_forcing_t();f%wfrac_t=.34d0;f%wfrac_t0=.34d0
  f%drybd=1300d0;f%sorpcoef=.0002d0;f%root_depth_cm=30d0
  f%crop_calendar_active=.true.;f%lai_crit_nupt=1d0;f%crop_n_demand_kg_m2=demands(l)
  f%nondepleting_top=.true.;f%proportional_constant_sinks=.true.;f%wflux_intop=-.001d0
  f%cnh4_top=.002d0;f%cno3_top=.005d0
  e=b111_soil_n_rate_environment_t();e%temperature_c=20d0;e%temperature_reference_c=20d0
  e%wfrac_sat=.423d0;e%wfpscrit2=.5d0;e%cdissi_half_kg_m2=.1d0
  e%nitrification_ref_per_day=.02d0*chem;e%denitrification_ref_per_day=.03d0*chem
  do day=1,6
   call evaluate_organic_first_day(p,s,k,e,f,c,r)
   call require(r%status==0,'composed day accepted')
   before=s%nitrogen_total(p);after=c%nitrogen_total(p)
   call require(abs(after-before+r%exchange%external_output_kg_m2)<1d-12,'whole N external budget')
   call require(abs(.45d0*p%depth_m*(sum(c%fom_kg_m3-s%fom_kg_m3)+ &
    c%biomass_kg_m3-s%biomass_kg_m3+c%humus_kg_m3-s%humus_kg_m3)+r%organic%carbon)<1d-12,'whole C')
   print '(2(I0,1X),22(ES25.17E3,1X))',id,day,stocks(i),nitrates(j),demands(l),real(chem,real64), &
    c%fom_kg_m3,c%biomass_kg_m3,c%humus_kg_m3,c%ammonium_n_kg_m2,c%nitrate_n_kg_m2,r%organic%carbon, &
    r%rates%nitrification_rate_constant,r%rates%denitrification_rate_constant, &
    r%exchange%nh4_crop_uptake_kg_m2,r%exchange%no3_crop_uptake_kg_m2,r%exchange%top_actual, &
    r%exchange%top_unmet,r%exchange%nh4_nitrified_kg_m2,r%exchange%no3_denitrified_kg_m2,r%budget%balance_residual_kg_m2
   good=c;bad=e;bad%temperature_c=ieee_value(0d0,ieee_quiet_nan)
   call evaluate_organic_first_day(p,s,k,bad,f,c,r)
   call require(r%status==2.and.r%organic%status==0,'late rate failure after organic completion')
   call require(all(c%fom_kg_m3==s%fom_kg_m3).and.c%biomass_kg_m3==s%biomass_kg_m3.and. &
    c%humus_kg_m3==s%humus_kg_m3.and.c%ammonium_n_kg_m2==s%ammonium_n_kg_m2.and. &
    c%nitrate_n_kg_m2==s%nitrate_n_kg_m2,'whole-state late rollback')
   s=good
  end do
 end do
 end do
 end do
 end do
 print '(A)','ORGANIC_FIRST_LATE_ROLLBACK_PASS'
contains
 subroutine require(ok,label)
  logical,intent(in)::ok
  character(*),intent(in)::label
  if(.not.ok)then;print *,id,day,r%status,r%exchange%status,label;error stop 1;end if
 end subroutine
end program
