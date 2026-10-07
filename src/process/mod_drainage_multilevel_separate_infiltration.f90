module mod_drainage_multilevel_separate_infiltration
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_drainage_spatial_distribution, only: drainage_distribution_parameters_t, &
       drainage_multilevel_diagnostics_t, distribute_multilevel_signed_divdra, DRAIN_DIST_OK
  use mod_drainage_b19_separate_infiltration_adapter, only: drainage_b19_separate_infiltration_parameters_t, &
       drainage_b19_separate_infiltration_result_t, distribute_single_level_separate_infiltration_b19, DRAIN_B19_INF_OK
  implicit none
  private

  integer,parameter,public :: DRAIN_MULTI_INF_OK=0
  integer,parameter,public :: DRAIN_MULTI_INF_INVALID_PARAMETERS=1
  integer,parameter,public :: DRAIN_MULTI_INF_INVALID_HYDRAULIC_VIEW=2
  integer,parameter,public :: DRAIN_MULTI_INF_BASE_REJECTED=3
  integer,parameter,public :: DRAIN_MULTI_INF_B19_REJECTED=4
  real(real64),parameter :: SMALL=1.0e-10_real64

  type,public :: drainage_multilevel_separate_infiltration_result_t
    integer :: status=DRAIN_MULTI_INF_OK
    logical :: available=.false.
    real(real64),allocatable :: authoritative_scalar_transfer(:)
    real(real64),allocatable :: fdisinf(:)
    real(real64),allocatable :: drainage_flux_by_level(:,:)
    type(drainage_multilevel_diagnostics_t) :: multilevel
    type(drainage_b19_separate_infiltration_result_t),allocatable :: infiltration(:)
  end type

  public :: distribute_multilevel_separate_infiltration_b19

contains

  subroutine distribute_multilevel_separate_infiltration_b19(level_parameters,view,scalar_transfer, &
       drain_bottom_cm,surface_water_level_cm,infiltration_depth_factor,result)
    type(drainage_distribution_parameters_t),intent(in)::level_parameters(:)
    type(process_hydraulic_view_t),intent(in)::view
    real(real64),intent(in)::scalar_transfer(:),drain_bottom_cm(:),surface_water_level_cm(:)
    real(real64),intent(in)::infiltration_depth_factor
    type(drainage_multilevel_separate_infiltration_result_t),intent(out)::result

    type(drainage_distribution_parameters_t),allocatable::effective(:)
    type(drainage_b19_separate_infiltration_parameters_t)::p
    real(real64),allocatable::base_flux(:,:)
    real(real64)::wlev,dz_top_sat,fac_aniso,minimum_factor
    integer::levels,n,i,wt_node

    result=drainage_multilevel_separate_infiltration_result_t()
    levels=size(level_parameters)
    if(levels<=1.or.size(scalar_transfer)/=levels.or.size(drain_bottom_cm)/=levels.or. &
         size(surface_water_level_cm)/=levels)then
      result%status=DRAIN_MULTI_INF_INVALID_PARAMETERS
      return
    end if
    if(.not.ieee_is_finite(infiltration_depth_factor).or.infiltration_depth_factor<0.0_real64.or. &
         infiltration_depth_factor>1.0_real64.or.any(.not.ieee_is_finite(scalar_transfer)).or. &
         any(.not.ieee_is_finite(drain_bottom_cm)).or.any(.not.ieee_is_finite(surface_water_level_cm)))then
      result%status=DRAIN_MULTI_INF_INVALID_PARAMETERS
      return
    end if
    n=level_parameters(1)%active_nodes
    if(n<2.or.view%active_nodes/=n.or..not.ieee_is_finite(view%groundwater_level))then
      result%status=DRAIN_MULTI_INF_INVALID_HYDRAULIC_VIEW
      return
    end if

    allocate(effective(levels),result%fdisinf(levels),result%authoritative_scalar_transfer(levels), &
         result%infiltration(levels))
    effective=level_parameters
    result%fdisinf=1.0_real64
    result%authoritative_scalar_transfer=scalar_transfer

    ! Reuse the already admitted multilevel validator/geometry first. This
    ! avoids a second parameter-validity implementation in the SWDIVDINF adapter.
    call distribute_multilevel_signed_divdra(level_parameters,view,scalar_transfer,base_flux,result%multilevel)
    if(result%multilevel%status/=DRAIN_DIST_OK.or..not.allocated(base_flux))then
      result%status=DRAIN_MULTI_INF_BASE_REJECTED
      return
    end if
    fac_aniso=result%multilevel%profile_anisotropy_factor
    wlev=-min(view%groundwater_level,0.0_real64)
    wt_node=result%multilevel%water_table_node
    if(wt_node<1.or.wt_node>n.or.fac_aniso<=0.0_real64)then
      result%status=DRAIN_MULTI_INF_INVALID_HYDRAULIC_VIEW
      return
    end if
    dz_top_sat=-level_parameters(1)%zbotcp(wt_node)-wlev

    do i=1,levels
      if(scalar_transfer(i)<-SMALL)then
        if(level_parameters(i)%drain_spacing<=0.0_real64)then
          result%status=DRAIN_MULTI_INF_INVALID_PARAMETERS
          return
        end if
        minimum_factor=dz_top_sat/(0.25_real64*level_parameters(i)%drain_spacing*fac_aniso)
        result%fdisinf(i)=max(infiltration_depth_factor,minimum_factor)
        effective(i)%drain_spacing=result%fdisinf(i)*level_parameters(i)%drain_spacing
      end if
    end do

    if(allocated(base_flux))deallocate(base_flux)
    call distribute_multilevel_signed_divdra(effective,view,scalar_transfer,base_flux,result%multilevel)
    if(result%multilevel%status/=DRAIN_DIST_OK.or..not.allocated(base_flux))then
      result%status=DRAIN_MULTI_INF_BASE_REJECTED
      return
    end if

    result%drainage_flux_by_level=base_flux
    do i=1,levels
      if(scalar_transfer(i)<-SMALL)then
        p%drain_bottom_cm=drain_bottom_cm(i)
        p%drain_level_cm=surface_water_level_cm(i)
        p%infiltration_depth_factor=infiltration_depth_factor
        call distribute_single_level_separate_infiltration_b19(level_parameters(i),view,scalar_transfer(i),p, &
             result%infiltration(i))
        if(result%infiltration(i)%status/=DRAIN_B19_INF_OK.or..not.result%infiltration(i)%available.or. &
             .not.allocated(result%infiltration(i)%nodal_transfer))then
          result%status=DRAIN_MULTI_INF_B19_REJECTED
          return
        end if
        result%drainage_flux_by_level(i,:)=result%infiltration(i)%nodal_transfer
      end if
    end do
    result%available=.true.
  end subroutine
end module mod_drainage_multilevel_separate_infiltration
