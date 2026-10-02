program test_ppa_wu05_migmac02_provider_geometry
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_ppa_wu05a16_inner_macropore_provider, only: ppa_wu05a16_inner_macropore_provider_t
  use mod_macropore_dynamic_shrinkage, only: prepare_clay_kim_option1
  use mod_ppa_wu05a5_multi_domain_process, only: macropore_geometry_result_t, evaluate_macropore_geometry
  implicit none
  type(ppa_wu05a16_inner_macropore_provider_t)::provider
  type(macropore_geometry_result_t)::geometry
  real(real64)::theta(3),accepted_before(3)
  logical::ok
  integer::i

  call provider%accepted_macro%initialize(1,3,ok)
  if(.not.ok)error stop 'MIGMAC02 provider state init'
  provider%accepted_macro%icp_bottom_domain=3
  provider%accepted_macro%dynamic_volume_cp=[0.0_real64,0.08_real64,0.0_real64]
  accepted_before=provider%accepted_macro%dynamic_volume_cp

  provider%geometry_config%num_domains=1
  provider%geometry_config%num_nodes=3
  provider%geometry_config%top_node=1
  provider%geometry_config%static_volume_cp=[0.1_real64,0.1_real64,0.1_real64]
  allocate(provider%geometry_config%domain_fraction(1,3)); provider%geometry_config%domain_fraction=1.0_real64
  provider%geometry_config%potential_bottom_domain=[3]
  provider%geometry_config%dz=[10.0_real64,10.0_real64,10.0_real64]
  provider%geometry_config%characteristic_diameter=[1.0_real64,1.0_real64,1.0_real64]
  call evaluate_macropore_geometry(provider%geometry_config,provider%accepted_macro%dynamic_volume_cp,provider%geometry)
  if(.not.provider%geometry%valid)error stop 'MIGMAC02 accepted geometry'

  provider%shrinkage%enabled=.true.
  allocate(provider%shrinkage%theta_s(3),provider%shrinkage%theta_crack(3),provider%shrinkage%geometry_factor(3), &
       provider%shrinkage%minimum_subsidence_cm(3),provider%shrinkage%kim(3))
  provider%shrinkage%theta_s=0.45_real64
  provider%shrinkage%theta_crack=0.30_real64
  provider%shrinkage%geometry_factor=3.0_real64
  provider%shrinkage%minimum_subsidence_cm=0.0_real64
  do i=1,3
    call prepare_clay_kim_option1(0.45_real64,0.20_real64,2.0_real64,1.20_real64,provider%shrinkage%kim(i),ok)
    if(.not.ok)error stop 'MIGMAC02 provider kim'
  end do
  provider%accepted_matrix_theta=[0.30_real64,0.30_real64,0.30_real64]
  provider%matrix_area_fraction=[0.92_real64,0.92_real64,0.92_real64]
  provider%dz=[10.0_real64,10.0_real64,10.0_real64]
  theta=[0.35_real64,0.35_real64,0.35_real64]

  call provider%evaluate_trial_geometry(theta,geometry,ok)
  if(.not.ok .or. .not.geometry%valid)error stop 'MIGMAC02 provider trial geometry'
  if(geometry%dynamic_volume_cp(1)<=0.0_real64 .or. geometry%dynamic_volume_cp(2)<=0.0_real64 .or. &
       geometry%dynamic_volume_cp(3)<=0.0_real64)error stop 'MIGMAC02 provider hysteresis inactive'
  if(maxval(abs(provider%accepted_macro%dynamic_volume_cp-accepted_before))>1.0e-15_real64) &
       error stop 'MIGMAC02 provider mutated accepted state'

  print '(a)', 'PPA_WU05_MIGMAC02_PROVIDER_TRIAL_GEOMETRY=PASS'
  print '(a,3(es24.16,1x))', 'PPA_WU05_MIGMAC02_PROVIDER_DYNAMIC_CM=',geometry%dynamic_volume_cp
end program
