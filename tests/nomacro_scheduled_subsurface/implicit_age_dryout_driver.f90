program actual_retained_surface_age_dryout
  use, intrinsic::ieee_arithmetic,only:ieee_is_finite
  use mod_b111_surface_age_budget,only:surface_age_request_t,surface_age_receipt_t, &
    advance_surface_age_budget,SURFACE_AGE_INVALID
  implicit none
  type(surface_age_request_t)::q
  type(surface_age_receipt_t)::r
  real(8)::v(16),water
  integer::unit
  character(1024)::path
  call get_command_argument(1,path)
  open(newunit=unit,file=trim(path),status='old',action='read');read(unit,*)v;close(unit)
  if(.not.all(ieee_is_finite(v)).or.minval(v)<0d0)error stop 'Invalid actual exported surface age request'
  q%dt_day=v(1);q%pond_start_cm=v(2);q%pond_end_cm=v(3);q%pond_age_stock_cm_day=v(4)
  q%rain_depth_cm=v(5);q%irrigation_depth_cm=v(6);q%runon_depth_cm=v(7)
  q%soil_return_depth_cm=v(8);q%soil_return_age_day=v(9)
  q%rain_age_day=v(10);q%irrigation_age_day=v(11);q%runon_age_day=v(12)
  q%infiltration_depth_cm=v(13);q%runoff_depth_cm=v(14);q%evaporation_depth_cm=v(15)
  water=q%pond_end_cm-q%pond_start_cm-q%rain_depth_cm-q%irrigation_depth_cm-q%runon_depth_cm &
    -q%soil_return_depth_cm+q%infiltration_depth_cm+q%runoff_depth_cm+q%evaporation_depth_cm
  if(abs(water)>1d-10)error stop 'Actual surface water observation does not conserve'
  if(q%pond_end_cm+q%infiltration_depth_cm+q%runoff_depth_cm/=0d0.or.q%pond_age_stock_cm_day<=1d-10) &
    error stop 'Actual retained-age no-owner condition not reproduced'
  call advance_surface_age_budget(q,r)
  if(r%status/=SURFACE_AGE_INVALID.or.r%status/=int(v(16)))error stop 'Actual original retained-age refusal differs'
  write(*,'(a,1x,i0,2(1x,es25.17e3))')'ACTUAL_RETAINED_SURFACE_AGE_DRYOUT_REFUSAL_REPRODUCED',r%status,water,q%pond_age_stock_cm_day
end program
