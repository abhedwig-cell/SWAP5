program test_fvq121_fapp06_swinter0_independent
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_pmdirect_swetr0_process
  use mod_b110_dynamic_top_boundary_provider, only: b110_dynamic_top_boundary_request_t
  use mod_fmr_pmdirect_swinter0_dynamic_top_binding
  implicit none
  integer :: i
  real(real64) :: rain, irr, dry, netirr
  type(pmdirect_swetr0_weather_t) :: w
  type(pmdirect_swetr0_daily_result_t) :: daily
  type(pmdirect_swetr0_interval_result_t) :: out
  type(pmdirect_swetr0_diagnostics_t) :: pd
  type(b110_dynamic_top_boundary_request_t) :: base, bound
  type(fmr_pmdirect_swinter0_top_diagnostics_t) :: bd

  call base_weather(w)
  call base_daily(daily)
  do i=0,100
    rain=0.037_real64*real(i,real64)
    irr=0.113_real64*real(100-i,real64)
    dry=0.0041_real64*real(i,real64)
    w%gross_rain_cm_d=rain
    daily%potential_transpiration_dry_cm_per_day=dry
    pd=pmdirect_swetr0_diagnostics_t(); pd%daily_result_produced=.true.
    call apply_swinter0_identity_interval(w,daily,irr,out,netirr,pd)
    call require(pd%status==PMDIRECT_SWETR0_OK .and. pd%interval_result_produced,1)
    call require(out%net_rain_cm_per_day==rain,2)
    call require(netirr==irr,3)
    call require(out%interception_rate_cm_per_day==0.0_real64,4)
    call require(out%wet_canopy_fraction==0.0_real64,5)
    call require(out%potential_transpiration_cm_per_day==dry,6)

    call sentinel(base)
    call fmr_bind_pmdirect_swinter0_surface_fluxes(base,out,netirr,pd,bound,bd)
    call require(bd%status==FMR_PMDIRECT_SWINTER0_TOP_OK .and. bd%result_produced,7)
    call require(bound%precipitation_rate_cm_per_day==rain,8)
    call require(bound%irrigation_rate_cm_per_day==irr,9)
    call preserve(base,bound,10)
  end do

  pd=pmdirect_swetr0_diagnostics_t(); pd%daily_result_produced=.true.
  call apply_swinter0_identity_interval(w,daily,-0.1_real64,out,netirr,pd)
  call require(pd%status==PMDIRECT_SWETR0_INVALID_SURFACE_IRRIGATION .and. .not.pd%interval_result_produced,30)

  pd=pmdirect_swetr0_diagnostics_t(); pd%interval_result_produced=.false.
  call sentinel(base)
  call fmr_bind_pmdirect_swinter0_surface_fluxes(base,out,0.0_real64,pd,bound,bd)
  call require(bd%status==FMR_PMDIRECT_SWINTER0_TOP_UPSTREAM_REJECTED .and. .not.bd%result_produced,31)

  print '(A)','F_VQ121_GENERIC_IDENTITY_SWEEP=PASS'
  print '(A)','F_VQ121_DYNAMIC_TOP_PRESERVATION=PASS'
  print '(A)','F_VQ121_FAIL_CLOSED=PASS'
contains
  subroutine base_weather(x)
    type(pmdirect_swetr0_weather_t),intent(out)::x
    x=pmdirect_swetr0_weather_t()
    x%day_of_year=120
    x%radiation_j_m2_d=1.0_real64
    x%minimum_air_temperature_c=5.0_real64
    x%maximum_air_temperature_c=15.0_real64
    x%vapour_pressure_kpa=0.7_real64
    x%wind_speed_m_s=2.0_real64
  end subroutine
  subroutine base_daily(x)
    type(pmdirect_swetr0_daily_result_t),intent(out)::x
    x=pmdirect_swetr0_daily_result_t()
    x%potential_soil_evaporation_cm_per_day=0.1_real64
    x%potential_pond_evaporation_cm_per_day=0.2_real64
    x%potential_transpiration_wet_cm_per_day=0.05_real64
    x%interception_evaporation_capacity_cm_per_day=0.15_real64
  end subroutine
  subroutine sentinel(x)
    type(b110_dynamic_top_boundary_request_t),intent(out)::x
    x=b110_dynamic_top_boundary_request_t()
    x%conductivity_mean_method=6
    x%pressure_head_top_cm=-321.0_real64
    x%water_content_top=0.33_real64
    x%candidate_ponding_depth_cm=0.02_real64
    x%previous_ponding_depth_cm=0.03_real64
    x%step_duration_day=0.04_real64
    x%precipitation_rate_cm_per_day=99.0_real64
    x%irrigation_rate_cm_per_day=88.0_real64
    x%snowmelt_rate_cm_per_day=0.7_real64
    x%runon_rate_cm_per_day=0.8_real64
    x%potential_bare_soil_evaporation_cm_per_day=0.9_real64
    x%potential_pond_evaporation_cm_per_day=1.0_real64
    x%ponding_max_cm=1.1_real64
    x%runoff_resistance_day=0.2_real64
    x%runoff_exponent=1.0_real64
  end subroutine
  subroutine preserve(a,b,n)
    type(b110_dynamic_top_boundary_request_t),intent(in)::a,b
    integer,intent(in)::n
    call require(a%conductivity_mean_method==b%conductivity_mean_method,n)
    call require(a%pressure_head_top_cm==b%pressure_head_top_cm,n)
    call require(a%water_content_top==b%water_content_top,n)
    call require(a%candidate_ponding_depth_cm==b%candidate_ponding_depth_cm,n)
    call require(a%previous_ponding_depth_cm==b%previous_ponding_depth_cm,n)
    call require(a%step_duration_day==b%step_duration_day,n)
    call require(a%snowmelt_rate_cm_per_day==b%snowmelt_rate_cm_per_day,n)
    call require(a%runon_rate_cm_per_day==b%runon_rate_cm_per_day,n)
    call require(a%potential_bare_soil_evaporation_cm_per_day==b%potential_bare_soil_evaporation_cm_per_day,n)
    call require(a%potential_pond_evaporation_cm_per_day==b%potential_pond_evaporation_cm_per_day,n)
    call require(a%ponding_max_cm==b%ponding_max_cm,n)
    call require(a%runoff_resistance_day==b%runoff_resistance_day,n)
    call require(a%runoff_exponent==b%runoff_exponent,n)
  end subroutine
  subroutine require(ok,n)
    logical,intent(in)::ok; integer,intent(in)::n
    if(.not.ok) then
      write(*,'(A,I0)') 'F_VQ121_FAIL=',n
      error stop 1
    end if
  end subroutine
end program test_fvq121_fapp06_swinter0_independent
