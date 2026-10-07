program test_crop_adaptive_root_profile_owner
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_wofost_rate_table, only: wofost_rate_table_t, construct_wofost_rate_table, WOFOST_RATE_TABLE_OK
  use mod_crop_adaptive_root_profile_owner
  implicit none
  type(wofost_rate_table_t)::density
  type(adaptive_root_profile_parameters_t)::p
  type(adaptive_root_profile_state_t)::s0,s1,s2
  type(adaptive_root_profile_daily_forcing_t)::f
  class(transaction_state_t),allocatable::copy
  real(real64),allocatable::cum(:),lrv(:)
  real(real64)::ztop(4),zbot(4),dz(4)
  integer::status
  real(real64),parameter::tol=1.0e-12_real64

  ztop=[0.0_real64,-10.0_real64,-20.0_real64,-30.0_real64]
  zbot=[-10.0_real64,-20.0_real64,-30.0_real64,-40.0_real64]
  dz=10.0_real64
  call construct_wofost_rate_table([0.0_real64,0.5_real64,1.0_real64], &
       [2.0_real64,1.0_real64,0.0_real64],density,status)
  if(status/=WOFOST_RATE_TABLE_OK)error stop 1
  call initialize_adaptive_root_profile_state(density,zbot,40.0_real64,20.0_real64,100.0_real64,s0,status)
  if(status/=ADAPTIVE_ROOT_PROFILE_OK)error stop 2
  if(maxval(abs(s0%root_biomass_by_node-[75.0_real64,25.0_real64,0.0_real64,0.0_real64]))>tol)error stop 3

  p%growth_adaptation_fraction=1.0_real64
  p%death_adaptation_fraction=0.0_real64
  p%minimum_root_biomass_per_cm=0.0_real64
  p%specific_root_length_m_per_kg=100.0_real64

  f%old_rooted_nodes=2;f%rooted_nodes=3
  f%old_root_depth_cm=20.0_real64;f%root_depth_cm=25.0_real64;f%root_depth_extension_cm=5.0_real64
  f%root_biomass_end=110.0_real64;f%root_growth=10.0_real64;f%root_death=0.0_real64
  f%potential_root_sink=[0.6_real64,0.3_real64,0.1_real64,0.0_real64]
  f%root_sink_reduction=[0.1_real64,0.2_real64,0.0_real64,0.0_real64]

  call evaluate_adaptive_root_profile_candidate(p,s0,f,ztop,zbot,dz,s1,status)
  if(status/=ADAPTIVE_ROOT_PROFILE_OK)error stop 4
  ! Source split uses the biomass density at the old deepest rooted node.
  ! Here (25 kg / 10 cm) * 5 cm = 12.5 kg, capped by GRRT=10 kg,
  ! so all new growth goes to the newly rooted extension.
  if(maxval(abs(s1%root_biomass_by_node-[75.0_real64,25.0_real64,10.0_real64,0.0_real64]))>tol)error stop 5
  if(abs(sum(s1%root_biomass_by_node)-110.0_real64)>tol)error stop 6

  call s1%cumulative_root_fraction(3,cum,status)
  if(status/=ADAPTIVE_ROOT_PROFILE_OK)error stop 7
  if(abs(cum(1))>tol.or.abs(cum(4)-1.0_real64)>tol)error stop 8

  call s1%root_length_density(3,dz,p,lrv,status)
  if(status/=ADAPTIVE_ROOT_PROFILE_OK)error stop 9
  if(abs(lrv(1)-75.0_real64*100.0_real64/1.0e7_real64)>tol)error stop 10
  if(any(lrv(4:4)/=0.0_real64))error stop 11

  ! Same checkpoint + forcing is deterministic and does not mutate committed state.
  call evaluate_adaptive_root_profile_candidate(p,s0,f,ztop,zbot,dz,s2,status)
  if(status/=ADAPTIVE_ROOT_PROFILE_OK)error stop 12
  if(maxval(abs(s2%root_biomass_by_node-s1%root_biomass_by_node))>tol)error stop 13
  if(maxval(abs(s0%root_biomass_by_node-[75.0_real64,25.0_real64,0.0_real64,0.0_real64]))>tol)error stop 14

  call s1%clone(copy)
  select type(typed=>copy)
  type is(adaptive_root_profile_state_t)
    if(maxval(abs(typed%root_biomass_by_node-s1%root_biomass_by_node))>tol)error stop 15
  class default
    error stop 16
  end select

  print '(a)','SW431_ROOT_DENSITY_ADAPTIVE=PASS'
end program
