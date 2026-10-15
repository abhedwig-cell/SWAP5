module mod_crop_soil_n_calendar_day
 use iso_fortran_env,only:real64
 use mod_b111_amendment_calendar
 use mod_b111_soil_n_addition,only:b111_soil_n_material_t,b111_soil_n_split_parameters_t
 use mod_crop_soil_n_material_day
 use mod_crop_soil_n_day,only:crop_soil_state_t
 use mod_soil_n_day_environment,only:soil_n_day_environment_t
 use mod_wofost_one_day_structural_evolution,only:wofost_one_day_forcing_t
 implicit none
 private
 public::advance_crop_soil_calendar_day,select_calendar_materials
contains
 subroutine select_calendar_materials(calendar,t0,t1,items,status)
  type(amendment_calendar_t),intent(in)::calendar
  real(real64),intent(in)::t0,t1
  type(soil_n_material_input_t),allocatable,intent(out)::items(:)
  integer,intent(out)::status
  type(b111_soil_n_material_t),allocatable::selected(:)
  integer::index,i
  call calendar%select_day(t0,t1,selected,index,status)
  allocate(items(size(selected)))
  if(status/=AMCAL_OK)return
  do i=1,size(selected)
   items(i)%kind=MATERIAL_AMENDMENT;items(i)%material=selected(i)
  end do
 end subroutine
 subroutine advance_crop_soil_calendar_day(state,t0,t1,water_end,outflow,in_bottom,in_lateral,root_water, &
     potential_cm,weather,calendar,split,r,environment)
  type(crop_soil_state_t),intent(inout)::state
  real(real64),intent(in)::t0,t1,water_end,outflow,in_bottom,in_lateral,root_water,potential_cm
  type(wofost_one_day_forcing_t),intent(in)::weather
  type(amendment_calendar_t),intent(in)::calendar
  type(b111_soil_n_split_parameters_t),intent(in)::split
  type(material_day_receipt_t),intent(out)::r
  type(soil_n_day_environment_t),intent(in),optional::environment
  type(soil_n_material_input_t),allocatable::items(:)
  integer::code
  r=material_day_receipt_t()
  call select_calendar_materials(calendar,t0,t1,items,code)
  if(code/=AMCAL_OK)return
  call advance_crop_soil_material_day(state,t0,t1,water_end,outflow,in_bottom,in_lateral,root_water, &
    potential_cm,weather,items,split,r,environment)
 end subroutine
end module
