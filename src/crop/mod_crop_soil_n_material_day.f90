! Material forcing is tentative inside one already-owned daily interval.
module mod_crop_soil_n_material_day
 use iso_fortran_env,only:real64,int64
 use ieee_arithmetic,only:ieee_is_finite
 use mod_b111_soil_n_addition
 use mod_soil_n_pool_state
 use mod_b111_soil_n_reactive_owner
 use mod_b111_soil_n_mineral_owner,only:MINERAL_OK
 use mod_crop_soil_n_day
 use mod_crop_soil_n_configuration
 use mod_wofost81_crop_owner_state
 use mod_wofost_one_day_structural_evolution,only:wofost_one_day_forcing_t
 use mod_soil_n_day_environment,only:soil_n_day_environment_t
 use mod_crop_senescence_residue,only:crop_residue_pending_t
 implicit none
 private
 integer,parameter,public::MATERIAL_OK=0,MATERIAL_INVALID=1,MATERIAL_BUILD=2,MATERIAL_TRANSFER=3, &
   MATERIAL_DAY=4,MATERIAL_BALANCE=5,MATERIAL_AMENDMENT=1,MATERIAL_RESIDUE=2
 type,public::soil_n_material_input_t
  integer::kind=0
  type(b111_soil_n_material_t)::material
 end type
 type,public::material_day_receipt_t
  integer::status=MATERIAL_INVALID,material_count=0
  real(real64)::gross_n=0d0,volatilized_n=0d0,mass_before=0d0,residual=0d0
  type(crop_soil_receipt_t)::day
 end type
 public::stage_crop_soil_materials,check_crop_soil_material_day,advance_crop_soil_material_day
contains
 subroutine stage_crop_soil_materials(committed,t0,items,split,candidate,r)
  type(crop_soil_state_t),intent(in)::committed
  real(real64),intent(in)::t0
  type(soil_n_material_input_t),intent(in)::items(:)
  type(b111_soil_n_split_parameters_t),intent(in)::split
  type(crop_soil_state_t),intent(out)::candidate
  type(material_day_receipt_t),intent(out)::r
  type(reactive_state_t)::soil,reconstructed
  type(reactive_parameters_t)::p
  type(wofost81_crop_owner_state_t)::crop,staged_crop
  type(wofost81_harvest_retired_t)::retired
  type(crop_n_configuration_t)::cp
  type(soil_n_pool_state_t)::pools,next,original_pools
  type(soil_n_transfer_t)::x
  type(soil_n_receipt_t)::budget
  integer(int64)::sid,cid,revision
  real(real64)::clock,water,want(8),splitv(5)
  integer::i,code
  type(crop_residue_pending_t)::pending
  logical::has_pending,has_retired
  real(real64)::delta_n,delta_om
  candidate=committed;r=material_day_receipt_t()
  if(.not.committed%ready().or..not.ieee_is_finite(t0))return
  if(size(items)>64)return
  call committed%snapshot(soil,crop);call soil%snapshot(clock,water,pools,revision)
  if(clock/=t0)return
  call soil%configuration(p,sid);call committed%configuration(cp,cid)
  original_pools=pools
  r%mass_before=pools%nitrogen_total(p%mineral%inventory)+crop_n_live(crop)
  if(size(items)==0)then;r%status=MATERIAL_OK;return;end if
  splitv=[split%nfrac_fom_min,split%nfrac_fom_max,split%nfrac_humus,split%asfa_min,split%asfa_max]
  if(.not.all(ieee_is_finite(splitv)))return
  if(size(p%mineral%inventory%nfrac_fom)/=8)return
  want=[split%nfrac_fom_max,split%nfrac_fom_min,split%nfrac_fom_max,split%nfrac_fom_min, &
        split%nfrac_fom_max,split%nfrac_fom_min,split%nfrac_fom_max,split%nfrac_fom_min]
  if(any(p%mineral%inventory%nfrac_fom/=want).or.p%mineral%inventory%nfrac_humus/=split%nfrac_humus)return
  want=[split%asfa_min,split%asfa_min,split%asfa_max,split%asfa_max, &
        split%asfa_min,split%asfa_min,split%asfa_max,split%asfa_max]
  if(any(abs(p%organic_reference%asfa_fom_bio+p%organic_reference%asfa_fom_hum-want)>1d-12))return
  do i=1,size(items)
   r%status=MATERIAL_BUILD
   select case(items(i)%kind)
   case(MATERIAL_AMENDMENT)
    call build_b111_amendment_transfer(p%mineral%inventory%depth_m,items(i)%material,split,x,code)
   case(MATERIAL_RESIDUE)
    call build_b111_residue_transfer(p%mineral%inventory%depth_m,items(i)%material,split,x,code)
   case default
    return
   end select
   if(code/=B111_NADD_OK)return
   r%status=MATERIAL_TRANSFER
   call apply_soil_n_transfer(p%mineral%inventory,pools,x,next,budget)
   if(budget%status/=SOIL_N_OK)return
   pools=next;r%gross_n=r%gross_n+budget%external_n_input_kg_m2
   r%volatilized_n=r%volatilized_n+budget%external_n_output_kg_m2
  end do
  if(crop%harvest_retired())then
   ! Source material changes whole-system totals without advancing the
   ! retired crop clock. Stage in existing owners before any acceptance.
   call crop%retired_snapshot(retired,has_retired)
   if(.not.has_retired)return
   delta_n=pools%nitrogen_total(p%mineral%inventory)-original_pools%nitrogen_total(p%mineral%inventory)
   delta_om=(sum(pools%fom_kg_m3-original_pools%fom_kg_m3)+ &
      pools%biomass_kg_m3-original_pools%biomass_kg_m3+ &
      pools%humus_kg_m3-original_pools%humus_kg_m3)*p%mineral%inventory%depth_m
   call stage_wofost81_retired_material_totals(crop,clock, &
      retired%continuation_totals+[delta_n,delta_om],staged_crop,code)
   if(code/=0)return
   crop=staged_crop
  end if
  call reconstruct_reactive_trusted(p,sid,revision,clock,water,pools,reconstructed,code)
  if(code/=MINERAL_OK)return
  call committed%pending_snapshot(pending,has_pending)
  if(has_pending)then
   call initialize_crop_soil(reconstructed,crop,cp,cid,candidate,code,pending)
  else
   call initialize_crop_soil(reconstructed,crop,cp,cid,candidate,code)
  end if
  if(code/=CROP_SOIL_OK)then;candidate=committed;return;end if
  r%material_count=size(items);r%status=MATERIAL_OK
 end subroutine
 subroutine check_crop_soil_material_day(candidate,day,r)
  type(crop_soil_state_t),intent(in)::candidate
  type(crop_soil_receipt_t),intent(in)::day
  type(material_day_receipt_t),intent(inout)::r
  type(reactive_state_t)::soil
  type(reactive_parameters_t)::p
  type(wofost81_crop_owner_state_t)::crop
  type(soil_n_pool_state_t)::pools
  integer(int64)::id,revision
  real(real64)::clock,water,final,input,output
  r%day=day;r%status=MATERIAL_DAY
  if(day%status/=CROP_SOIL_OK.or..not.candidate%ready())return
  call candidate%snapshot(soil,crop);call soil%configuration(p,id);call soil%snapshot(clock,water,pools,revision)
  final=pools%nitrogen_total(p%mineral%inventory)+crop_n_live(crop)
  input=r%gross_n+day%soil%external_in+day%fixation_kg_m2
  output=r%volatilized_n+day%soil%external_out-day%internal_supply_kg_m2+day%crop_loss_kg_m2
  r%residual=r%mass_before+input-final-output;r%status=MATERIAL_BALANCE
  if(.not.ieee_is_finite(r%residual))return
  if(abs(r%residual)>1d-12*max(1d0,r%mass_before,input,final,output))return
  r%status=MATERIAL_OK
 end subroutine
 subroutine advance_crop_soil_material_day(state,t0,t1,water_end,outflow,in_bottom,in_lateral,root_water, &
     potential_cm,weather,items,split,r,environment)
  type(crop_soil_state_t),intent(inout)::state
  real(real64),intent(in)::t0,t1,water_end,outflow,in_bottom,in_lateral,root_water,potential_cm
  type(wofost_one_day_forcing_t),intent(in)::weather
  type(soil_n_material_input_t),intent(in)::items(:)
  type(b111_soil_n_split_parameters_t),intent(in)::split
  type(material_day_receipt_t),intent(out)::r
  type(soil_n_day_environment_t),optional,intent(in)::environment
  type(crop_soil_state_t)::trial
  type(crop_soil_receipt_t)::day
  call stage_crop_soil_materials(state,t0,items,split,trial,r)
  if(r%status/=MATERIAL_OK)return
  call advance_crop_soil_day(trial,t0,t1,water_end,outflow,in_bottom,in_lateral,root_water,potential_cm,weather,day,environment)
  call check_crop_soil_material_day(trial,day,r)
  if(r%status==MATERIAL_OK)state=trial
 end subroutine
end module
