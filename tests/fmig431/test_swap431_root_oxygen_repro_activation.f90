program test_swap431_root_oxygen_repro_activation
  use mod_fmr_bartholomeus_activation
  implicit none
  type(fmr_bartholomeus_selection_t)::c
  integer::route,wmode
  call select_fmr_bartholomeus_route(c,route,wmode)
  if(route/=FMR_BARTHOLOMEUS_DISABLED)error stop 1
  c%oxygen_mode=FMR_OXYGEN_BARTHOLOMEUS
  c%oxygen_type=FMR_OXYGEN_TYPE_BARTHOLOMEUS
  c%hydraulic_waterfilm_mode=FMR_HYDRAULICS_ANALYTICAL_MVG
  call select_fmr_bartholomeus_route(c,route,wmode)
  if(route/=FMR_BARTHOLOMEUS_ACTIVE)error stop 2
  c%oxygen_type=FMR_OXYGEN_TYPE_REPRODUCTION
  c%hydraulic_waterfilm_mode=99
  call select_fmr_bartholomeus_route(c,route,wmode)
  if(route/=FMR_BARTHOLOMEUS_REPRODUCTION)error stop 3
  c%oxygen_type=99
  call select_fmr_bartholomeus_route(c,route,wmode)
  if(route/=FMR_BARTHOLOMEUS_UNSUPPORTED)error stop 4
  print '(a)','SW431_ROOT_OXYGEN_REPRO_ACTIVATION=PASS'
end program
