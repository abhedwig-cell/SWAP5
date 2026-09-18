program test_fapp06_swinter0_identity
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_pmdirect_swetr0_process
  use mod_b110_dynamic_top_boundary_provider, only: b110_dynamic_top_boundary_request_t
  use mod_fmr_pmdirect_swinter0_dynamic_top_binding
  implicit none

  type(pmdirect_swetr0_weather_t) :: w
  type(pmdirect_swetr0_daily_result_t) :: daily
  type(pmdirect_swetr0_interval_result_t) :: interval
  type(pmdirect_swetr0_diagnostics_t) :: pd
  type(b110_dynamic_top_boundary_request_t) :: base, bound
  type(fmr_pmdirect_swinter0_top_diagnostics_t) :: bd
  real(real64) :: netirr
  real(real64), parameter :: tol=1.0e-14_real64

  call setup_weather(w)
  call setup_daily(daily)
  pd=pmdirect_swetr0_diagnostics_t()
  pd%status=PMDIRECT_SWETR0_OK
  pd%daily_result_produced=.true.

  w%gross_rain_cm_d=0.47_real64
  call apply_swinter0_identity_interval(w,daily,36.0_real64,interval,netirr,pd)
  call require(pd%status==PMDIRECT_SWETR0_OK .and. pd%interval_result_produced,1)
  call require(abs(interval%net_rain_cm_per_day-0.47_real64)<tol,2)
  call require(abs(netirr-36.0_real64)<tol,3)
  call require(abs(interval%wet_canopy_fraction)<tol,4)
  call require(abs(interval%interception_rate_cm_per_day)<tol,5)
  call require(abs(interval%potential_transpiration_cm_per_day-daily%potential_transpiration_dry_cm_per_day)<tol,6)

  call setup_base(base)
  call fmr_bind_pmdirect_swinter0_surface_fluxes(base,interval,netirr,pd,bound,bd)
  call require(bd%status==FMR_PMDIRECT_SWINTER0_TOP_OK .and. bd%result_produced,7)
  call require(abs(bound%precipitation_rate_cm_per_day-0.47_real64)<tol,8)
  call require(abs(bound%irrigation_rate_cm_per_day-36.0_real64)<tol,9)
  call require(bd%incoming_precipitation_ignored .and. bd%incoming_irrigation_ignored,10)
  call require_non_surface_fields_preserved(base,bound,11)

  ! Zero route remains exact zero and does not invent interception or irrigation.
  pd=pmdirect_swetr0_diagnostics_t(); pd%daily_result_produced=.true.
  w%gross_rain_cm_d=0.0_real64
  call apply_swinter0_identity_interval(w,daily,0.0_real64,interval,netirr,pd)
  call require(pd%interval_result_produced .and. interval%net_rain_cm_per_day==0.0_real64 .and. netirr==0.0_real64,12)

  ! Fail closed for invalid irrigation.
  pd=pmdirect_swetr0_diagnostics_t(); pd%daily_result_produced=.true.
  call apply_swinter0_identity_interval(w,daily,-1.0_real64,interval,netirr,pd)
  call require(pd%status==PMDIRECT_SWETR0_INVALID_SURFACE_IRRIGATION .and. .not.pd%interval_result_produced,13)

  ! Binding rejects invalid mapped irrigation and does not leak the base request.
  pd=pmdirect_swetr0_diagnostics_t(); pd%interval_result_produced=.true.
  interval=pmdirect_swetr0_interval_result_t(); interval%net_rain_cm_per_day=0.2_real64
  call fmr_bind_pmdirect_swinter0_surface_fluxes(base,interval,-1.0_real64,pd,bound,bd)
  call require(bd%status==FMR_PMDIRECT_SWINTER0_TOP_INVALID_NET_IRRIGATION .and. .not.bd%result_produced,14)
  call require(bound%precipitation_rate_cm_per_day==0.0_real64 .and. bound%irrigation_rate_cm_per_day==0.0_real64,15)

  ! Upstream reject is fail closed.
  pd=pmdirect_swetr0_diagnostics_t(); pd%status=PMDIRECT_SWETR0_INVALID_RESULT
  call fmr_bind_pmdirect_swinter0_surface_fluxes(base,interval,0.0_real64,pd,bound,bd)
  call require(bd%status==FMR_PMDIRECT_SWINTER0_TOP_UPSTREAM_REJECTED .and. .not.bd%result_produced,16)

  print '(A)','F_APP06_SWINTER0_IDENTITY=PASS'
  print '(A)','F_APP06_DYNAMIC_TOP_RAIN_IRRIGATION_MAPPING=PASS'
  print '(A)','F_APP06_DYNAMIC_TOP_OTHER_FIELDS_PRESERVED=PASS'
  print '(A)','F_APP06_FAIL_CLOSED=PASS'
contains
  subroutine setup_weather(x)
    type(pmdirect_swetr0_weather_t),intent(out)::x
    x=pmdirect_swetr0_weather_t()
    x%day_of_year=1
    x%radiation_j_m2_d=1.0_real64
    x%minimum_air_temperature_c=5.0_real64
    x%maximum_air_temperature_c=10.0_real64
    x%vapour_pressure_kpa=0.5_real64
    x%wind_speed_m_s=1.0_real64
  end subroutine
  subroutine setup_daily(x)
    type(pmdirect_swetr0_daily_result_t),intent(out)::x
    x=pmdirect_swetr0_daily_result_t()
    x%potential_soil_evaporation_cm_per_day=0.1_real64
    x%potential_pond_evaporation_cm_per_day=0.2_real64
    x%potential_transpiration_dry_cm_per_day=0.3_real64
    x%potential_transpiration_wet_cm_per_day=0.1_real64
    x%interception_evaporation_capacity_cm_per_day=0.2_real64
  end subroutine
  subroutine setup_base(x)
    type(b110_dynamic_top_boundary_request_t),intent(out)::x
    x=b110_dynamic_top_boundary_request_t()
    x%conductivity_mean_method=4
    x%pressure_head_top_cm=-123.0_real64
    x%water_content_top=0.25_real64
    x%candidate_ponding_depth_cm=0.11_real64
    x%previous_ponding_depth_cm=0.12_real64
    x%step_duration_day=0.04_real64
    x%precipitation_rate_cm_per_day=99.0_real64
    x%irrigation_rate_cm_per_day=88.0_real64
    x%snowmelt_rate_cm_per_day=0.21_real64
    x%runon_rate_cm_per_day=0.31_real64
    x%potential_bare_soil_evaporation_cm_per_day=0.41_real64
    x%potential_pond_evaporation_cm_per_day=0.51_real64
    x%ponding_max_cm=1.2_real64
    x%runoff_resistance_day=0.13_real64
    x%runoff_exponent=1.0_real64
  end subroutine
  subroutine require_non_surface_fields_preserved(a,b,n)
    type(b110_dynamic_top_boundary_request_t),intent(in)::a,b
    integer,intent(in)::n
    call require(a%conductivity_mean_method==b%conductivity_mean_method,n)
    call require(a%pressure_head_top_cm==b%pressure_head_top_cm,n+1)
    call require(a%water_content_top==b%water_content_top,n+2)
    call require(a%candidate_ponding_depth_cm==b%candidate_ponding_depth_cm,n+3)
    call require(a%previous_ponding_depth_cm==b%previous_ponding_depth_cm,n+4)
    call require(a%step_duration_day==b%step_duration_day,n+5)
    call require(a%snowmelt_rate_cm_per_day==b%snowmelt_rate_cm_per_day,n+6)
    call require(a%runon_rate_cm_per_day==b%runon_rate_cm_per_day,n+7)
    call require(a%potential_bare_soil_evaporation_cm_per_day==b%potential_bare_soil_evaporation_cm_per_day,n+8)
    call require(a%potential_pond_evaporation_cm_per_day==b%potential_pond_evaporation_cm_per_day,n+9)
    call require(a%ponding_max_cm==b%ponding_max_cm,n+10)
    call require(a%runoff_resistance_day==b%runoff_resistance_day,n+11)
    call require(a%runoff_exponent==b%runoff_exponent,n+12)
  end subroutine
  subroutine require(ok,n)
    logical,intent(in)::ok
    integer,intent(in)::n
    if(.not.ok) then
      write(*,'(A,I0)') 'F_APP06_FAIL=',n
      error stop 1
    end if
  end subroutine
end program test_fapp06_swinter0_identity
