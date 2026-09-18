program test_fvq126_fapp06_exact_b111
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_pmdirect_swetr0_process
  use mod_b110_dynamic_top_boundary_provider, only: b110_dynamic_top_boundary_request_t
  use mod_fmr_pmdirect_swinter0_dynamic_top_binding
  implicit none
  character(len=1024) :: fixture,line
  integer :: unit,ios,n
  real(real64) :: graidt,nraidt,pdry,ptra,aint,wfrac,gird,nird,netirr,maxerr
  type(pmdirect_swetr0_weather_t)::w
  type(pmdirect_swetr0_daily_result_t)::daily
  type(pmdirect_swetr0_interval_result_t)::out
  type(pmdirect_swetr0_diagnostics_t)::pd
  type(b110_dynamic_top_boundary_request_t)::base,bound
  type(fmr_pmdirect_swinter0_top_diagnostics_t)::bd

  call get_command_argument(1,fixture)
  if(len_trim(fixture)==0) error stop 1
  open(newunit=unit,file=trim(fixture),status='old',action='read',iostat=ios)
  if(ios/=0) error stop 2
  read(unit,'(A)',iostat=ios) line
  if(ios/=0) error stop 3

  n=0; maxerr=0.0_real64
  do
    read(unit,'(A)',iostat=ios) line
    if(ios<0) exit
    if(ios/=0) error stop 4
    read(line,*,iostat=ios) graidt,nraidt,pdry,ptra,aint,wfrac,gird,nird
    if(ios/=0) error stop 5

    w=pmdirect_swetr0_weather_t()
    w%day_of_year=1
    w%radiation_j_m2_d=0.0_real64
    w%minimum_air_temperature_c=0.0_real64
    w%maximum_air_temperature_c=0.0_real64
    w%vapour_pressure_kpa=0.0_real64
    w%wind_speed_m_s=0.0_real64
    w%gross_rain_cm_d=graidt
    daily=pmdirect_swetr0_daily_result_t()
    daily%potential_transpiration_dry_cm_per_day=pdry
    pd=pmdirect_swetr0_diagnostics_t(); pd%daily_result_produced=.true.

    call apply_swinter0_identity_interval(w,daily,gird,out,netirr,pd)
    if(pd%status/=PMDIRECT_SWETR0_OK .or. .not.pd%interval_result_produced) error stop 6
    maxerr=max(maxerr,abs(out%net_rain_cm_per_day-nraidt))
    maxerr=max(maxerr,abs(out%potential_transpiration_cm_per_day-ptra))
    maxerr=max(maxerr,abs(out%interception_rate_cm_per_day-aint))
    maxerr=max(maxerr,abs(out%wet_canopy_fraction-wfrac))
    maxerr=max(maxerr,abs(netirr-nird))

    call sentinel(base)
    call fmr_bind_pmdirect_swinter0_surface_fluxes(base,out,netirr,pd,bound,bd)
    if(bd%status/=FMR_PMDIRECT_SWINTER0_TOP_OK .or. .not.bd%result_produced) error stop 7
    maxerr=max(maxerr,abs(bound%precipitation_rate_cm_per_day-nraidt))
    maxerr=max(maxerr,abs(bound%irrigation_rate_cm_per_day-nird))
    if(bound%snowmelt_rate_cm_per_day/=base%snowmelt_rate_cm_per_day) error stop 8
    if(bound%runon_rate_cm_per_day/=base%runon_rate_cm_per_day) error stop 9
    if(bound%potential_bare_soil_evaporation_cm_per_day/=base%potential_bare_soil_evaporation_cm_per_day) error stop 10
    if(bound%potential_pond_evaporation_cm_per_day/=base%potential_pond_evaporation_cm_per_day) error stop 11
    n=n+1
  end do
  close(unit)

  if(n/=3505) error stop 12
  if(maxerr/=0.0_real64) error stop 13
  write(*,'(A,I0)') 'F_VQ126_EXACT_B111_RECORDS=',n
  write(*,'(A,ES24.16)') 'F_VQ126_EXACT_B111_MAX_ERROR=',maxerr
  write(*,'(A)') 'F_VQ126_EXACT_3505_PROCESS_AND_BINDING=PASS'
contains
  subroutine sentinel(x)
    type(b110_dynamic_top_boundary_request_t),intent(out)::x
    x=b110_dynamic_top_boundary_request_t()
    x%conductivity_mean_method=4
    x%pressure_head_top_cm=-222.0_real64
    x%water_content_top=0.31_real64
    x%candidate_ponding_depth_cm=0.02_real64
    x%previous_ponding_depth_cm=0.03_real64
    x%step_duration_day=0.04_real64
    x%precipitation_rate_cm_per_day=99.0_real64
    x%irrigation_rate_cm_per_day=88.0_real64
    x%snowmelt_rate_cm_per_day=0.12_real64
    x%runon_rate_cm_per_day=0.23_real64
    x%potential_bare_soil_evaporation_cm_per_day=0.34_real64
    x%potential_pond_evaporation_cm_per_day=0.45_real64
    x%ponding_max_cm=1.0_real64
    x%runoff_resistance_day=0.2_real64
    x%runoff_exponent=1.0_real64
  end subroutine
end program test_fvq126_fapp06_exact_b111
