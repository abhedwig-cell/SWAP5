module mod_irrigation_root_zone_summary
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, constitutive_hydraulics_provider_t, &
       CONSTITUTIVE_DEMAND_WATER_CONTENT
  implicit none
  private

  integer, parameter, public :: IRR_ROOT_ZONE_OK = 0
  integer, parameter, public :: IRR_ROOT_ZONE_INVALID_PARAMETERS = 1
  integer, parameter, public :: IRR_ROOT_ZONE_INVALID_VIEW = 2

  type, public :: irrigation_root_zone_parameters_t
    integer :: active_nodes = 0
    integer :: rooted_nodes = 0
    real(real64) :: last_rooted_fraction = 1.0_real64
    real(real64), allocatable :: node_thickness_cm(:)
    real(real64), allocatable :: field_capacity_water_content(:)
    real(real64), allocatable :: stress_water_content(:)
    real(real64), allocatable :: wilting_water_content(:)
  end type irrigation_root_zone_parameters_t

  type, public :: irrigation_root_zone_summary_t
    real(real64) :: total_available_water_cm = 0.0_real64
    real(real64) :: stress_to_wilting_available_cm = 0.0_real64
    real(real64) :: actual_available_water_cm = 0.0_real64
    real(real64) :: field_capacity_deficit_cm = 0.0_real64
  end type irrigation_root_zone_summary_t

  public :: evaluate_irrigation_root_zone_summary
  public :: derive_irrigation_root_zone_parameters

contains

  ! Disposable view of accepted material and root extent, not a new owner.
  ! Caller supplies the already validated constitutive provider. B1.11 uses
  ! PHFIELDCAPACITY, (HLIM3L+HLIM3H)/2 and HLIM4, not today's variable HLIM3.
  subroutine derive_irrigation_root_zone_parameters(geometry, provider, root_depth_cm, field_capacity_head_cm, &
       stress_head_cm, wilting_head_cm, parameters, status)
    type(soil_water_parameter_set_t), intent(in) :: geometry
    class(constitutive_hydraulics_provider_t), intent(in) :: provider
    real(real64), intent(in) :: root_depth_cm, field_capacity_head_cm, stress_head_cm, wilting_head_cm
    type(irrigation_root_zone_parameters_t), intent(out) :: parameters
    integer, intent(out) :: status
    type(irrigation_root_zone_parameters_t) :: candidate
    real(real64), allocatable :: heads(:), k(:), c(:), dk(:)
    real(real64) :: top, bottom, tolerance
    integer :: i, n

    parameters=irrigation_root_zone_parameters_t()
    status=IRR_ROOT_ZONE_INVALID_PARAMETERS
    n=geometry%active_nodes
    if(n<=0) return
    if(.not.allocated(geometry%z).or..not.allocated(geometry%dz)) return
    if(size(geometry%z)/=n.or.size(geometry%dz)/=n) return
    if(.not.all(ieee_is_finite(geometry%z)).or..not.all(ieee_is_finite(geometry%dz))) return
    if(any(geometry%dz<=0.0_real64)) return
    if(.not.all(ieee_is_finite([root_depth_cm,field_capacity_head_cm,stress_head_cm,wilting_head_cm]))) return
    if(root_depth_cm<=0.0_real64.or.field_capacity_head_cm < -500.0_real64.or.field_capacity_head_cm>0.0_real64) return
    if(wilting_head_cm>stress_head_cm.or.stress_head_cm>field_capacity_head_cm) return
    ! Current typed columns are surface-anchored, descending contiguous cells.
    ! Reject inconsistent geometry rather than guessing a root fraction.
    top=0.0_real64
    do i=1,n
      tolerance=64.0_real64*epsilon(top)*max(1.0_real64,abs(top),geometry%dz(i))
      if(abs(geometry%z(i)+0.5_real64*geometry%dz(i)-top)>tolerance) return
      bottom=geometry%z(i)-0.5_real64*geometry%dz(i)
      if(candidate%rooted_nodes==0.and.root_depth_cm<=-bottom) then
        candidate%rooted_nodes=i
        candidate%last_rooted_fraction=(top+root_depth_cm)/geometry%dz(i)
      end if
      top=bottom
    end do
    if(candidate%rooted_nodes==0) return
    candidate%active_nodes=n
    candidate%node_thickness_cm=geometry%dz
    allocate(heads(n),k(n),c(n),dk(n),candidate%field_capacity_water_content(n), &
             candidate%stress_water_content(n),candidate%wilting_water_content(n))
    heads=field_capacity_head_cm
    call provider%evaluate_demand(heads,CONSTITUTIVE_DEMAND_WATER_CONTENT,candidate%field_capacity_water_content,k,c,dk)
    heads=stress_head_cm
    call provider%evaluate_demand(heads,CONSTITUTIVE_DEMAND_WATER_CONTENT,candidate%stress_water_content,k,c,dk)
    heads=wilting_head_cm
    call provider%evaluate_demand(heads,CONSTITUTIVE_DEMAND_WATER_CONTENT,candidate%wilting_water_content,k,c,dk)
    if(.not.valid_parameters(candidate)) return
    parameters=candidate
    status=IRR_ROOT_ZONE_OK
  end subroutine derive_irrigation_root_zone_parameters

  pure subroutine evaluate_irrigation_root_zone_summary(parameters, hydraulic_view, summary, status)
    type(irrigation_root_zone_parameters_t), intent(in) :: parameters
    type(process_hydraulic_view_t), intent(in) :: hydraulic_view
    type(irrigation_root_zone_summary_t), intent(out) :: summary
    integer, intent(out) :: status
    integer :: node
    real(real64) :: fraction, dz, theta_fc, theta_stress, theta_wilt, theta_actual

    summary = irrigation_root_zone_summary_t()
    status = IRR_ROOT_ZONE_OK
    if (.not. valid_parameters(parameters)) then
      status = IRR_ROOT_ZONE_INVALID_PARAMETERS
      return
    end if
    if (.not. valid_view(parameters, hydraulic_view)) then
      status = IRR_ROOT_ZONE_INVALID_VIEW
      return
    end if

    do node = 1, parameters%rooted_nodes
      fraction = 1.0_real64
      if (node == parameters%rooted_nodes) fraction = parameters%last_rooted_fraction
      dz = parameters%node_thickness_cm(node) * fraction
      theta_fc = parameters%field_capacity_water_content(node)
      theta_stress = parameters%stress_water_content(node)
      theta_wilt = parameters%wilting_water_content(node)
      theta_actual = hydraulic_view%water_content(node)
      summary%total_available_water_cm = summary%total_available_water_cm + (theta_fc-theta_wilt)*dz
      summary%stress_to_wilting_available_cm = summary%stress_to_wilting_available_cm + (theta_stress-theta_wilt)*dz
      summary%actual_available_water_cm = summary%actual_available_water_cm + (theta_actual-theta_wilt)*dz
      summary%field_capacity_deficit_cm = summary%field_capacity_deficit_cm + (theta_fc-theta_actual)*dz
    end do
  end subroutine evaluate_irrigation_root_zone_summary

  pure logical function valid_parameters(parameters)
    type(irrigation_root_zone_parameters_t), intent(in) :: parameters
    integer :: n
    valid_parameters = .false.
    n = parameters%active_nodes
    if (n <= 0 .or. parameters%rooted_nodes <= 0 .or. parameters%rooted_nodes > n) return
    if (.not. ieee_is_finite(parameters%last_rooted_fraction) .or. parameters%last_rooted_fraction <= 0.0_real64 .or. &
        parameters%last_rooted_fraction > 1.0_real64) return
    if (.not. allocated(parameters%node_thickness_cm) .or. .not. allocated(parameters%field_capacity_water_content) .or. &
        .not. allocated(parameters%stress_water_content) .or. .not. allocated(parameters%wilting_water_content)) return
    if (size(parameters%node_thickness_cm) /= n .or. size(parameters%field_capacity_water_content) /= n .or. &
        size(parameters%stress_water_content) /= n .or. size(parameters%wilting_water_content) /= n) return
    if (.not. all(ieee_is_finite(parameters%node_thickness_cm)) .or. &
        .not. all(ieee_is_finite(parameters%field_capacity_water_content)) .or. &
        .not. all(ieee_is_finite(parameters%stress_water_content)) .or. &
        .not. all(ieee_is_finite(parameters%wilting_water_content))) return
    if (any(parameters%node_thickness_cm <= 0.0_real64)) return
    if (any(parameters%field_capacity_water_content < 0.0_real64) .or. any(parameters%field_capacity_water_content > 1.0_real64) .or. &
        any(parameters%stress_water_content < 0.0_real64) .or. any(parameters%stress_water_content > 1.0_real64) .or. &
        any(parameters%wilting_water_content < 0.0_real64) .or. any(parameters%wilting_water_content > 1.0_real64)) return
    if (any(parameters%field_capacity_water_content(1:parameters%rooted_nodes) < &
            parameters%stress_water_content(1:parameters%rooted_nodes))) return
    if (any(parameters%stress_water_content(1:parameters%rooted_nodes) < &
            parameters%wilting_water_content(1:parameters%rooted_nodes))) return
    valid_parameters = .true.
  end function valid_parameters

  pure logical function valid_view(parameters, hydraulic_view)
    type(irrigation_root_zone_parameters_t), intent(in) :: parameters
    type(process_hydraulic_view_t), intent(in) :: hydraulic_view
    valid_view = .false.
    if (hydraulic_view%active_nodes /= parameters%active_nodes) return
    if (.not. allocated(hydraulic_view%water_content)) return
    if (size(hydraulic_view%water_content) /= hydraulic_view%active_nodes) return
    if (.not. all(ieee_is_finite(hydraulic_view%water_content(1:parameters%rooted_nodes)))) return
    valid_view = .true.
  end function valid_view
end module mod_irrigation_root_zone_summary
