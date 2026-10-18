program test_surface_age_budget
  use iso_fortran_env, only: real64
  use mod_b111_surface_age_budget
  implicit none
  type(surface_age_request_t)::q
  type(surface_age_receipt_t)::r
  real(real64)::tol
  tol=1.0e-11_real64
  q%dt_day=0.25_real64
  q%pond_start_cm=1.0_real64
  q%pond_end_cm=1.5_real64
  q%pond_age_stock_cm_day=2.0_real64
  q%rain_depth_cm=0.6_real64
  q%irrigation_depth_cm=0.3_real64
  q%runon_depth_cm=0.4_real64
  q%rain_age_day=0.0_real64
  q%irrigation_age_day=0.2_real64
  q%runon_age_day=2.0_real64
  q%infiltration_depth_cm=0.4_real64
  q%runoff_depth_cm=0.2_real64
  q%evaporation_depth_cm=0.2_real64
  call advance_surface_age_budget(q,r)
  if(r%status/=SURFACE_AGE_OK) error stop 'positive gross case rejected'
  if(abs(r%residual_cm_day)>tol) error stop 'age mass balance'
  if(abs(r%pond_end_stock_cm_day-1.5_real64*r%mixed_age_day)>tol) error stop 'pond owner'
  if(abs(r%infiltration_age_export_cm_day-0.4_real64*r%mixed_age_day)>tol) error stop 'soil transfer'
  if(abs(r%runoff_age_export_cm_day-0.2_real64*r%mixed_age_day)>tol) error stop 'runoff export'
  if(abs(r%age_production_cm_day-0.3125_real64)>tol) error stop 'age source'
  ! Evaporation removes water, never age directly.
  if(abs(r%pond_end_stock_cm_day+r%infiltration_age_export_cm_day+ &
      r%runoff_age_export_cm_day-(q%pond_age_stock_cm_day+ &
      r%external_age_input_cm_day+r%age_production_cm_day))>tol) error stop 'evaporated age'
  q%runon_depth_cm=-0.1_real64
  call advance_surface_age_budget(q,r)
  if(r%status/=SURFACE_AGE_INVALID) error stop 'negative runon accepted'
  q%runon_depth_cm=0.4_real64
  q%pond_end_cm=1.4_real64
  call advance_surface_age_budget(q,r)
  if(r%status/=SURFACE_AGE_BALANCE) error stop 'water budget drift accepted'
  ! An all-evaporation dry-down with old age stock cannot silently
  ! destroy the remaining age amount: it is currently unsupported.
  q=surface_age_request_t()
  q%dt_day=0.1_real64
  q%pond_start_cm=1.0_real64
  q%pond_age_stock_cm_day=3.0_real64
  q%evaporation_depth_cm=1.0_real64
  call advance_surface_age_budget(q,r)
  if(r%status==SURFACE_AGE_OK) error stop 'full evaporation destroyed age stock'
  q=surface_age_request_t()
  q%dt_day=0.1_real64
  call advance_surface_age_budget(q,r)
  if(r%status/=SURFACE_AGE_OK) error stop 'dry zero case'
  if(r%pond_end_stock_cm_day>0.0_real64) error stop 'dry phantom amount'
  q%pond_age_stock_cm_day=1.0_real64
  call advance_surface_age_budget(q,r)
  if(r%status/=SURFACE_AGE_INVALID) error stop 'dry stock without water accepted'
  print *, 'MC_SOL01_SURFACE_AGE_BUDGET=PASS'
end program
