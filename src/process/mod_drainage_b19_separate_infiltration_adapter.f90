module mod_drainage_b19_separate_infiltration_adapter
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_drainage_spatial_distribution, only: drainage_distribution_parameters_t
  use mod_frost_divdra_drainage_effect, only: frost_divdra_parameters_t, frost_divdra_result_t, &
       compose_single_level_signed_frost_divdra, FROST_DIVDRA_OK
  implicit none
  private

  integer,parameter,public :: DRAIN_B19_INF_OK=0
  integer,parameter,public :: DRAIN_B19_INF_INVALID_PARAMETERS=1
  integer,parameter,public :: DRAIN_B19_INF_INVALID_HYDRAULIC_VIEW=2
  integer,parameter,public :: DRAIN_B19_INF_COMPONENT_REJECTED=3

  type,public :: drainage_b19_separate_infiltration_parameters_t
    real(real64) :: drain_bottom_cm=0.0_real64
    real(real64) :: drain_level_cm=0.0_real64
    real(real64) :: infiltration_depth_factor=0.5_real64
  end type

  type,public :: drainage_b19_separate_infiltration_result_t
    integer :: status=DRAIN_B19_INF_OK
    logical :: available=.false.
    real(real64) :: authoritative_scalar_transfer=0.0_real64
    real(real64),allocatable :: nodal_transfer(:)
    type(frost_divdra_result_t) :: b19
  end type

  public :: distribute_single_level_separate_infiltration_b19

contains

  subroutine distribute_single_level_separate_infiltration_b19(distribution,view,scalar_transfer,parameters,result)
    type(drainage_distribution_parameters_t),intent(in)::distribution
    type(process_hydraulic_view_t),intent(in)::view
    real(real64),intent(in)::scalar_transfer
    type(drainage_b19_separate_infiltration_parameters_t),intent(in)::parameters
    type(drainage_b19_separate_infiltration_result_t),intent(out)::result
    type(frost_divdra_parameters_t)::p
    real(real64),allocatable::factor(:),saturation(:)
    integer::n

    result=drainage_b19_separate_infiltration_result_t()
    result%authoritative_scalar_transfer=scalar_transfer
    n=distribution%active_nodes
    if(n<2.or..not.ieee_is_finite(scalar_transfer).or. &
         .not.all(ieee_is_finite([parameters%drain_bottom_cm,parameters%drain_level_cm, &
         parameters%infiltration_depth_factor])))then
      result%status=DRAIN_B19_INF_INVALID_PARAMETERS
      return
    end if
    if(parameters%infiltration_depth_factor<0.0_real64.or.parameters%infiltration_depth_factor>1.0_real64)then
      result%status=DRAIN_B19_INF_INVALID_PARAMETERS
      return
    end if
    if(view%active_nodes/=n.or..not.allocated(view%water_content).or.size(view%water_content)/=n.or. &
         any(.not.ieee_is_finite(view%water_content)).or.any(view%water_content<0.0_real64).or. &
         any(view%water_content>1.0_real64))then
      result%status=DRAIN_B19_INF_INVALID_HYDRAULIC_VIEW
      return
    end if

    p%distribution=distribution
    p%drain_bottom_cm=parameters%drain_bottom_cm
    p%separate_infiltration=.true.
    p%surface_water_level_cm=min(parameters%drain_level_cm,0.0_real64)
    p%infiltration_depth_factor=parameters%infiltration_depth_factor
    allocate(factor(n),saturation(n))
    factor=1.0_real64
    saturation=view%water_content

    call compose_single_level_signed_frost_divdra(p,view,factor,-1,0.0_real64,view%water_content,saturation, &
         scalar_transfer,0.0_real64,result%b19)
    if(.not.result%b19%available.or.result%b19%status/=FROST_DIVDRA_OK)then
      result%status=DRAIN_B19_INF_COMPONENT_REJECTED
      return
    end if
    if(abs(result%b19%final_bottom)>0.0_real64)then
      result%status=DRAIN_B19_INF_COMPONENT_REJECTED
      return
    end if
    result%nodal_transfer=result%b19%final_nodal_sink
    result%available=.true.
  end subroutine
end module
