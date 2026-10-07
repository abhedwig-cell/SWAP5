module mod_drainage_separate_infiltration_distribution
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_drainage_spatial_distribution, only: drainage_distribution_parameters_t
  use mod_frost_divdra_drainage_effect, only: frost_divdra_parameters_t, frost_divdra_result_t, &
       compose_single_level_signed_frost_divdra, FROST_DIVDRA_OK
  implicit none
  private

  integer,parameter,public :: DRAIN_INF_SPLIT_OK=0
  integer,parameter,public :: DRAIN_INF_SPLIT_INVALID_PARAMETERS=1
  integer,parameter,public :: DRAIN_INF_SPLIT_INVALID_VIEW=2
  integer,parameter,public :: DRAIN_INF_SPLIT_B19_REJECTED=3

  type,public :: drainage_separate_infiltration_diagnostics_t
    integer :: status=DRAIN_INF_SPLIT_OK
    logical :: evaluated=.false.
    logical :: reused_b19_partition=.true.
    integer :: b19_status=FROST_DIVDRA_OK
    real(real64) :: partition_correction=0.0_real64
    logical :: scalar_transfer_is_authoritative=.true.
    logical :: persistent_process_state=.false.
  end type

  public :: distribute_single_level_separate_infiltration

contains

  subroutine distribute_single_level_separate_infiltration(distribution,view,scalar_transfer, &
       drain_bottom_cm,surface_water_level_cm,infiltration_depth_factor,nodal_sink,diagnostics)
    type(drainage_distribution_parameters_t),intent(in)::distribution
    type(process_hydraulic_view_t),intent(in)::view
    real(real64),intent(in)::scalar_transfer,drain_bottom_cm,surface_water_level_cm,infiltration_depth_factor
    real(real64),allocatable,intent(out)::nodal_sink(:)
    type(drainage_separate_infiltration_diagnostics_t),intent(out)::diagnostics

    type(frost_divdra_parameters_t)::p
    type(frost_divdra_result_t)::r
    real(real64),allocatable::factor(:),theta(:),saturation(:)
    integer::n

    diagnostics=drainage_separate_infiltration_diagnostics_t()
    n=distribution%active_nodes
    if(n<2.or.scalar_transfer>=0.0_real64.or..not.ieee_is_finite(scalar_transfer).or. &
         .not.ieee_is_finite(drain_bottom_cm).or..not.ieee_is_finite(surface_water_level_cm).or. &
         .not.ieee_is_finite(infiltration_depth_factor))then
      diagnostics%status=DRAIN_INF_SPLIT_INVALID_PARAMETERS
      return
    end if
    if(.not.allocated(view%water_content).or.size(view%water_content)/=n.or. &
         any(.not.ieee_is_finite(view%water_content)).or.any(view%water_content<0.0_real64).or. &
         any(view%water_content>1.0_real64))then
      diagnostics%status=DRAIN_INF_SPLIT_INVALID_VIEW
      return
    end if

    p%distribution=distribution
    p%drain_bottom_cm=drain_bottom_cm
    p%separate_infiltration=.true.
    p%surface_water_level_cm=surface_water_level_cm
    p%infiltration_depth_factor=infiltration_depth_factor
    allocate(factor(n),theta(n),saturation(n))
    factor=1.0_real64
    theta=view%water_content
    saturation=view%water_content

    call compose_single_level_signed_frost_divdra(p,view,factor,-1,0.0_real64,theta,saturation, &
         scalar_transfer,0.0_real64,r)
    diagnostics%b19_status=r%status
    if(.not.r%available.or.r%status/=FROST_DIVDRA_OK.or..not.allocated(r%final_nodal_sink))then
      diagnostics%status=DRAIN_INF_SPLIT_B19_REJECTED
      return
    end if
    if(size(r%final_nodal_sink)/=n)then
      diagnostics%status=DRAIN_INF_SPLIT_B19_REJECTED
      return
    end if
    nodal_sink=r%final_nodal_sink
    diagnostics%partition_correction=r%initial_partition_correction
    diagnostics%evaluated=.true.
  end subroutine
end module
