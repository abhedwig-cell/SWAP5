program age_dryout_probe
  use iso_fortran_env,only:real64
  use mod_b111_surface_age_budget
  implicit none
  type(surface_age_request_t)::q,wet,empty
  type(surface_age_receipt_t)::r,again
  real(real64)::water
  ! Actual failed-period water depths; dt and AGE stock are declared controlled
  ! probe values, not a reconstruction of the unlogged failed microstep.
  q%dt_day=0.01_real64
  q%pond_start_cm=2.7309710278648297e-4_real64
  q%pond_end_cm=0.0_real64
  q%soil_return_depth_cm=7.0565128332235306e-4_real64
  q%evaporation_depth_cm=9.7874838610883608e-4_real64
  q%pond_age_stock_cm_day=0.01_real64
  water=q%pond_end_cm-q%pond_start_cm-q%soil_return_depth_cm+q%evaporation_depth_cm
  if(abs(water)>1e-10_real64)error stop 'Probe water closure invalid'
  call advance_surface_age_budget(q,r)
  if(r%status/=SURFACE_AGE_INVALID)error stop 'Expected retained-AGE zero-capacity refusal'
  write(*,'(a,1x,i0,3(1x,es25.17e3))')'ACTUAL_DRY_REFUSAL',r%status,water,q%dt_day,q%pond_age_stock_cm_day
  wet=q;wet%pond_end_cm=1e-4_real64
  wet%evaporation_depth_cm=q%evaporation_depth_cm-wet%pond_end_cm
  call advance_surface_age_budget(wet,r)
  if(r%status/=SURFACE_AGE_OK.or.abs(r%residual_cm_day)>8192*epsilon(1d0))error stop 'Positive-capacity control refused'
  write(*,'(a,1x,i0,3(1x,es25.17e3))')'ACTUAL_WET_CONTROL',r%status,r%residual_cm_day,r%pond_end_stock_cm_day,r%age_production_cm_day
  empty=q;empty%pond_start_cm=0d0;empty%pond_age_stock_cm_day=0d0
  empty%evaporation_depth_cm=empty%soil_return_depth_cm
  call advance_surface_age_budget(empty,r)
  if(r%status/=SURFACE_AGE_OK.or.r%pond_end_stock_cm_day/=0d0)error stop 'Zero-stock control refused'
  call advance_surface_age_budget(q,again)
  if(again%status/=SURFACE_AGE_INVALID.or.q%pond_age_stock_cm_day/=0.01_real64)error stop 'Probe mutated its origin'
  write(*,'(a)')'ACTUAL_PRODUCTION_RETAINED_AGE_DRY_DOMAIN_AND_CONTROLS_PASS'
end program
