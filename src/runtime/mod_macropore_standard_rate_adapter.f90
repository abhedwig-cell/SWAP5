module mod_macropore_standard_rate_adapter
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: soil_water_physical_state_t
  use mod_macropore_continuation_state, only: macropore_continuation_state_t
  use mod_ppa_wu05a5_multi_domain_process, only: macropore_geometry_result_t
  use mod_ppa_wu05a6_rate_bundle, only: macropore_rate_bundle_request_t
  use mod_ppa_wu05a6_sorptivity_history, only: sorptivity_history_update_request_t
  use mod_macropore_standard_storage, only: macropore_standard_storage_view_t
  implicit none
  private

  type, public :: matrix_saturated_zone_view_t
    logical :: valid=.false.
    logical :: active=.false.
    integer :: top_node=1
    integer :: bottom_node=0
    real(real64) :: groundwater_level_cm=0.0_real64
  end type matrix_saturated_zone_view_t

  public :: derive_matrix_saturated_zone_view
  public :: prepare_standard_macropore_rate_request
  public :: prepare_standard_sorptivity_history_request
  public :: macropore_volume_below_level

contains

  subroutine derive_matrix_saturated_zone_view(matrix,z,dz,view)
    type(soil_water_physical_state_t),intent(in)::matrix
    real(real64),intent(in)::z(:),dz(:)
    type(matrix_saturated_zone_view_t),intent(out)::view
    integer::n,ic
    real(real64)::gwl,upper,lower

    view=matrix_saturated_zone_view_t()
    n=matrix%active_nodes
    if(n<=0 .or. size(z)/=n .or. size(dz)/=n .or. any(dz<=0.0_real64))return
    if(.not.allocated(matrix%pressure_head) .or. .not.allocated(matrix%water_content))return
    if(size(matrix%pressure_head)/=n .or. size(matrix%water_content)/=n)return

    gwl=matrix%groundwater_level
    view%groundwater_level_cm=gwl
    view%top_node=1
    view%bottom_node=0
    view%active=.false.

    lower=z(n)-0.5_real64*dz(n)
    if(gwl<=lower+1.0e-10_real64)then
      view%valid=.true.
      return
    end if

    upper=z(1)+0.5_real64*dz(1)
    if(gwl>=upper-1.0e-10_real64)then
      view%active=.true.
      view%top_node=1
      view%bottom_node=n
      view%valid=.true.
      return
    end if

    do ic=1,n
      upper=z(ic)+0.5_real64*dz(ic)
      lower=z(ic)-0.5_real64*dz(ic)
      if(gwl<=upper+1.0e-10_real64 .and. gwl>lower+1.0e-10_real64)then
        view%active=.true.
        view%top_node=ic
        view%bottom_node=n
        view%valid=.true.
        return
      end if
    end do
  end subroutine derive_matrix_saturated_zone_view

  pure real(real64) function macropore_volume_below_level(bottom_node,level_cm,volume_cp,z,dz) result(volume)
    integer,intent(in)::bottom_node
    real(real64),intent(in)::level_cm
    real(real64),intent(in)::volume_cp(:),z(:),dz(:)
    integer::ic,n
    real(real64)::z_help

    volume=0.0_real64
    n=size(volume_cp)
    if(n<=0 .or. size(z)/=n .or. size(dz)/=n)return
    if(bottom_node<1 .or. bottom_node>n .or. any(dz<=0.0_real64))return

    ic=bottom_node+1
    z_help=z(bottom_node)-0.5_real64*dz(bottom_node)
    do while(z_help<level_cm .and. ic>1)
      ic=ic-1
      z_help=z_help+dz(ic)
      volume=volume+volume_cp(ic)
    end do
    if(volume>0.0_real64)then
      volume=volume-(z_help-level_cm)*volume_cp(ic)/dz(ic)
      volume=max(0.0_real64,volume)
    end if
  end function macropore_volume_below_level

  subroutine prepare_standard_macropore_rate_request(template,accepted_macro,geometry,macro_view, &
       matrix,z,dz,step_duration,request,matrix_view,ok)
    type(macropore_rate_bundle_request_t),intent(in)::template
    type(macropore_continuation_state_t),intent(in)::accepted_macro
    type(macropore_geometry_result_t),intent(in)::geometry
    type(macropore_standard_storage_view_t),intent(in)::macro_view
    type(soil_water_physical_state_t),intent(in)::matrix
    real(real64),intent(in)::z(:),dz(:),step_duration
    type(macropore_rate_bundle_request_t),intent(out)::request
    type(matrix_saturated_zone_view_t),intent(out)::matrix_view
    logical,intent(out)::ok

    integer::id,n,nd,topw

    ok=.false.
    if(.not.accepted_macro%ready() .or. .not.geometry%valid .or. .not.macro_view%valid)return
    n=accepted_macro%num_nodes
    nd=accepted_macro%num_domains
    if(matrix%active_nodes/=n .or. size(z)/=n .or. size(dz)/=n .or. step_duration<=0.0_real64)return

    ! Dynamic top input may be supplied by the A9 source-faithful forcing carrier.
    ! A10 may additionally opt in the typed source-bound rapid-drain request.
    call derive_matrix_saturated_zone_view(matrix,z,dz,matrix_view)
    if(.not.matrix_view%valid)return

    request=template

    request%unsaturated%sorptivity%step_duration=step_duration
    request%unsaturated%sorptivity%theta=matrix%water_content
    request%unsaturated%pressure_head=matrix%pressure_head
    request%unsaturated%sorptivity%history_sorptivity=accepted_macro%sorptivity
    request%unsaturated%sorptivity%history_theta_ref=accepted_macro%theta_sorption_ref
    request%unsaturated%sorptivity%history_absorption_time=accepted_macro%absorption_time
    request%unsaturated%sorptivity%bottom_domain=geometry%bottom_domain
    request%unsaturated%sorptivity%top_water_node=macro_view%top_water_node
    request%unsaturated%sorptivity%wet_fraction=macro_view%wet_fraction
    request%unsaturated%groundwater_level_domain=macro_view%water_level_cm

    ! No perched zone in the first FMR admission scope.
    request%unsaturated%sorptivity%perched_active=.false.
    if(matrix_view%active)then
      request%unsaturated%sorptivity%matrix_top_saturated_node=matrix_view%top_node
    else
      request%unsaturated%sorptivity%matrix_top_saturated_node=n+1
    end if
    request%interflow_sat%step_duration=step_duration
    request%interflow_sat%matrix_top_saturated_node=1
    request%interflow_sat%matrix_bottom_saturated_node=0
    request%interflow_sat%matrix_level=matrix%groundwater_level
    request%interflow_sat%matrix_head=matrix%pressure_head
    request%interflow_sat%bottom_domain=geometry%bottom_domain

    request%matrix_sat%step_duration=step_duration
    request%matrix_sat%matrix_level=matrix%groundwater_level
    request%matrix_sat%matrix_head=matrix%pressure_head
    request%matrix_sat%bottom_domain=geometry%bottom_domain
    if(matrix_view%active)then
      request%matrix_sat%matrix_top_saturated_node=matrix_view%top_node
      request%matrix_sat%matrix_bottom_saturated_node=matrix_view%bottom_node
    else
      request%matrix_sat%matrix_top_saturated_node=1
      request%matrix_sat%matrix_bottom_saturated_node=0
    end if

    do id=1,nd
      topw=macro_view%top_water_node(id)
      request%interflow_sat%top_macro_saturated_node(id)=topw
      request%interflow_sat%macro_saturated_fraction(id)=macro_view%wet_fraction(id,topw)
      request%interflow_sat%macro_reference_level(id)=macro_view%water_level_cm(id)
      request%matrix_sat%top_macro_saturated_node(id)=topw
      request%matrix_sat%macro_saturated_fraction(id)=macro_view%wet_fraction(id,topw)
      request%matrix_sat%macro_reference_level(id)=macro_view%water_level_cm(id)
    end do

    request%rapid%step_duration=step_duration
    request%rapid%bottom_domain_node=geometry%bottom_domain(1)
    request%rapid%top_water_node=macro_view%top_water_node(1)
    request%rapid%saturated_top_fraction=macro_view%wet_fraction(1,macro_view%top_water_node(1))
    request%rapid%water_level_cm=macro_view%water_level_cm(1)
    request%rapid%domain_bottom_cm=z(geometry%bottom_domain(1))-0.5_real64*dz(geometry%bottom_domain(1))
    request%rapid%ponding_cm=max(0.0_real64,matrix%ponding_depth)
    request%rapid%water_storage_cm=sum(accepted_macro%water_domain_cp(1,:))
    request%rapid%volume_main_domain_cp=geometry%volume_domain_cp(1,:)
    request%rapid%volume_under_drain_cm=0.0_real64
    if(request%rapid%domain_bottom_cm<request%rapid%drain_level_cm)then
      request%rapid%volume_under_drain_cm=macropore_volume_below_level(geometry%bottom_domain(1), &
           request%rapid%drain_level_cm,geometry%volume_domain_cp(1,:),z,dz)
    end if

    request%limiter%accepted_storage_cm=sum(accepted_macro%water_domain_cp,dim=2)
    request%limiter%maximum_storage_cm=sum(geometry%volume_domain_cp,dim=2)
    request%limiter%redistribution_capacity_cm=max(0.0_real64, &
         request%limiter%maximum_storage_cm-request%limiter%accepted_storage_cm)

    ok=request%unsaturated%valid() .and. request%interflow_sat%valid() .and. &
         request%matrix_sat%valid() .and. request%rapid%valid() .and. request%limiter%valid()
  end subroutine prepare_standard_macropore_rate_request

  subroutine prepare_standard_sorptivity_history_request(template,geometry,macro_view,matrix_view,step_duration,request,ok)
    type(sorptivity_history_update_request_t),intent(in)::template
    type(macropore_geometry_result_t),intent(in)::geometry
    type(macropore_standard_storage_view_t),intent(in)::macro_view
    type(matrix_saturated_zone_view_t),intent(in)::matrix_view
    real(real64),intent(in)::step_duration
    type(sorptivity_history_update_request_t),intent(out)::request
    logical,intent(out)::ok

    ok=.false.
    if(.not.geometry%valid .or. .not.macro_view%valid .or. step_duration<=0.0_real64)return
    request=template
    request%step_duration=step_duration
    request%bottom_domain=geometry%bottom_domain
    request%top_water_node=macro_view%top_water_node
    request%wet_fraction=macro_view%wet_fraction
    if(matrix_view%active)then
      request%matrix_top_saturated_node=matrix_view%top_node
    else
      request%matrix_top_saturated_node=geometry%num_nodes+1
    end if
    ok=request%valid()
  end subroutine prepare_standard_sorptivity_history_request

end module mod_macropore_standard_rate_adapter
