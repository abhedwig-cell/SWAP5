module mod_drainage_top_interflow_distribution
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_drainage_spatial_distribution, only: drainage_distribution_parameters_t, drainage_node_transfer_t, &
       drainage_distribution_diagnostics_t, drainage_multilevel_diagnostics_t, &
       distribute_single_level_signed_divdra, distribute_multilevel_signed_divdra, DRAIN_DIST_OK
  implicit none
  private

  integer,parameter,public :: DRAIN_TOPINT_OK=0
  integer,parameter,public :: DRAIN_TOPINT_INVALID_PARAMETERS=1
  integer,parameter,public :: DRAIN_TOPINT_INVALID_HYDRAULIC_VIEW=2
  integer,parameter,public :: DRAIN_TOPINT_DISTRIBUTION_REJECTED=3

  real(real64),parameter :: ACTIVE_MAGNITUDE=1.0e-10_real64
  real(real64),parameter :: LEVEL_OFFSET=1.0e-10_real64

  type,public :: drainage_top_interflow_diagnostics_t
    integer :: status=DRAIN_TOPINT_OK
    logical :: evaluated=.false.
    logical :: top_interflow_active=.false.
    integer :: top_interflow_level=0
    integer :: top_interflow_bottom_node=0
    real(real64) :: top_interflow_bottom_depth_cm=0.0_real64
    real(real64) :: top_interflow_transmissivity=0.0_real64
    real(real64) :: top_interflow_closure_correction=0.0_real64
    type(drainage_distribution_diagnostics_t) :: lower_single
    type(drainage_multilevel_diagnostics_t) :: lower_multilevel
    logical :: scalar_transfer_is_authoritative=.true.
    logical :: persistent_process_state=.false.
  end type

  public :: distribute_highest_interflow_signed_divdra

contains

  subroutine distribute_highest_interflow_signed_divdra(level_parameters,view,scalar_transfer, &
       top_drain_bottom_cm,drainage_flux_by_level,diagnostics)
    type(drainage_distribution_parameters_t),intent(in)::level_parameters(:)
    type(process_hydraulic_view_t),intent(in)::view
    real(real64),intent(in)::scalar_transfer(:)
    real(real64),intent(in)::top_drain_bottom_cm
    real(real64),allocatable,intent(out)::drainage_flux_by_level(:,:)
    type(drainage_top_interflow_diagnostics_t),intent(out)::diagnostics

    type(drainage_distribution_parameters_t),allocatable::lower(:)
    type(process_hydraulic_view_t)::lower_view
    type(drainage_node_transfer_t)::single_result
    type(drainage_distribution_diagnostics_t)::single_diag
    type(drainage_multilevel_diagnostics_t)::multi_diag
    real(real64),allocatable::lower_flux(:,:),khor(:)
    real(real64)::wlev,target_depth,profile_depth,dz_top_sat,depth_accum,kd,raw_bottom,sum_previous
    real(real64)::top_bottom_thickness,lower_first_thickness,cumulative
    integer::levels,n,top_level,wt_node,bottom_node,i,j,sub_n,lower_count

    diagnostics=drainage_top_interflow_diagnostics_t()
    levels=size(level_parameters)
    if(levels<1.or.size(scalar_transfer)/=levels.or..not.ieee_is_finite(top_drain_bottom_cm))then
      diagnostics%status=DRAIN_TOPINT_INVALID_PARAMETERS
      return
    end if
    if(any(.not.ieee_is_finite(scalar_transfer)))then
      diagnostics%status=DRAIN_TOPINT_INVALID_PARAMETERS
      return
    end if
    n=level_parameters(1)%active_nodes
    if(n<1.or..not.allocated(level_parameters(1)%dz).or..not.allocated(level_parameters(1)%zbotcp).or. &
         .not.allocated(level_parameters(1)%saturated_conductivity).or. &
         .not.allocated(level_parameters(1)%horizontal_anisotropy_factor))then
      diagnostics%status=DRAIN_TOPINT_INVALID_PARAMETERS
      return
    end if
    do i=2,levels
      if(.not.allocated(level_parameters(i)%dz).or..not.allocated(level_parameters(i)%zbotcp).or. &
           .not.allocated(level_parameters(i)%saturated_conductivity).or. &
           .not.allocated(level_parameters(i)%horizontal_anisotropy_factor))then
        diagnostics%status=DRAIN_TOPINT_INVALID_PARAMETERS
        return
      end if
      if(level_parameters(i)%active_nodes/=n.or.size(level_parameters(i)%dz)/=n.or. &
           any(abs(level_parameters(i)%dz-level_parameters(1)%dz)>0.0_real64).or. &
           any(abs(level_parameters(i)%zbotcp-level_parameters(1)%zbotcp)>0.0_real64).or. &
           any(abs(level_parameters(i)%saturated_conductivity-level_parameters(1)%saturated_conductivity)>0.0_real64).or. &
           any(abs(level_parameters(i)%horizontal_anisotropy_factor- &
               level_parameters(1)%horizontal_anisotropy_factor)>0.0_real64))then
        diagnostics%status=DRAIN_TOPINT_INVALID_PARAMETERS
        return
      end if
    end do
    if(.not.ieee_is_finite(view%groundwater_level))then
      diagnostics%status=DRAIN_TOPINT_INVALID_HYDRAULIC_VIEW
      return
    end if

    profile_depth=-level_parameters(1)%zbotcp(n)
    target_depth=-top_drain_bottom_cm
    wlev=-min(view%groundwater_level,0.0_real64)
    if(target_depth<=wlev.or.target_depth>profile_depth)then
      diagnostics%status=DRAIN_TOPINT_INVALID_PARAMETERS
      return
    end if

    allocate(drainage_flux_by_level(levels,n))
    drainage_flux_by_level=0.0_real64
    top_level=levels
    diagnostics%top_interflow_level=top_level

    if(abs(scalar_transfer(top_level))>ACTIVE_MAGNITUDE)then
      diagnostics%top_interflow_active=.true.
      wt_node=1
      do while(wlev>-level_parameters(1)%zbotcp(wt_node)+LEVEL_OFFSET)
        wt_node=wt_node+1
        if(wt_node>n)then
          diagnostics%status=DRAIN_TOPINT_INVALID_HYDRAULIC_VIEW
          return
        end if
      end do
      dz_top_sat=-level_parameters(1)%zbotcp(wt_node)-wlev
      allocate(khor(n))
      khor=level_parameters(1)%saturated_conductivity*level_parameters(1)%horizontal_anisotropy_factor
      bottom_node=wt_node
      depth_accum=dz_top_sat
      kd=dz_top_sat*khor(wt_node)
      do while(target_depth-wlev>depth_accum)
        bottom_node=bottom_node+1
        if(bottom_node>n)then
          diagnostics%status=DRAIN_TOPINT_INVALID_PARAMETERS
          return
        end if
        depth_accum=depth_accum+level_parameters(1)%dz(bottom_node)
        kd=kd+level_parameters(1)%dz(bottom_node)*khor(bottom_node)
      end do
      kd=kd-(depth_accum-(target_depth-wlev))*khor(bottom_node)
      top_bottom_thickness=level_parameters(1)%dz(bottom_node)-(depth_accum-(target_depth-wlev))
      lower_first_thickness=depth_accum-(target_depth-wlev)
      if(kd<=0.0_real64.or.top_bottom_thickness<=0.0_real64.or.lower_first_thickness<0.0_real64)then
        diagnostics%status=DRAIN_TOPINT_INVALID_PARAMETERS
        return
      end if
      if(wt_node==bottom_node)then
        drainage_flux_by_level(top_level,wt_node)=scalar_transfer(top_level)
      else
        drainage_flux_by_level(top_level,wt_node)=scalar_transfer(top_level)*dz_top_sat*khor(wt_node)/kd
        do i=wt_node+1,bottom_node-1
          drainage_flux_by_level(top_level,i)=scalar_transfer(top_level)*level_parameters(1)%dz(i)*khor(i)/kd
        end do
        raw_bottom=scalar_transfer(top_level)*top_bottom_thickness*khor(bottom_node)/kd
        sum_previous=sum(drainage_flux_by_level(top_level,1:bottom_node-1))
        drainage_flux_by_level(top_level,bottom_node)=scalar_transfer(top_level)-sum_previous
        diagnostics%top_interflow_closure_correction=drainage_flux_by_level(top_level,bottom_node)-raw_bottom
      end if
      diagnostics%top_interflow_bottom_node=bottom_node
      diagnostics%top_interflow_bottom_depth_cm=top_drain_bottom_cm
      diagnostics%top_interflow_transmissivity=kd

      lower_count=levels-1
      if(lower_count==0)then
        diagnostics%evaluated=.true.
        return
      end if

      sub_n=n-bottom_node+1
      allocate(lower(lower_count))
      do j=1,lower_count
        lower(j)%active_nodes=sub_n
        lower(j)%drain_spacing=level_parameters(j)%drain_spacing
        allocate(lower(j)%dz(sub_n),lower(j)%zbotcp(sub_n),lower(j)%saturated_conductivity(sub_n), &
             lower(j)%horizontal_anisotropy_factor(sub_n))
        lower(j)%dz=level_parameters(j)%dz(bottom_node:n)
        lower(j)%dz(1)=lower_first_thickness
        lower(j)%saturated_conductivity=level_parameters(j)%saturated_conductivity(bottom_node:n)
        lower(j)%horizontal_anisotropy_factor=level_parameters(j)%horizontal_anisotropy_factor(bottom_node:n)
        cumulative=0.0_real64
        do i=1,sub_n
          cumulative=cumulative+lower(j)%dz(i)
          lower(j)%zbotcp(i)=-cumulative
        end do
      end do
      lower_view%active_nodes=sub_n
      lower_view%groundwater_level=0.0_real64
      allocate(lower_view%pressure_head(sub_n),lower_view%water_content(sub_n))
      lower_view%pressure_head=0.0_real64
      lower_view%water_content=0.0_real64
      if(lower_count==1)then
        if(abs(scalar_transfer(1))<=ACTIVE_MAGNITUDE)then
          call distribute_single_level_signed_divdra(lower(1),lower_view,0.0_real64,single_result,single_diag)
        else
          call distribute_single_level_signed_divdra(lower(1),lower_view,scalar_transfer(1),single_result,single_diag)
        end if
        diagnostics%lower_single=single_diag
        if(single_diag%status/=DRAIN_DIST_OK)then
          diagnostics%status=DRAIN_TOPINT_DISTRIBUTION_REJECTED
          return
        end if
        drainage_flux_by_level(1,bottom_node:n)=single_result%soil_to_drain_rate
      else
        call distribute_multilevel_signed_divdra(lower,lower_view,scalar_transfer(1:lower_count),lower_flux,multi_diag)
        diagnostics%lower_multilevel=multi_diag
        if(multi_diag%status/=DRAIN_DIST_OK)then
          diagnostics%status=DRAIN_TOPINT_DISTRIBUTION_REJECTED
          return
        end if
        drainage_flux_by_level(1:lower_count,bottom_node:n)=lower_flux
      end if
    else
      lower_count=levels-1
      if(lower_count==0)then
        diagnostics%evaluated=.true.
        return
      else if(lower_count==1)then
        if(abs(scalar_transfer(1))<=ACTIVE_MAGNITUDE)then
          call distribute_single_level_signed_divdra(level_parameters(1),view,0.0_real64,single_result,single_diag)
        else
          call distribute_single_level_signed_divdra(level_parameters(1),view,scalar_transfer(1),single_result,single_diag)
        end if
        diagnostics%lower_single=single_diag
        if(single_diag%status/=DRAIN_DIST_OK)then
          diagnostics%status=DRAIN_TOPINT_DISTRIBUTION_REJECTED
          return
        end if
        drainage_flux_by_level(1,:)=single_result%soil_to_drain_rate
      else
        call distribute_multilevel_signed_divdra(level_parameters(1:lower_count),view, &
             scalar_transfer(1:lower_count),lower_flux,multi_diag)
        diagnostics%lower_multilevel=multi_diag
        if(multi_diag%status/=DRAIN_DIST_OK)then
          diagnostics%status=DRAIN_TOPINT_DISTRIBUTION_REJECTED
          return
        end if
        drainage_flux_by_level(1:lower_count,:)=lower_flux
      end if
    end if

    diagnostics%evaluated=.true.
  end subroutine
end module
