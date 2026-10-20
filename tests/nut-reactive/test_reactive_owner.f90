program test_reactive_owner
 use iso_fortran_env,only:real64,int64
 use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
 use mod_b111_soil_n_mineral_owner
 use mod_b111_soil_n_reactive_owner
 use mod_soil_n_pool_state
 implicit none
 type(reactive_parameters_t)::p,bad
 type(reactive_state_t)::state,copy,restored
 type(reactive_restart_t)::payload
 type(mineral_state_t)::off
 type(reactive_receipt_t)::r
 type(mineral_receipt_t)::mr
 type(soil_n_pool_state_t)::pools,got,want,other
 real(real64),allocatable::base_vector(:),experiment_vector(:)
 real(real64)::hum_rates(6)
 real(real64)::w,temp(4),moisture(4),time,theta,nit,denit,carbon
 integer(int64)::revision
 integer::i,j,code
 call parameters(p)
 call initialize_soil_n_pool_state(p%mineral%inventory,[10d0,20d0],5d0,40d0,.02d0,.03d0,pools,code)
 call require(code==0,'initial pools')
 temp=[5d0,15d0,20d0,30d0];moisture=[.12d0,.25d0,.34d0,.42d0]
 do i=1,4
  do j=1,4
   p%environment%temperature_c=temp(i);w=moisture(j)
   call initialize_reactive(p,9001_int64,0d0,w,pools,state,code);call require(code==0,'reactive init')
   call literal_day(p,pools,w,w,0d0,0d0,0d0,0d0,want,nit,denit,carbon)
   call advance_reactive_day(state,0d0,1d0,w,0d0,0d0,0d0,0d0,r)
   if(r%status/=0)print *,'diagnostics',i,j,r%status,r%process%status,r%process%exchange%status
   call require(r%status==0,'reactive accepted')
   call state%snapshot(time,theta,got,revision);call compare(got,want,'literal whole state')
   call near(r%process%exchange%nh4_nitrified_kg_m2,nit,'literal nitrification')
   call near(r%process%exchange%no3_denitrified_kg_m2,denit,'literal gas loss')
   call near(r%process%dissimilation%carbon_dissimilation_kg_m2,carbon,'literal carbon')
   call near(pools%nitrogen_total(p%mineral%inventory)-got%nitrogen_total(p%mineral%inventory),denit,'whole N gas only')
   call require(r%process%organic%nitrogen%mineralized_n_kg_m2>0d0,'positive mineralisation')
   if(j==1)call require(denit==0d0,'dry denitrification off')
   if(j==4)call require(denit>0d0,'wet denitrification active')
  end do
 end do
 call parameters(p)
 call initialize_reactive(p,9001_int64,0d0,.34d0,pools,state,code)
 copy=state
 call literal_day(p,pools,.34d0,.33d0,.002d0,0d0,0d0,.001d0,want,nit,denit,carbon)
 call advance_reactive_day(state,0d0,1d0,.33d0,.002d0,0d0,0d0,.001d0,r)
 call require(r%status==0,'simultaneous transport/reaction')
 call state%snapshot(time,theta,got,revision);call compare(got,want,'moving-water literal state')
 call export_reactive_restart(state,payload,code);call require(code==0,'opaque export')
 call restore_reactive_restart(payload,9002_int64,restored,code);call require(code/=0,'wrong identity')
 call restore_reactive_restart(payload,9001_int64,restored,code);call require(code==0,'opaque restore')
 call advance_reactive_day(state,1d0,2d0,.34d0,0d0,.003d0,0d0,0d0,r);call require(r%status==0,'day2 inflow')
 call advance_reactive_day(restored,1d0,2d0,.34d0,0d0,.003d0,0d0,0d0,r);call require(r%status==0,'restart inflow')
 call state%snapshot(time,theta,got,revision);call restored%snapshot(time,theta,other,revision);call compare(got,other,'opaque continuation')
 call advance_reactive_day(state,1d0,2d0,.34d0,0d0,.003d0,0d0,0d0,r);call require(r%status/=0,'replay rejected')
 call state%snapshot(time,theta,want,revision);call compare(got,want,'replay atomic')
 p%enabled=.false.
 call initialize_reactive(p,9001_int64,0d0,.34d0,pools,state,code)
 call initialize_mineral(p%mineral,9001_int64,0d0,.34d0,pools,off,code)
 call advance_reactive_day(state,0d0,1d0,.33d0,.002d0,0d0,0d0,.001d0,r)
 call advance_mineral_day(off,0d0,1d0,.33d0,.002d0,0d0,0d0,.001d0,mr)
 call require(r%status==0.and.mr%status==0.and..not.r%reactions_executed,'explicit off')
 call state%snapshot(time,theta,got,revision);call off%snapshot(time,theta,want,revision)
 call require(all(got%fom_kg_m3==want%fom_kg_m3).and.got%biomass_kg_m3==want%biomass_kg_m3.and. &
    got%humus_kg_m3==want%humus_kg_m3.and.got%ammonium_n_kg_m2==want%ammonium_n_kg_m2.and. &
    got%nitrate_n_kg_m2==want%nitrate_n_kg_m2,'off bit identity')
 call parameters(p);p%mineral%inventory%nfrac_fom=.001d0
 p%mineral%inventory%nfrac_biomass=.08d0;p%mineral%inventory%nfrac_humus=.06d0
 call initialize_soil_n_pool_state(p%mineral%inventory,[100d0,200d0],.1d0,.1d0,1d-12,.03d0,pools,code)
 call initialize_reactive(p,9001_int64,0d0,.34d0,pools,state,code);call require(code==0,'immobilisation init')
 call advance_reactive_day(state,0d0,1d0,.34d0,0d0,0d0,0d0,0d0,r)
 call require(r%status/=0,'insufficient mineral N rejected')
 call state%snapshot(time,theta,got,revision);call compare(got,pools,'immobilisation rollback')
 call require(time==0d0.and.revision==0,'no consumed day on failed immobilisation')
 bad=p;bad%environment%temperature_c=ieee_value(0d0,ieee_quiet_nan)
 call initialize_reactive(bad,9001_int64,0d0,.34d0,pools,state,code);call require(code/=0,'invalid temperature')
 call parameters(p);p%mineral%c_top=[.005d0,.015d0]
 call initialize_soil_n_pool_state(p%mineral%inventory,[10d0,20d0],5d0,40d0,.02d0,.03d0,pools,code)
 call require(code==0,'top reactive pools')
 call initialize_reactive(p,9001_int64,0d0,.34d0,pools,state,code);call require(code==0,'top reactive owner')
 call literal_day(p,pools,.34d0,.35d0,0d0,0d0,0d0,0d0,want,nit,denit,carbon,surface_water=.003d0)
 call advance_reactive_day(state,0d0,1d0,.35d0,0d0,0d0,0d0,0d0,r,surface_water=.003d0)
 call require(r%status==0,'top reactive accepted')
 call state%snapshot(time,theta,got,revision);call compare(got,want,'top reactive original full state')
 call near(r%external_in,.003d0*sum(p%mineral%c_top),'reactive top input once')
 call near(r%process%exchange%nh4_nitrified_kg_m2,nit,'top reactive nitrification')
 call near(r%process%exchange%no3_denitrified_kg_m2,denit,'top reactive denitrification')
 call export_reactive_restart(state,payload,code);call require(code==0,'top reactive opaque export')
 call restore_reactive_restart(payload,9001_int64,restored,code);call require(code==0,'top reactive opaque restore')
 pools=got
 call literal_day(p,pools,.35d0,.34d0,0d0,0d0,0d0,0d0,want,nit,denit,carbon,surface_water=-.003d0)
 call advance_reactive_day(state,1d0,2d0,.34d0,0d0,0d0,0d0,0d0,r,surface_water=-.003d0)
 call require(r%status==0.and.r%external_in==0d0,'reactive evaporation no top input')
 call state%snapshot(time,theta,got,revision);call compare(got,want,'evaporative reactive literal state')
 call advance_reactive_day(restored,1d0,2d0,.34d0,0d0,0d0,0d0,0d0,r,surface_water=-.003d0)
 call require(r%status==0,'reactive top restart accepted')
 call restored%snapshot(time,theta,other,revision);call compare(got,other,'top reactive opaque continuation')
 call parameters(p);base_vector=reactive_parameter_vector(p)
 hum_rates=[-1d0,0d0,.5d-6,1d-6,1.0001d-6,.02d0/365.2425d0]
 do i=1,size(hum_rates)
  call parameters(p);p%hum_exp_daily=hum_rates(i)
  if(i>1)p%hum_exp_start_day=2d0
  experiment_vector=reactive_parameter_vector(p)
  if(i==1)then
   call require(all(experiment_vector==base_vector),'absent humus experiment old parameter identity')
  else
   call require(size(experiment_vector)==size(base_vector)+3,'humus experiment explicit identity length')
   call require(all(experiment_vector(:size(base_vector))==base_vector),'humus experiment old prefix')
   call require(experiment_vector(size(base_vector)+1)==-81005d0,'humus experiment identity marker')
  end if
  call initialize_soil_n_pool_state(p%mineral%inventory,[10d0,20d0],5d0,40d0,.02d0,.03d0,pools,code)
  call require(code==0,'humus experiment initial pools')
  call initialize_reactive(p,9001_int64,0d0,.34d0,pools,state,code)
  call require(code==0,'humus experiment owner')
  do j=0,2
   call literal_day(p,pools,.34d0,.34d0,0d0,0d0,0d0,0d0,want,nit,denit,carbon,soil_clock=real(j,real64))
   call advance_reactive_day(state,real(j,real64),real(j+1,real64),.34d0,0d0,0d0,0d0,0d0,r)
   call require(r%status==0.and.abs(r%residual)<=1d-12,'humus switch accepted with hard balance')
   call state%snapshot(time,theta,got,revision);call compare(got,want,'humus original switch full state')
   if(j==0)then
    call export_reactive_restart(state,payload,code);call require(code==0,'humus before switch opaque export')
    call restore_reactive_restart(payload,9001_int64,restored,code);call require(code==0,'humus before switch opaque restore')
   else
    call advance_reactive_day(restored,real(j,real64),real(j+1,real64),.34d0,0d0,0d0,0d0,0d0,r)
    call require(r%status==0,'humus switched opaque accepted')
    call restored%snapshot(time,theta,other,revision);call compare(got,other,'humus opaque switch continuation')
   end if
   pools=got
  end do
 end do
 bad=p;bad%hum_exp_daily=-.1d0
 call initialize_reactive(bad,9001_int64,0d0,.34d0,pools,copy,code);call require(code/=0,'negative humus experiment rejected')
 bad=p;bad%hum_exp_start_day=1.5d0
 call initialize_reactive(bad,9001_int64,0d0,.34d0,pools,copy,code);call require(code/=0,'fractional humus switch rejected')
 bad=p;bad%hum_exp_daily=ieee_value(0d0,ieee_quiet_nan)
 call initialize_reactive(bad,9001_int64,0d0,.34d0,pools,copy,code);call require(code/=0,'NaN humus experiment rejected')
 call parameters(p);p%mineral%c_top=[.005d0,.015d0]
 call initialize_soil_n_pool_state(p%mineral%inventory,[10d0,20d0],5d0,40d0,.02d0,.03d0,pools,code)
 do i=0,2
  do j=1,3
   w=moisture(j)
   call initialize_reactive(p,9001_int64,0d0,w,pools,state,code)
   call require(code==0,'gross reactive initialize')
   call literal_day(p,pools,w,w,0d0,0d0,0d0,0d0,want,nit,denit,carbon,surface_water=.004d0*i)
   call advance_reactive_day(state,0d0,1d0,w,0d0,0d0,0d0,0d0,r, &
    surface_water=0d0,historical_top_water=.004d0*i)
   call require(r%status==0,'gross reactive accepted')
   call state%snapshot(time,theta,got,revision);call compare(got,want,'gross original full chemistry')
   call near(r%external_in,.004d0*i*sum(p%mineral%c_top),'gross reactive source receipt')
   call near(r%process%exchange%nh4_nitrified_kg_m2,nit,'gross original nitrification')
   call near(r%process%exchange%no3_denitrified_kg_m2,denit,'gross original gas loss')
   copy=state
   call advance_reactive_day(state,1d0,2d0,w,0d0,0d0,0d0,0d0,r, &
    historical_top_water=ieee_value(0d0,ieee_quiet_nan))
   call require(r%status/=0,'gross reactive invalid source rejected')
   call state%snapshot(time,theta,other,revision);call compare(got,other,'gross invalid source rollback')
   call require(time==1d0.and.revision==1,'gross invalid source preserves clock/revision')
   call export_reactive_restart(state,payload,code);call require(code==0,'gross reactive restart export')
   call restore_reactive_restart(payload,9001_int64,restored,code);call require(code==0,'gross reactive restart restore')
   call advance_reactive_day(state,1d0,2d0,w,0d0,0d0,0d0,0d0,r,historical_top_water=.004d0)
   call require(r%status==0,'gross reactive retry')
   call advance_reactive_day(restored,1d0,2d0,w,0d0,0d0,0d0,0d0,r,historical_top_water=.004d0)
   call require(r%status==0,'gross reactive resumed retry')
   call state%snapshot(time,theta,got,revision);call restored%snapshot(time,theta,other,revision)
   call compare(got,other,'gross reactive restart continuation')
  end do
 end do
 print '(A)','REACTIVE_GROSS_ORIGINAL_9_CHEMISTRY_DAYS_RESTART_ROLLBACK=PASS'
 print '(A)','REACTIVE_ORIGINAL_HUMUS_SWITCH_THRESHOLD_18_DAYS_OPAQUE=PASS'
 print '(A)','REACTIVE_ATMOSPHERIC_ORIGINAL_CHEMISTRY_EVAPORATION_RESTART=PASS'
 print '(A)','REACTIVE_LITERAL_16_ENVIRONMENTS_TRANSPORT_OFF_MASS_IMMOBILISATION_RESTART=PASS'
contains
 subroutine near(x,y,label)
 real(real64),intent(in)::x,y
 character(*),intent(in)::label
 call require(abs(x-y)<=1d-12*max(1d0,abs(x),abs(y)),label)
 end subroutine
 subroutine compare(a,b,label)
 type(soil_n_pool_state_t),intent(in)::a,b
 character(*),intent(in)::label
 call require(all(abs(a%fom_kg_m3-b%fom_kg_m3)<=1d-12*max(1d0,maxval(abs(b%fom_kg_m3)))),label)
 call near(a%biomass_kg_m3,b%biomass_kg_m3,label);call near(a%humus_kg_m3,b%humus_kg_m3,label)
 call near(a%ammonium_n_kg_m2,b%ammonium_n_kg_m2,label);call near(a%nitrate_n_kg_m2,b%nitrate_n_kg_m2,label)
 end subroutine
 subroutine require(ok,label)
 logical,intent(in)::ok
 character(*),intent(in)::label
 if(.not.ok)then;print *,label;error stop 1;end if
 end subroutine
 include 'reactive_parameters.inc'
 include 'reactive_oracle.inc'
end program
