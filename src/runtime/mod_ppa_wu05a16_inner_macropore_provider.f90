module mod_ppa_wu05a16_inner_macropore_provider
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: macropore_exchange_provider_t, soil_water_physical_state_t
  use mod_macropore_continuation_state, only: macropore_continuation_state_t, copy_macropore_continuation_state
  use mod_ppa_wu05a5_multi_domain_process, only: macropore_geometry_config_t, macropore_geometry_result_t, evaluate_macropore_geometry
  use mod_macropore_dynamic_shrinkage, only: dynamic_shrinkage_config_t, evaluate_dynamic_crack_profile
  use mod_macropore_standard_storage, only: macropore_standard_storage_view_t, derive_macropore_standard_storage_view
  use mod_ppa_wu05a6_rate_bundle, only: macropore_rate_bundle_request_t, macropore_rate_bundle_result_t, &
       evaluate_macropore_rate_bundle
  use mod_macropore_standard_rate_adapter, only: matrix_saturated_zone_view_t, &
       prepare_standard_macropore_rate_request
  use mod_ppa_wu05a15_exchange_derivative, only: macropore_exchange_derivative_result_t, &
       evaluate_macropore_exchange_derivative
  use mod_macropore_covering_layer_input, only: covering_layer_input_request_t, evaluate_covering_layer_input, &
       evaluate_covering_layer_rate_derivative
  implicit none
  private

  type, extends(macropore_exchange_provider_t), public :: ppa_wu05a16_inner_macropore_provider_t
    logical :: configured=.false.
    type(macropore_continuation_state_t) :: accepted_macro
    type(macropore_geometry_result_t) :: geometry
    type(macropore_geometry_config_t) :: geometry_config
    type(dynamic_shrinkage_config_t) :: shrinkage
    type(macropore_standard_storage_view_t) :: accepted_view
    real(real64), allocatable :: accepted_matrix_theta(:), matrix_area_fraction(:)
    type(macropore_rate_bundle_request_t) :: rate_template
    real(real64), allocatable :: z(:),dz(:)
    real(real64) :: step_duration=0.0_real64
    real(real64) :: accepted_ponding_depth=0.0_real64
    real(real64) :: accepted_groundwater_level=0.0_real64
    logical :: covering_layer_enabled=.false.
    real(real64) :: covering_minimum_polygon_diameter_cm=0.0_real64
    real(real64) :: covering_ksat_cm_per_day=0.0_real64
  contains
    procedure, public :: configure => configure_inner_macropore_provider
    procedure, public :: evaluate_rate => evaluate_inner_macropore_rate
    procedure, public :: evaluate_derivative => evaluate_inner_macropore_derivative
  end type ppa_wu05a16_inner_macropore_provider_t

contains

  subroutine configure_inner_macropore_provider(self,accepted_macro,geometry,rate_template,z,dz,step_duration, &
                                                 accepted_ponding_depth,accepted_groundwater_level,ok, &
                                                 covering_minimum_polygon_diameter_cm,covering_ksat_cm_per_day, &
                                                 geometry_config,shrinkage,accepted_matrix_theta,matrix_area_fraction)
    class(ppa_wu05a16_inner_macropore_provider_t),intent(inout)::self
    type(macropore_continuation_state_t),intent(in)::accepted_macro
    type(macropore_geometry_result_t),intent(in)::geometry
    type(macropore_rate_bundle_request_t),intent(in)::rate_template
    real(real64),intent(in)::z(:),dz(:),step_duration,accepted_ponding_depth,accepted_groundwater_level
    logical,intent(out)::ok
    real(real64),intent(in),optional::covering_minimum_polygon_diameter_cm,covering_ksat_cm_per_day
    type(macropore_geometry_config_t),intent(in),optional::geometry_config
    type(dynamic_shrinkage_config_t),intent(in),optional::shrinkage
    real(real64),intent(in),optional::accepted_matrix_theta(:),matrix_area_fraction(:)

    self%configured=.false.
    ok=.false.
    if(.not.accepted_macro%ready() .or. .not.geometry%valid)return
    if(step_duration<=0.0_real64)return
    if(size(z)/=accepted_macro%num_nodes .or. size(dz)/=accepted_macro%num_nodes .or. any(dz<=0.0_real64))return
    if(geometry%num_nodes/=accepted_macro%num_nodes .or. geometry%num_domains/=accepted_macro%num_domains)return

    call copy_macropore_continuation_state(accepted_macro,self%accepted_macro,ok)
    if(.not.ok)return
    self%geometry=geometry
    self%rate_template=rate_template
    self%shrinkage=dynamic_shrinkage_config_t()
    if(present(shrinkage))self%shrinkage=shrinkage
    if(self%shrinkage%enabled)then
      if(.not.present(geometry_config) .or. .not.present(accepted_matrix_theta) .or. .not.present(matrix_area_fraction))return
      if(.not.geometry_config%valid() .or. .not.self%shrinkage%valid_for_nodes(accepted_macro%num_nodes))return
      if(size(accepted_matrix_theta)/=accepted_macro%num_nodes .or. size(matrix_area_fraction)/=accepted_macro%num_nodes)return
      self%geometry_config=geometry_config
      self%accepted_matrix_theta=accepted_matrix_theta
      self%matrix_area_fraction=matrix_area_fraction
    end if
    self%z=z
    self%dz=dz
    self%step_duration=step_duration
    self%accepted_ponding_depth=accepted_ponding_depth
    self%accepted_groundwater_level=accepted_groundwater_level
    self%covering_layer_enabled=.false.
    if(self%geometry%top_node>1)then
      if(.not.present(covering_minimum_polygon_diameter_cm) .or. .not.present(covering_ksat_cm_per_day))return
      if(covering_minimum_polygon_diameter_cm<=0.0_real64 .or. covering_ksat_cm_per_day<0.0_real64)return
      self%covering_layer_enabled=.true.
      self%covering_minimum_polygon_diameter_cm=covering_minimum_polygon_diameter_cm
      self%covering_ksat_cm_per_day=covering_ksat_cm_per_day
    end if

    call derive_macropore_standard_storage_view(self%accepted_macro,self%geometry%top_node,self%z,self%dz,self%accepted_view)
    if(.not.self%accepted_view%valid)return
    if(maxval(abs(self%accepted_view%normalized_water_cm-self%accepted_macro%water_domain_cp))>1.0e-10_real64)return

    self%configured=.true.
    ok=.true.
  end subroutine configure_inner_macropore_provider

  subroutine evaluate_inner_macropore_rate(self,pressure_head,water_content,exchange_flux,active)
    class(ppa_wu05a16_inner_macropore_provider_t),intent(in)::self
    real(real64),intent(in)::pressure_head(:),water_content(:)
    real(real64),intent(out)::exchange_flux(:)
    logical,intent(out)::active

    type(macropore_rate_bundle_request_t)::request
    type(macropore_rate_bundle_result_t)::rates
    type(matrix_saturated_zone_view_t)::matrix_view
    type(soil_water_physical_state_t)::matrix
    type(covering_layer_input_request_t)::covering
    real(real64),allocatable::covered_cm(:)
    integer::cover_node
    logical::ok

    exchange_flux=0.0_real64
    active=.false.
    if(.not.self%configured)return
    call evaluate_current_rates(self,pressure_head,water_content,request,rates,matrix_view,matrix,ok)
    if(.not.ok)return
    if(size(exchange_flux)/=self%accepted_macro%num_nodes)return
    exchange_flux=sum(rates%qexc_to_matrix_rate,dim=1)
    if(self%covering_layer_enabled)then
      cover_node=self%geometry%top_node-1
      covering%top_node=self%geometry%top_node
      covering%step_duration_day=self%step_duration
      covering%matrix_head_above_cm=pressure_head(cover_node)
      covering%dz_above_cm=self%dz(cover_node)
      covering%minimum_polygon_diameter_cm=self%covering_minimum_polygon_diameter_cm
      covering%covering_layer_ksat_cm_per_day=self%covering_ksat_cm_per_day
      covering%total_macropore_volume_top_cm=sum(self%geometry%volume_domain_cp(:,self%geometry%top_node))
      covering%domain_top_volume_cm=self%geometry%volume_domain_cp(:,self%geometry%top_node)
      call evaluate_covering_layer_input(covering,covered_cm,ok)
      if(.not.ok)return
      exchange_flux(cover_node)=exchange_flux(cover_node)-sum(covered_cm)/self%step_duration
    end if
    active=maxval(abs(exchange_flux))>1.0e-14_real64
  end subroutine evaluate_inner_macropore_rate

  subroutine evaluate_inner_macropore_derivative(self,pressure_head,water_content,capacity,dexchange_dhead, &
                                                  derivative_available,active)
    class(ppa_wu05a16_inner_macropore_provider_t),intent(in)::self
    real(real64),intent(in)::pressure_head(:),water_content(:),capacity(:)
    real(real64),intent(out)::dexchange_dhead(:)
    logical,intent(out)::derivative_available,active

    type(macropore_rate_bundle_request_t)::request
    type(macropore_rate_bundle_result_t)::rates
    type(macropore_exchange_derivative_result_t)::derivative
    type(matrix_saturated_zone_view_t)::matrix_view
    type(soil_water_physical_state_t)::matrix
    real(real64),allocatable::exchange(:),covered_cm(:)
    type(covering_layer_input_request_t)::covering
    real(real64)::covered_dqdh
    integer::cover_node
    logical::ok

    dexchange_dhead=0.0_real64
    derivative_available=.false.
    active=.false.
    if(.not.self%configured)return
    if(size(capacity)/=self%accepted_macro%num_nodes)return

    call evaluate_current_rates(self,pressure_head,water_content,request,rates,matrix_view,matrix,ok)
    if(.not.ok)return
    call evaluate_macropore_exchange_derivative(request,rates,capacity,derivative)
    if(.not.derivative%valid)return
    if(size(dexchange_dhead)/=self%accepted_macro%num_nodes)return

    allocate(exchange(self%accepted_macro%num_nodes))
    exchange=sum(rates%qexc_to_matrix_rate,dim=1)
    dexchange_dhead=derivative%total_dqdh_node
    if(self%covering_layer_enabled)then
      cover_node=self%geometry%top_node-1
      covering%top_node=self%geometry%top_node
      covering%step_duration_day=self%step_duration
      covering%matrix_head_above_cm=pressure_head(cover_node)
      covering%dz_above_cm=self%dz(cover_node)
      covering%minimum_polygon_diameter_cm=self%covering_minimum_polygon_diameter_cm
      covering%covering_layer_ksat_cm_per_day=self%covering_ksat_cm_per_day
      covering%total_macropore_volume_top_cm=sum(self%geometry%volume_domain_cp(:,self%geometry%top_node))
      covering%domain_top_volume_cm=self%geometry%volume_domain_cp(:,self%geometry%top_node)
      call evaluate_covering_layer_input(covering,covered_cm,ok)
      if(.not.ok)return
      call evaluate_covering_layer_rate_derivative(covering,covered_dqdh,ok)
      if(.not.ok)return
      exchange(cover_node)=exchange(cover_node)-sum(covered_cm)/self%step_duration
      dexchange_dhead(cover_node)=dexchange_dhead(cover_node)-covered_dqdh
    end if
    derivative_available=.true.
    active=max(maxval(abs(exchange)),maxval(abs(dexchange_dhead)))>1.0e-14_real64
  end subroutine evaluate_inner_macropore_derivative

  subroutine evaluate_current_rates(self,pressure_head,water_content,request,rates,matrix_view,matrix,ok)
    class(ppa_wu05a16_inner_macropore_provider_t),intent(in)::self
    real(real64),intent(in)::pressure_head(:),water_content(:)
    type(macropore_rate_bundle_request_t),intent(out)::request
    type(macropore_rate_bundle_result_t),intent(out)::rates
    type(matrix_saturated_zone_view_t),intent(out)::matrix_view
    type(soil_water_physical_state_t),intent(out)::matrix
    type(macropore_geometry_result_t)::geometry_current
    type(macropore_standard_storage_view_t)::view_current
    real(real64),allocatable::dynamic_current(:)
    logical,intent(out)::ok
    integer::n

    ok=.false.
    n=self%accepted_macro%num_nodes
    if(size(pressure_head)/=n .or. size(water_content)/=n)return

    matrix%active_nodes=n
    allocate(matrix%pressure_head(n),matrix%water_content(n))
    matrix%pressure_head=pressure_head
    matrix%water_content=water_content
    matrix%ponding_depth=self%accepted_ponding_depth
    matrix%groundwater_level=self%accepted_groundwater_level

    geometry_current=self%geometry
    view_current=self%accepted_view
    if(self%shrinkage%enabled)then
      call evaluate_dynamic_crack_profile(self%shrinkage,water_content,self%accepted_matrix_theta,self%dz, &
           self%matrix_area_fraction,self%accepted_macro%dynamic_volume_cp,dynamic_current,ok)
      if(.not.ok)return
      call evaluate_macropore_geometry(self%geometry_config,dynamic_current,geometry_current)
      if(.not.geometry_current%valid)return
      call derive_macropore_standard_storage_view(self%accepted_macro,geometry_current%top_node,self%z,self%dz,view_current)
      if(.not.view_current%valid)return
    end if

    call prepare_standard_macropore_rate_request(self%rate_template,self%accepted_macro,geometry_current,view_current, &
         matrix,self%z,self%dz,self%step_duration,request,matrix_view,ok)
    if(.not.ok)return
    call evaluate_macropore_rate_bundle(request,rates)
    ok=rates%valid
  end subroutine evaluate_current_rates

end module mod_ppa_wu05a16_inner_macropore_provider
