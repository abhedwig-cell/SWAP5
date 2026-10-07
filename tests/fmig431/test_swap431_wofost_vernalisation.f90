program test_swap431_wofost_vernalisation
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_wofost_rate_table, only: construct_wofost_rate_table, WOFOST_RATE_TABLE_OK
  use mod_wofost_vernalisation_phenology
  implicit none

  type(wofost_vernalisation_parameters_t) :: p
  type(wofost_vernalisation_state_t) :: s
  type(wofost_vernalisation_daily_result_t) :: r
  integer :: status
  real(real64), parameter :: tol=1.0e-12_real64

  p%critical_development_stage=0.30_real64
  p%base_requirement=10.0_real64
  p%saturation_requirement=30.0_real64
  call construct_wofost_rate_table([-10.0_real64,20.0_real64,100.0_real64], &
       [0.0_real64,5.0_real64,0.0_real64],p%temperature_rate,status)
  if(status/=WOFOST_RATE_TABLE_OK) error stop 1
  if(.not.p%ready()) error stop 101

  ! Below VERNBASE, factor is clamped to zero but VERN still accumulates.
  s%accumulated_units=0.0_real64
  s%vernalised=.false.
  call evaluate_wofost_idsl2_daily_candidate(p,s,0.10_real64,20.0_real64,0.8_real64,10.0_real64,100.0_real64,r,status)
  if(status/=WOFOST_VERN_OK) error stop 2
  if(abs(r%vernalisation_rate-5.0_real64)>tol.or.abs(r%vernalisation_factor)>tol) error stop 3
  if(abs(r%development_rate)>tol.or.abs(r%candidate_state%accumulated_units-5.0_real64)>tol) error stop 4
  if(r%candidate_state%vernalised) error stop 5

  ! Factor uses committed VERN, not same-day VERN after rate accumulation.
  s%accumulated_units=20.0_real64
  call evaluate_wofost_idsl2_daily_candidate(p,s,0.10_real64,20.0_real64,0.8_real64,10.0_real64,100.0_real64,r,status)
  if(status/=WOFOST_VERN_OK.or.abs(r%vernalisation_factor-0.5_real64)>tol) error stop 6
  if(abs(r%development_rate-0.04_real64)>tol) error stop 7
  if(abs(r%candidate_state%accumulated_units-25.0_real64)>tol.or.r%candidate_state%vernalised) error stop 8

  ! Saturation happens after the day's rate has been used for DVS.
  s%accumulated_units=28.0_real64
  call evaluate_wofost_idsl2_daily_candidate(p,s,0.10_real64,20.0_real64,1.0_real64,10.0_real64,100.0_real64,r,status)
  if(status/=WOFOST_VERN_OK.or.abs(r%vernalisation_factor-0.9_real64)>tol) error stop 9
  if(abs(r%development_rate-0.09_real64)>tol) error stop 10
  if(.not.r%saturated_after_update.or..not.r%candidate_state%vernalised) error stop 11
  if(abs(r%candidate_state%accumulated_units-33.0_real64)>tol) error stop 12
  if(abs(r%candidate_state%retained_rate-5.0_real64)>tol) error stop 121

  ! Once saturated, pinned SAVE VERNRATE is not reassigned. It therefore
  ! remains part of source-compatible continuation and VERN keeps advancing.
  s=r%candidate_state
  call evaluate_wofost_idsl2_daily_candidate(p,s,0.20_real64,5.0_real64,1.0_real64,2.0_real64,100.0_real64,r,status)
  if(status/=WOFOST_VERN_OK.or.abs(r%vernalisation_rate-5.0_real64)>tol) error stop 122
  if(abs(r%candidate_state%accumulated_units-38.0_real64)>tol) error stop 123
  if(.not.r%candidate_state%vernalised) error stop 124

  ! At VERNDVS the source forces vernalisation immediately, keeps VERNRATE=0
  ! and VERNFAC=1, then reaches the warning condition if VERN<VERNSAT.
  s%accumulated_units=5.0_real64
  s%vernalised=.false.
  call evaluate_wofost_idsl2_daily_candidate(p,s,0.30_real64,20.0_real64,0.5_real64,10.0_real64,100.0_real64,r,status)
  if(status/=WOFOST_VERN_OK.or..not.r%forced_at_critical_dvs) error stop 13
  if(abs(r%vernalisation_rate)>tol.or.abs(r%vernalisation_factor-1.0_real64)>tol) error stop 14
  if(abs(r%development_rate-0.05_real64)>tol) error stop 15
  if(.not.r%candidate_state%vernalised.or..not.r%warning_condition) error stop 16
  if(abs(r%candidate_state%accumulated_units-5.0_real64)>tol) error stop 17

  print '(a)','SW431_CROP_VERNALISATION=PASS'
end program
