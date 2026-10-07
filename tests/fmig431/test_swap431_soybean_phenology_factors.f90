program test_swap431_soybean_phenology_factors
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_wofost_soybean_phenology_factors
  implicit none

  type(soybean_phenology_parameters_t) :: p
  real(real64) :: f, dayl, popt, pcrt, alpha, p0, p1, p2, expected, dtsum, dvr
  logical :: anthesis_candidate, anthesis_triggered
  integer :: status
  real(real64), parameter :: tol=2.0e-12_real64

  p%maturity_group=4.0_real64
  p%maximum_vegetative_development_rate=0.10_real64
  p%maximum_generative_development_rate=0.08_real64
  p%minimum_development_temperature_c=5.0_real64
  p%optimum_development_temperature_c=25.0_real64
  p%maximum_development_temperature_c=40.0_real64
  p%derive_photoperiod_from_maturity_group=.true.
  if(.not.p%ready()) error stop 1

  call soybean_temperature_reduction_factor(p,4.0_real64,f,status)
  if(status/=SOY_PHENOLOGY_OK.or.f/=0.0_real64) error stop 2
  call soybean_temperature_reduction_factor(p,25.0_real64,f,status)
  if(status/=SOY_PHENOLOGY_OK.or.abs(f-1.0_real64)>tol) error stop 3
  call soybean_temperature_reduction_factor(p,40.0_real64,f,status)
  if(status/=SOY_PHENOLOGY_OK.or.abs(f)>tol) error stop 4
  call soybean_temperature_reduction_factor(p,41.0_real64,f,status)
  if(status/=SOY_PHENOLOGY_OK.or.f/=0.0_real64) error stop 5

  call p%resolved_photoperiod_bounds(popt,pcrt)
  if(abs(popt-(12.759_real64-0.388_real64*4.0_real64-0.058_real64*16.0_real64))>tol) error stop 6
  if(abs(pcrt-(27.275_real64-0.493_real64*4.0_real64-0.066_real64*16.0_real64))>tol) error stop 7
  if(pcrt<=24.0_real64) error stop 8

  call soybean_astronomic_daylength_hours(0.0_real64,100,dayl,status)
  if(status/=SOY_PHENOLOGY_OK.or.abs(dayl-12.0_real64)>tol) error stop 9

  p%derive_photoperiod_from_maturity_group=.false.
  p%optimum_photoperiod_hours=13.0_real64
  p%critical_photoperiod_hours=16.0_real64
  if(.not.p%ready()) error stop 10
  call soybean_photoperiod_reduction_factor(p,0.0_real64,100,f,dayl,status)
  if(status/=SOY_PHENOLOGY_OK.or.abs(f-1.0_real64)>tol) error stop 11

  p%optimum_photoperiod_hours=5.0_real64
  p%critical_photoperiod_hours=10.0_real64
  call soybean_photoperiod_reduction_factor(p,0.0_real64,100,f,dayl,status)
  if(status/=SOY_PHENOLOGY_OK.or.abs(f)>tol) error stop 12

  p%optimum_photoperiod_hours=10.0_real64
  p%critical_photoperiod_hours=16.0_real64
  call soybean_photoperiod_reduction_factor(p,0.0_real64,100,f,dayl,status)
  if(status/=SOY_PHENOLOGY_OK) error stop 13
  alpha=log(2.0_real64)/log(((16.0_real64-10.0_real64)/3.0_real64)+1.0_real64)
  p0=(16.0_real64-10.0_real64)/3.0_real64
  p1=(12.0_real64-10.0_real64)/3.0_real64+1.0_real64
  p2=(16.0_real64-12.0_real64)/(16.0_real64-10.0_real64)
  expected=(p1*(p2**p0))**alpha
  if(abs(f-expected)>tol) error stop 14

  ! Exact B1.11 soybean daily-rate assembly.
  p%apply_photoperiod_in_vegetative_phase=.false.
  call soybean_daily_development_rate(p,0.20_real64,25.0_real64,0.0_real64,100,.false., &
       dtsum,dvr,anthesis_candidate,anthesis_triggered,status)
  if(status/=SOY_PHENOLOGY_OK.or.abs(dtsum-25.0_real64)>tol.or.abs(dvr-0.10_real64)>tol) error stop 15
  if(anthesis_candidate.or.anthesis_triggered) error stop 16

  p%apply_photoperiod_in_vegetative_phase=.true.
  p%optimum_photoperiod_hours=13.0_real64
  p%critical_photoperiod_hours=16.0_real64
  call soybean_daily_development_rate(p,0.95_real64,25.0_real64,0.0_real64,100,.false., &
       dtsum,dvr,anthesis_candidate,anthesis_triggered,status)
  if(status/=SOY_PHENOLOGY_OK.or.abs(dvr-0.05_real64)>tol) error stop 17
  if(.not.anthesis_candidate.or..not.anthesis_triggered) error stop 18

  ! Generative phase always applies photoperiod in B1.11.
  call soybean_daily_development_rate(p,1.20_real64,25.0_real64,0.0_real64,100,.true., &
       dtsum,dvr,anthesis_candidate,anthesis_triggered,status)
  if(status/=SOY_PHENOLOGY_OK.or.abs(dvr-0.08_real64)>tol) error stop 19
  if(.not.anthesis_candidate.or.anthesis_triggered) error stop 20

  print '(a)','SW431_CROP_SOY_FACTORS=PASS'
end program
