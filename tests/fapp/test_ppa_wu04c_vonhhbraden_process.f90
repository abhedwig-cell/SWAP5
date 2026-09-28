program test_ppa_wu04c_vonhhbraden_process
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_vonhhbraden_interception
  implicit none
  type(vonhhbraden_parameters_t) :: p
  type(vonhhbraden_source_window_t) :: s
  type(vonhhbraden_result_t) :: r
  real(real64) :: a,nr,ni,expected
  integer :: status
  p%cofab_cm=0.20_real64; s%gross_rain_cm_per_day=0.40_real64; s%sprinkling_irrigation_cm_per_day=0.20_real64
  s%leaf_area_index=2.0_real64; s%vegetation_cover_fraction=0.50_real64
  call evaluate_vonhhbraden_source_window(p,s,0.10_real64,r)
  expected=0.1_real64/(1.0_real64/(p%cofab_cm*s%leaf_area_index)+1.0_real64/(10.0_real64*0.60_real64*s%vegetation_cover_fraction))
  if(r%status/=VONHHBRADEN_AVAILABLE .or. abs(r%source_window_interception_cm_per_day-expected)>1.e-14_real64) error stop 1
  call apportion_vonhhbraden_interception(s,r%source_window_interception_cm_per_day,0.20_real64,0.10_real64,a,nr,ni,status)
  if(status/=VONHHBRADEN_AVAILABLE .or. abs(a-0.5_real64*r%source_window_interception_cm_per_day)>1.e-14_real64) error stop 2
  if(abs((nr+ni+a)-0.30_real64)>1.e-14_real64) error stop 3
  s%snow_present=.true.
  call evaluate_vonhhbraden_source_window(p,s,0.10_real64,r)
  if(r%status/=VONHHBRADEN_AVAILABLE .or. r%source_window_interception_cm_per_day/=0.0_real64) error stop 4
  s%snow_present=.false.; p%cofab_cm=0.0_real64
  call evaluate_vonhhbraden_source_window(p,s,0.10_real64,r)
  if(r%status/=VONHHBRADEN_INVALID_INPUT) error stop 5
  print '(a)', 'PPA_WU04C_VONHHBRADEN_SOURCE_ORACLE=PASS'
  print '(a)', 'PPA_WU04C_PARTITION_CONSERVATION=PASS'
  print '(a)', 'PPA_WU04C_GATES_AND_INVALID_INPUT=PASS'
end program
