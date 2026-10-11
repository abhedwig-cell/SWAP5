program test_fapp06_swinter0_exact_b111
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_pmdirect_swetr0_process
  implicit none

  character(len=1024) :: fixture, line
  integer :: unit, ios, n
  real(real64) :: graidt,nraidt,ptra_dry,ptra,aintcdt,wfrac,gird,nird,netirr
  real(real64) :: max_rain,max_ptra,max_aint,max_wfrac,max_irr
  type(pmdirect_swetr0_weather_t) :: weather
  type(pmdirect_swetr0_daily_result_t) :: daily
  type(pmdirect_swetr0_interval_result_t) :: interval
  type(pmdirect_swetr0_diagnostics_t) :: d

  call get_command_argument(1,fixture)
  if(len_trim(fixture)==0) error stop 1
  open(newunit=unit,file=trim(fixture),status='old',action='read',iostat=ios)
  if(ios/=0) error stop 2
  read(unit,'(A)',iostat=ios) line
  if(ios/=0) error stop 3

  n=0; max_rain=0; max_ptra=0; max_aint=0; max_wfrac=0; max_irr=0
  do
    read(unit,'(A)',iostat=ios) line
    if(ios<0) exit
    if(ios/=0) error stop 4
    read(line,*,iostat=ios) graidt,nraidt,ptra_dry,ptra,aintcdt,wfrac,gird,nird
    if(ios/=0) error stop 5

    weather=pmdirect_swetr0_weather_t()
    weather%gross_rain_cm_d=graidt
    daily=pmdirect_swetr0_daily_result_t()
    daily%potential_transpiration_dry_cm_per_day=ptra_dry
    d=pmdirect_swetr0_diagnostics_t()
    d%daily_result_produced=.true.

    call apply_swinter0_identity_interval(weather,daily,gird,interval,netirr,d)
    if(d%status/=PMDIRECT_SWETR0_OK .or. .not.d%interval_result_produced) error stop 6
    max_rain=max(max_rain,abs(interval%net_rain_cm_per_day-nraidt))
    max_ptra=max(max_ptra,abs(interval%potential_transpiration_cm_per_day-ptra))
    max_aint=max(max_aint,abs(interval%interception_rate_cm_per_day-aintcdt))
    max_wfrac=max(max_wfrac,abs(interval%wet_canopy_fraction-wfrac))
    max_irr=max(max_irr,abs(netirr-nird))
    n=n+1
  end do
  close(unit)

  if(n/=3505) error stop 7
  if(max_rain/=0.0_real64 .or. max_ptra/=0.0_real64 .or. max_aint/=0.0_real64 .or. &
     max_wfrac/=0.0_real64 .or. max_irr/=0.0_real64) error stop 8

  write(*,'(A,I0)') 'F_APP06_EXACT_B111_RECORDS=',n
  write(*,'(A,ES24.16)') 'F_APP06_MAX_RAIN_ERROR=',max_rain
  write(*,'(A,ES24.16)') 'F_APP06_MAX_PTRA_ERROR=',max_ptra
  write(*,'(A,ES24.16)') 'F_APP06_MAX_INTERCEPTION_ERROR=',max_aint
  write(*,'(A,ES24.16)') 'F_APP06_MAX_WFRAC_ERROR=',max_wfrac
  write(*,'(A,ES24.16)') 'F_APP06_MAX_IRRIGATION_ERROR=',max_irr
  write(*,'(A)') 'F_APP06_EXACT_3505_B111_ROUTE=PASS'
end program test_fapp06_swinter0_exact_b111
