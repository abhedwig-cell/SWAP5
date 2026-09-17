program test_fapp03_pmdirect_swetr0_process
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_pmdirect_swetr0_process
  implicit none
  real(real64), parameter :: tol=1.0e-12_real64
  type(pmdirect_swetr0_weather_t) :: w
  type(pmdirect_swetr0_site_t) :: site
  type(pmdirect_swetr0_canopy_t) :: canopy
  type(pmdirect_swetr0_daily_result_t) :: daily
  type(pmdirect_swetr0_interval_result_t) :: interval
  type(pmdirect_swetr0_diagnostics_t) :: diag

  call set_site(site)

  ! Exact-source Hupsel vector, 20 May 2002 (DOY 140), dry interval.
  w=pmdirect_swetr0_weather_t(140,2.2350e7_real64,8.6_real64,23.0_real64,1.193698_real64,3.08_real64,0.0_real64)
  canopy=pmdirect_swetr0_canopy_t(.true.,0.1_real64,0.0440025181669001508_real64,0.25_real64,0.23_real64,70.0_real64,0.0_real64,1.0_real64)
  call evaluate_pmdirect_swetr0_daily(w,site,canopy,daily,diag)
  call require(diag%status==PMDIRECT_SWETR0_OK .and. diag%daily_result_produced,'DOY140 daily rejected')
  call close_to(daily%potential_soil_evaporation_cm_per_day,2.53814812232436682e-1_real64,'DOY140 peva')
  call close_to(daily%potential_transpiration_dry_cm_per_day,2.06019959953761093e-2_real64,'DOY140 ptra_dry')
  call close_to(daily%interception_evaporation_capacity_cm_per_day,1.27116203064736796e-2_real64,'DOY140 eintc')
  call apply_swinter1_daily_interval(w,canopy,daily,interval,diag)
  call require(diag%interval_result_produced,'DOY140 interval rejected')
  call close_to(interval%net_rain_cm_per_day,0.0_real64,'DOY140 net rain')
  call close_to(interval%wet_canopy_fraction,0.0_real64,'DOY140 wet fraction')

  ! Exact-source Hupsel vector, 10 June 2002 (DOY 161), positive interception gate.
  w=pmdirect_swetr0_weather_t(161,1.2450e7_real64,11.0_real64,18.1_real64,1.315514_real64,4.92_real64,0.47_real64)
  canopy=pmdirect_swetr0_canopy_t(.true.,3.12683333333333335_real64,0.755141552325116483_real64,0.25_real64,0.23_real64,70.0_real64,0.0_real64,1.0_real64)
  call evaluate_pmdirect_swetr0_daily(w,site,canopy,daily,diag)
  call require(diag%status==PMDIRECT_SWETR0_OK .and. diag%daily_result_produced,'DOY161 daily rejected')
  call close_to(daily%es0_mm_per_day,5.41625553648753200e-1_real64,'DOY161 es0')
  call close_to(daily%et0_mm_per_day,2.31788172538356108_real64,'DOY161 et0')
  call close_to(daily%ew0_mm_per_day,2.90497181315647346_real64,'DOY161 ew0')
  call close_to(daily%ep0_mm_per_day,7.59571188156944910e-1_real64,'DOY161 ep0')
  call close_to(daily%potential_transpiration_dry_cm_per_day,2.31788172538356124e-1_real64,'DOY161 ptra_dry')
  call close_to(daily%potential_transpiration_wet_cm_per_day,1.02866673423296751e-1_real64,'DOY161 ptra_wet')
  call close_to(daily%interception_evaporation_capacity_cm_per_day,1.61575682200587989e-1_real64,'DOY161 eintc')
  call apply_swinter1_daily_interval(w,canopy,daily,interval,diag)
  call require(diag%interval_result_produced,'DOY161 interval rejected')
  call close_to(interval%interception_rate_cm_per_day,6.40612570512150981e-2_real64,'DOY161 interception')
  call close_to(interval%net_rain_cm_per_day,4.05938742948784959e-1_real64,'DOY161 net rain')
  call close_to(interval%wet_canopy_fraction,3.96478332498613917e-1_real64,'DOY161 wet fraction')
  call close_to(interval%potential_transpiration_cm_per_day,1.80673591545995882e-1_real64,'DOY161 ptra')

  ! Exact-source Hupsel vector, DOY 300, non-emerged crop branch.
  w=pmdirect_swetr0_weather_t(300,3.6e6_real64,8.4_real64,16.4_real64,1.103545_real64,13.58_real64,1.49_real64)
  canopy=pmdirect_swetr0_canopy_t(.false.,0.0_real64,0.0_real64,0.25_real64,0.23_real64,70.0_real64,0.0_real64,1.0_real64)
  call evaluate_pmdirect_swetr0_daily(w,site,canopy,daily,diag)
  call require(diag%status==PMDIRECT_SWETR0_OK .and. diag%daily_result_produced,'DOY300 daily rejected')
  call close_to(daily%potential_soil_evaporation_cm_per_day,4.34359752650668382e-2_real64,'DOY300 peva')
  call close_to(daily%potential_pond_evaporation_cm_per_day,2.08567410149469362e-1_real64,'DOY300 epond')
  call close_to(daily%potential_transpiration_dry_cm_per_day,1.65611569011325211e-24_real64,'DOY300 ptra_dry')

  write(*,'(a)') 'F-APP03 PMdirect SWETR=0 restricted regression PASS'
contains
  subroutine set_site(s)
    type(pmdirect_swetr0_site_t),intent(out)::s
    s%latitude_degrees=52.0_real64; s%altitude_m=10.0_real64
    s%wind_measurement_height_m=10.0_real64; s%humidity_measurement_height_m=1.5_real64
    s%angstrom_a=0.25_real64; s%angstrom_b=0.5_real64
    s%wind_function_factor=1.0_real64; s%soil_surface_resistance_s_m=600.0_real64
  end subroutine set_site
  subroutine close_to(a,b,label)
    real(real64),intent(in)::a,b
    character(*),intent(in)::label
    if(abs(a-b)>tol) then
      write(*,'(a,2(1x,es25.17e3))') trim(label)//' mismatch:',a,b
      error stop 1
    end if
  end subroutine close_to
  subroutine require(ok,label)
    logical,intent(in)::ok
    character(*),intent(in)::label
    if(.not.ok) then
      write(*,'(a)') trim(label)
      error stop 1
    end if
  end subroutine require
end program test_fapp03_pmdirect_swetr0_process
