program test_ppa_wu05a6_rate_bundle
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_ppa_wu05a6_rate_bundle, only: macropore_rate_bundle_request_t, &
       macropore_rate_bundle_result_t, evaluate_macropore_rate_bundle
  implicit none

  type(macropore_rate_bundle_request_t)::request
  type(macropore_rate_bundle_result_t)::result
  integer,parameter::nd=1,n=3

  call setup_unsat(request)
  call setup_sat(request%interflow_sat)
  call setup_sat(request%matrix_sat)

  request%interflow_sat%matrix_head=[20.0_real64,20.0_real64,20.0_real64]
  request%matrix_sat%matrix_head=[2.0_real64,2.0_real64,2.0_real64]

  request%rapid%num_nodes=n
  request%rapid%top_water_node=1
  request%rapid%bottom_domain_node=3
  request%rapid%drain_type=2
  request%rapid%enabled=.true.
  request%rapid%saturated_top_fraction=1.0_real64
  request%rapid%water_level_cm=-60.0_real64
  request%rapid%domain_bottom_cm=-100.0_real64
  request%rapid%drain_level_cm=-80.0_real64
  request%rapid%ponding_cm=0.0_real64
  request%rapid%step_duration=0.1_real64
  request%rapid%area_exponent=3.0_real64
  request%rapid%kd_reference=0.001_real64
  request%rapid%resistance_reference_day=20.0_real64
  request%rapid%flow_reduction=1.0_real64
  request%rapid%water_storage_cm=0.6_real64
  request%rapid%volume_under_drain_cm=0.0_real64
  allocate(request%rapid%diameter(n),request%rapid%dz(n),request%rapid%volume_main_domain_cp(n))
  request%rapid%diameter=4.0_real64
  request%rapid%dz=10.0_real64
  request%rapid%volume_main_domain_cp=0.3_real64

  request%limiter%num_domains=nd
  allocate(request%limiter%accepted_storage_cm(nd),request%limiter%maximum_storage_cm(nd), &
       request%limiter%minimum_storage_cm(nd),request%limiter%potential_top_vertical_cm(nd), &
       request%limiter%potential_top_lateral_cm(nd),request%limiter%potential_interflow_sat_cm(nd), &
       request%limiter%potential_matrix_sat_cm(nd),request%limiter%potential_outflow_cm(nd), &
       request%limiter%redistribution_capacity_cm(nd),request%limiter%top_domain_fraction(nd))
  request%limiter%accepted_storage_cm=0.2_real64
  request%limiter%maximum_storage_cm=1.0_real64
  request%limiter%minimum_storage_cm=0.0_real64
  request%limiter%potential_top_vertical_cm=0.02_real64
  request%limiter%potential_top_lateral_cm=0.01_real64
  request%limiter%potential_interflow_sat_cm=0.0_real64
  request%limiter%potential_matrix_sat_cm=0.0_real64
  request%limiter%potential_outflow_cm=0.0_real64
  request%limiter%redistribution_capacity_cm=0.5_real64
  request%limiter%top_domain_fraction=1.0_real64
  request%top_node=1

  call evaluate_macropore_rate_bundle(request,result)
  if(.not.result%valid)error stop 'A6 bundle invalid'
  if(abs(result%top_partition%receipt_residual_cm)>1.0e-12_real64) &
       error stop 'A6 bundle top receipt'
  if(abs(sum(result%qexc_to_matrix_rate) - &
       sum(result%qout_sat_rate+result%qout_unsat_rate-result%qin_interflow_rate-result%qin_matrix_sat_rate)) > &
       1.0e-12_real64) error stop 'A6 bundle qexc composition'
  if(abs(sum(result%rapid_outflow_cp_cm) - &
       result%limiter%outflow_fraction(1)*result%rapid%total_amount_cm)>1.0e-12_real64) &
       error stop 'A6 bundle rapid scaling'

  print '(a)', 'PPA_WU05A6_RATE_BUNDLE=PASS'

contains

  subroutine setup_unsat(bundle)
    type(macropore_rate_bundle_request_t),intent(inout)::bundle
    allocate(bundle%unsaturated%sorptivity%bottom_domain(nd),bundle%unsaturated%sorptivity%top_water_node(nd), &
         bundle%unsaturated%sorptivity%theta(n),bundle%unsaturated%sorptivity%theta_s(n), &
         bundle%unsaturated%sorptivity%theta_r(n),bundle%unsaturated%sorptivity%dz(n), &
         bundle%unsaturated%sorptivity%diameter(n),bundle%unsaturated%sorptivity%wall_correction(n), &
         bundle%unsaturated%sorptivity%sorptivity_max(n),bundle%unsaturated%sorptivity%sorptivity_alpha(n), &
         bundle%unsaturated%sorptivity%domain_fraction(nd,n),bundle%unsaturated%sorptivity%wet_fraction(nd,n), &
         bundle%unsaturated%sorptivity%history_sorptivity(nd,n), &
         bundle%unsaturated%sorptivity%history_theta_ref(nd,n), &
         bundle%unsaturated%sorptivity%history_absorption_time(nd,n),bundle%unsaturated%pressure_head(n), &
         bundle%unsaturated%elevation(n),bundle%unsaturated%conductivity(n),bundle%unsaturated%entry_head(n), &
         bundle%unsaturated%groundwater_level_domain(nd),bundle%unsaturated%sorp_fac_parallel(n))
    bundle%unsaturated%sorptivity%num_domains=nd
    bundle%unsaturated%sorptivity%num_nodes=n
    bundle%unsaturated%sorptivity%top_node=1
    bundle%unsaturated%sorptivity%swmbf=1
    bundle%unsaturated%sorptivity%matrix_top_saturated_node=4
    bundle%unsaturated%sorptivity%step_duration=0.1_real64
    bundle%unsaturated%sorptivity%flow_reduction=1.0_real64
    bundle%unsaturated%sorptivity%bottom_domain=3
    bundle%unsaturated%sorptivity%top_water_node=1
    bundle%unsaturated%sorptivity%theta=0.16_real64
    bundle%unsaturated%sorptivity%theta_s=0.45_real64
    bundle%unsaturated%sorptivity%theta_r=0.05_real64
    bundle%unsaturated%sorptivity%dz=10.0_real64
    bundle%unsaturated%sorptivity%diameter=4.0_real64
    bundle%unsaturated%sorptivity%wall_correction=0.95_real64
    bundle%unsaturated%sorptivity%sorptivity_max=0.2_real64
    bundle%unsaturated%sorptivity%sorptivity_alpha=0.5_real64
    bundle%unsaturated%sorptivity%domain_fraction=1.0_real64
    bundle%unsaturated%sorptivity%wet_fraction=1.0_real64
    bundle%unsaturated%sorptivity%history_sorptivity=0.0_real64
    bundle%unsaturated%sorptivity%history_theta_ref=0.0_real64
    bundle%unsaturated%sorptivity%history_absorption_time=0.0_real64
    bundle%unsaturated%shape_factor=1.0_real64
    bundle%unsaturated%pressure_head=-100.0_real64
    bundle%unsaturated%elevation=[-40.0_real64,-50.0_real64,-60.0_real64]
    bundle%unsaturated%conductivity=0.01_real64
    bundle%unsaturated%entry_head=-1.0_real64
    bundle%unsaturated%groundwater_level_domain=-20.0_real64
    bundle%unsaturated%sorp_fac_parallel=0.5_real64
  end subroutine setup_unsat

  subroutine setup_sat(request)
    use mod_ppa_wu05a6_saturated_exchange_rate, only: saturated_exchange_request_t
    type(saturated_exchange_request_t),intent(out)::request
    request%num_domains=nd
    request%num_nodes=n
    request%matrix_top_saturated_node=1
    request%matrix_bottom_saturated_node=3
    request%swsep=0
    request%matrix_level=5.0_real64
    request%step_duration=0.1_real64
    request%flow_reduction=1.0_real64
    request%shape_factor=1.0_real64
    allocate(request%bottom_domain(nd),request%top_macro_saturated_node(nd), &
         request%macro_saturated_fraction(nd),request%macro_reference_level(nd),request%z(n),request%dz(n), &
         request%matrix_head(n),request%ksat_horizontal(n),request%diameter(n),request%domain_fraction(nd,n), &
         request%cdarcy(nd,n))
    request%bottom_domain=3
    request%top_macro_saturated_node=1
    request%macro_saturated_fraction=1.0_real64
    request%macro_reference_level=10.0_real64
    request%z=[0.0_real64,0.0_real64,0.0_real64]
    request%dz=10.0_real64
    request%ksat_horizontal=0.1_real64
    request%diameter=4.0_real64
    request%domain_fraction=1.0_real64
    request%cdarcy=0.01_real64
  end subroutine setup_sat

end program test_ppa_wu05a6_rate_bundle
