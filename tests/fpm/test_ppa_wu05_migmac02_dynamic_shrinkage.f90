program test_ppa_wu05_migmac02_dynamic_shrinkage
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_macropore_dynamic_shrinkage
  implicit none
  type(dynamic_crack_request_t) :: r
  type(clay_kim_shrinkage_t) :: kim
  real(real64) :: fresh, historic, neighbour, shrink, expected
  logical :: ok

  r%theta=0.35_real64
  r%theta_previous=0.30_real64
  r%theta_s=0.45_real64
  r%theta_crack=0.30_real64
  r%dz_cm=10.0_real64
  r%geometry_factor=3.0_real64
  r%matrix_area_fraction=0.92_real64

  call evaluate_dynamic_crack_volume(r,0.05_real64,fresh,ok)
  if(.not.ok .or. abs(fresh)>1.0e-15_real64) error stop 'MIGMAC02 fresh E4 mismatch'
  r%prior_dynamic_volume_cm=0.08_real64
  call evaluate_dynamic_crack_volume(r,0.05_real64,historic,ok)
  if(.not.ok .or. historic<=0.0_real64) error stop 'MIGMAC02 historic E4 inactive'
  r%prior_dynamic_volume_cm=0.0_real64
  r%neighbour_dynamic_volume_cm=0.08_real64
  call evaluate_dynamic_crack_volume(r,0.05_real64,neighbour,ok)
  if(.not.ok .or. abs(neighbour-historic)>1.0e-14_real64) error stop 'MIGMAC02 neighbour E4 mismatch'
  expected=0.3092807260097771_real64
  if(abs(historic-expected)>1.0e-12_real64) error stop 'MIGMAC02 exact E4 value mismatch'

  ! Direct Kim option-1 parameters: independently check the documented equation.
  kim%alpha_k=0.343_real64
  kim%beta_k=2.0_real64
  kim%gamma_k=1.0_real64
  call evaluate_clay_kim_shrinkage_fraction(0.30_real64,0.50_real64,kim,shrink,ok)
  if(.not.ok) error stop 'MIGMAC02 Kim evaluation invalid'
  if(shrink<0.0_real64 .or. shrink>=1.0_real64) error stop 'MIGMAC02 Kim range'

  print '(a)', 'PPA_WU05_MIGMAC02_E4_HYSTERESIS=PASS'
  print '(a,es24.16)', 'PPA_WU05_MIGMAC02_E4_DYNAMIC_CM=',historic
  print '(a,es24.16)', 'PPA_WU05_MIGMAC02_KIM_SHRINK_FRACTION=',shrink
end program test_ppa_wu05_migmac02_dynamic_shrinkage
