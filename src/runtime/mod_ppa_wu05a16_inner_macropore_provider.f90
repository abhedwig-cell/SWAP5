module mod_ppa_wu05a16_inner_macropore_provider
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_soil_water_solver_contract, only: macropore_exchange_provider_t, soil_water_physical_state_t
  use mod_macropore_continuation_state, only: macropore_continuation_state_t, copy_macropore_continuation_state
  use mod_ppa_wu05a5_multi_domain_process, only: macropore_geometry_config_t, macropore_geometry_result_t, &
       evaluate_macropore_geometry, evaluate_macropore_geometry_return
  use mod_macropore_dynamic_shrinkage, only: dynamic_shrinkage_config_t, evaluate_dynamic_crack_profile
  use mod_macropore_dynamic_shrinkage, only: find_dynamic_groundwater_cutoff
  use mod_macropore_standard_storage, only: macropore_standard_storage_view_t, derive_macropore_standard_storage_view
  use mod_ppa_wu05a6_rate_bundle, only: macropore_rate_bundle_request_t, macropore_rate_bundle_result_t, &
       evaluate_macropore_rate_bundle
  use mod_macropore_standard_rate_adapter, only: matrix_saturated_zone_view_t, &
       prepare_standard_macropore_rate_request
  use mod_ppa_wu05a15_exchange_derivative, only: macropore_exchange_derivative_result_t, &
       evaluate_macropore_exchange_derivative
  use mod_macropore_covering_layer_input, only: covering_layer_input_request_t, evaluate_covering_layer_input, &
       evaluate_covering_layer_rate_derivative
  use mod_fmr_macropore_top_input, only: fmr_macropore_top_input_forcing_t, prepare_fmr_macropore_top_input
  implicit none
  private

  type, extends(macropore_exchange_provider_t), public :: ppa_wu05a16_inner_macropore_provider_t
    logical :: configured=.false.
    type(macropore_continuation_state_t) :: accepted_macro
    type(macropore_geometry_result_t) :: geometry
    type(macropore_geometry_config_t) :: geometry_config
    type(dynamic_shrinkage_config_t) :: shrinkage
    type(fmr_macropore_top_input_forcing_t) :: top_input
    type(macropore_standard_storage_view_t) :: accepted_view
    real(real64), allocatable :: accepted_matrix_theta(:), matrix_area_fraction(:)
    type(macropore_rate_bundle_request_t) :: rate_template
    real(real64), allocatable :: z(:),dz(:)
    real(real64) :: step_duration=0.0_real64
    real(real64) :: accepted_ponding_depth=0.0_real64
    real(real64) :: accepted_groundwater_level=0.0_real64
    real(real64) :: candidate_pond_lateral_cm=0.0_real64
    integer :: bottom_boundary_mode=1
    logical :: covering_layer_enabled=.false.
    real(real64) :: covering_minimum_polygon_diameter_cm=0.0_real64
    real(real64) :: covering_ksat_cm_per_day=0.0_real64
  contains
    procedure, public :: configure => configure_inner_macropore_provider
    procedure, public :: evaluate_rate => evaluate_inner_macropore_rate
    procedure, public :: evaluate_derivative => evaluate_inner_macropore_derivative
    procedure, public :: evaluate_trial_geometry => evaluate_inner_trial_geometry
    procedure, public :: permits_source_freezing => inner_permits_source_freezing
    procedure, public :: set_candidate_pond_lateral => inner_set_candidate_pond_lateral
    procedure, public :: candidate_pond_lateral => inner_candidate_pond_lateral
  end type ppa_wu05a16_inner_macropore_provider_t

contains

  subroutine inner_set_candidate_pond_lateral(self,amount_cm)
    class(ppa_wu05a16_inner_macropore_provider_t),intent(inout)::self
    real(real64),intent(in)::amount_cm
    if(ieee_is_finite(amount_cm) .and. amount_cm>=0.0_real64)then
      self%candidate_pond_lateral_cm=amount_cm
    else
      self%candidate_pond_lateral_cm=0.0_real64
    end if
  end subroutine inner_set_candidate_pond_lateral

  real(real64) function inner_candidate_pond_lateral(self) result(amount_cm)
    class(ppa_wu05a16_inner_macropore_provider_t),intent(in)::self
    amount_cm=self%candidate_pond_lateral_cm
  end function inner_candidate_pond_lateral

  logical function inner_permits_source_freezing(self) result(permitted)
    class(ppa_wu05a16_inner_macropore_provider_t),intent(in)::self
    permitted=.true.
    if(.not.self%configured .or. .not.self%shrinkage%enabled)return
    permitted=all(self%shrinkage%theta_crack==0.0_real64) .and. &
         all(self%accepted_macro%dynamic_volume_cp==0.0_real64)
  end function inner_permits_source_freezing

  subroutine derive_dynamic_surface_area(config,crack_area_node,geometry,ok)
    type(macropore_geometry_config_t),intent(in)::config
    integer,intent(in)::crack_area_node
    type(macropore_geometry_result_t),intent(inout)::geometry
    logical,intent(out)::ok
    integer::ic,top
    real(real64)::dynamic_area,static_area,minimum_area,denominator
    ok=.false.
    if(.not.config%valid() .or. .not.geometry%valid)return
    top=config%top_node
    if(crack_area_node<1 .or. crack_area_node>config%num_nodes)return
    ic=max(top,crack_area_node)
    if(ic>config%num_nodes)return
    if(.not.allocated(geometry%subsidence_cp))return
    if(size(geometry%subsidence_cp)/=config%num_nodes)return
    denominator=config%dz(ic)-geometry%subsidence_cp(ic)
    if(denominator<=0.0_real64)return
    dynamic_area=geometry%dynamic_volume_cp(ic)/denominator
    static_area=config%static_volume_cp(top)/config%dz(top)
    geometry%surface_area_fraction=min(0.6_real64,max(0.0_real64,dynamic_area+static_area))
    minimum_area=1.0_real64-(1.0_real64-0.001_real64/config%characteristic_diameter(top))**2
    if(geometry%surface_area_fraction<minimum_area)geometry%surface_area_fraction=0.0_real64
    ok=.true.
  end subroutine derive_dynamic_surface_area

  subroutine configure_inner_macropore_provider(self,accepted_macro,geometry,rate_template,z,dz,step_duration, &
                                                 accepted_ponding_depth,accepted_groundwater_level,ok, &
                                                 covering_minimum_polygon_diameter_cm,covering_ksat_cm_per_day, &
                                                 geometry_config,shrinkage,accepted_matrix_theta,matrix_area_fraction,top_input, &
                                                 bottom_boundary_mode)
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
    type(fmr_macropore_top_input_forcing_t),intent(in),optional::top_input
    integer,intent(in),optional::bottom_boundary_mode

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
    self%top_input=fmr_macropore_top_input_forcing_t()
    if(present(top_input))self%top_input=top_input
    if(present(geometry_config))then
      if(.not.geometry_config%valid())return
      self%geometry_config=geometry_config
    else if(self%top_input%supplied)then
      return
    end if
    if(self%shrinkage%enabled)then
      if(.not.present(geometry_config) .or. .not.present(accepted_matrix_theta) .or. .not.present(matrix_area_fraction))return
      if(.not.geometry_config%valid())return
      if(.not.self%shrinkage%valid_for_nodes(accepted_macro%num_nodes))return
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
    self%candidate_pond_lateral_cm=0.0_real64
    self%bottom_boundary_mode=1
    if(present(bottom_boundary_mode))self%bottom_boundary_mode=bottom_boundary_mode
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

  subroutine evaluate_inner_macropore_rate(self,pressure_head,water_content,exchange_flux,active,surface_area_fraction)
    class(ppa_wu05a16_inner_macropore_provider_t),intent(in)::self
    real(real64),intent(in)::pressure_head(:),water_content(:)
    real(real64),intent(out)::exchange_flux(:)
    logical,intent(out)::active
    real(real64),intent(out),optional::surface_area_fraction

    type(macropore_rate_bundle_request_t)::request
    type(macropore_rate_bundle_result_t)::rates
    type(matrix_saturated_zone_view_t)::matrix_view
    type(soil_water_physical_state_t)::matrix
    type(covering_layer_input_request_t)::covering
    real(real64),allocatable::covered_cm(:)
    integer::cover_node
    logical::ok

    active=.false.
    if(present(surface_area_fraction))surface_area_fraction=-1.0_real64
    if(.not.self%configured)return
    if(size(exchange_flux)/=self%accepted_macro%num_nodes)return
    exchange_flux=0.0_real64
    call evaluate_current_rates(self,pressure_head,water_content,request,rates,matrix_view,matrix,ok, &
         surface_area_fraction)
    if(.not.ok)return
    if(.not.allocated(rates%qexc_to_matrix_rate))return
    if(size(rates%qexc_to_matrix_rate,2)/=size(exchange_flux))return
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
    type(macropore_geometry_result_t)::geometry_plus,geometry_minus
    type(matrix_saturated_zone_view_t)::matrix_view
    type(soil_water_physical_state_t)::matrix
    real(real64),allocatable::exchange(:),covered_cm(:)
    real(real64),allocatable::theta_plus(:),theta_minus(:),return_plus(:,:),return_minus(:,:)
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
    if(self%shrinkage%enabled)then
      ! Geometry displacement is an implicit matrix source. Its local theta
      ! derivative must accompany the same source in the Richards Jacobian.
      ! Accepted neighbour history is fixed, so each theta perturbation is local;
      ! hold the discrete groundwater cutoff at the current pressure profile.
      theta_plus=min(self%shrinkage%theta_s,water_content+sqrt(epsilon(1.0_real64)))
      theta_minus=max(0.0_real64,water_content-sqrt(epsilon(1.0_real64)))
      call self%evaluate_trial_geometry(theta_plus,geometry_plus,ok,pressure_head)
      if(.not.ok)return
      call self%evaluate_trial_geometry(theta_minus,geometry_minus,ok,pressure_head)
      if(.not.ok)return
      call evaluate_macropore_geometry_return(self%accepted_macro,geometry_plus,return_plus,ok)
      if(.not.ok)return
      call evaluate_macropore_geometry_return(self%accepted_macro,geometry_minus,return_minus,ok)
      if(.not.ok)return
      dexchange_dhead=dexchange_dhead+sum(return_plus-return_minus,dim=1)*capacity / &
           ((theta_plus-theta_minus)*self%step_duration)
    end if
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

  subroutine evaluate_inner_trial_geometry(self,water_content,geometry_current,ok,pressure_head)
    class(ppa_wu05a16_inner_macropore_provider_t),intent(in)::self
    real(real64),intent(in)::water_content(:)
    type(macropore_geometry_result_t),intent(out)::geometry_current
    logical,intent(out)::ok
    real(real64),intent(in),optional::pressure_head(:)
    real(real64),allocatable::dynamic_current(:),subsidence_current(:)
    integer::active_node

    ok=.false.
    geometry_current=self%geometry
    if(.not.self%shrinkage%enabled)then
      ok=geometry_current%valid
      return
    end if
    if(size(water_content)/=self%accepted_macro%num_nodes)return
    active_node=self%accepted_macro%num_nodes
    if(present(pressure_head))then
      if(size(pressure_head)/=self%accepted_macro%num_nodes)return
      active_node=min(self%accepted_macro%num_nodes, &
           find_dynamic_groundwater_cutoff(pressure_head,self%z,self%dz,self%bottom_boundary_mode))
    end if
    call evaluate_dynamic_crack_profile(self%shrinkage,water_content,self%accepted_matrix_theta,self%dz, &
         self%matrix_area_fraction,self%accepted_macro%dynamic_volume_cp,dynamic_current,ok, &
         subsidence_current,active_node,self%geometry_config%top_node)
    if(.not.ok)return
    call evaluate_macropore_geometry(self%geometry_config,dynamic_current,geometry_current)
    if(.not.geometry_current%valid)return
    geometry_current%subsidence_cp=subsidence_current
    call derive_dynamic_surface_area(self%geometry_config,self%shrinkage%surface_crack_area_node,geometry_current,ok)
  end subroutine evaluate_inner_trial_geometry

  subroutine evaluate_current_rates(self,pressure_head,water_content,request,rates,matrix_view,matrix,ok, &
                                    surface_area_fraction)
    class(ppa_wu05a16_inner_macropore_provider_t),intent(in)::self
    real(real64),intent(in)::pressure_head(:),water_content(:)
    type(macropore_rate_bundle_request_t),intent(out)::request
    type(macropore_rate_bundle_result_t),intent(out)::rates
    type(matrix_saturated_zone_view_t),intent(out)::matrix_view
    type(soil_water_physical_state_t),intent(out)::matrix
    type(macropore_geometry_result_t)::geometry_current
    type(macropore_standard_storage_view_t)::view_current
    real(real64),allocatable::geometry_return(:,:),top_vertical(:),top_lateral(:)
    logical,intent(out)::ok
    real(real64),intent(out),optional::surface_area_fraction
    integer::n

    ok=.false.
    if(present(surface_area_fraction))surface_area_fraction=-1.0_real64
    n=self%accepted_macro%num_nodes
    if(size(pressure_head)/=n .or. size(water_content)/=n)return

    matrix%active_nodes=n
    allocate(matrix%pressure_head(n),matrix%water_content(n))
    matrix%pressure_head=pressure_head
    matrix%water_content=water_content
    matrix%ponding_depth=self%accepted_ponding_depth
    matrix%groundwater_level=self%accepted_groundwater_level

    call self%evaluate_trial_geometry(water_content,geometry_current,ok,pressure_head)
    if(.not.ok)return
    if(present(surface_area_fraction))then
      if(geometry_current%surface_area_fraction>=0.0_real64)then
        surface_area_fraction=geometry_current%surface_area_fraction
      else
        surface_area_fraction=sum(geometry_current%volume_domain_cp(:,geometry_current%top_node))/ &
             self%dz(geometry_current%top_node)
      end if
      if(.not.ieee_is_finite(surface_area_fraction) .or. surface_area_fraction<0.0_real64 .or. &
         surface_area_fraction>1.0_real64)return
    end if
    view_current=self%accepted_view
    if(self%shrinkage%enabled)then
      call derive_macropore_standard_storage_view(self%accepted_macro,geometry_current%top_node,self%z,self%dz,view_current)
      if(.not.view_current%valid)return
    end if

    call prepare_standard_macropore_rate_request(self%rate_template,self%accepted_macro,geometry_current,view_current, &
         matrix,self%z,self%dz,self%step_duration,request,matrix_view,ok)
    if(.not.ok)return
    if(self%top_input%supplied)then
      call prepare_fmr_macropore_top_input(self%top_input,self%geometry_config,geometry_current,self%step_duration, &
           top_vertical,top_lateral,ok)
      if(.not.ok)return
      request%limiter%potential_top_vertical_cm=top_vertical
      request%limiter%potential_top_lateral_cm=top_lateral
    end if
    if(self%candidate_pond_lateral_cm>0.0_real64)then
      if(.not.self%geometry_config%valid())return
      if(sum(request%limiter%potential_top_lateral_cm)>1.0e-14_real64)return
      request%limiter%potential_top_lateral_cm= &
           self%geometry_config%domain_fraction(:,geometry_current%top_node)*self%candidate_pond_lateral_cm
    end if
    call evaluate_macropore_rate_bundle(request,rates)
    ok=rates%valid
    if(.not.ok)return
    if(self%shrinkage%enabled)then
      call evaluate_macropore_geometry_return(self%accepted_macro,geometry_current,geometry_return,ok)
      if(.not.ok)return
      rates%qexc_to_matrix_rate = rates%qexc_to_matrix_rate + geometry_return/self%step_duration
    end if
  end subroutine evaluate_current_rates

end module mod_ppa_wu05a16_inner_macropore_provider
