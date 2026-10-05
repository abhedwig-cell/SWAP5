program test_ppa_wu05_migmac02_dynamic_shrinkage
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_macropore_dynamic_shrinkage
  implicit none
  type(dynamic_crack_request_t) :: r
  type(dynamic_crack_request_t) :: invalid
  type(clay_kim_shrinkage_t) :: kim
  type(dynamic_shrinkage_config_t) :: config
  real(real64) :: fresh, historic, neighbour, shrink, expected, drying, large_change, replay
  logical :: ok
  real(real64)::head_profile(5),z_profile(5),dz_profile(5)
  integer::crack_node

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
  z_profile=[0.0_real64,-10.0_real64,-20.0_real64,-30.0_real64,-40.0_real64]
  dz_profile=10.0_real64
  call map_surface_crack_depth_to_node(-10.0_real64,z_profile,dz_profile,1,crack_node,ok)
  if(.not.ok .or. crack_node/=2) error stop 'MIGMAC02 B1.11 ZnCrAr compartment mapping mismatch'
  call map_surface_crack_depth_to_node(-10.0_real64,z_profile,dz_profile,3,crack_node,ok)
  if(.not.ok .or. crack_node/=3) error stop 'MIGMAC02 covered-profile top-node mapping mismatch'
  call map_surface_crack_depth_to_node(-1000.0_real64,z_profile,dz_profile,1,crack_node,ok)
  if(ok) error stop 'MIGMAC02 out-of-profile ZnCrAr was accepted'
  head_profile=[-100.0_real64,-100.0_real64,-10.0_real64,5.0_real64,10.0_real64]
  if(find_dynamic_groundwater_cutoff(head_profile,z_profile,dz_profile,2)/=4) &
       error stop 'MIGMAC02 B1.11 groundwater cutoff mismatch'
  if(find_dynamic_groundwater_cutoff(head_profile,z_profile,dz_profile,1)/=6) &
       error stop 'MIGMAC02 fixed-head no-cutoff mismatch'
  head_profile=10.0_real64
  if(find_dynamic_groundwater_cutoff(head_profile,z_profile,dz_profile,2)/=1) &
       error stop 'MIGMAC02 fully saturated cutoff mismatch'
  if(find_dynamic_groundwater_cutoff(head_profile,z_profile,dz_profile,1)/=1) &
       error stop 'MIGMAC02 fully saturated prescribed-head cutoff mismatch'

  ! A/B/A replay starts each evaluation from the same accepted crack history.
  r%theta=0.35_real64
  r%theta_previous=0.30_real64
  r%prior_dynamic_volume_cm=0.08_real64
  call evaluate_dynamic_crack_volume(r,0.05_real64,historic,ok)
  if(.not.ok) error stop 'MIGMAC02 replay A failed'
  r%theta=0.20_real64
  r%theta_previous=0.35_real64
  r%prior_dynamic_volume_cm=0.0_real64
  call evaluate_dynamic_crack_volume(r,0.05_real64,drying,ok)
  if(.not.ok .or. drying<=0.0_real64) error stop 'MIGMAC02 drying transition inactive'
  r%theta=0.35_real64
  r%theta_previous=0.30_real64
  r%prior_dynamic_volume_cm=0.08_real64
  call evaluate_dynamic_crack_volume(r,0.05_real64,replay,ok)
  if(.not.ok .or. transfer(replay,0_int64)/=transfer(historic,0_int64)) error stop 'MIGMAC02 A/B/A mismatch'

  ! A non-transitioning state leaves geometry unchanged; saturation closes it.
  r%theta=0.35_real64
  r%theta_previous=0.36_real64
  r%prior_dynamic_volume_cm=0.0_real64
  r%neighbour_dynamic_volume_cm=0.0_real64
  call evaluate_dynamic_crack_volume(r,0.05_real64,replay,ok)
  if(.not.ok .or. abs(replay)>1.0e-15_real64) error stop 'MIGMAC02 unchanged geometry mismatch'
  r%theta=r%theta_s
  r%prior_dynamic_volume_cm=0.08_real64
  call evaluate_dynamic_crack_volume(r,0.05_real64,replay,ok)
  if(.not.ok .or. abs(replay)>1.0e-15_real64) error stop 'MIGMAC02 saturated crack closure mismatch'
  invalid=r
  invalid%theta=ieee_value(0.0_real64,ieee_quiet_nan)
  call evaluate_dynamic_crack_volume(invalid,0.05_real64,replay,ok)
  if(ok) error stop 'MIGMAC02 accepted NaN moisture'

  ! Large but bounded shrinkage remains a valid physical geometry.
  r%theta=0.20_real64
  r%theta_previous=0.35_real64
  r%prior_dynamic_volume_cm=0.0_real64
  call evaluate_dynamic_crack_volume(r,0.20_real64,large_change,ok)
  if(.not.ok .or. large_change<=1.0_real64 .or. large_change>=r%dz_cm*r%matrix_area_fraction) &
       error stop 'MIGMAC02 large geometry change outside physical bound'

  ! Direct Kim option-1 parameters: independently check the documented equation.
  call prepare_clay_kim_option1(0.50_real64,0.20_real64,2.0_real64,1.20_real64,kim,ok)
  if(.not.ok) error stop 'MIGMAC02 SHRINKPAR option1 invalid'
  if(abs(kim%transition_moisture_ratio-0.34657359027997265_real64)>1.0e-14_real64) &
       error stop 'MIGMAC02 SHRINKPAR transition mismatch'
  call evaluate_clay_kim_shrinkage_fraction(0.10_real64,0.50_real64,kim,shrink,ok)
  if(.not.ok) error stop 'MIGMAC02 Kim evaluation invalid'
  if(abs(shrink-0.31296799539643605_real64)>1.0e-14_real64) error stop 'MIGMAC02 donor-transcribed SHRINK mismatch'
  config%enabled=.true.
  config%theta_s=[0.50_real64,0.50_real64]
  config%theta_crack=[0.10_real64,0.10_real64]
  config%kim=[kim,kim]
  call derive_dynamic_minimum_subsidence(config,[10.0_real64,20.0_real64],ok)
  if(.not.ok .or. maxval(abs(config%minimum_subsidence_cm- &
       [3.1296799539643605_real64,6.259359907928721_real64]))>2.0e-14_real64) &
       error stop 'MIGMAC02 source minimum subsidence oracle'
  call evaluate_clay_kim_shrinkage_fraction(0.20_real64,0.50_real64,kim,shrink,ok)
  if(.not.ok .or. abs(shrink-0.30_real64)>1.0e-14_real64) &
       error stop 'MIGMAC02 normal shrinkage branch mismatch'

  print '(a)', 'PPA_WU05_MIGMAC02_E4_HYSTERESIS=PASS'
  print '(a,es24.16)', 'PPA_WU05_MIGMAC02_E4_DYNAMIC_CM=',historic
  print '(a,es24.16)', 'PPA_WU05_MIGMAC02_KIM_SHRINK_FRACTION=',shrink
end program test_ppa_wu05_migmac02_dynamic_shrinkage
