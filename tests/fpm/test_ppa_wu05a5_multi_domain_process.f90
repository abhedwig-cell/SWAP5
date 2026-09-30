program test_ppa_wu05a5_multi_domain_process
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_macropore_continuation_state, only: macropore_continuation_state_t
  use mod_ppa_wu05a5_top_partition, only: macropore_top_partition_request_t, &
       macropore_top_partition_result_t, evaluate_macropore_top_partition
  use mod_ppa_wu05a5_multi_domain_process, only: macropore_geometry_config_t, &
       macropore_geometry_result_t, macropore_multi_domain_receipt_t, &
       evaluate_macropore_geometry, compose_macropore_candidate
  implicit none

  integer, parameter :: nd=3,n=5
  type(macropore_continuation_state_t) :: accepted,candidate
  type(macropore_geometry_config_t) :: config
  type(macropore_geometry_result_t) :: geometry
  type(macropore_top_partition_request_t) :: top_request
  type(macropore_top_partition_result_t) :: top_result
  type(macropore_multi_domain_receipt_t) :: receipt
  real(real64) :: exchange(nd,n), rapid(n)
  logical :: ok

  call accepted%initialize(nd,n,ok)
  if(.not.ok) error stop 'A5 composition state init'
  accepted%icp_bottom_domain=[4,4,3]
  accepted%dynamic_volume_cp=[0.05_real64,0.04_real64,0.03_real64,0.02_real64,0.01_real64]
  accepted%volume_domain_cp=0.0_real64
  accepted%water_domain_cp=0.0_real64

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

  call evaluate_macropore_geometry(config,accepted%dynamic_volume_cp,geometry)
  if(.not.geometry%valid) error stop 'A5 geometry invalid'

  accepted%icp_bottom_domain=geometry%bottom_domain
  accepted%volume_domain_cp=geometry%volume_domain_cp
  accepted%water_domain_cp=0.35_real64*geometry%volume_domain_cp

  top_request%num_domains=nd
  top_request%top_node=1
  allocate(top_request%requested_vertical_cm(nd),top_request%requested_lateral_cm(nd), &
       top_request%available_capacity_cm(nd),top_request%domain_fraction(nd))
  top_request%requested_vertical_cm=[0.02_real64,0.012_real64,0.008_real64]
  top_request%requested_lateral_cm=[0.01_real64,0.006_real64,0.004_real64]
  top_request%domain_fraction=[0.5_real64,0.3_real64,0.2_real64]
  top_request%available_capacity_cm = geometry%volume_domain_cp(:,1)-accepted%water_domain_cp(:,1)

  call evaluate_macropore_top_partition(top_request,top_result)
  if(.not.top_result%valid) error stop 'A5 top result invalid'

  exchange=0.0_real64
  exchange(1,1:5)=[0.01_real64,0.008_real64,0.006_real64,0.004_real64,0.002_real64]
  exchange(2,1:4)=[0.005_real64,0.004_real64,0.003_real64,0.002_real64]
  exchange(3,1:3)=[0.003_real64,0.002_real64,0.001_real64]

  rapid=0.0_real64
  rapid(3)=0.001_real64
  rapid(4)=0.0015_real64
  rapid(5)=0.001_real64

  call compose_macropore_candidate(accepted,geometry,top_result,exchange,rapid,0.1_real64, &
       candidate,receipt,ok)
  if(.not.ok .or. .not.receipt%valid) error stop 'A5 composition failed'
  if(abs(receipt%macro_balance_residual_cm)>1.0e-10_real64) error stop 'A5 macro mass residual'
  if(abs(sum(receipt%matrix_exchange_rate)*0.1_real64-receipt%internal_exchange_to_matrix_cm)>1.0e-10_real64) &
       error stop 'A5 matrix exchange receipt'
  if(abs(receipt%rapid_external_outflow_cm-0.0035_real64)>1.0e-12_real64) &
       error stop 'A5 rapid external receipt'
  if(any(candidate%water_domain_cp<0.0_real64)) error stop 'A5 negative candidate water'
  if(any(candidate%water_domain_cp-candidate%volume_domain_cp>1.0e-12_real64)) &
       error stop 'A5 candidate exceeds geometry'
  if(any(candidate%icp_bottom_domain/=geometry%bottom_domain)) error stop 'A5 candidate bottoms'

  print '(a)', 'PPA_WU05A5_MULTI_DOMAIN_COMPOSITION=PASS'
end program test_ppa_wu05a5_multi_domain_process
