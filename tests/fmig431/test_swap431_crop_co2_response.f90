program test_swap431_crop_co2_response
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_crop_co2_response_resolver
  use mod_wofost_one_day_structural_evolution, only: wofost_one_day_forcing_t
  use mod_crop_et_canopy_view_provider
  use mod_fmr_crop_co2_response_binding
  implicit none

  type(crop_co2_response_parameters_t) :: response_parameters, disabled_parameters
  type(crop_co2_response_t) :: response
  type(wofost_one_day_forcing_t) :: base_forcing, crop_forcing
  type(crop_et_canopy_parameters_t) :: canopy_parameters
  type(crop_et_canopy_state_view_t) :: canopy_state
  type(crop_et_canopy_view_t) :: canopy_view
  type(crop_et_canopy_diagnostics_t) :: canopy_diagnostics
  type(fmr_crop_co2_binding_diagnostics_t) :: diagnostics
  integer :: status
  real(real64), parameter :: tol=1.0e-12_real64

  call construct_crop_co2_response_parameters([400.0_real64,600.0_real64], [1.0_real64,1.2_real64], &
       [350.0_real64,500.0_real64,650.0_real64], [0.9_real64,1.2_real64,1.5_real64], &
       [300.0_real64,700.0_real64], [1.0_real64,0.8_real64], .true., response_parameters,status)
  if(status/=CROP_CO2_RESPONSE_OK) error stop 1

  call construct_crop_et_canopy_parameters(0.5_real64,0.8_real64, &
       [0.0_real64,1.0_real64,2.0_real64],[0.8_real64,1.0_real64,0.7_real64], &
       .false.,canopy_parameters,status)
  if(status/=CROP_ET_CANOPY_OK) error stop 2

  base_forcing%minimum_temperature=5.0_real64
  base_forcing%average_temperature=15.0_real64
  base_forcing%daytime_average_temperature=18.0_real64
  base_forcing%global_radiation=1000.0_real64
  base_forcing%daylength_hours=12.0_real64
  base_forcing%photoperiodic_daylength_hours=12.0_real64
  base_forcing%daily_sine_solar_elevation_integral=1.0_real64
  base_forcing%co2_efficiency_factor=9.0_real64
  base_forcing%co2_amax_factor=9.0_real64

  canopy_state%crop_emerged=.true.
  canopy_state%development_stage=0.5_real64
  canopy_state%leaf_area_index=2.0_real64

  call fmr_bind_crop_co2_response(response_parameters,500.0_real64,base_forcing,canopy_parameters,canopy_state, &
       crop_forcing,canopy_view,response,canopy_diagnostics,diagnostics)

  if(diagnostics%status/=FMR_CROP_CO2_BINDING_OK) error stop 3
  if(.not.diagnostics%response_resolved.or..not.diagnostics%crop_forcing_bound.or. &
       .not.diagnostics%canopy_view_bound) error stop 4
  if(abs(response%efficiency_factor-1.1_real64)>tol) error stop 5
  if(abs(response%amax_factor-1.2_real64)>tol) error stop 6
  if(abs(response%transpiration_factor-0.9_real64)>tol) error stop 7
  if(abs(crop_forcing%co2_efficiency_factor-response%efficiency_factor)>tol) error stop 8
  if(abs(crop_forcing%co2_amax_factor-response%amax_factor)>tol) error stop 9
  if(abs(canopy_view%co2_transpiration_factor-response%transpiration_factor)>tol) error stop 10
  if(.not.canopy_diagnostics%resolved_co2_factor_consumed) error stop 11
  if(canopy_diagnostics%co2_table_consumed.or.canopy_diagnostics%co2_forcing_consumed) error stop 12

  ! Each AFGEN table has its own independent CO2 knot vector.
  call evaluate_crop_co2_response(response_parameters,300.0_real64,response,status)
  if(status/=CROP_CO2_RESPONSE_OK.or.abs(response%efficiency_factor-1.0_real64)>tol.or. &
       abs(response%amax_factor-0.9_real64)>tol.or.abs(response%transpiration_factor-1.0_real64)>tol) error stop 13
  call evaluate_crop_co2_response(response_parameters,700.0_real64,response,status)
  if(status/=CROP_CO2_RESPONSE_OK.or.abs(response%efficiency_factor-1.2_real64)>tol.or. &
       abs(response%amax_factor-1.5_real64)>tol.or.abs(response%transpiration_factor-0.8_real64)>tol) error stop 14

  ! Disabled response is forcing-independent and resolves neutral factors.
  call construct_crop_co2_response_parameters([1.0_real64],[1.0_real64],[1.0_real64],[1.0_real64], &
       [1.0_real64],[1.0_real64],.false.,disabled_parameters,status)
  if(status/=CROP_CO2_RESPONSE_OK) error stop 15
  call evaluate_crop_co2_response(disabled_parameters,-999.0_real64,response,status)
  if(status/=CROP_CO2_RESPONSE_OK.or.abs(response%efficiency_factor-1.0_real64)>tol.or. &
       abs(response%amax_factor-1.0_real64)>tol.or.abs(response%transpiration_factor-1.0_real64)>tol) error stop 16

  ! Inactive crop does not consume or validate atmospheric CO2.
  canopy_state%crop_emerged=.false.
  call fmr_bind_crop_co2_response(response_parameters,-999.0_real64,base_forcing,canopy_parameters,canopy_state, &
       crop_forcing,canopy_view,response,canopy_diagnostics,diagnostics)
  if(diagnostics%status/=FMR_CROP_CO2_BINDING_OK.or.diagnostics%response_resolved) error stop 17
  if(.not.diagnostics%canopy_view_bound.or.canopy_view%co2_transpiration_factor/=1.0_real64) error stop 18

  print '(a)','SW431_CROP_CO2_RESPONSE=PASS'
end program test_swap431_crop_co2_response
