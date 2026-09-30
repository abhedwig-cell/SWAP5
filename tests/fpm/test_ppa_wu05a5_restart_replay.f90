program test_ppa_wu05a5_restart_replay
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_macropore_continuation_state, only: macropore_continuation_state_t
  use mod_ppa_wu05a5_top_partition, only: macropore_top_partition_request_t, &
       macropore_top_partition_result_t, evaluate_macropore_top_partition
  use mod_ppa_wu05a5_multi_domain_process, only: macropore_geometry_config_t, &
       macropore_geometry_result_t, macropore_multi_domain_receipt_t, &
       evaluate_macropore_geometry, compose_macropore_candidate
  use mod_ppa_wu05a5_macropore_restart, only: macropore_restart_payload_t, &
       encode_macropore_restart, decode_macropore_restart
  implicit none

  integer, parameter :: nd=3,n=5
  type(macropore_continuation_state_t) :: accepted,restored,next_a,next_b
  type(macropore_restart_payload_t) :: payload
  type(macropore_geometry_config_t) :: config
  type(macropore_geometry_result_t) :: geom_a,geom_b
  type(macropore_top_partition_request_t) :: top_request
  type(macropore_top_partition_result_t) :: top_result
  type(macropore_multi_domain_receipt_t) :: receipt_a,receipt_b
  real(real64) :: exchange(nd,n),rapid(n)
  logical :: ok

  call accepted%initialize(nd,n,ok)
  if(.not.ok) error stop 'A5 restart accepted init'
  accepted%icp_bottom_domain=[5,4,3]
  accepted%sorptivity=reshape([(0.01_real64*i,i=1,nd*n)],[nd,n])
  accepted%theta_sorption_ref=accepted%sorptivity+0.30_real64
  accepted%absorption_time=accepted%sorptivity+0.10_real64
  accepted%dynamic_volume_cp=[0.05_real64,0.04_real64,0.03_real64,0.02_real64,0.01_real64]

  config%num_domains=nd
  config%num_nodes=n
  config%top_node=1
  allocate(config%static_volume_cp(n),config%domain_fraction(nd,n), &
       config%potential_bottom_domain(nd),config%dz(n),config%characteristic_diameter(n))
  config%static_volume_cp=[0.20_real64,0.20_real64,0.15_real64,0.10_real64,0.05_real64]
  config%domain_fraction(:,1)=[0.5_real64,0.3_real64,0.2_real64]
  config%domain_fraction(:,2)=[0.5_real64,0.3_real64,0.2_real64]
  config%domain_fraction(:,3)=[0.6_real64,0.25_real64,0.15_real64]
  config%domain_fraction(:,4)=[0.8_real64,0.2_real64,0.0_real64]
  config%domain_fraction(:,5)=[1.0_real64,0.0_real64,0.0_real64]
  config%potential_bottom_domain=[5,4,3]
  config%dz=10.0_real64
  config%characteristic_diameter=4.0_real64

  call evaluate_macropore_geometry(config,accepted%dynamic_volume_cp,geom_a)
  if(.not.geom_a%valid) error stop 'A5 restart geometry A'
  accepted%icp_bottom_domain=geom_a%bottom_domain
  accepted%volume_domain_cp=geom_a%volume_domain_cp
  accepted%water_domain_cp=0.30_real64*accepted%volume_domain_cp

  call encode_macropore_restart(accepted,payload,ok)
  if(.not.ok) error stop 'A5 restart encode'
  call decode_macropore_restart(payload,restored,ok)
  if(.not.ok) error stop 'A5 restart decode'
  if(.not.restored%same_values(accepted)) error stop 'A5 restart state identity'

  call evaluate_macropore_geometry(config,restored%dynamic_volume_cp,geom_b)
  if(.not.geom_b%valid) error stop 'A5 restart geometry B'
  if(any(geom_a%bottom_domain/=geom_b%bottom_domain)) error stop 'A5 restart derived bottoms'
  if(maxval(abs(geom_a%volume_domain_cp-geom_b%volume_domain_cp))>1.0e-14_real64) &
       error stop 'A5 restart derived volume'

  top_request%num_domains=nd
  top_request%top_node=1
  allocate(top_request%requested_vertical_cm(nd),top_request%requested_lateral_cm(nd), &
       top_request%available_capacity_cm(nd),top_request%domain_fraction(nd))
  top_request%requested_vertical_cm=[0.01_real64,0.006_real64,0.004_real64]
  top_request%requested_lateral_cm=[0.005_real64,0.003_real64,0.002_real64]
  top_request%domain_fraction=[0.5_real64,0.3_real64,0.2_real64]
  top_request%available_capacity_cm=geom_a%volume_domain_cp(:,1)-accepted%water_domain_cp(:,1)
  call evaluate_macropore_top_partition(top_request,top_result)
  if(.not.top_result%valid) error stop 'A5 restart top partition'

  exchange=0.0_real64
  exchange(1,1:5)=[0.004_real64,0.003_real64,0.002_real64,0.001_real64,0.0005_real64]
  exchange(2,1:4)=[0.002_real64,0.0015_real64,0.001_real64,0.0005_real64]
  exchange(3,1:3)=[0.001_real64,0.0008_real64,0.0004_real64]
  rapid=0.0_real64
  rapid(4)=0.0005_real64
  rapid(5)=0.0004_real64

  call compose_macropore_candidate(accepted,geom_a,top_result,exchange,rapid,0.1_real64, &
       next_a,receipt_a,ok)
  if(.not.ok) error stop 'A5 restart replay candidate A'
  call compose_macropore_candidate(restored,geom_b,top_result,exchange,rapid,0.1_real64, &
       next_b,receipt_b,ok)
  if(.not.ok) error stop 'A5 restart replay candidate B'

  if(.not.next_a%same_values(next_b)) error stop 'A5 restart next candidate identity'
  if(abs(receipt_a%macro_balance_residual_cm-receipt_b%macro_balance_residual_cm)>1.0e-15_real64) &
       error stop 'A5 restart receipt residual'
  if(maxval(abs(receipt_a%matrix_exchange_rate-receipt_b%matrix_exchange_rate))>1.0e-15_real64) &
       error stop 'A5 restart matrix receipt identity'

  print '(a)', 'PPA_WU05A5_RESTART_REPLAY=PASS'

contains
  integer :: i
end program test_ppa_wu05a5_restart_replay
