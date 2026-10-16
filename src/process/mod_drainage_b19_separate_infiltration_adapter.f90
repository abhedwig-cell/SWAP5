module mod_drainage_b19_separate_infiltration_adapter
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_drainage_spatial_distribution, only: drainage_distribution_parameters_t, drainage_node_transfer_t, &
       drainage_distribution_diagnostics_t, drainage_multilevel_diagnostics_t, distribute_single_level_signed_divdra, &
       distribute_multilevel_signed_divdra, DRAIN_DIST_OK
  use mod_frost_divdra_drainage_effect, only: frost_divdra_parameters_t, partition_signed_divdra, FROST_DIVDRA_OK
  implicit none
  private
  integer,parameter,public :: DRAIN_B19_INF_OK=0, DRAIN_B19_INF_INVALID_PARAMETERS=1
  integer,parameter,public :: DRAIN_B19_INF_COMPONENT_REJECTED=3
  type,public :: drainage_b19_separate_infiltration_parameters_t
    real(real64) :: drain_level_cm=0._real64
    real(real64) :: infiltration_depth_factor=.5_real64
  end type
  type,public :: drainage_b19_separate_infiltration_result_t
    integer :: status=DRAIN_B19_INF_INVALID_PARAMETERS
    logical :: available=.false.
    real(real64) :: authoritative_scalar_transfer=0._real64, correction=0._real64
    integer :: component_status=0
    real(real64),allocatable :: nodal_transfer(:)
  end type
  public :: distribute_single_level_separate_infiltration_b19, distribute_multilevel_separate_infiltration_b19
contains
  subroutine distribute_single_level_separate_infiltration_b19(distribution,view,scalar_transfer,parameters,result)
    type(drainage_distribution_parameters_t),intent(in)::distribution
    type(process_hydraulic_view_t),intent(in)::view
    real(real64),intent(in)::scalar_transfer
    type(drainage_b19_separate_infiltration_parameters_t),intent(in)::parameters
    type(drainage_b19_separate_infiltration_result_t),intent(out)::result
    type(frost_divdra_parameters_t)::p
    type(drainage_node_transfer_t)::ordinary
    type(drainage_distribution_diagnostics_t)::d
    real(real64),allocatable::nodes(:)
    integer::status
    result=drainage_b19_separate_infiltration_result_t();result%authoritative_scalar_transfer=scalar_transfer
    if(.not.valid_control(parameters))return
    call distribute_single_level_signed_divdra(distribution,view,scalar_transfer,ordinary,d)
    result%component_status=d%status
    if(d%status/=DRAIN_DIST_OK)then
      result%status=DRAIN_B19_INF_COMPONENT_REJECTED;return
    end if
    if(scalar_transfer>=0._real64)then
      ! SWDIVDINF changes only infiltration. The admitted ordinary row remains exact.
      call move_alloc(ordinary%soil_to_drain_rate,result%nodal_transfer)
    else
      p%distribution=distribution;p%separate_infiltration=.true.
      p%surface_water_level_cm=min(parameters%drain_level_cm,0._real64)
      p%infiltration_depth_factor=parameters%infiltration_depth_factor
      call partition_signed_divdra(p,distribution%saturated_conductivity,view%groundwater_level,scalar_transfer, &
           nodes,result%correction,status,ordinary_surface_geometry=.true.)
      result%component_status=status
      if(status/=FROST_DIVDRA_OK)then
        result%status=DRAIN_B19_INF_COMPONENT_REJECTED;return
      end if
      call move_alloc(nodes,result%nodal_transfer)
    end if
    result%status=DRAIN_B19_INF_OK;result%available=.true.
  end subroutine

  subroutine distribute_multilevel_separate_infiltration_b19(distribution,view,scalar_transfer,parameters,flux,status)
    type(drainage_distribution_parameters_t),intent(in)::distribution(:)
    type(process_hydraulic_view_t),intent(in)::view
    real(real64),intent(in)::scalar_transfer(:)
    type(drainage_b19_separate_infiltration_parameters_t),intent(in)::parameters(:)
    real(real64),allocatable,intent(out)::flux(:,:)
    integer,intent(out)::status
    type(drainage_distribution_parameters_t),allocatable::effective(:)
    type(drainage_multilevel_diagnostics_t)::d
    type(drainage_b19_separate_infiltration_result_t)::row
    real(real64),allocatable::scratch(:,:)
    real(real64)::factor,top_saturated
    integer::i,n
    status=DRAIN_B19_INF_INVALID_PARAMETERS;n=size(distribution)
    if(n<=1.or.size(parameters)/=n.or.size(scalar_transfer)/=n)return
    do i=1,n
      if(.not.valid_control(parameters(i)))return
    end do
    ! The admitted owner computes the profile anisotropy and legacy water-table node.
    ! Its temporary row is worker scratch, never a second scalar or published forcing.
    call distribute_multilevel_signed_divdra(distribution,view,scalar_transfer,scratch,d)
    if(d%status/=DRAIN_DIST_OK)then
      status=DRAIN_B19_INF_COMPONENT_REJECTED;return
    end if
    if(any(scalar_transfer<0._real64))then
      effective=distribution
      do i=1,n
        if(scalar_transfer(i)>=0._real64)cycle
        top_saturated=-distribution(i)%zbotcp(d%water_table_node)-d%groundwater_depth
        factor=max(parameters(i)%infiltration_depth_factor, &
             top_saturated/(.25_real64*distribution(i)%drain_spacing*d%profile_anisotropy_factor))
        effective(i)%drain_spacing=factor*distribution(i)%drain_spacing
      end do
      ! FDisInf multiplies L in ordering, cumulative flow and dmax in the source.
      ! Reuse the admitted interacting-layer algebra with this effective spacing.
      call distribute_multilevel_signed_divdra(effective,view,scalar_transfer,scratch,d)
      if(d%status/=DRAIN_DIST_OK)then
        status=DRAIN_B19_INF_COMPONENT_REJECTED;return
      end if
      do i=1,n
        if(scalar_transfer(i)>=0._real64)cycle
        call distribute_single_level_separate_infiltration_b19(distribution(i),view,scalar_transfer(i),parameters(i),row)
        if(.not.row%available)then
          status=DRAIN_B19_INF_COMPONENT_REJECTED;return
        end if
        scratch(i,:)=row%nodal_transfer
      end do
    end if
    call move_alloc(scratch,flux);status=DRAIN_B19_INF_OK
  end subroutine

  logical function valid_control(p) result(ok)
    type(drainage_b19_separate_infiltration_parameters_t),intent(in)::p
    ok=.false.
    if(.not.all(ieee_is_finite([p%drain_level_cm,p%infiltration_depth_factor])))return
    if(p%infiltration_depth_factor<0._real64.or.p%infiltration_depth_factor>1._real64)return
    ok=.true.
  end function
end module
