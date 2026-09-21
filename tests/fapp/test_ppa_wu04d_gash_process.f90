program test_ppa_wu04d_gash_process
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_vonhhbraden_interception
  use mod_gash_interception
  implicit none
  type(gash_parameters_t) :: p
  type(vonhhbraden_source_window_t) :: s
  real(real64) :: a, c, scanopy, avevap, psat, expected
  integer :: status
  p%free_throughfall=.2_real64; p%stemflow=.1_real64; p%canopy_storage_cm=.07_real64
  p%average_evaporation=.15_real64; p%average_precipitation=.5_real64
  s%leaf_area_index=2._real64; s%gross_rain_cm_per_day=.01_real64
  call evaluate_gash_source_window(p,s,a,status)
  c=.7_real64; if(status/=VONHHBRADEN_AVAILABLE .or. abs(a-c*.01_real64)>1.e-14_real64) error stop 1
  s%gross_rain_cm_per_day=.5_real64
  scanopy=p%canopy_storage_cm/c; avevap=p%average_evaporation/c
  psat=-p%average_precipitation*scanopy/avevap*log(1._real64-avevap/p%average_precipitation)
  expected=c*(psat+avevap*c/p%average_precipitation*(s%gross_rain_cm_per_day-psat))
  call evaluate_gash_source_window(p,s,a,status)
  if(status/=VONHHBRADEN_AVAILABLE .or. abs(a-expected)>1.e-14_real64) error stop 2
  print '(a)', 'PPA_WU04D_GASH_SOURCE_ORACLE=PASS'
end program
