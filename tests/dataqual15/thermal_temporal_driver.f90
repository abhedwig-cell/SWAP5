program thermal_temporal_contract
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
 use mod_fmr_serialized_reference_backend,only:evaluate_fmr_thermal_temporal_error, &
  fmr_serialized_reference_backend_t,fmr_b110_physical_state_t
 use mod_fixed_flux_top_boundary_provider,only:fixed_flux_top_boundary_provider_t
 use mod_soil_temperature_contract,only:initialize_soil_temperature_state,copy_soil_temperature_profile
 implicit none
 real(real64)::thermal_tolerance,water_tolerance
 type(fmr_serialized_reference_backend_t)::backend
 type(fixed_flux_top_boundary_provider_t),target::top
 type(fmr_b110_physical_state_t)::full,half
 real(real64),allocatable::before(:),after(:)
 real(real64)::water,error,nan
 integer::code
 logical::ok
 nan=ieee_value(0d0,ieee_quiet_nan)
 call backend%configure_soil_temperature_temporal_tolerance(1d-5,ok)
 call check(.not.ok,'requires initialized instance')
 call backend%initialize(top)
 call backend%configure_soil_temperature_temporal_tolerance(-1d-5,ok)
 call check(.not.ok,'negative rejected')
 call backend%configure_soil_temperature_temporal_tolerance(nan,ok)
 call check(.not.ok,'nonfinite rejected without trap')
 call backend%configure_soil_temperature_temporal_tolerance(1d-5,ok)
 call check(ok,'explicit configuration')
 call backend%configure_soil_temperature_temporal_tolerance(0d0,ok)
 call check(ok,'explicit disabled compatibility')
 thermal_tolerance=0d0;water_tolerance=1d-4
 full%active_nodes=2;allocate(full%pressure_head(2),full%water_content(2),full%soil_temperature)
 full%pressure_head=-10d0;full%water_content=.3d0
 call initialize_soil_temperature_state([10d0,11d0],full%soil_temperature,code)
 call check(code==0,'real thermal state')
 half=full
 call initialize_soil_temperature_state([10d0+4d-5,11d0],half%soil_temperature,code)
 water=evaluate_fmr_thermal_temporal_error(full,half,0d0,water_tolerance,thermal_tolerance)
 call check(water==0d0,'incumbent ignores temperature, unchanged')
 call copy_soil_temperature_profile(half%soil_temperature,before,code)
 thermal_tolerance=1d-5
 error=evaluate_fmr_thermal_temporal_error(full,half,0d0,water_tolerance,thermal_tolerance)
 call check(abs(error-4d-4)<2d-14,'thermal-only rejection and normalized ratio')
 call check(evaluate_fmr_thermal_temporal_error(full,half,0d0,1d-4,0d0)==0d0,'disabled instance unaffected')
 call initialize_soil_temperature_state([10d0+2d-6,11d0],half%soil_temperature,code)
 call check(abs(evaluate_fmr_thermal_temporal_error(full,half,0d0,water_tolerance,thermal_tolerance)-2d-5)<2d-14,'subthreshold candidate accepted')
 water=.1d0
 call check(evaluate_fmr_thermal_temporal_error(full,half,water,water_tolerance,thermal_tolerance)==water, &
  'existing water indicator cannot be weakened')
 deallocate(half%soil_temperature)
 call check(evaluate_fmr_thermal_temporal_error(full,half,0d0,water_tolerance,thermal_tolerance)>1d100,'missing thermal state fails closed')
 allocate(half%soil_temperature)
 call initialize_soil_temperature_state([10d0,11d0,12d0],half%soil_temperature,code)
 call check(evaluate_fmr_thermal_temporal_error(full,half,0d0,water_tolerance,thermal_tolerance)>1d100,'node mismatch fails closed')
 call initialize_soil_temperature_state([10d0,11d0],half%soil_temperature,code)
 thermal_tolerance=nan
 call check(evaluate_fmr_thermal_temporal_error(full,half,0d0,water_tolerance,thermal_tolerance)>1d100,'invalid direct policy fails closed')
 thermal_tolerance=1d-5
 water_tolerance=nan
 call check(evaluate_fmr_thermal_temporal_error(full,half,0d0,water_tolerance,thermal_tolerance)>1d100,'invalid scaling fails closed')
 call copy_soil_temperature_profile(full%soil_temperature,after,code)
 call check(all(after==[10d0,11d0]),'candidate assessment never mutates full state')
 print '(a)','THERMAL_TEMPORAL_REAL_BACKEND_CONTRACT_PASS'
contains
 subroutine check(yes,label)
  logical,intent(in)::yes
  character(*),intent(in)::label
  if(.not.yes)then
   print *,label;error stop 1
  end if
 end subroutine
end program
