! One aggregate soil-N owner; no organic-N duplicate and no water ownership.
module mod_b111_soil_n_mineral_owner
 use iso_fortran_env,only:real64,int64
 use ieee_arithmetic,only:ieee_is_finite
 use mod_soil_n_pool_state
 use mod_b111_soil_n_storage_conversion
 use mod_b111_soil_n_transport
 implicit none
 private
 integer,parameter,public::MINERAL_OK=0,MINERAL_INVALID=1,MINERAL_BALANCE=2
 type,public::mineral_parameters_t
   type(soil_n_inventory_parameters_t)::inventory
   real(real64),allocatable::dz_cm(:)
   real(real64)::drybd=0d0,sorption=0d0,c_bottom(2)=0d0,c_lateral(2)=0d0,c_top(2)=0d0
 end type
 type,public::mineral_state_t
   private
   type(mineral_parameters_t)::p
   type(soil_n_pool_state_t)::pools
   real(real64)::time=0d0,water=0d0
   integer(int64)::id=0,revision=0
   logical::initialized=.false.
 contains
   procedure::ready=>mineral_ready
   procedure::snapshot=>mineral_snapshot
   procedure::configuration=>mineral_configuration
 end type
 type,public::mineral_receipt_t
   integer::status=MINERAL_INVALID,solution_class(2)=0
   real(real64)::mass_before=0d0,mass_after=0d0,external_in=0d0,external_out=0d0,residual=0d0
   real(real64)::concentration_end(2)=0d0,concentration_average(2)=0d0
   real(real64)::top_requested(2)=0d0,top_actual(2)=0d0,top_unmet(2)=0d0
 end type
 type,public::mineral_restart_t
   private
   integer::schema=1
   type(mineral_state_t)::state
 end type
 public::initialize_mineral,advance_mineral_day,apply_mineral_day_transfer,mineral_parameter_vector,mineral_parameters_valid
 public::export_mineral_restart,restore_mineral_restart,reconstruct_mineral_trusted
contains
 logical function mineral_parameters_valid(p) result(ok)
   type(mineral_parameters_t),intent(in)::p
   real(real64),allocatable::v(:)
   ok=.false.
   if(.not.p%inventory%valid())return
   if(.not.allocated(p%dz_cm))return
   if(size(p%dz_cm)<1.or.size(p%dz_cm)>4096.or.size(p%inventory%nfrac_fom)>64)return
   if(.not.all(ieee_is_finite(p%c_top)))return
   allocate(v(0))
   v=mineral_parameter_vector(p)
   if(.not.all(ieee_is_finite(v)))return
   if(any(p%dz_cm<1d-4).or.any(p%dz_cm>1d4))return
   if(p%inventory%depth_m<1d-3.or.p%inventory%depth_m>100d0)return
   if(abs(sum(p%dz_cm)*.01d0-p%inventory%depth_m)>1d-12)return
   if(any(p%inventory%nfrac_fom>1d0).or.p%inventory%nfrac_biomass>1d0.or.p%inventory%nfrac_humus>1d0)return
   if(p%drybd<0d0.or.p%drybd>4000d0.or.p%sorption<0d0.or.p%sorption>1d0)return
   if(any(p%c_bottom<0d0).or.any(p%c_lateral<0d0).or.any(p%c_bottom>1d6).or.any(p%c_lateral>1d6))return
   if(any(p%c_top<0d0).or.any(p%c_top>1d6))return
   ok=.true.
 end function
 function mineral_parameter_vector(p) result(v)
   type(mineral_parameters_t),intent(in)::p
   real(real64),allocatable::v(:)
   if(.not.allocated(p%dz_cm).or..not.allocated(p%inventory%nfrac_fom))return
   if(.not.all(ieee_is_finite(p%c_top)))return
   v=[p%inventory%depth_m,p%inventory%nfrac_fom,p%inventory%nfrac_biomass,p%inventory%nfrac_humus, &
      p%dz_cm,p%drybd,p%sorption,p%c_bottom,p%c_lateral]
   ! Keep every old zero-top identity byte exact. Nonzero immutable input
   ! has an explicit extension marker and is checked by existing codecs.
   if(any(abs(p%c_top)>0d0))v=[v,-81004d0,p%c_top]
 end function
 logical function bounded_pools(s) result(ok)
   type(soil_n_pool_state_t),intent(in)::s
   ok=.false.
   if(.not.s%valid())return
   if(any(s%fom_kg_m3>1000d0).or.s%biomass_kg_m3>1000d0.or.s%humus_kg_m3>1000d0)return
   if(s%ammonium_n_kg_m2>100d0.or.s%nitrate_n_kg_m2>100d0)return
   ok=.true.
 end function
 subroutine initialize_mineral(p,id,time,water,pools,state,status)
   type(mineral_parameters_t),intent(in)::p
   integer(int64),intent(in)::id
   real(real64),intent(in)::time,water
   type(soil_n_pool_state_t),intent(in)::pools
   type(mineral_state_t),intent(out)::state
   integer,intent(out)::status
   state=mineral_state_t();status=MINERAL_INVALID
   if(.not.mineral_parameters_valid(p).or..not.bounded_pools(pools))return
   if(size(pools%fom_kg_m3)/=size(p%inventory%nfrac_fom))return
   if(.not.all(ieee_is_finite([time,water])))return
   if(id<=0.or.abs(time)>1d8.or.water<1d-4.or.water>1d0)return
   state%p=p;state%id=id;state%time=time;state%water=water;state%pools=pools;state%initialized=.true.
   status=MINERAL_OK
 end subroutine
 logical function mineral_ready(self) result(ok)
   class(mineral_state_t),intent(in)::self
   ok=self%initialized
 end function
 subroutine mineral_snapshot(self,time,water,pools,revision)
   class(mineral_state_t),intent(in)::self
   real(real64),intent(out)::time,water
   type(soil_n_pool_state_t),intent(out)::pools
   integer(int64),intent(out)::revision
   time=self%time;water=self%water;pools=self%pools;revision=self%revision
 end subroutine
 subroutine mineral_configuration(self,p,id)
   class(mineral_state_t),intent(in)::self
   type(mineral_parameters_t),intent(out)::p
   integer(int64),intent(out)::id
   p=self%p;id=self%id
 end subroutine
 subroutine advance_mineral_day(state,t0,t1,water_end,outflow,in_bottom,in_lateral,root_water,receipt,surface_water,historical_top_water,finite_donor_top)
   type(mineral_state_t),intent(inout)::state
   real(real64),intent(in)::t0,t1,water_end,outflow,in_bottom,in_lateral,root_water
   real(real64),intent(in),optional::surface_water,historical_top_water
   logical,intent(in),optional::finite_donor_top
   logical::bounded_top
   real(real64)::surface,top_n_water
   type(mineral_receipt_t),intent(out)::receipt
   type(b111_soil_n_concentration_state_t)::c
   type(b111_soil_n_transport_result_t)::r(2)
   type(soil_n_transfer_t)::x
   type(soil_n_pool_state_t)::trial
   type(soil_n_receipt_t)::budget
   real(real64)::initial(2),sorption(2),mass(2),dz,dt,closure
   integer::i,code
   receipt=mineral_receipt_t()
   bounded_top=.false.;if(present(finite_donor_top))bounded_top=finite_donor_top
   if(bounded_top.and..not.present(historical_top_water))return
   surface=0d0;if(present(surface_water))surface=surface_water
   if(.not.ieee_is_finite(surface))return
   if(abs(surface)>100d0)return
   ! Original management_soil supplies gross atmospheric water to the N
   ! equation independently of evaporation/accepted soil-water storage.
   ! Absent this explicit historical input, preserve the admitted net route.
   top_n_water=max(0d0,surface)
   if(present(historical_top_water))then
     if(.not.ieee_is_finite(historical_top_water))return
     if(abs(historical_top_water)>100d0)return
     if(historical_top_water<0d0.and..not.bounded_top)return
     if(bounded_top.and.historical_top_water>=0d0)return
     top_n_water=historical_top_water
   end if
   if(.not.state%ready())return
   if(.not.all(ieee_is_finite([t0,t1,water_end,outflow,in_bottom,in_lateral,root_water])))return
   if(abs(t0-state%time)>0d0.or.abs(t1-t0-1d0)>0d0.or.abs(t1)>1d8)return
   if(water_end<1d-4.or.water_end>1d0)return
   if(min(outflow,in_bottom,in_lateral,root_water)<0d0.or.max(outflow,in_bottom,in_lateral,root_water)>100d0)return
   if(bounded_top.and.abs(root_water)>0d0)return
   if(outflow>0d0.and.(in_bottom>0d0.or.in_lateral>0d0))return
   dz=state%p%inventory%depth_m;dt=t1-t0
   closure=(water_end-state%water)*dz-dt*(surface+in_bottom+in_lateral-outflow-root_water)
   if(abs(closure)>1d-12)return ! metres; identical 1e-10 cm hard water budget
   call b111_soil_n_concentrations_from_mass(dz,state%water,state%p%drybd,state%p%sorption, &
      state%pools%ammonium_n_kg_m2,state%pools%nitrate_n_kg_m2,c)
   if(c%status/=B111_NSTORE_OK)return
   initial=[c%cnh4_kg_m3,c%cno3_kg_m3];sorption=[state%p%sorption,0d0]
   if(any(initial>1d6))return
   do i=1,2
    if(bounded_top)then
     call evaluate_b111_soil_n_negative_boundary(dz,dt,water_end,state%water,outflow,in_bottom,top_n_water, &
       in_lateral,0d0,0d0,state%p%drybd,sorption(i),state%p%c_bottom(i),state%p%c_top(i), &
       state%p%c_lateral(i),initial(i),r(i))
    else
     call evaluate_b111_soil_n_transport(dz,dt,water_end,state%water,outflow,root_water,in_bottom,top_n_water, &
       in_lateral,0d0,0d0,0d0,state%p%drybd,sorption(i),state%p%c_bottom(i),state%p%c_top(i), &
       state%p%c_lateral(i),initial(i),r(i))
    end if
     if(r(i)%status/=B111_NTRANS_OK)return
     receipt%concentration_end(i)=r(i)%concentration_end
     receipt%concentration_average(i)=r(i)%concentration_average
     receipt%solution_class(i)=r(i)%solution_class
   end do
   call b111_soil_n_mass_from_concentrations(dz,water_end,state%p%drybd,state%p%sorption, &
     r(1)%concentration_end,r(2)%concentration_end,mass(1),mass(2),code)
   if(code/=B111_NSTORE_OK)return
   x%fom_delta_kg_m3=spread(0d0,1,size(state%pools%fom_kg_m3))
   x%ammonium_n_delta_kg_m2=mass(1)-state%pools%ammonium_n_kg_m2
   x%nitrate_n_delta_kg_m2=mass(2)-state%pools%nitrate_n_kg_m2
   x%external_n_input_kg_m2=dt*sum(in_bottom*state%p%c_bottom+in_lateral*state%p%c_lateral+top_n_water*state%p%c_top)
   x%external_n_output_kg_m2=dt*outflow*sum(receipt%concentration_average)
   if(bounded_top)then
    receipt%top_requested=dt*top_n_water*state%p%c_top
    receipt%top_actual=dt*r%top_actual_rate;receipt%top_unmet=r%top_unmet
    x%external_n_input_kg_m2=dt*sum(in_bottom*state%p%c_bottom+in_lateral*state%p%c_lateral)
    x%external_n_output_kg_m2=x%external_n_output_kg_m2-sum(receipt%top_actual)
   end if
   call apply_soil_n_transfer(state%p%inventory,state%pools,x,trial,budget)
   receipt%status=MINERAL_BALANCE
   receipt%mass_before=budget%nitrogen_before_kg_m2;receipt%mass_after=budget%nitrogen_after_kg_m2
   receipt%external_in=budget%external_n_input_kg_m2;receipt%external_out=budget%external_n_output_kg_m2
   receipt%residual=budget%balance_residual_kg_m2
   if(budget%status/=SOIL_N_OK.or..not.bounded_pools(trial))return
   if(state%revision==huge(state%revision))return
   state%pools=trial;state%water=water_end;state%time=t1;state%revision=state%revision+1
   receipt%status=MINERAL_OK
 end subroutine
 ! Budget-checked publication seam: all N stores still have this single owner.
 subroutine apply_mineral_day_transfer(state,t0,t1,water_end,outflow,in_bottom,in_lateral,root_water,x,receipt,surface_water)
   type(mineral_state_t),intent(inout)::state
   real(real64),intent(in)::t0,t1,water_end,outflow,in_bottom,in_lateral,root_water
   type(soil_n_transfer_t),intent(in)::x
   real(real64),intent(in),optional::surface_water
   real(real64)::surface
   type(mineral_receipt_t),intent(out)::receipt
   type(soil_n_pool_state_t)::trial
   type(soil_n_receipt_t)::budget
   real(real64)::closure
   receipt=mineral_receipt_t()
   surface=0d0;if(present(surface_water))surface=surface_water
   if(.not.ieee_is_finite(surface))return
   if(abs(surface)>100d0)return
   if(.not.state%ready())return
   if(.not.all(ieee_is_finite([t0,t1,water_end,outflow,in_bottom,in_lateral,root_water])))return
   if(abs(t0-state%time)>0d0.or.abs(t1-t0-1d0)>0d0.or.abs(t1)>1d8)return
   if(water_end<1d-4.or.water_end>1d0)return
   if(min(outflow,in_bottom,in_lateral,root_water)<0d0.or.max(outflow,in_bottom,in_lateral,root_water)>100d0)return
   if(outflow>0d0.and.(in_bottom>0d0.or.in_lateral>0d0))return
   closure=(water_end-state%water)*state%p%inventory%depth_m-(surface+in_bottom+in_lateral-outflow-root_water)
   if(abs(closure)>1d-12)return
   ! This public seam accepts only bounded transfers, before any donor arithmetic.
   if(.not.allocated(x%fom_delta_kg_m3))return
   if(size(x%fom_delta_kg_m3)/=size(state%pools%fom_kg_m3))return
   if(.not.all(ieee_is_finite(x%fom_delta_kg_m3)))return
   if(.not.all(ieee_is_finite([x%biomass_delta_kg_m3,x%humus_delta_kg_m3,x%ammonium_n_delta_kg_m2, &
      x%nitrate_n_delta_kg_m2,x%external_n_input_kg_m2,x%external_n_output_kg_m2])))return
   if(any(abs(x%fom_delta_kg_m3)>1000d0).or.max(abs(x%biomass_delta_kg_m3),abs(x%humus_delta_kg_m3))>1000d0)return
   if(max(abs(x%ammonium_n_delta_kg_m2),abs(x%nitrate_n_delta_kg_m2))>100d0)return
   if(min(x%external_n_input_kg_m2,x%external_n_output_kg_m2)<0d0)return
   if(max(x%external_n_input_kg_m2,x%external_n_output_kg_m2)>1d9)return
   call apply_soil_n_transfer(state%p%inventory,state%pools,x,trial,budget)
   receipt%status=MINERAL_BALANCE
   receipt%mass_before=budget%nitrogen_before_kg_m2;receipt%mass_after=budget%nitrogen_after_kg_m2
   receipt%external_in=budget%external_n_input_kg_m2;receipt%external_out=budget%external_n_output_kg_m2
   receipt%residual=budget%balance_residual_kg_m2
   if(budget%status/=SOIL_N_OK.or..not.bounded_pools(trial))return
   if(state%revision>=100000000_int64)return
   state%pools=trial;state%water=water_end;state%time=t1;state%revision=state%revision+1
   receipt%status=MINERAL_OK
 end subroutine
 subroutine export_mineral_restart(state,payload,status)
   type(mineral_state_t),intent(in)::state
   type(mineral_restart_t),intent(out)::payload
   integer,intent(out)::status
   payload=mineral_restart_t();status=MINERAL_INVALID
   if(.not.state%ready())return
   payload%state=state;status=MINERAL_OK
 end subroutine
 subroutine restore_mineral_restart(payload,id,state,status)
   type(mineral_restart_t),intent(in)::payload
   integer(int64),intent(in)::id
   type(mineral_state_t),intent(out)::state
   integer,intent(out)::status
   state=mineral_state_t();status=MINERAL_INVALID
   if(payload%schema/=1.or.id/=payload%state%id.or..not.payload%state%ready())return
   state=payload%state;status=MINERAL_OK
 end subroutine
 subroutine reconstruct_mineral_trusted(p,id,revision,time,water,pools,state,status)
   type(mineral_parameters_t),intent(in)::p
   integer(int64),intent(in)::id,revision
   real(real64),intent(in)::time,water
   type(soil_n_pool_state_t),intent(in)::pools
   type(mineral_state_t),intent(out)::state
   integer,intent(out)::status
   call initialize_mineral(p,id,time,water,pools,state,status)
   if(status/=MINERAL_OK)return
   if(revision<0.or.revision>100000000_int64)then
     state=mineral_state_t();status=MINERAL_INVALID;return
   end if
   state%revision=revision
 end subroutine
end module
