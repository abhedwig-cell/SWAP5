module mod_irrigation_root_zone_summary
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
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

contains

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
