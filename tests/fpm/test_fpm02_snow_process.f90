program test_fpm02_snow_process
  use iso_fortran_env, only: real64, int64
  use mod_snow_process
  implicit none
  type(snow_parameters_t) :: p
  type(snow_state_t) :: committed, untouched
  type(snow_forcing_t) :: f
  type(snow_result_t) :: a, replay, rejected

  p%suppress_sublimation=0; p%melt_coefficient=0.15_real64
  committed%snow_water_storage=3.0_real64; committed%liquid_water_storage=0.1_real64
  f%snowfall_input=0.4_real64; f%rain_on_snow_input=0.1_real64
  f%mean_air_temperature=2.0_real64; f%potential_soil_evaporation=0.2_real64
  f%reduced_soil_evaporation=0.15_real64; f%ponding_evaporation=0.25_real64
  untouched=committed
  call evaluate_snow_reference_call(p,committed,f,100.25_real64,101.25_real64,a)
  call evaluate_snow_reference_call(p,committed,f,100.25_real64,101.25_real64,replay)
  if(a%status/=SNOW_OK) error stop 'admitted call rejected'
  if(.not.same_state(committed,untouched)) error stop 'committed state mutated'
  if(.not.same_result(a,replay)) error stop 'replay differs'
  if(abs(a%unrounded_mass_residual)>128.0_real64*epsilon(1.0_real64)*3.0_real64) error stop 'mass residual'
  call evaluate_snow_reference_call(p,committed,f,1.0_real64,1.5_real64,rejected)
  if(rejected%status/=SNOW_UNADMITTED_DURATION) error stop 'subdaily did not fail closed'
  if(.not.same_state(rejected%candidate_state,committed)) error stop 'rejected candidate changed'
  print '(A)', 'FPM02_SNOW_PROCESS_PASS'
contains
  logical function same_state(x,y)
    type(snow_state_t),intent(in)::x,y
    same_state=transfer(x%snow_water_storage,0_int64)==transfer(y%snow_water_storage,0_int64).and.&
      transfer(x%liquid_water_storage,0_int64)==transfer(y%liquid_water_storage,0_int64)
  end function
  logical function same_result(x,y)
    type(snow_result_t),intent(in)::x,y
    same_result=same_state(x%candidate_state,y%candidate_state).and.&
      transfer(x%melt,0_int64)==transfer(y%melt,0_int64).and.&
      transfer(x%sublimation,0_int64)==transfer(y%sublimation,0_int64)
  end function
end program
