program test_macropore_standard_rate_adapter
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: soil_water_physical_state_t
  use mod_macropore_continuation_state, only: macropore_continuation_state_t
  use mod_ppa_wu05a5_multi_domain_process, only: macropore_geometry_result_t
  use mod_ppa_wu05a6_rate_bundle, only: macropore_rate_bundle_request_t
  use mod_ppa_wu05a6_sorptivity_history, only: sorptivity_history_update_request_t
  use mod_macropore_standard_storage, only: macropore_standard_storage_view_t, &
       canonicalize_macropore_standard_storage
  use mod_macropore_standard_rate_adapter, only: matrix_saturated_zone_view_t, &
       derive_matrix_saturated_zone_view, prepare_standard_macropore_rate_request, &
       prepare_standard_sorptivity_history_request
  implicit none

  integer,parameter::n=4,nd=1
  type(soil_water_physical_state_t)::matrix
  type(macropore_continuation_state_t)::macro
  type(macropore_geometry_result_t)::geometry
  type(macropore_standard_storage_view_t)::macro_view
  type(matrix_saturated_zone_view_t)::matrix_view
  type(macropore_rate_bundle_request_t)::template,request
  type(sorptivity_history_update_request_t)::history_template,history
  real(real64)::z(n),dz(n)
  logical::ok

  z=[-5.0_real64,-15.0_real64,-25.0_real64,-35.0_real64]
  dz=10.0_real64
  matrix%active_nodes=n
  allocate(matrix%pressure_head(n),matrix%water_content(n))
  matrix%pressure_head=[-100.0_real64,-50.0_real64,2.0_real64,12.0_real64]
  matrix%water_content=0.20_real64
  matrix%groundwater_level=-22.0_real64

  call derive_matrix_saturated_zone_view(matrix,z,dz,matrix_view)
  if(.not.matrix_view%valid .or. .not.matrix_view%active)error stop 'A8 matrix sat view'
  if(matrix_view%top_node/=3 .or. matrix_view%bottom_node/=4)error stop 'A8 matrix sat indices'

  call macro%initialize(nd,n,ok)
  if(.not.ok)error stop 'A8 adapter macro init'
  macro%icp_bottom_domain=4
  macro%volume_domain_cp=0.2_real64
  macro%water_domain_cp=0.0_real64
  macro%water_domain_cp(1,4)=0.27_real64
  call canonicalize_macropore_standard_storage(macro,1,z,dz,macro_view,ok)
  if(.not.ok)error stop 'A8 adapter macro view'

  geometry%valid=.true.
  geometry%num_domains=nd
  geometry%num_nodes=n
  geometry%top_node=1
  allocate(geometry%bottom_domain(nd),geometry%dynamic_volume_cp(n),geometry%total_volume_cp(n), &
       geometry%volume_domain_cp(nd,n))
  geometry%bottom_domain=4
  geometry%dynamic_volume_cp=0.0_real64
  geometry%total_volume_cp=0.2_real64
  geometry%volume_domain_cp=0.2_real64

  call setup_template(template)
  call prepare_standard_macropore_rate_request(template,macro,geometry,macro_view,matrix,z,dz,0.05_real64, &
       request,matrix_view,ok)
  if(.not.ok)error stop 'A8 rate adapter'
  if(request%unsaturated%sorptivity%top_water_node(1)/=3)error stop 'A8 adapted top water'
  if(abs(request%unsaturated%sorptivity%wet_fraction(1,3)-0.35_real64)>1.0e-12_real64) &
       error stop 'A8 adapted wet fraction'
  if(abs(request%unsaturated%groundwater_level_domain(1)+26.5_real64)>1.0e-12_real64) &
       error stop 'A8 adapted macro level'
  if(request%matrix_sat%matrix_top_saturated_node/=3 .or. request%matrix_sat%matrix_bottom_saturated_node/=4) &
       error stop 'A8 adapted matrix sat'
  if(abs(request%unsaturated%sorptivity%step_duration-0.05_real64)>1.0e-15_real64) &
       error stop 'A8 adapted dt'

  call setup_history(history_template)
  call prepare_standard_sorptivity_history_request(history_template,geometry,macro_view,matrix_view,0.05_real64,history,ok)
  if(.not.ok)error stop 'A8 history adapter'
  if(history%top_water_node(1)/=3 .or. abs(history%wet_fraction(1,3)-0.35_real64)>1.0e-12_real64) &
       error stop 'A8 history dynamic view'

  print '(a)', 'PPA_WU05A8_RATE_ADAPTER=PASS'

contains

  subroutine setup_template(bundle)
    type(macropore_rate_bundle_request_t),intent(out)::bundle
    allocate(bundle%unsaturated%sorptivity%bottom_domain(nd),bundle%unsaturated%sorptivity%top_water_node(nd), &
         bundle%unsaturated%sorptivity%theta(n),bundle%unsaturated%sorptivity%theta_s(n), &
         bundle%unsaturated%sorptivity%theta_r(n),bundle%unsaturated%sorptivity%dz(n), &
         bundle%unsaturated%sorptivity%diameter(n),bundle%unsaturated%sorptivity%wall_correction(n), &
         bundle%unsaturated%sorptivity%sorptivity_max(n),bundle%unsaturated%sorptivity%sorptivity_alpha(n), &
         bundle%unsaturated%sorptivity%domain_fraction(nd,n),bundle%unsaturated%sorptivity%wet_fraction(nd,n), &
         bundle%unsaturated%sorptivity%history_sorptivity(nd,n),bundle%unsaturated%sorptivity%history_theta_ref(nd,n), &
         bundle%unsaturated%sorptivity%history_absorption_time(nd,n),bundle%unsaturated%pressure_head(n), &
         bundle%unsaturated%elevation(n),bundle%unsaturated%conductivity(n),bundle%unsaturated%entry_head(n), &
         bundle%unsaturated%groundwater_level_domain(nd),bundle%unsaturated%sorp_fac_parallel(n))
    bundle%unsaturated%sorptivity%num_domains=nd
    bundle%unsaturated%sorptivity%num_nodes=n
    bundle%unsaturated%sorptivity%top_node=1
    bundle%unsaturated%sorptivity%swmbf=1
    bundle%unsaturated%sorptivity%matrix_top_saturated_node=n+1
    bundle%unsaturated%sorptivity%step_duration=0.1_real64
    bundle%unsaturated%sorptivity%flow_reduction=1.0_real64
    bundle%unsaturated%sorptivity%bottom_domain=4
    bundle%unsaturated%sorptivity%top_water_node=1
    bundle%unsaturated%sorptivity%theta=0.2_real64
    bundle%unsaturated%sorptivity%theta_s=0.45_real64
    bundle%unsaturated%sorptivity%theta_r=0.05_real64
    bundle%unsaturated%sorptivity%dz=dz
    bundle%unsaturated%sorptivity%diameter=4.0_real64
    bundle%unsaturated%sorptivity%wall_correction=0.95_real64
    bundle%unsaturated%sorptivity%sorptivity_max=0.1_real64
    bundle%unsaturated%sorptivity%sorptivity_alpha=0.5_real64
    bundle%unsaturated%sorptivity%domain_fraction=1.0_real64
    bundle%unsaturated%sorptivity%wet_fraction=1.0_real64
    bundle%unsaturated%sorptivity%history_sorptivity=0.0_real64
    bundle%unsaturated%sorptivity%history_theta_ref=0.0_real64
    bundle%unsaturated%sorptivity%history_absorption_time=0.0_real64
    bundle%unsaturated%shape_factor=1.0_real64
    bundle%unsaturated%pressure_head=-100.0_real64
    bundle%unsaturated%elevation=z
    bundle%unsaturated%conductivity=0.01_real64
    bundle%unsaturated%entry_head=-1.0_real64
    bundle%unsaturated%groundwater_level_domain=-30.0_real64
    bundle%unsaturated%sorp_fac_parallel=0.5_real64

    call setup_sat(bundle%interflow_sat)
    call setup_sat(bundle%matrix_sat)

    bundle%rapid%num_nodes=n
    bundle%rapid%top_water_node=1
    bundle%rapid%bottom_domain_node=4
    bundle%rapid%drain_type=2
    bundle%rapid%enabled=.false.
    bundle%rapid%saturated_top_fraction=1.0_real64
    bundle%rapid%water_level_cm=-30.0_real64
    bundle%rapid%domain_bottom_cm=-40.0_real64
    bundle%rapid%drain_level_cm=-20.0_real64
    bundle%rapid%ponding_cm=0.0_real64
    bundle%rapid%step_duration=0.1_real64
    bundle%rapid%area_exponent=3.0_real64
    bundle%rapid%kd_reference=0.001_real64
    bundle%rapid%resistance_reference_day=20.0_real64
    bundle%rapid%flow_reduction=1.0_real64
    bundle%rapid%water_storage_cm=sum(macro%water_domain_cp)
    bundle%rapid%volume_under_drain_cm=0.0_real64
    allocate(bundle%rapid%diameter(n),bundle%rapid%dz(n),bundle%rapid%volume_main_domain_cp(n))
    bundle%rapid%diameter=4.0_real64
    bundle%rapid%dz=dz
    bundle%rapid%volume_main_domain_cp=geometry%volume_domain_cp(1,:)

    bundle%limiter%num_domains=nd
    allocate(bundle%limiter%accepted_storage_cm(nd),bundle%limiter%maximum_storage_cm(nd), &
         bundle%limiter%minimum_storage_cm(nd),bundle%limiter%potential_top_vertical_cm(nd), &
         bundle%limiter%potential_top_lateral_cm(nd),bundle%limiter%potential_interflow_sat_cm(nd), &
         bundle%limiter%potential_matrix_sat_cm(nd),bundle%limiter%potential_outflow_cm(nd), &
         bundle%limiter%redistribution_capacity_cm(nd),bundle%limiter%top_domain_fraction(nd))
    bundle%limiter%accepted_storage_cm=sum(macro%water_domain_cp,dim=2)
    bundle%limiter%maximum_storage_cm=sum(geometry%volume_domain_cp,dim=2)
    bundle%limiter%minimum_storage_cm=0.0_real64
    bundle%limiter%potential_top_vertical_cm=0.0_real64
    bundle%limiter%potential_top_lateral_cm=0.0_real64
    bundle%limiter%potential_interflow_sat_cm=0.0_real64
    bundle%limiter%potential_matrix_sat_cm=0.0_real64
    bundle%limiter%potential_outflow_cm=0.0_real64
    bundle%limiter%redistribution_capacity_cm=0.5_real64
    bundle%limiter%top_domain_fraction=1.0_real64
    bundle%top_node=1
  end subroutine setup_template

  subroutine setup_sat(sat)
    use mod_ppa_wu05a6_saturated_exchange_rate, only: saturated_exchange_request_t
    type(saturated_exchange_request_t),intent(out)::sat
    sat%num_domains=nd
    sat%num_nodes=n
    sat%matrix_top_saturated_node=1
    sat%matrix_bottom_saturated_node=0
    sat%swsep=0
    sat%matrix_level=-50.0_real64
    sat%step_duration=0.1_real64
    sat%flow_reduction=1.0_real64
    sat%shape_factor=1.0_real64
    allocate(sat%bottom_domain(nd),sat%top_macro_saturated_node(nd),sat%macro_saturated_fraction(nd), &
         sat%macro_reference_level(nd),sat%z(n),sat%dz(n),sat%matrix_head(n),sat%ksat_horizontal(n), &
         sat%diameter(n),sat%domain_fraction(nd,n),sat%cdarcy(nd,n))
    sat%bottom_domain=4
    sat%top_macro_saturated_node=1
    sat%macro_saturated_fraction=1.0_real64
    sat%macro_reference_level=-30.0_real64
    sat%z=z
    sat%dz=dz
    sat%matrix_head=matrix%pressure_head
    sat%ksat_horizontal=0.01_real64
    sat%diameter=4.0_real64
    sat%domain_fraction=1.0_real64
    sat%cdarcy=0.001_real64
  end subroutine setup_sat

  subroutine setup_history(history)
    type(sorptivity_history_update_request_t),intent(out)::history
    history%num_domains=nd
    history%num_nodes=n
    history%top_node=1
    history%matrix_top_saturated_node=n+1
    history%step_duration=0.1_real64
    allocate(history%bottom_domain(nd),history%top_water_node(nd),history%wall_correction(n), &
         history%wet_fraction(nd,n),history%domain_fraction(nd,n),history%diameter(n))
    history%bottom_domain=4
    history%top_water_node=1
    history%wall_correction=0.95_real64
    history%wet_fraction=1.0_real64
    history%domain_fraction=1.0_real64
    history%diameter=4.0_real64
  end subroutine setup_history

end program test_macropore_standard_rate_adapter
