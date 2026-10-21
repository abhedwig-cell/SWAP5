module mod_b111_soil_n_reactive_owner
 use iso_fortran_env,only:real64,int64
 use ieee_arithmetic,only:ieee_is_finite
 use mod_b111_soil_n_mineral_owner
 use mod_soil_n_pool_state
 use mod_b111_soil_n_daily_candidate
 use mod_b111_soil_n_daily_exchange,only:b111_soil_n_exchange_forcing_t
 use mod_b111_soil_organic_turnover,only:b111_organic_turnover_parameters_t
 use mod_b111_soil_n_organic_rate_environment,only:b111_organic_environment_factor
 use mod_soil_n_day_environment,only:soil_n_day_environment_t,soil_n_day_environment_valid
 implicit none
 private
 type,public::reactive_crop_demand_t
   real(real64)::demand_kg_m2=0d0,root_depth_cm=0d0,tcsf_n=0d0,dvs=0d0,lai=0d0,lai_crit_nupt=0d0
 end type
 type,public::reactive_parameters_t
   type(mineral_parameters_t)::mineral
   type(b111_organic_turnover_parameters_t)::organic_reference
   type(b111_soil_n_rate_environment_t)::environment
   real(real64),allocatable::cfrac_fom(:)
   real(real64)::cfrac_biomass=0d0,cfrac_humus=0d0,wfpscrit=.6d0
   real(real64)::hum_exp_daily=-1d0,hum_exp_start_day=0d0
   logical::enabled=.true.
 end type
 type,public::reactive_state_t
   private
   type(mineral_state_t)::inventory
   type(reactive_parameters_t)::p
 contains
   procedure::ready=>reactive_ready
   procedure::snapshot=>reactive_snapshot
   procedure::configuration=>reactive_configuration
   procedure::mineral_snapshot=>base_snapshot
 end type
 type,extends(mineral_receipt_t),public::reactive_receipt_t
   type(b111_soil_n_daily_candidate_result_t)::process
   logical::reactions_executed=.false.,environment_forcing_used=.false.
   real(real64)::temperature_used_c=0d0
 end type
 type,public::reactive_restart_t
   private
   integer::schema=1
   type(reactive_state_t)::state
 end type
 public::initialize_reactive,advance_reactive_day,reactive_parameters_valid,reactive_parameter_vector
 public::export_reactive_restart,restore_reactive_restart,reconstruct_reactive_trusted
contains
 function reactive_parameter_vector(p)result(v)
   type(reactive_parameters_t),intent(in)::p
   real(real64),allocatable::v(:),b(:)
   allocate(v(0))
   if(.not.all(ieee_is_finite([p%hum_exp_daily,p%hum_exp_start_day])))return
   if(.not.mineral_parameters_valid(p%mineral))return
   b=mineral_parameter_vector(p%mineral)
   if(.not.allocated(b).or..not.allocated(p%cfrac_fom))return
   if(.not.allocated(p%organic_reference%ratecon_fom).or..not.allocated(p%organic_reference%asfa_fom_bio).or. &
      .not.allocated(p%organic_reference%asfa_fom_hum))return
   associate(o=>p%organic_reference,e=>p%environment)
    v=[b,o%ratecon_fom,o%asfa_fom_bio,o%asfa_fom_hum,o%ratecon_bio,o%ratecon_hum,o%asfa_bio,o%asfa_hum, &
       p%cfrac_fom,p%cfrac_biomass,p%cfrac_humus,p%wfpscrit,e%temperature_c,e%temperature_reference_c, &
       e%wfrac_sat,e%wfpscrit2,e%cdissi_half_kg_m2,e%nitrification_ref_per_day,e%denitrification_ref_per_day, &
       merge(1d0,0d0,p%enabled)]
   end associate
   if(p%hum_exp_daily>=0d0)v=[v,-81005d0,p%hum_exp_daily,p%hum_exp_start_day]
 end function
 logical function reactive_parameters_valid(p)result(ok)
   type(reactive_parameters_t),intent(in)::p
   real(real64),allocatable::v(:)
   integer::n
   ok=.false.
   if(.not.mineral_parameters_valid(p%mineral))return
   v=reactive_parameter_vector(p)
   if(size(v)==0)return
   if(.not.all(ieee_is_finite(v)))return
   if(p%hum_exp_daily<0d0.and.abs(p%hum_exp_daily+1d0)>0d0)return
   if(p%hum_exp_daily>100d0/365.2425d0)return
   if(p%hum_exp_start_day<0d0.or.p%hum_exp_start_day>3d6)return
   if(p%hum_exp_daily<0d0.and.abs(p%hum_exp_start_day)>0d0)return
   n=size(p%mineral%inventory%nfrac_fom)
   if(n>8)return
   associate(o=>p%organic_reference,e=>p%environment)
    if(size(o%ratecon_fom)/=n.or.size(o%asfa_fom_bio)/=n.or.size(o%asfa_fom_hum)/=n.or.size(p%cfrac_fom)/=n)return
    if(any(o%ratecon_fom<0d0).or.any(o%ratecon_fom>1d0).or.min(o%ratecon_bio,o%ratecon_hum)<0d0.or. &
       max(o%ratecon_bio,o%ratecon_hum)>1d0)return
    if(any(o%asfa_fom_bio<0d0).or.any(o%asfa_fom_hum<0d0))return
    if(any(o%asfa_fom_bio+o%asfa_fom_hum>1d0))return
    if(min(o%asfa_bio,o%asfa_hum)<0d0.or.o%asfa_bio+o%asfa_hum>1d0)return
    if(any(p%cfrac_fom<0d0).or.any(p%cfrac_fom>1d0))return
    if(min(p%cfrac_biomass,p%cfrac_humus)<0d0.or.max(p%cfrac_biomass,p%cfrac_humus)>1d0)return
    if(min(e%temperature_c,e%temperature_reference_c)<-20d0.or.max(e%temperature_c,e%temperature_reference_c)>60d0)return
    if(p%wfpscrit<.05d0.or.p%wfpscrit>.95d0.or.e%wfpscrit2<0d0.or.e%wfpscrit2>.95d0)return
    if(e%wfrac_sat<.01d0.or.e%wfrac_sat>1d0.or.e%cdissi_half_kg_m2<0d0.or.e%cdissi_half_kg_m2>1000d0)return
    if(min(e%nitrification_ref_per_day,e%denitrification_ref_per_day)<0d0.or. &
       max(e%nitrification_ref_per_day,e%denitrification_ref_per_day)>1d0)return
   end associate
   ok=.true.
 end function
 subroutine initialize_reactive(p,id,time,water,pools,state,status)
   type(reactive_parameters_t),intent(in)::p
   integer(int64),intent(in)::id
   real(real64),intent(in)::time,water
   type(soil_n_pool_state_t),intent(in)::pools
   type(reactive_state_t),intent(out)::state
   integer,intent(out)::status
   state=reactive_state_t();status=MINERAL_INVALID
   if(.not.reactive_parameters_valid(p))return
   call initialize_mineral(p%mineral,id,time,water,pools,state%inventory,status)
   if(status/=MINERAL_OK)return
   state%p=p
 end subroutine
 logical function reactive_ready(self)result(ok)
   class(reactive_state_t),intent(in)::self
   ok=self%inventory%ready()
 end function
 subroutine reactive_snapshot(self,time,water,pools,revision)
   class(reactive_state_t),intent(in)::self
   real(real64),intent(out)::time,water
   type(soil_n_pool_state_t),intent(out)::pools
   integer(int64),intent(out)::revision
   call self%inventory%snapshot(time,water,pools,revision)
 end subroutine
 subroutine base_snapshot(self,state)
   class(reactive_state_t),intent(in)::self
   type(mineral_state_t),intent(out)::state
   state=self%inventory
 end subroutine
 subroutine reactive_configuration(self,p,id)
   class(reactive_state_t),intent(in)::self
   type(reactive_parameters_t),intent(out)::p
   integer(int64),intent(out)::id
   type(mineral_parameters_t)::base
   p=self%p;call self%inventory%configuration(base,id)
 end subroutine
 subroutine advance_reactive_day(state,t0,t1,water_end,outflow,in_bottom,in_lateral,root_water,receipt,crop,environment,surface_water,historical_top_water,finite_donor_top)
   type(reactive_state_t),intent(inout)::state
   real(real64),intent(in)::t0,t1,water_end,outflow,in_bottom,in_lateral,root_water
   type(reactive_receipt_t),intent(out)::receipt
   type(reactive_crop_demand_t),intent(in),optional::crop
   type(soil_n_day_environment_t),intent(in),optional::environment
   real(real64),intent(in),optional::surface_water,historical_top_water
   logical,intent(in),optional::finite_donor_top
   logical::bounded_top
   real(real64)::surface,top_n_water
   type(b111_soil_n_rate_environment_t)::effective_environment
   type(mineral_state_t)::trial
   type(soil_n_pool_state_t)::before,after
   type(soil_n_transfer_t)::x
   type(b111_organic_turnover_parameters_t)::actual
   type(b111_soil_n_exchange_forcing_t)::f
   type(b111_soil_n_daily_candidate_result_t)::r
   type(mineral_receipt_t)::budget
   real(real64)::time,water,factor
   integer(int64)::revision
   integer::code
   receipt=reactive_receipt_t()
   bounded_top=.false.;if(present(finite_donor_top))bounded_top=finite_donor_top
   if(bounded_top.and.(present(crop).or..not.present(historical_top_water)))return
   if(bounded_top)then
     if(.not.ieee_is_finite(root_water))return
     if(abs(root_water)>0d0)return
   end if
   surface=0d0;if(present(surface_water))surface=surface_water
   if(.not.ieee_is_finite(surface))return
   if(abs(surface)>100d0)return
   top_n_water=max(0d0,surface)
   if(present(historical_top_water))then
     if(.not.ieee_is_finite(historical_top_water))return
     if(abs(historical_top_water)>100d0)return
     if(historical_top_water<0d0.and..not.bounded_top)return
     if(bounded_top.and.historical_top_water>=0d0)return
     top_n_water=historical_top_water
   end if
   if(.not.state%ready())return
   if(present(crop))then
     if(.not.state%p%enabled)return
     if(.not.all(ieee_is_finite([crop%demand_kg_m2,crop%root_depth_cm,crop%tcsf_n,crop%dvs,crop%lai,crop%lai_crit_nupt])))return
     if(min(crop%demand_kg_m2,crop%root_depth_cm,crop%tcsf_n,crop%lai,crop%lai_crit_nupt)<0d0)return
     if(crop%demand_kg_m2>100d0.or.crop%root_depth_cm>1d4.or.crop%tcsf_n>1d0.or. &
        abs(crop%dvs)>10d0.or.max(crop%lai,crop%lai_crit_nupt)>100d0)return
   end if
   effective_environment=state%p%environment
   if(present(environment))then
     if(.not.state%p%enabled)return
     if(.not.soil_n_day_environment_valid(environment,t0,t1))return
     effective_environment%temperature_c=environment%temperature_c
   end if
   trial=state%inventory
   if(.not.state%p%enabled)then
     call advance_mineral_day(trial,t0,t1,water_end,outflow,in_bottom,in_lateral,root_water,budget,surface_water=surface,historical_top_water=historical_top_water,finite_donor_top=bounded_top)
     receipt%mineral_receipt_t=budget
     if(budget%status==MINERAL_OK)state%inventory=trial
     return
   end if
   if(.not.all(ieee_is_finite([t0,t1,water_end,outflow,in_bottom,in_lateral,root_water])))return
   call state%snapshot(time,water,before,revision)
   if(abs(t0-time)>0d0.or.abs(t1-t0-1d0)>0d0)return
   if(min(outflow,in_bottom,in_lateral,root_water)<0d0.or.max(outflow,in_bottom,in_lateral,root_water)>100d0)return
   call b111_organic_environment_factor(effective_environment%temperature_c,effective_environment%temperature_reference_c, &
       water,water_end,state%p%environment%wfrac_sat,state%p%wfpscrit,factor,code)
   if(code/=0)return
   actual=state%p%organic_reference
   ! Original wofost_soil_rateconstants task1: strict daily threshold,
   ! then inclusive end-of-day date switch, before environmental correction.
   if(state%p%hum_exp_daily>1d-6.and.t1>=state%p%hum_exp_start_day) &
     actual%ratecon_hum=state%p%hum_exp_daily
   actual%ratecon_fom=actual%ratecon_fom*factor
   actual%ratecon_bio=actual%ratecon_bio*factor;actual%ratecon_hum=actual%ratecon_hum*factor
   f%dt_day=1d0;f%wfrac_t0=water;f%wfrac_t=water_end;f%wflux_out=outflow;f%wflux_inbot=in_bottom
   f%wflux_intop=top_n_water
   f%finite_donor_top=bounded_top
   f%cnh4_top=state%p%mineral%c_top(1);f%cno3_top=state%p%mineral%c_top(2)
   f%wflux_inlat=in_lateral;f%wflux_transp=root_water;f%drybd=state%p%mineral%drybd;f%sorpcoef=state%p%mineral%sorption
   f%cnh4_seep=state%p%mineral%c_bottom(1);f%cno3_seep=state%p%mineral%c_bottom(2)
   f%cnh4_lat=state%p%mineral%c_lateral(1);f%cno3_lat=state%p%mineral%c_lateral(2)
   if(present(crop))then
     f%crop_calendar_active=.true.;f%crop_n_demand_kg_m2=crop%demand_kg_m2
     f%root_depth_cm=crop%root_depth_cm;f%tcsf_n=crop%tcsf_n
     f%dvs=crop%dvs;f%lai=crop%lai;f%lai_crit_nupt=crop%lai_crit_nupt
   end if
   call evaluate_b111_soil_n_daily_candidate(state%p%mineral%inventory,before,actual,state%p%cfrac_fom, &
      state%p%cfrac_biomass,state%p%cfrac_humus,effective_environment,f,after,r)
   receipt%process=r;receipt%reactions_executed=.true.
   if(r%status/=B111_NDAY_OK)return
   x%fom_delta_kg_m3=after%fom_kg_m3-before%fom_kg_m3
   x%biomass_delta_kg_m3=after%biomass_kg_m3-before%biomass_kg_m3
   x%humus_delta_kg_m3=after%humus_kg_m3-before%humus_kg_m3
   x%ammonium_n_delta_kg_m2=after%ammonium_n_kg_m2-before%ammonium_n_kg_m2
   x%nitrate_n_delta_kg_m2=after%nitrate_n_kg_m2-before%nitrate_n_kg_m2
   x%external_n_input_kg_m2=r%exchange%external_input_kg_m2;x%external_n_output_kg_m2=r%exchange%external_output_kg_m2
   call apply_mineral_day_transfer(trial,t0,t1,water_end,outflow,in_bottom,in_lateral,root_water,x,budget,surface_water=surface)
   receipt%mineral_receipt_t=budget
   if(bounded_top)then
     receipt%top_actual=r%exchange%top_actual;receipt%top_unmet=r%exchange%top_unmet
     receipt%top_requested=r%exchange%top_requested
   end if
   if(budget%status==MINERAL_OK)then
     state%inventory=trial
     receipt%environment_forcing_used=present(environment)
     receipt%temperature_used_c=effective_environment%temperature_c
   end if
 end subroutine
 subroutine export_reactive_restart(state,payload,status)
   type(reactive_state_t),intent(in)::state
   type(reactive_restart_t),intent(out)::payload
   integer,intent(out)::status
   payload=reactive_restart_t();status=MINERAL_INVALID
   if(.not.state%ready())return
   payload%state=state;status=MINERAL_OK
 end subroutine
 subroutine restore_reactive_restart(payload,id,state,status)
   type(reactive_restart_t),intent(in)::payload
   integer(int64),intent(in)::id
   type(reactive_state_t),intent(out)::state
   integer,intent(out)::status
   type(mineral_parameters_t)::p
   integer(int64)::actual
   state=reactive_state_t();status=MINERAL_INVALID
   if(payload%schema/=1.or..not.payload%state%ready())return
   call payload%state%inventory%configuration(p,actual)
   if(actual/=id)return
   state=payload%state;status=MINERAL_OK
 end subroutine
 subroutine reconstruct_reactive_trusted(p,id,revision,time,water,pools,state,status)
   type(reactive_parameters_t),intent(in)::p
   integer(int64),intent(in)::id,revision
   real(real64),intent(in)::time,water
   type(soil_n_pool_state_t),intent(in)::pools
   type(reactive_state_t),intent(out)::state
   integer,intent(out)::status
   state=reactive_state_t();status=MINERAL_INVALID
   if(.not.reactive_parameters_valid(p))return
   call reconstruct_mineral_trusted(p%mineral,id,revision,time,water,pools,state%inventory,status)
   if(status==MINERAL_OK)state%p=p
 end subroutine
end module
