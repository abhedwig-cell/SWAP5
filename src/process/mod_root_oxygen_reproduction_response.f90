module mod_root_oxygen_reproduction_response
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: ROOT_OXYGEN_REPRO_OK = 0
  integer, parameter, public :: ROOT_OXYGEN_REPRO_INVALID_INPUT = 1
  integer, parameter, public :: ROOT_OXYGEN_REPRO_INVALID_RESULT = 2

  type, public :: root_oxygen_reproduction_parameters_t
    real(real64) :: slope(6) = 0.0_real64
    real(real64) :: intercept(6) = 0.0_real64
    real(real64), allocatable :: saturated_water_content(:)
    real(real64), allocatable :: z_cm(:)
    real(real64), allocatable :: zbotcp_cm(:)
    real(real64), allocatable :: dz_cm(:)
  contains
    procedure, public :: ready => root_oxygen_reproduction_parameters_ready
    procedure, public :: active_nodes => root_oxygen_reproduction_active_nodes
  end type root_oxygen_reproduction_parameters_t

  public :: evaluate_root_oxygen_reproduction_factor
  public :: evaluate_root_oxygen_reproduction_profile

contains

  logical function root_oxygen_reproduction_parameters_ready(self) result(ready)
    class(root_oxygen_reproduction_parameters_t), intent(in) :: self
    integer :: n
    ready = .false.
    if (.not. all(ieee_is_finite(self%slope)) .or. .not. all(ieee_is_finite(self%intercept))) return
    if (.not. allocated(self%saturated_water_content) .or. .not. allocated(self%z_cm) .or. &
        .not. allocated(self%zbotcp_cm) .or. .not. allocated(self%dz_cm)) return
    n = size(self%saturated_water_content)
    if (n <= 0 .or. size(self%z_cm) /= n .or. size(self%zbotcp_cm) /= n .or. size(self%dz_cm) /= n) return
    if (any(.not. ieee_is_finite(self%saturated_water_content)) .or. &
        any(.not. ieee_is_finite(self%z_cm)) .or. any(.not. ieee_is_finite(self%zbotcp_cm)) .or. &
        any(.not. ieee_is_finite(self%dz_cm))) return
    if (any(self%saturated_water_content <= 0.0_real64) .or. any(self%saturated_water_content > 1.0_real64)) return
    if (any(self%zbotcp_cm >= 0.0_real64) .or. any(self%dz_cm <= 0.0_real64)) return
    ready = .true.
  end function root_oxygen_reproduction_parameters_ready

  integer function root_oxygen_reproduction_active_nodes(self) result(n)
    class(root_oxygen_reproduction_parameters_t), intent(in) :: self
    n = 0
    if (self%ready()) n = size(self%saturated_water_content)
  end function root_oxygen_reproduction_active_nodes

  subroutine evaluate_root_oxygen_reproduction_factor(parameters, water_content, soil_temperature_c, &
                                                       node, factor, status)
    type(root_oxygen_reproduction_parameters_t), intent(in) :: parameters
    real(real64), intent(in) :: water_content(:), soil_temperature_c(:)
    integer, intent(in) :: node
    real(real64), intent(out) :: factor
    integer, intent(out) :: status

    real(real64) :: gas_filled_porosity, soil_temp_k, depth_m
    real(real64) :: sum_porosity, mean_gas_filled_porosity
    real(real64) :: intercept_value, slope_value
    integer :: i, n

    factor = 0.0_real64
    status = ROOT_OXYGEN_REPRO_INVALID_INPUT
    if (.not. parameters%ready()) return

    n = size(water_content)
    if (n <= 0 .or. node < 1 .or. node > n) return
    if (n /= parameters%active_nodes() .or. size(soil_temperature_c) /= n) return
    if (any(.not. ieee_is_finite(water_content)) .or. any(.not. ieee_is_finite(soil_temperature_c))) return

    ! Literal pinned B1.11 SWAP/oxygenstress.f90 OxygenReproFunction.
    gas_filled_porosity = max(0.0_real64, parameters%saturated_water_content(node) - water_content(node))
    soil_temp_k = soil_temperature_c(node) + 273.0_real64
    depth_m = -parameters%z_cm(node) * 0.01_real64

    if (gas_filled_porosity < 1.0e-10_real64) then
      factor = 0.0_real64
      status = ROOT_OXYGEN_REPRO_OK
      return
    end if

    sum_porosity = 0.0_real64
    do i = 1, node
      sum_porosity = sum_porosity + (parameters%saturated_water_content(i) - water_content(i)) * parameters%dz_cm(i)
    end do
    mean_gas_filled_porosity = sum_porosity / (-parameters%zbotcp_cm(node))

    intercept_value = parameters%intercept(1)*soil_temp_k**2 + &
                      parameters%intercept(2)*depth_m**2 + &
                      parameters%intercept(3)*soil_temp_k + &
                      parameters%intercept(4)*depth_m + &
                      parameters%intercept(5)*soil_temp_k*depth_m + &
                      parameters%intercept(6)

    slope_value = parameters%slope(1)*soil_temp_k**2 + &
                  parameters%slope(2)*depth_m**2 + &
                  parameters%slope(3)*soil_temp_k + &
                  parameters%slope(4)*depth_m + &
                  parameters%slope(5)*soil_temp_k*depth_m + &
                  parameters%slope(6)

    factor = intercept_value + slope_value*mean_gas_filled_porosity
    factor = min(1.0_real64, max(0.0_real64, factor))
    if (.not. ieee_is_finite(factor)) then
      factor = 0.0_real64
      status = ROOT_OXYGEN_REPRO_INVALID_RESULT
      return
    end if
    status = ROOT_OXYGEN_REPRO_OK
  end subroutine evaluate_root_oxygen_reproduction_factor

  subroutine evaluate_root_oxygen_reproduction_profile(parameters, water_content, soil_temperature_c, &
                                                        rooted_nodes, factors, status)
    type(root_oxygen_reproduction_parameters_t), intent(in) :: parameters
    real(real64), intent(in) :: water_content(:), soil_temperature_c(:)
    integer, intent(in) :: rooted_nodes
    real(real64), allocatable, intent(out) :: factors(:)
    integer, intent(out) :: status

    integer :: node, local_status

    if (allocated(factors)) deallocate(factors)
    status = ROOT_OXYGEN_REPRO_INVALID_INPUT
    if (rooted_nodes < 0 .or. rooted_nodes > size(water_content)) return
    allocate(factors(rooted_nodes))
    do node = 1, rooted_nodes
      call evaluate_root_oxygen_reproduction_factor(parameters, water_content, soil_temperature_c, &
           node, factors(node), local_status)
      if (local_status /= ROOT_OXYGEN_REPRO_OK) then
        deallocate(factors)
        status = local_status
        return
      end if
    end do
    status = ROOT_OXYGEN_REPRO_OK
  end subroutine evaluate_root_oxygen_reproduction_profile

end module mod_root_oxygen_reproduction_response
