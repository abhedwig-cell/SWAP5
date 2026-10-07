program test_swap431_crop_preemergence
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_crop_preemergence_owner
  implicit none
  type(crop_preemergence_parameters_t)::p
  type(crop_preemergence_state_t)::s,c
  type(crop_preemergence_daily_forcing_t)::f
  type(crop_preemergence_diagnostics_t)::d
  integer::status
  real(real64),parameter::tol=1e-12_real64

  p%preparation_enabled=.true.;p%preparation_head_threshold_cm=-100._real64;p%maximum_preparation_delay_days=2
  p%sowing_enabled=.true.;p%sowing_head_threshold_cm=-100._real64;p%sowing_temperature_threshold_c=8._real64;p%maximum_sowing_delay_days=3
  p%germination_mode=GERMINATION_TEMPERATURE_WATER
  p%optimal_emergence_temperature_sum=20._real64;p%germination_base_temperature_c=0._real64
  p%germination_effective_max_temperature_c=20._real64
  p%dry_germination_head_cm=-500._real64;p%wet_germination_head_cm=-100._real64;p%germination_head_slope=5._real64
  if(.not.p%ready())error stop 1
  call initialize_crop_preemergence_owner(p,s,status)
  if(status/=PREEMERGENCE_OK.or.s%preparation_complete.or.s%sowing_complete.or.s%germination_complete)error stop 2

  ! Wet preparation condition: h-hprep > 0 delays and sets DVS=-0.3.
  f%preparation_average_head_cm=-50._real64
  f%sowing_average_head_cm=-50._real64;f%sowing_soil_temperature_c=5._real64
  f%germination_average_head_cm=-200._real64;f%average_air_temperature_c=10._real64
  call evaluate_crop_preemergence_day(p,s,f,c,d,status)
  if(status/=PREEMERGENCE_OK.or..not.d%preparation_delayed)error stop 3
  if(c%preparation_delay_days/=1.or.c%sowing_delay_days/=1.or.abs(c%development_stage_marker+.3_real64)>tol)error stop 4

  ! Second delay reaches max preparation delay.
  s=c
  call evaluate_crop_preemergence_day(p,s,f,c,d,status)
  if(status/=PREEMERGENCE_OK.or.c%preparation_delay_days/=2.or.c%sowing_delay_days/=2)error stop 5
  if(c%preparation_complete)error stop 6

  ! On next day source no longer delays preparation because delay==max.
  ! Sowing is still bad, but has inherited delay=2 and may delay only once to max=3.
  s=c
  call evaluate_crop_preemergence_day(p,s,f,c,d,status)
  if(status/=PREEMERGENCE_OK.or..not.c%preparation_complete)error stop 7
  if(.not.d%sowing_delayed.or.c%sowing_delay_days/=3.or.c%sowing_complete)error stop 8
  if(abs(c%development_stage_marker+.2_real64)>tol)error stop 9

  ! At max sow delay, source releases sowing even with bad conditions and starts germination.
  s=c
  call evaluate_crop_preemergence_day(p,s,f,c,d,status)
  if(status/=PREEMERGENCE_OK.or..not.c%sowing_complete)error stop 10
  if(c%germination_temperature_sum<=0._real64)error stop 11
  if(c%germination_complete)then
    if(abs(c%development_stage_marker)>tol)error stop 12
  else
    if(c%development_stage_marker>=0._real64.or.c%development_stage_marker<-.1_real64)error stop 13
  end if

  ! Temperature-only germination uses TSUMEMEOPT directly.
  p%preparation_enabled=.false.;p%sowing_enabled=.false.;p%germination_mode=GERMINATION_TEMPERATURE
  call initialize_crop_preemergence_owner(p,s,status)
  if(status/=PREEMERGENCE_OK)error stop 14
  f%average_air_temperature_c=10._real64
  call evaluate_crop_preemergence_day(p,s,f,c,d,status)
  if(status/=PREEMERGENCE_OK.or.abs(d%effective_germination_requirement-20._real64)>tol)error stop 15
  if(abs(d%germination_temperature_increment-10._real64)>tol)error stop 16
  if(abs(c%development_stage_marker+.05_real64)>tol.or.c%germination_complete)error stop 17
  s=c
  call evaluate_crop_preemergence_day(p,s,f,c,d,status)
  if(status/=PREEMERGENCE_OK.or..not.c%germination_complete.or.abs(c%development_stage_marker)>tol)error stop 18

  ! All selectors off is immediate emergence-ready state.
  p%germination_mode=GERMINATION_OFF
  call initialize_crop_preemergence_owner(p,s,status)
  if(status/=PREEMERGENCE_OK.or..not.s%preparation_complete.or..not.s%sowing_complete.or..not.s%germination_complete)error stop 19

  print '(a)','SW431_CROP_PREEMERGENCE=PASS'
end program
