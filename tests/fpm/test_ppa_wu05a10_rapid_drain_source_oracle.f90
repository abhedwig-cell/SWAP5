program test_ppa_wu05a10_rapid_drain_source_oracle
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_ppa_wu05a6_rapid_drain_rate, only: rapid_drain_request_t, rapid_drain_result_t, &
       evaluate_rapid_drain
  implicit none

  type(rapid_drain_request_t)::request
  type(rapid_drain_result_t)::result

  request%num_nodes=5
  request%top_water_node=2
  request%bottom_domain_node=4
  request%drain_type=2
  request%enabled=.true.
  request%saturated_top_fraction=0.6_real64
  request%water_level_cm=-60.0_real64
  request%domain_bottom_cm=-100.0_real64
  request%drain_level_cm=-80.0_real64
  request%ponding_cm=0.0_real64
  request%step_duration=0.1_real64
  request%area_exponent=3.0_real64
  request%kd_reference=0.001_real64
  request%resistance_reference_day=20.0_real64
  request%flow_reduction=1.0_real64
  request%water_storage_cm=0.7_real64
  request%volume_under_drain_cm=0.1_real64

  allocate(request%diameter(5),request%dz(5),request%volume_main_domain_cp(5))
  request%diameter=4.0_real64
  request%dz=10.0_real64
  request%volume_main_domain_cp=[0.2_real64,0.3_real64,0.4_real64,0.5_real64,0.0_real64]

  call evaluate_rapid_drain(request,result)
  if(.not.result%valid)error stop 'A10 source rapid invalid'
  if(abs(result%total_amount_cm-0.42484550516807507_real64)>1.0e-12_real64) &
       error stop 'A10 source rapid total oracle'
  if(abs(sum(result%amount_cp_cm)-result%total_amount_cm)>1.0e-12_real64) &
       error stop 'A10 source rapid distribution mass'
  if(.not.(result%amount_cp_cm(4)>result%amount_cp_cm(3) .and. &
           result%amount_cp_cm(3)>result%amount_cp_cm(2))) &
       error stop 'A10 source rapid kD ordering'

  request%water_storage_cm=0.03_real64
  request%volume_under_drain_cm=0.0_real64
  request%water_level_cm=-20.0_real64
  call evaluate_rapid_drain(request,result)
  if(abs(result%total_amount_cm-0.03_real64)>1.0e-12_real64) error stop 'A10 source rapid storage cap'

  request%drain_type=1
  request%domain_bottom_cm=-70.0_real64
  request%drain_level_cm=-80.0_real64
  call evaluate_rapid_drain(request,result)
  if(abs(result%total_amount_cm)>1.0e-15_real64) error stop 'A10 source rapid drain tube depth gate'

  print '(a)', 'PPA_WU05A10_RAPID_DRAIN=PASS'
end program test_ppa_wu05a10_rapid_drain_source_oracle
