module mod_crop_soil_n_calendar_day
 use iso_fortran_env,only:real64
 use mod_soil_n_amendment_calendar
 use mod_b111_soil_n_addition,only:b111_soil_n_material_t,b111_soil_n_split_parameters_t
 use mod_crop_soil_n_material_day,only:soil_n_material_input_t,MATERIAL_AMENDMENT, &
  material_day_receipt_t,MATERIAL_OK,stage_crop_soil_materials,check_crop_soil_material_day
 use mod_crop_soil_n_day,only:crop_soil_state_t,crop_soil_receipt_t,advance_crop_soil_fallow_day,CROP_SOIL_OK
 use mod_crop_soil_n_senescence_day
 use mod_crop_senescence_residue,only:crop_senescence_policy_t
 use mod_wofost_one_day_structural_evolution,only:wofost_one_day_forcing_t
 use mod_soil_n_day_environment,only:soil_n_day_environment_t
 implicit none
 private
 public::select_calendar_material_batch,advance_crop_soil_calendar_day,advance_crop_soil_fallow_calendar_day
contains
 subroutine select_calendar_material_batch(plan,t0,t1,items,status)
  type(soil_n_amendment_calendar_t),intent(in)::plan
  real(real64),intent(in)::t0,t1
  type(soil_n_material_input_t),allocatable,intent(out)::items(:)
  integer,intent(out)::status
  type(b111_soil_n_material_t),allocatable::materials(:)
  integer,allocatable::indices(:)
  integer::i
  call select_soil_n_amendments(plan,t0,t1,materials,indices,status)
  allocate(items(size(materials)))
  do i=1,size(materials)
   items(i)%kind=MATERIAL_AMENDMENT;items(i)%material=materials(i)
  end do
 end subroutine
 subroutine advance_crop_soil_calendar_day(state,t0,t1,water_end,outflow,in_bottom,in_lateral,root_water, &
    potential_cm,weather,plan,split,policy,r,environment)
  type(crop_soil_state_t),intent(inout)::state
  real(real64),intent(in)::t0,t1,water_end,outflow,in_bottom,in_lateral,root_water,potential_cm
  type(wofost_one_day_forcing_t),intent(in)::weather
  type(soil_n_amendment_calendar_t),intent(in)::plan
  type(b111_soil_n_split_parameters_t),intent(in)::split
  type(crop_senescence_policy_t),intent(in)::policy
  type(senescence_day_receipt_t),intent(out)::r
  type(soil_n_day_environment_t),intent(in),optional::environment
  type(soil_n_material_input_t),allocatable::items(:)
  integer::code
  r=senescence_day_receipt_t()
  call select_calendar_material_batch(plan,t0,t1,items,code)
  if(code/=N_CALENDAR_OK)return
  call advance_crop_soil_senescence_day(state,t0,t1,water_end,outflow,in_bottom,in_lateral,root_water, &
   potential_cm,weather,items,split,policy,r,environment)
 end subroutine
 subroutine advance_crop_soil_fallow_calendar_day(state,t0,t1,water_end,outflow,in_bottom,in_lateral, &
   plan,split,r,environment)
  ! Atomic day: calendar amendments and crop-free reactions share the existing
  ! committed Soil-N owner. Failed stages do not replace the input state.
  type(crop_soil_state_t),intent(inout)::state
  real(real64),intent(in)::t0,t1,water_end,outflow,in_bottom,in_lateral
  type(soil_n_amendment_calendar_t),intent(in)::plan
  type(b111_soil_n_split_parameters_t),intent(in)::split
  type(material_day_receipt_t),intent(out)::r
  type(soil_n_day_environment_t),intent(in),optional::environment
  type(crop_soil_state_t)::trial
  type(crop_soil_receipt_t)::day
  type(soil_n_material_input_t),allocatable::items(:)
  integer::code
  r=material_day_receipt_t()
  call select_calendar_material_batch(plan,t0,t1,items,code)
  if(code/=N_CALENDAR_OK)return
  call stage_crop_soil_materials(state,t0,items,split,trial,r)
  if(r%status/=MATERIAL_OK)return
  call advance_crop_soil_fallow_day(trial,t0,t1,water_end,outflow,in_bottom,in_lateral, &
    0d0,0d0,day,environment)
  call check_crop_soil_material_day(trial,day,r)
  if(r%status==MATERIAL_OK)state=trial
 end subroutine
end module
