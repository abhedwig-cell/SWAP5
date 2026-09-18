program test_fapp07_hupsel_irrigation_composition
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_irrigation_process, only: irrigation_flux_result_t, irrigation_diagnostics_t, &
       IRRIGATION_APPLICATION_SURFACE
  use mod_tcs1_dcs2_sprinkling_irrigation_process, only: tcs1_dcs2_sprinkling_result_t, &
       tcs1_dcs2_sprinkling_diagnostics_t
  use mod_rutter_interception_process, only: rutter_interval_input_t, rutter_interval_result_t, rutter_diagnostics_t
  use mod_b110_dynamic_top_boundary_provider, only: b110_dynamic_top_boundary_request_t
  use mod_fmr_hupsel_irrigation_application_binding
  implicit none

  character(len=1024) :: fixture, line
  integer :: unit, ios, n, n0, n3, iyear, daynr, swinter
  real(real64) :: tcum, dt, gird, nird
  type(b110_dynamic_top_boundary_request_t) :: base_top, bound_top
  type(irrigation_flux_result_t) :: fixed_flux
  type(irrigation_diagnostics_t) :: fixed_diag
  type(tcs1_dcs2_sprinkling_result_t) :: scheduled
  type(tcs1_dcs2_sprinkling_diagnostics_t) :: scheduled_diag
  type(rutter_interval_input_t) :: base_rutter, bound_rutter
  type(rutter_interval_result_t) :: rutter
  type(rutter_diagnostics_t) :: rutter_diag
  type(fmr_hupsel_irrigation_binding_diagnostics_t) :: d
  real(real64) :: max_error

  call get_command_argument(1,fixture)
  if (len_trim(fixture) == 0) error stop 1
  open(newunit=unit,file=trim(fixture),status='old',action='read',iostat=ios)
  if (ios /= 0) error stop 2
  read(unit,'(A)',iostat=ios) line
  if (ios /= 0) error stop 3

  n=0; n0=0; n3=0; max_error=0.0_real64
  do
    read(unit,'(A)',iostat=ios) line
    if (ios < 0) exit
    if (ios /= 0) error stop 4
    read(line,*,iostat=ios) iyear,daynr,tcum,dt,swinter,gird,nird
    if (ios /= 0) error stop 5

    base_top = b110_dynamic_top_boundary_request_t()
    base_top%precipitation_rate_cm_per_day = 1.25_real64
    base_top%snowmelt_rate_cm_per_day = 2.5_real64
    base_top%runon_rate_cm_per_day = 3.75_real64
    base_top%potential_bare_soil_evaporation_cm_per_day = 0.125_real64

    select case(swinter)
    case(0)
      fixed_flux = irrigation_flux_result_t()
      fixed_flux%applied = .true.
      fixed_flux%application_type = IRRIGATION_APPLICATION_SURFACE
      fixed_flux%surface_gross_rate = gird
      fixed_diag = irrigation_diagnostics_t()
      call fmr_bind_fixed_surface_irrigation_identity_to_dynamic_top(base_top,fixed_flux,fixed_diag,bound_top,d)
      if (d%status /= FMR_HUPSEL_IRR_BIND_OK .or. .not. d%result_produced) error stop 6
      max_error=max(max_error,abs(bound_top%irrigation_rate_cm_per_day-nird))
      if (bound_top%precipitation_rate_cm_per_day /= base_top%precipitation_rate_cm_per_day) error stop 7
      if (bound_top%snowmelt_rate_cm_per_day /= base_top%snowmelt_rate_cm_per_day) error stop 8
      if (bound_top%runon_rate_cm_per_day /= base_top%runon_rate_cm_per_day) error stop 9
      n0=n0+1

    case(3)
      scheduled = tcs1_dcs2_sprinkling_result_t()
      scheduled%applied = .true.
      scheduled%gross_surface_rate_cm_per_day = gird
      scheduled_diag = tcs1_dcs2_sprinkling_diagnostics_t()
      base_rutter = rutter_interval_input_t()
      base_rutter%gross_rain_cm_per_day = 0.33_real64
      base_rutter%vegetation_cover_fraction = 0.42_real64
      call fmr_bind_tcs1_sprinkling_to_rutter(base_rutter,scheduled,scheduled_diag,bound_rutter,d)
      if (d%status /= FMR_HUPSEL_IRR_BIND_OK .or. .not. d%result_produced) error stop 10
      if (.not. bound_rutter%surface_irrigation_is_intercepted) error stop 11
      if (bound_rutter%surface_irrigation_cm_per_day /= gird) error stop 12
      if (bound_rutter%gross_rain_cm_per_day /= base_rutter%gross_rain_cm_per_day) error stop 13
      if (bound_rutter%vegetation_cover_fraction /= base_rutter%vegetation_cover_fraction) error stop 14

      rutter = rutter_interval_result_t()
      rutter%net_surface_irrigation_cm_per_day = nird
      rutter_diag = rutter_diagnostics_t()
      rutter_diag%result_produced = .true.
      call fmr_bind_rutter_net_irrigation_to_dynamic_top(base_top,rutter,rutter_diag,bound_top,d)
      if (d%status /= FMR_HUPSEL_IRR_BIND_OK .or. .not. d%result_produced) error stop 15
      max_error=max(max_error,abs(bound_top%irrigation_rate_cm_per_day-nird))
      if (bound_top%precipitation_rate_cm_per_day /= base_top%precipitation_rate_cm_per_day) error stop 16
      if (bound_top%snowmelt_rate_cm_per_day /= base_top%snowmelt_rate_cm_per_day) error stop 17
      if (bound_top%runon_rate_cm_per_day /= base_top%runon_rate_cm_per_day) error stop 18
      n3=n3+1

    case default
      error stop 19
    end select
    n=n+1
  end do
  close(unit)

  if (n /= 110 .or. n0 /= 18 .or. n3 /= 92) error stop 20
  if (max_error /= 0.0_real64) error stop 21

  ! Invalid gross scheduled irrigation must fail closed.
  scheduled = tcs1_dcs2_sprinkling_result_t()
  scheduled%applied = .true.
  scheduled%gross_surface_rate_cm_per_day = -1.0_real64
  scheduled_diag = tcs1_dcs2_sprinkling_diagnostics_t()
  call fmr_bind_tcs1_sprinkling_to_rutter(base_rutter,scheduled,scheduled_diag,bound_rutter,d)
  if (d%status /= FMR_HUPSEL_IRR_BIND_INVALID_RATE .or. d%result_produced) error stop 22

  write(*,'(A,I0)') 'F_APP07_EXACT_ACTIVE_INTERVALS=',n
  write(*,'(A,I0)') 'F_APP07_SWINTER0_INTERVALS=',n0
  write(*,'(A,I0)') 'F_APP07_SWINTER3_INTERVALS=',n3
  write(*,'(A,ES24.16)') 'F_APP07_MAX_COMPOSITION_ERROR=',max_error
  write(*,'(A)') 'F_APP07_IRRIGATION_RUTTER_DYNAMIC_TOP_COMPOSITION=PASS'
  write(*,'(A)') 'F_APP07_COMPOSITION_FAIL_CLOSED=PASS'
end program test_fapp07_hupsel_irrigation_composition
