program test_mig431_forcing_composition
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_irrigation_process, only: irrigation_flux_result_t, irrigation_diagnostics_t, &
       IRRIGATION_APPLICATION_SPRINKLER, IRRIGATION_APPLICATION_SURFACE, IRRIGATION_APPLICATION_SSDI
  use mod_rutter_interception_process, only: rutter_interval_input_t
  use mod_b110_dynamic_top_boundary_provider, only: b110_dynamic_top_boundary_request_t
  use mod_fmr_irrigation_forcing_composition
  implicit none
  type(irrigation_flux_result_t) :: flux
  type(irrigation_diagnostics_t) :: upstream
  type(rutter_interval_input_t) :: base_rutter,rutter
  type(b110_dynamic_top_boundary_request_t) :: base_top,top
  real(real64), allocatable :: source(:)
  integer :: route,status

  base_top%precipitation_rate_cm_per_day = 0.3_real64
  base_rutter%gross_rain_cm_per_day = 0.3_real64
  flux%applied = .true.
  flux%application_type = IRRIGATION_APPLICATION_SURFACE
  flux%surface_gross_rate = 2.0_real64
  flux%active_duration = 0.25_real64
  flux%external_inflow_amount = 0.5_real64
  call fmr_compose_irrigation_forcing(base_top,base_rutter,[0.1_real64,0.0_real64],flux,upstream, &
       top,rutter,source,route,status)
  if (status /= FMR_IRR_COMPOSE_OK .or. route /= FMR_IRR_COMPOSE_TOP .or. &
      top%irrigation_rate_cm_per_day /= 2.0_real64 .or. &
      top%precipitation_rate_cm_per_day /= 0.3_real64) error stop 1

  flux%application_type = IRRIGATION_APPLICATION_SPRINKLER
  call fmr_compose_irrigation_forcing(base_top,base_rutter,[0.1_real64,0.0_real64],flux,upstream, &
       top,rutter,source,route,status)
  if (status /= FMR_IRR_COMPOSE_OK .or. route /= FMR_IRR_COMPOSE_RUTTER .or. &
      .not. rutter%surface_irrigation_is_intercepted .or. &
      top%irrigation_rate_cm_per_day /= 0.0_real64) error stop 2

  flux%application_type = IRRIGATION_APPLICATION_SSDI
  flux%surface_gross_rate = 0.0_real64
  allocate(flux%subsurface_source(2))
  flux%subsurface_source = [0.0_real64,2.0_real64]
  call fmr_compose_irrigation_forcing(base_top,base_rutter,[0.1_real64,0.0_real64],flux,upstream, &
       top,rutter,source,route,status)
  if (status /= FMR_IRR_COMPOSE_OK .or. route /= FMR_IRR_COMPOSE_SUBSURFACE .or. &
      abs(source(1)-0.1_real64) > 1.e-14_real64 .or. &
      abs(source(2)-2.0_real64) > 1.e-14_real64) error stop 3
  flux%external_inflow_amount = 0.25_real64
  call fmr_compose_irrigation_forcing(base_top,base_rutter,[0.1_real64,0.0_real64],flux,upstream, &
       top,rutter,source,route,status)
  if (status /= FMR_IRR_COMPOSE_INVALID .or. allocated(source)) error stop 4
  print '(a)', 'F_MIG431_THREE_ROUTE_FORCING_COMPOSITION=PASS'
end program
