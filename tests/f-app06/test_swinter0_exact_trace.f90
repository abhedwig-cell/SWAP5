program test_fapp06_swinter0_exact_trace
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_pmdirect_swetr0_process
  implicit none

  type(pmdirect_swetr0_weather_t) :: weather
  type(pmdirect_swetr0_daily_result_t) :: daily
  type(pmdirect_swetr0_interval_result_t) :: interval
  type(pmdirect_swetr0_diagnostics_t) :: diagnostics
  character(len=1024) :: fixture, line
  real(real64) :: graidt, nraidt, ptra_dry, ptra, aintcdt, wfrac
  integer :: unit, ios, n
  real(real64) :: max_rain_error, max_ptra_error, max_aint_error, max_wfrac_error

  call get_command_argument(1, fixture)
  if (len_trim(fixture) == 0) error stop 1
  open(newunit=unit,file=trim(fixture),status='old',action='read',iostat=ios)
  if (ios /= 0) error stop 2
  read(unit,'(A)',iostat=ios) line
  if (ios /= 0) error stop 3

  n = 0
  max_rain_error = 0.0_real64
  max_ptra_error = 0.0_real64
  max_aint_error = 0.0_real64
  max_wfrac_error = 0.0_real64
  do
    read(unit,'(A)',iostat=ios) line
    if (ios < 0) exit
    if (ios /= 0) error stop 4
    read(line,*,iostat=ios) graidt, nraidt, ptra_dry, ptra, aintcdt, wfrac
    if (ios /= 0) error stop 5

    weather = pmdirect_swetr0_weather_t()
    weather%gross_rain_cm_d = graidt
    daily = pmdirect_swetr0_daily_result_t()
    daily%potential_transpiration_dry_cm_per_day = ptra_dry
    diagnostics = pmdirect_swetr0_diagnostics_t()
    diagnostics%daily_result_produced = .true.

    call apply_swinter0_no_interception_interval(weather,daily,interval,diagnostics)
    if (diagnostics%status /= PMDIRECT_SWETR0_OK .or. .not. diagnostics%interval_result_produced) error stop 6

    max_rain_error = max(max_rain_error,abs(interval%net_rain_cm_per_day-nraidt))
    max_ptra_error = max(max_ptra_error,abs(interval%potential_transpiration_cm_per_day-ptra))
    max_aint_error = max(max_aint_error,abs(interval%interception_rate_cm_per_day-aintcdt))
    max_wfrac_error = max(max_wfrac_error,abs(interval%wet_canopy_fraction-wfrac))
    n = n + 1
  end do
  close(unit)

  if (n /= 3505) error stop 7
  if (max_rain_error /= 0.0_real64) error stop 8
  if (max_ptra_error /= 0.0_real64) error stop 9
  if (max_aint_error /= 0.0_real64) error stop 10
  if (max_wfrac_error /= 0.0_real64) error stop 11

  diagnostics = pmdirect_swetr0_diagnostics_t()
  diagnostics%daily_result_produced = .true.
  weather = pmdirect_swetr0_weather_t()
  weather%gross_rain_cm_d = -1.0_real64
  daily = pmdirect_swetr0_daily_result_t()
  call apply_swinter0_no_interception_interval(weather,daily,interval,diagnostics)
  if (diagnostics%status /= PMDIRECT_SWETR0_INVALID_WEATHER .or. diagnostics%interval_result_produced) error stop 12

  write(*,'(A,I0)') 'F_APP06_EXACT_B111_RECORDS=',n
  write(*,'(A,ES24.16)') 'F_APP06_MAX_RAIN_ERROR=',max_rain_error
  write(*,'(A,ES24.16)') 'F_APP06_MAX_PTRA_ERROR=',max_ptra_error
  write(*,'(A,ES24.16)') 'F_APP06_MAX_INTERCEPTION_ERROR=',max_aint_error
  write(*,'(A,ES24.16)') 'F_APP06_MAX_WFRAC_ERROR=',max_wfrac_error
  write(*,'(A)') 'F_APP06_SWINTER0_EXACT_TRACE=PASS'
  write(*,'(A)') 'F_APP06_FAIL_CLOSED=PASS'
end program test_fapp06_swinter0_exact_trace
