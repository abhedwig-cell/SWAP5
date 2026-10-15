module mod_crop_soil_n_senescence_day
 use iso_fortran_env,only:real64,int64
 use ieee_arithmetic,only:ieee_is_finite
 use mod_crop_senescence_residue
 use mod_b111_soil_n_addition
 use mod_crop_soil_n_day
 use mod_crop_soil_n_material_day
 use mod_crop_soil_n_configuration
 use mod_b111_soil_n_reactive_owner
 use mod_soil_n_pool_state
 use mod_wofost81_crop_owner_state
 use mod_wofost_one_day_structural_evolution,only:wofost_one_day_forcing_t
 use mod_soil_n_day_environment,only:soil_n_day_environment_t
 implicit none
 private
 integer,parameter,public::SENESCENCE_DAY_OK=0,SENESCENCE_DAY_INVALID=1,SENESCENCE_DAY_MATERIAL=2, &
  SENESCENCE_DAY_CROP=3,SENESCENCE_DAY_RETURN=4,SENESCENCE_DAY_BALANCE=5
 type,public::senescence_day_receipt_t
  integer::status=SENESCENCE_DAY_INVALID
  type(material_day_receipt_t)::materials
  real(real64)::initial_n=0d0,incorporated_n=0d0,pending_n=0d0,whole_n_residual=0d0
 end type
 public::prepare_senescence_day,finish_senescence_day,advance_crop_soil_senescence_day,pending_incorporation_valid
contains
 real(real64)function coupled_total(state)result(n)
  type(crop_soil_state_t),intent(in)::state
  type(reactive_state_t)::soil
  type(wofost81_crop_owner_state_t)::crop
  type(reactive_parameters_t)::p
  type(soil_n_pool_state_t)::pools
  type(crop_residue_pending_t)::pending
  integer(int64)::id,rev
  real(real64)::clock,water
  logical::has
  call state%snapshot(soil,crop);call soil%configuration(p,id);call soil%snapshot(clock,water,pools,rev)
  n=pools%nitrogen_total(p%mineral%inventory)+crop_n_live(crop)
  call state%pending_snapshot(pending,has)
  if(has)n=n+pending%nitrogen_kg_m2()
 end function
 subroutine stage_pending(state,pending,candidate,status)
  type(crop_soil_state_t),intent(in)::state
  type(crop_residue_pending_t),intent(in)::pending
  type(crop_soil_state_t),intent(out)::candidate
  integer,intent(out)::status
  type(b111_soil_n_material_t)::m(3)
  type(soil_n_material_input_t)::items(3)
  type(b111_soil_n_split_parameters_t)::split
  type(material_day_receipt_t)::r
  type(reactive_state_t)::soil
  type(reactive_parameters_t)::p
  type(wofost81_crop_owner_state_t)::crop
  integer(int64)::id
  integer::i
  candidate=state;status=SENESCENCE_DAY_RETURN
  call build_pending_residue_materials(pending,m,i);if(i/=SENESCENCE_OK)return
  call state%snapshot(soil,crop);call soil%configuration(p,id)
  if(size(p%mineral%inventory%nfrac_fom)/=8)return
  split%nfrac_fom_max=p%mineral%inventory%nfrac_fom(1);split%nfrac_fom_min=p%mineral%inventory%nfrac_fom(2)
  split%nfrac_humus=p%mineral%inventory%nfrac_humus
  split%asfa_min=p%organic_reference%asfa_fom_bio(1)+p%organic_reference%asfa_fom_hum(1)
  split%asfa_max=p%organic_reference%asfa_fom_bio(3)+p%organic_reference%asfa_fom_hum(3)
  do i=1,3;items(i)%kind=MATERIAL_RESIDUE;items(i)%material=m(i);end do
  call stage_crop_soil_materials(state,pending%clock,items,split,candidate,r)
  if(r%status/=MATERIAL_OK)return
  if(abs(r%gross_n-pending%nitrogen_kg_m2())>1d-12.or.r%volatilized_n/=0d0)return
  status=SENESCENCE_DAY_OK
 end subroutine
 logical function pending_incorporation_valid(state)result(ok)
  type(crop_soil_state_t),intent(in)::state
  type(crop_residue_pending_t)::pending
  type(crop_soil_state_t)::probe
  integer::code
  logical::has
  ok=state%ready();if(.not.ok)return
  call state%pending_snapshot(pending,has);if(.not.has)return
  call stage_pending(state,pending,probe,code);ok=code==SENESCENCE_DAY_OK
 end function
 subroutine prepare_senescence_day(state,t0,candidate,r)
  type(crop_soil_state_t),intent(in)::state
  real(real64),intent(in)::t0
  type(crop_soil_state_t),intent(out)::candidate
  type(senescence_day_receipt_t),intent(out)::r
  type(crop_residue_pending_t)::pending
  type(reactive_state_t)::soil
  type(wofost81_crop_owner_state_t)::crop
  type(crop_n_configuration_t)::cp
  type(crop_soil_state_t)::cleared,staged
  integer(int64)::id,rev
  type(soil_n_pool_state_t)::pools
  real(real64)::clock,water
  integer::code
  logical::has
  candidate=state;r=senescence_day_receipt_t()
  if(.not.state%ready().or..not.ieee_is_finite(t0))return
  call state%snapshot(soil,crop);call soil%snapshot(clock,water,pools,rev);if(clock/=t0)return
  r%initial_n=coupled_total(state)
  call state%pending_snapshot(pending,has)
  if(has)then
   call state%configuration(cp,id);call initialize_crop_soil(soil,crop,cp,id,cleared,code);if(code/=0)return
   call stage_pending(cleared,pending,staged,code);if(code/=0)return
   candidate=staged;r%incorporated_n=pending%nitrogen_kg_m2()
  end if
  r%status=SENESCENCE_DAY_OK
 end subroutine
 subroutine finish_senescence_day(day_state,t1,policy,r,candidate)
  type(crop_soil_state_t),intent(in)::day_state
  real(real64),intent(in)::t1
  type(crop_senescence_policy_t),intent(in)::policy
  type(senescence_day_receipt_t),intent(inout)::r
  type(crop_soil_state_t),intent(out)::candidate
  type(crop_residue_pending_t)::pending
  type(crop_soil_state_t)::probe
  type(reactive_state_t)::soil
  type(wofost81_crop_owner_state_t)::crop
  type(crop_n_configuration_t)::cp
  integer(int64)::id
  real(real64)::dm(3),n(3),external_in,external_out,final
  integer::code
  candidate=day_state;r%status=SENESCENCE_DAY_CROP
  if(r%materials%status/=MATERIAL_OK)return
  associate(d=>r%materials%day)
   dm=[d%prepared%drrt,d%prepared%drlv,d%prepared%drst]
   n=[d%crop%rndeathrt,d%crop%rndeathlv,d%crop%rndeathst]
   if(abs(d%prepared%leaf_diagnostics%applied_leaf_death-dm(2))>1d-12)return
   call create_crop_residue_pending(t1,dm,n,policy,pending,code)
   r%status=SENESCENCE_DAY_RETURN;if(code/=SENESCENCE_OK)return
   if(abs(pending%nitrogen_kg_m2()-d%crop_loss_kg_m2)>1d-12)return
   call stage_pending(day_state,pending,probe,code);if(code/=0)return
   call day_state%snapshot(soil,crop);call day_state%configuration(cp,id)
   if(any(dm>0d0))then
    call initialize_crop_soil(soil,crop,cp,id,candidate,code,pending)
   else
    candidate=day_state;code=CROP_SOIL_OK
   end if
   if(code/=0)return
   r%pending_n=pending%nitrogen_kg_m2()
   external_in=r%materials%gross_n+d%soil%external_in+d%fixation_kg_m2
   external_out=r%materials%volatilized_n+d%soil%external_out-d%internal_supply_kg_m2
   final=coupled_total(candidate);r%whole_n_residual=r%initial_n+external_in-final-external_out
   r%status=SENESCENCE_DAY_BALANCE
   if(.not.ieee_is_finite(r%whole_n_residual))return
   if(abs(r%whole_n_residual)>1d-12*max(1d0,r%initial_n,final,external_in,external_out))return
  end associate
  r%status=SENESCENCE_DAY_OK
 end subroutine
 subroutine advance_crop_soil_senescence_day(state,t0,t1,water_end,outflow,in_bottom,in_lateral,root_water, &
     potential_cm,weather,items,split,policy,r,environment)
  type(crop_soil_state_t),intent(inout)::state
  real(real64),intent(in)::t0,t1,water_end,outflow,in_bottom,in_lateral,root_water,potential_cm
  type(wofost_one_day_forcing_t),intent(in)::weather
  type(soil_n_material_input_t),intent(in)::items(:)
  type(b111_soil_n_split_parameters_t),intent(in)::split
  type(crop_senescence_policy_t),intent(in)::policy
  type(senescence_day_receipt_t),intent(out)::r
  type(soil_n_day_environment_t),optional,intent(in)::environment
  type(crop_soil_state_t)::trial,completed
  call prepare_senescence_day(state,t0,trial,r);if(r%status/=0)return
  call advance_crop_soil_material_day(trial,t0,t1,water_end,outflow,in_bottom,in_lateral,root_water,potential_cm, &
    weather,items,split,r%materials,environment)
  call finish_senescence_day(trial,t1,policy,r,completed)
  if(r%status==0)state=completed
 end subroutine
end module
