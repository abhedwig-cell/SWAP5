program test_ppa_wu05a10_rapid_source_contract
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_ppa_wu05a6_rapid_drain_rate, only: rapid_drain_request_t, rapid_drain_result_t, evaluate_rapid_drain
  use mod_macropore_standard_rate_adapter, only: macropore_volume_below_level
  implicit none

  type(rapid_drain_request_t) :: request
  type(rapid_drain_result_t) :: result
  real(real64) :: z(4),dz(4),vol(4),under

  z=[-5.0_real64,-15.0_real64,-25.0_real64,-35.0_real64]
  dz=10.0_real64
  vol=0.2_real64

  under=macropore_volume_below_level(4,-35.0_real64,vol,z,dz)
  if(abs(under-0.1_real64)>1.0e-12_real64)error stop 'A10 VOLUNDR partial layer'
  under=macropore_volume_below_level(4,-30.0_real64,vol,z,dz)
  if(abs(under-0.2_real64)>1.0e-12_real64)error stop 'A10 VOLUNDR full bottom layer'

  request%num_nodes=4
  request%top_water_node=4
  request%bottom_domain_node=4
  request%drain_type=1
  request%enabled=.true.
  request%saturated_top_fraction=1.0_real64
  request%water_level_cm=-79.0_real64
  request%domain_bottom_cm=-79.95_real64
  request%drain_level_cm=-80.0_real64
  request%ponding_cm=0.0_real64
  request%step_duration=0.1_real64
  request%area_exponent=3.0_real64
  request%kd_reference=0.001_real64
  request%resistance_reference_day=20.0_real64
  request%flow_reduction=1.0_real64
  request%water_storage_cm=0.15_real64
  request%volume_under_drain_cm=0.0_real64
  allocate(request%diameter(4),request%dz(4),request%volume_main_domain_cp(4))
  request%diameter=4.0_real64
  request%dz=10.0_real64
  request%volume_main_domain_cp=0.0_real64
  request%volume_main_domain_cp(4)=0.2_real64

  call evaluate_rapid_drain(request,result)
  if(.not.result%valid)error stop 'A10 rapid request invalid'
  if(result%total_amount_cm<=0.0_real64)error stop 'A10 0.1 cm drain tube gate not active'
  if(abs(sum(result%amount_cp_cm)-result%total_amount_cm)>1.0e-12_real64) &
       error stop 'A10 rapid compartment distribution'

  request%domain_bottom_cm=-79.89_real64
  call evaluate_rapid_drain(request,result)
  if(.not.result%valid)error stop 'A10 rapid blocked request invalid'
  if(abs(result%total_amount_cm)>1.0e-15_real64)error stop 'A10 drain tube should block above tolerance'

  print '(a)', 'PPA_WU05A10_RAPID_SOURCE_CONTRACT=PASS'
end program test_ppa_wu05a10_rapid_source_contract
