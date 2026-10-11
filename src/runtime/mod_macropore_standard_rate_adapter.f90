module mod_macropore_standard_rate_adapter
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_ppa_wu05a6_rapid_drain_rate, only: derive_rapid_volume_under_drain
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

  type, public :: matrix_perched_zone_view_t
    logical :: valid=.false.
    logical :: active=.false.
    integer :: top_node=1
    integer :: bottom_node=0
    logical :: partial_top_active=.false.
    real(real64) :: water_level_cm=0.0_real64
    real(real64) :: bottom_level_cm=0.0_real64
  end type matrix_perched_zone_view_t

  public :: derive_matrix_saturated_zone_view
  public :: derive_matrix_perched_zone_view
  public :: prepare_standard_macropore_rate_request
  public :: prepare_standard_sorptivity_history_request

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

  subroutine derive_matrix_perched_zone_view(matrix,theta_s,z,dz,matrix_view,critical_under_saturated_volume_cm,view)
    type(soil_water_physical_state_t),intent(in)::matrix
    real(real64),intent(in)::theta_s(:),z(:),dz(:),critical_under_saturated_volume_cm
    type(matrix_saturated_zone_view_t),intent(in)::matrix_view
    type(matrix_perched_zone_view_t),intent(out)::view

    integer::n,ic,scan_start,bottom_seed,node,npegwl
    real(real64)::bottom_level,water_level
    logical::flsat,found

    view=matrix_perched_zone_view_t()
    n=matrix%active_nodes
    if(n<=1 .or. critical_under_saturated_volume_cm<0.0_real64)return
    if(size(theta_s)/=n .or. size(z)/=n .or. size(dz)/=n .or. any(dz<=0.0_real64))return
    if(any(z(1:n-1)<=z(2:n)))return
    if(.not.matrix_view%valid)return
    if(.not.allocated(matrix%pressure_head) .or. .not.allocated(matrix%water_content))return
    if(size(matrix%pressure_head)/=n .or. size(matrix%water_content)/=n)return

    ! Exact 4.3.1 CALCGWL/MACROSTATE carrier semantics, represented as a
    ! recomputable hydraulic view. A whole-profile saturated state has no
    ! separate perched groundwater table.
    if(matrix_view%active .and. matrix_view%top_node==1)then
      view%valid=.true.
      return
    end if

    if(matrix_view%active)then
      scan_start=max(1,matrix_view%top_node-1)
    else
      scan_start=n
    end if

    found=.false.
    bottom_seed=0
    do ic=scan_start,1,-1
      if(matrix%pressure_head(ic)>=0.0_real64)then
        bottom_seed=ic
        found=.true.
        exit
      end if
    end do
    if(.not.found)then
      view%valid=.true.
      return
    end if

    ! A saturated bottom compartment without an ordinary groundwater zone is
    ! inconsistent with the bounded carrier reconstructed here.
    if(bottom_seed>=n)return

    bottom_level=perched_bottom_level(bottom_seed)
    node=node_for_level(bottom_seed,bottom_level)
    if(node<1 .or. node>n)return
    view%bottom_node=node
    view%bottom_level_cm=bottom_level

    flsat=.true.
    water_level=999.0_real64
    npegwl=-1
    do while(flsat .and. node>1)
      node=node-1
      if(matrix%pressure_head(node)<0.0_real64)then
        call advance_water_table(node,critical_under_saturated_volume_cm,flsat,water_level,npegwl)
      end if
    end do

    if(flsat)then
      if(matrix%pressure_head(1)>0.0_real64)then
        if(matrix%ponding_depth<1.0e-8_real64)then
          water_level=min(z(1)+matrix%pressure_head(1),matrix%ponding_depth)
        else
          water_level=matrix%ponding_depth
        end if
      else
        water_level=0.0_real64
      end if
      npegwl=1
    end if
    if(npegwl<1 .or. npegwl>n)return

    ! Exact active B1.11 MACRORATE code is:
    !   ICpTpPerZon = NPeGwl
    ! The historic "+ 1" and ICpSatPeGwl alternatives are commented out.
    ! SATFLOW always applies the PeGwl-derived saturation fraction in CpTpZon.
    view%top_node=npegwl
    view%partial_top_active=.true.

    if(view%top_node<1 .or. view%top_node>n)return
    if(view%bottom_node<view%top_node)return
    view%water_level_cm=water_level
    view%active=.true.
    view%valid=.true.

  contains

    real(real64) function node_spacing(node_index) result(distance)
      integer,intent(in)::node_index
      if(node_index<1 .or. node_index>=n)then
        distance=0.0_real64
      else
        distance=abs(z(node_index)-z(node_index+1))
      end if
    end function node_spacing

    integer function node_for_level(seed,level) result(level_node)
      integer,intent(in)::seed
      real(real64),intent(in)::level
      integer::j
      j=max(seed-2,1)
      do while(z(j)-0.5_real64*dz(j)>level .and. j<n)
        j=j+1
      end do
      level_node=min(max(j,1),n)
    end function node_for_level

    real(real64) function ordinary_water_level(node_index) result(level)
      integer,intent(in)::node_index
      real(real64)::distance,bottom
      level=0.0_real64
      bottom=z(node_index)-0.5_real64*dz(node_index)
      if(node_index<n .and. matrix%pressure_head(node_index+1)>=0.0_real64)then
        distance=node_spacing(node_index)
        if(distance<=0.0_real64)return
        level=z(node_index+1)+matrix%pressure_head(node_index+1) / &
             (matrix%pressure_head(node_index+1)-matrix%pressure_head(node_index))*distance
      else
        level=bottom-matrix%pressure_head(node_index)
        level=min(z(node_index),max(bottom,level))
      end if
    end function ordinary_water_level

    real(real64) function perched_bottom_level(node_index) result(level)
      integer,intent(in)::node_index
      real(real64)::distance,bottom
      level=0.0_real64
      bottom=z(node_index)-0.5_real64*dz(node_index)
      if(node_index<n .and. matrix%pressure_head(node_index+1)<=0.0_real64)then
        distance=node_spacing(node_index)
        if(distance<=0.0_real64)return
        level=z(node_index+1)+matrix%pressure_head(node_index+1) / &
             (matrix%pressure_head(node_index+1)-matrix%pressure_head(node_index))*distance
      else
        level=bottom+matrix%pressure_head(node_index)
        level=min(z(node_index),max(bottom,level))
      end if
    end function perched_bottom_level

    subroutine advance_water_table(node_index,critical_volume,still_saturated,level,level_node)
      integer,intent(inout)::node_index
      real(real64),intent(in)::critical_volume
      logical,intent(inout)::still_saturated
      real(real64),intent(out)::level
      integer,intent(out)::level_node
      integer::j
      real(real64)::total_under_saturated
      logical::found_saturated

      total_under_saturated=0.0_real64
      found_saturated=.false.
      j=node_index
      do while(total_under_saturated<critical_volume .and. .not.found_saturated .and. j>0)
        total_under_saturated=total_under_saturated + &
             max(0.0_real64,theta_s(j)-matrix%water_content(j))*dz(j)
        if(matrix%pressure_head(j)>-1.0e-7_real64)found_saturated=.true.
        j=j-1
      end do

      if(j==0 .or. total_under_saturated>critical_volume-1.0e-8_real64)then
        still_saturated=.false.
        level=ordinary_water_level(node_index)
        level_node=node_for_level(node_index,level)
      else if(found_saturated)then
        node_index=j+1
      end if
    end subroutine advance_water_table

  end subroutine derive_matrix_perched_zone_view

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

    type(matrix_perched_zone_view_t)::perched_view
    integer::id,n,nd,topw
    real(real64)::volume_under_drain
    logical::rapid_view_ok

    ok=.false.
    if(.not.accepted_macro%ready() .or. .not.geometry%valid .or. .not.macro_view%valid)return
    n=accepted_macro%num_nodes
    nd=accepted_macro%num_domains
    if(matrix%active_nodes/=n .or. size(z)/=n .or. size(dz)/=n .or. step_duration<=0.0_real64)return

    ! Dynamic A9 top input and A10 rapid drainage are both composed from
    ! immutable configuration plus current accepted/candidate hydraulic views.

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

    perched_view=matrix_perched_zone_view_t()
    perched_view%valid=.true.
    if(template%perched_detection_enabled)then
      call derive_matrix_perched_zone_view(matrix,template%unsaturated%sorptivity%theta_s,z,dz,matrix_view, &
           template%critical_under_saturated_volume_cm,perched_view)
      if(.not.perched_view%valid)return
    end if
    request%unsaturated%sorptivity%perched_active=perched_view%active
    request%unsaturated%sorptivity%perched_top_node=perched_view%top_node
    request%unsaturated%sorptivity%perched_bottom_node=perched_view%bottom_node
    if(matrix_view%active)then
      request%unsaturated%sorptivity%matrix_top_saturated_node=matrix_view%top_node
    else
      request%unsaturated%sorptivity%matrix_top_saturated_node=n+1
    end if
    request%interflow_sat%step_duration=step_duration
    if(perched_view%active)then
      request%interflow_sat%matrix_top_saturated_node=perched_view%top_node
      request%interflow_sat%matrix_bottom_saturated_node=perched_view%bottom_node
      request%interflow_sat%matrix_partial_top_active=perched_view%partial_top_active
      request%interflow_sat%matrix_level=perched_view%water_level_cm
    else
      request%interflow_sat%matrix_top_saturated_node=1
      request%interflow_sat%matrix_bottom_saturated_node=0
      request%interflow_sat%matrix_partial_top_active=.false.
      request%interflow_sat%matrix_level=0.0_real64
    end if
    request%interflow_sat%matrix_head=matrix%pressure_head
    request%interflow_sat%bottom_domain=geometry%bottom_domain

    request%matrix_sat%step_duration=step_duration
    request%matrix_sat%matrix_partial_top_active=.true.
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
    if(matrix%ponding_depth < -1.0e-10_real64)return
    request%rapid%ponding_cm=max(0.0_real64,matrix%ponding_depth)
    request%rapid%water_storage_cm=sum(accepted_macro%water_domain_cp(1,:))
    request%rapid%volume_main_domain_cp=geometry%volume_domain_cp(1,:)
    if(request%rapid%enabled)then
      call derive_rapid_volume_under_drain(request%rapid%drain_level_cm,z,dz,geometry%volume_domain_cp(1,:), &
           geometry%top_node,geometry%bottom_domain(1),volume_under_drain,rapid_view_ok)
      if(.not.rapid_view_ok)return
      request%rapid%volume_under_drain_cm=volume_under_drain
    else
      request%rapid%volume_under_drain_cm=0.0_real64
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
