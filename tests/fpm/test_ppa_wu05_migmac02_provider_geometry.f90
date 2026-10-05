program test_ppa_wu05_migmac02_provider_geometry
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_ppa_wu05a16_inner_macropore_provider, only: ppa_wu05a16_inner_macropore_provider_t
  use mod_macropore_dynamic_shrinkage, only: prepare_clay_kim_option1
  use mod_ppa_wu05a5_multi_domain_process, only: macropore_geometry_result_t, macropore_multi_domain_receipt_t, &
       macropore_geometry_config_t, evaluate_macropore_geometry, evaluate_macropore_geometry_return, compose_macropore_candidate
  use mod_macropore_standard_storage, only: macropore_standard_storage_view_t, macropore_standard_candidate_receipt_t, &
       canonicalize_macropore_standard_storage, build_macropore_standard_candidate
  use mod_ppa_wu05a5_top_partition, only: macropore_top_partition_request_t, macropore_top_partition_result_t, &
       evaluate_macropore_top_partition
  use mod_macropore_continuation_state, only: macropore_continuation_state_t, copy_macropore_continuation_state
  use mod_fmr_macropore_top_input, only: fmr_macropore_top_input_forcing_t, prepare_fmr_macropore_top_input
  implicit none
  type(ppa_wu05a16_inner_macropore_provider_t)::provider
  type(macropore_geometry_result_t)::geometry
  type(macropore_multi_domain_receipt_t)::receipt
  type(macropore_top_partition_request_t)::partition_request
  type(macropore_top_partition_result_t)::partition
  type(macropore_continuation_state_t)::candidate_macro,restarted_macro
  type(fmr_macropore_top_input_forcing_t)::forcing
  real(real64)::theta(3),accepted_before(3),trial_a(3)
  real(real64),allocatable::geometry_return(:,:)
  real(real64),allocatable::requested_vertical(:),requested_lateral(:)
  real(real64)::exchange(1,3),rapid(3)
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
  provider%accepted_macro%volume_domain_cp=provider%geometry%volume_domain_cp
  provider%accepted_macro%water_domain_cp(1,:)=[0.05_real64,0.15_real64,0.05_real64]

  provider%shrinkage%enabled=.true.
  provider%shrinkage%surface_crack_area_node=1
  provider%shrinkage%surface_crack_area_node_supplied=.true.
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
  provider%z=[0.0_real64,-10.0_real64,-20.0_real64]
  theta=[0.35_real64,0.35_real64,0.35_real64]

  call provider%evaluate_trial_geometry(theta,geometry,ok)
  if(.not.ok .or. .not.geometry%valid)error stop 'MIGMAC02 provider trial geometry'
  if(geometry%dynamic_volume_cp(1)<=0.0_real64 .or. geometry%dynamic_volume_cp(2)<=0.0_real64 .or. &
       geometry%dynamic_volume_cp(3)<=0.0_real64)error stop 'MIGMAC02 provider hysteresis inactive'
  if(.not.allocated(geometry%subsidence_cp) .or. geometry%subsidence_cp(1)<=0.0_real64 .or. &
       geometry%surface_area_fraction<=0.0_real64)error stop 'MIGMAC02 dynamic surface geometry absent'
  if(abs(geometry%subsidence_cp(1)-0.3451061539437028_real64)>2.0e-14_real64 .or. &
       abs(geometry%dynamic_volume_cp(1)-0.6240382835673493_real64)>2.0e-14_real64 .or. &
       abs(geometry%surface_area_fraction-0.07463440132200398_real64)>2.0e-14_real64) &
       error stop 'MIGMAC02 independent B1.11 geometry oracle mismatch'
  if(abs(geometry%surface_area_fraction-(0.1_real64/10.0_real64+ &
       geometry%dynamic_volume_cp(1)/(10.0_real64-geometry%subsidence_cp(1))))>1.0e-14_real64) &
       error stop 'MIGMAC02 subsidence-adjusted surface area mismatch'
  forcing%supplied=.true.
  forcing%net_rain_rate_cm_per_day=1.0_real64
  call prepare_fmr_macropore_top_input(forcing,provider%geometry_config,geometry,1.0_real64, &
       requested_vertical,requested_lateral,ok)
  if(.not.ok .or. abs(sum(requested_vertical)-geometry%surface_area_fraction)>1.0e-14_real64) &
       error stop 'MIGMAC02 dynamic surface area top-input feedback'
  trial_a=geometry%dynamic_volume_cp
  if(maxval(abs(provider%accepted_macro%dynamic_volume_cp-accepted_before))>1.0e-15_real64) &
       error stop 'MIGMAC02 provider mutated accepted state'

  provider%bottom_boundary_mode=2
  call provider%evaluate_trial_geometry(theta,geometry,ok,[-10.0_real64,5.0_real64,10.0_real64])
  if(.not.ok .or. geometry%dynamic_volume_cp(3)/=0.0_real64) &
       error stop 'MIGMAC02 current groundwater clipping mismatch'
  provider%bottom_boundary_mode=1
  call provider%evaluate_trial_geometry(theta,geometry,ok)
  if(.not.ok .or. any(transfer(geometry%dynamic_volume_cp,[0_int64],3)/=transfer(trial_a,[0_int64],3))) &
       error stop 'MIGMAC02 groundwater candidate leaked into accepted replay'

  ! A rejected/superseded trial cannot publish its geometry; the accepted
  ! boundary remains the sole history source for the next candidate.
  call copy_macropore_continuation_state(provider%accepted_macro,restarted_macro,ok)
  if(.not.ok .or. .not.provider%accepted_macro%same_values(restarted_macro)) &
       error stop 'MIGMAC02 accepted-boundary restart copy mismatch'
  ! A rejected wet trial followed by a retry from the accepted boundary must
  ! reproduce A exactly, independent of the rejected B candidate.
  call provider%evaluate_trial_geometry([0.45_real64,0.45_real64,0.45_real64],geometry,ok)
  if(.not.ok .or. any(geometry%dynamic_volume_cp/=0.0_real64)) error stop 'MIGMAC02 wet closure geometry'
  call provider%evaluate_trial_geometry(theta,geometry,ok)
  if(.not.ok .or. any(transfer(geometry%dynamic_volume_cp,[0_int64],3)/=transfer(trial_a,[0_int64],3))) &
       error stop 'MIGMAC02 rejected-trial retry mismatch'
  call provider%evaluate_trial_geometry([0.45_real64,0.45_real64,0.45_real64],geometry,ok)
  if(.not.ok)error stop 'MIGMAC02 wet displacement geometry'
  call evaluate_macropore_geometry_return(provider%accepted_macro,geometry,geometry_return,ok)
  if(.not.ok .or. abs(sum(geometry_return)-0.05_real64)>1.0e-14_real64) &
       error stop 'MIGMAC02 shrink displacement amount'

  partition_request%num_domains=1
  partition_request%top_node=1
  partition_request%requested_vertical_cm=[0.0_real64]
  partition_request%requested_lateral_cm=[0.0_real64]
  partition_request%available_capacity_cm=[0.1_real64]
  partition_request%domain_fraction=[1.0_real64]
  call evaluate_macropore_top_partition(partition_request,partition)
  if(.not.partition%valid)error stop 'MIGMAC02 zero-input top partition'
  exchange=0.0_real64
  rapid=0.0_real64
  call compose_macropore_candidate(provider%accepted_macro,geometry,partition,exchange,rapid,1.0_real64, &
       candidate_macro,receipt,ok)
  if(.not.ok .or. .not.receipt%valid)error stop 'MIGMAC02 geometry candidate composition'
  if(abs(receipt%geometry_return_to_matrix_cm-0.05_real64)>1.0e-14_real64 .or. &
       abs(receipt%macro_balance_residual_cm)>1.0e-14_real64)error stop 'MIGMAC02 geometry water balance'
  if(abs(candidate_macro%water_domain_cp(1,2)-geometry%volume_domain_cp(1,2))>1.0e-14_real64) &
       error stop 'MIGMAC02 geometry capacity clamp'
  if(.not.provider%accepted_macro%same_values(restarted_macro))error stop 'MIGMAC02 rejected trial changed checkpoint'

  ! With the feature disabled, the admitted static/dynamic-zero route returns
  ! the exact supplied geometry carrier unchanged.
  provider%shrinkage%enabled=.false.
  call provider%evaluate_trial_geometry(theta,geometry,ok)
  if(.not.ok .or. any(geometry%dynamic_volume_cp/=provider%geometry%dynamic_volume_cp)) &
       error stop 'MIGMAC02 disabled-path geometry preservation'

  print '(a)', 'PPA_WU05_MIGMAC02_PROVIDER_TRIAL_GEOMETRY=PASS'
  print '(a,3(es24.16,1x))', 'PPA_WU05_MIGMAC02_PROVIDER_DYNAMIC_CM=',geometry%dynamic_volume_cp
  call exercise_standard_owner_transitions()
contains
  subroutine exercise_standard_owner_transitions()
    type(macropore_continuation_state_t)::dry,wet,redry,again,unchanged
    type(macropore_geometry_config_t)::cfg
    type(macropore_geometry_result_t)::g
    type(macropore_standard_storage_view_t)::view
    type(macropore_standard_candidate_receipt_t)::r
    type(macropore_top_partition_request_t)::tr
    type(macropore_top_partition_result_t)::tp
    real(real64),allocatable::returned(:,:)
    real(real64)::zz(3),dd(3),rates(2,3),rr(3)
    logical::valid

    zz=[-5.0_real64,-15.0_real64,-25.0_real64];dd=10.0_real64;rr=0.0_real64
    cfg%num_domains=2;cfg%num_nodes=3;cfg%top_node=1
    cfg%static_volume_cp=[0.1_real64,0.0_real64,0.0_real64]
    cfg%dz=dd;cfg%characteristic_diameter=[1.0_real64,1.0_real64,1.0_real64];cfg%potential_bottom_domain=[3,1]
    allocate(cfg%domain_fraction(2,3))
    cfg%domain_fraction(1,:)=[0.3_real64,1.0_real64,1.0_real64]
    cfg%domain_fraction(2,:)=[0.7_real64,0.0_real64,0.0_real64]
    call dry%initialize(2,3,valid)
    if(.not.valid)error stop 'MIGMAC02 standard two-domain init'
    dry%dynamic_volume_cp=[0.0_real64,0.4_real64,0.4_real64]
    call evaluate_macropore_geometry(cfg,dry%dynamic_volume_cp,g)
    dry%volume_domain_cp=g%volume_domain_cp;dry%icp_bottom_domain=g%bottom_domain
    dry%water_domain_cp=g%volume_domain_cp
    call canonicalize_macropore_standard_storage(dry,1,zz,dd,view,valid)
    if(.not.valid)error stop 'MIGMAC02 standard dry canonicalization'
    tr%num_domains=2;tr%top_node=1
    tr%requested_vertical_cm=[0.0_real64,0.0_real64];tr%requested_lateral_cm=[0.0_real64,0.0_real64]
    tr%available_capacity_cm=[0.0_real64,0.0_real64];tr%domain_fraction=[0.3_real64,0.7_real64]
    call evaluate_macropore_top_partition(tr,tp)
    rates=0.0_real64
    call build_macropore_standard_candidate(dry,g,tp,rates,rr,1.0_real64,1,zz,dd,unchanged,view,r,valid)
    if(.not.valid .or. .not.dry%same_values(unchanged))error stop 'MIGMAC02 unchanged standard owner identity'

    ! Independent oracle: 0.9 cm dry storage -> 0.1 cm wet capacity + 0.8 cm matrix return.
    call evaluate_macropore_geometry(cfg,[0.0_real64,0.0_real64,0.0_real64],g)
    call evaluate_macropore_geometry_return(dry,g,returned,valid)
    if(.not.valid .or. abs(sum(returned)-0.8_real64)>1.0e-14_real64)error stop 'MIGMAC02 two-domain return oracle'
    if(abs(sum(returned(1,:))-0.8_real64)>1.0e-14_real64 .or. &
       abs(sum(returned(2,:)))>1.0e-14_real64)error stop 'MIGMAC02 domain return ownership'
    rates=returned
    call build_macropore_standard_candidate(dry,g,tp,rates,rr,1.0_real64,1,zz,dd,wet,view,r,valid)
    if(.not.valid .or. .not.r%valid)error stop 'MIGMAC02 deactivated bottom candidate'
    if(abs(sum(wet%water_domain_cp)-0.1_real64)>1.0e-14_real64 .or. &
       abs(r%internal_exchange_to_matrix_cm-0.8_real64)>1.0e-14_real64 .or. &
       abs(r%macro_balance_residual_cm)>1.0e-14_real64)error stop 'MIGMAC02 two-domain mass oracle'
    if(any(wet%icp_bottom_domain/=1) .or. any(wet%dynamic_volume_cp/=0.0_real64)) &
         error stop 'MIGMAC02 geometry history publication'
    call evaluate_macropore_geometry(cfg,[0.0_real64,0.4_real64,0.4_real64],g)
    rates=0.0_real64
    call build_macropore_standard_candidate(wet,g,tp,rates,rr,1.0_real64,1,zz,dd,redry,view,r,valid)
    if(.not.valid .or. abs(sum(redry%water_domain_cp)-0.1_real64)>1.0e-14_real64) &
         error stop 'MIGMAC02 wet dry creates water'
    if(any(redry%icp_bottom_domain/=[3,1]) .or. any(redry%dynamic_volume_cp/=g%dynamic_volume_cp)) &
         error stop 'MIGMAC02 dry capacity and history publication'
    call build_macropore_standard_candidate(wet,g,tp,rates,rr,0.5_real64,1,zz,dd,again,view,r,valid)
    if(.not.valid .or. .not.redry%same_values(again))error stop 'MIGMAC02 standard retry geometry identity'
    print '(a)', 'PPA_WU05_MIGMAC02_STANDARD_OWNER_TWO_DOMAIN_TRANSITIONS=PASS'
  end subroutine exercise_standard_owner_transitions
end program
