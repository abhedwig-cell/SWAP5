module mod_linear_mixture_sensible_storage
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: LMSS_OK = 0
  integer, parameter, public :: LMSS_INVALID_PROPERTIES = 1
  integer, parameter, public :: LMSS_INVALID_STATE = 2

  type, public :: linear_mixture_sensible_storage_parameters_t
    real(real64) :: theta_sat = 0.0_real64
    real(real64) :: solid_heat_capacity_j_cm3_k = 0.0_real64
    real(real64) :: liquid_heat_capacity_j_cm3_k = 0.0_real64
    real(real64) :: gas_heat_capacity_j_cm3_k = 0.0_real64
    real(real64) :: reference_temperature_c = 0.0_real64
    logical :: initialized = .false.
  contains
    procedure, public :: ready => linear_mixture_parameters_ready
  end type linear_mixture_sensible_storage_parameters_t

  type, public :: linear_mixture_sensible_storage_change_t
    real(real64) :: capacity_start_j_cm3_k = 0.0_real64
    real(real64) :: capacity_end_j_cm3_k = 0.0_real64
    real(real64) :: capacity_average_j_cm3_k = 0.0_real64
    real(real64) :: exact_change_j_m2 = 0.0_real64
    real(real64) :: temperature_change_component_j_m2 = 0.0_real64
    real(real64) :: composition_change_component_j_m2 = 0.0_real64
    real(real64) :: decomposition_residual_j_m2 = 0.0_real64
  end type linear_mixture_sensible_storage_change_t

  public :: initialize_linear_mixture_sensible_storage_parameters
  public :: evaluate_mixture_heat_capacity
  public :: evaluate_sensible_storage
  public :: evaluate_sensible_storage_change

contains

  subroutine initialize_linear_mixture_sensible_storage_parameters(theta_sat, solid_heat_capacity_j_cm3_k, &
       liquid_heat_capacity_j_cm3_k, gas_heat_capacity_j_cm3_k, reference_temperature_c, parameters, status)
    real(real64), intent(in) :: theta_sat
    real(real64), intent(in) :: solid_heat_capacity_j_cm3_k
    real(real64), intent(in) :: liquid_heat_capacity_j_cm3_k
    real(real64), intent(in) :: gas_heat_capacity_j_cm3_k
    real(real64), intent(in) :: reference_temperature_c
    type(linear_mixture_sensible_storage_parameters_t), intent(out) :: parameters
    integer, intent(out) :: status

    parameters = linear_mixture_sensible_storage_parameters_t()
    status = LMSS_INVALID_PROPERTIES
    if (.not. ieee_is_finite(theta_sat) .or. theta_sat <= 0.0_real64 .or. theta_sat > 1.0_real64) return
    if (.not. ieee_is_finite(solid_heat_capacity_j_cm3_k) .or. solid_heat_capacity_j_cm3_k < 0.0_real64) return
    if (.not. ieee_is_finite(liquid_heat_capacity_j_cm3_k) .or. liquid_heat_capacity_j_cm3_k <= 0.0_real64) return
    if (.not. ieee_is_finite(gas_heat_capacity_j_cm3_k) .or. gas_heat_capacity_j_cm3_k < 0.0_real64) return
    if (.not. ieee_is_finite(reference_temperature_c)) return

    parameters%theta_sat = theta_sat
    parameters%solid_heat_capacity_j_cm3_k = solid_heat_capacity_j_cm3_k
    parameters%liquid_heat_capacity_j_cm3_k = liquid_heat_capacity_j_cm3_k
    parameters%gas_heat_capacity_j_cm3_k = gas_heat_capacity_j_cm3_k
    parameters%reference_temperature_c = reference_temperature_c
    parameters%initialized = .true.
    status = LMSS_OK
  end subroutine initialize_linear_mixture_sensible_storage_parameters

  logical function linear_mixture_parameters_ready(self) result(ready)
    class(linear_mixture_sensible_storage_parameters_t), intent(in) :: self
    ready = self%initialized .and. ieee_is_finite(self%theta_sat) .and. self%theta_sat > 0.0_real64 .and. &
            self%theta_sat <= 1.0_real64 .and. ieee_is_finite(self%solid_heat_capacity_j_cm3_k) .and. &
            self%solid_heat_capacity_j_cm3_k >= 0.0_real64 .and. &
            ieee_is_finite(self%liquid_heat_capacity_j_cm3_k) .and. self%liquid_heat_capacity_j_cm3_k > 0.0_real64 .and. &
            ieee_is_finite(self%gas_heat_capacity_j_cm3_k) .and. self%gas_heat_capacity_j_cm3_k >= 0.0_real64 .and. &
            ieee_is_finite(self%reference_temperature_c)
  end function linear_mixture_parameters_ready

  subroutine evaluate_mixture_heat_capacity(theta, parameters, heat_capacity_j_cm3_k, status)
    real(real64), intent(in) :: theta
    type(linear_mixture_sensible_storage_parameters_t), intent(in) :: parameters
    real(real64), intent(out) :: heat_capacity_j_cm3_k
    integer, intent(out) :: status
    real(real64) :: gas_fraction

    heat_capacity_j_cm3_k = 0.0_real64
    status = LMSS_INVALID_STATE
    if (.not. parameters%ready()) then
      status = LMSS_INVALID_PROPERTIES
      return
    end if
    if (.not. valid_theta(theta, parameters%theta_sat)) return

    gas_fraction = parameters%theta_sat - theta
    heat_capacity_j_cm3_k = parameters%solid_heat_capacity_j_cm3_k + &
         theta * parameters%liquid_heat_capacity_j_cm3_k + &
         gas_fraction * parameters%gas_heat_capacity_j_cm3_k
    if (.not. ieee_is_finite(heat_capacity_j_cm3_k) .or. heat_capacity_j_cm3_k <= 0.0_real64) return
    status = LMSS_OK
  end subroutine evaluate_mixture_heat_capacity

  subroutine evaluate_sensible_storage(dz_cm, theta, temperature_c, parameters, energy_j_m2, status)
    real(real64), intent(in) :: dz_cm, theta, temperature_c
    type(linear_mixture_sensible_storage_parameters_t), intent(in) :: parameters
    real(real64), intent(out) :: energy_j_m2
    integer, intent(out) :: status
    real(real64) :: heat_capacity_j_cm3_k

    energy_j_m2 = 0.0_real64
    status = LMSS_INVALID_STATE
    if (.not. ieee_is_finite(dz_cm) .or. dz_cm <= 0.0_real64) return
    if (.not. ieee_is_finite(temperature_c)) return
    call evaluate_mixture_heat_capacity(theta, parameters, heat_capacity_j_cm3_k, status)
    if (status /= LMSS_OK) return

    energy_j_m2 = 1.0e4_real64 * dz_cm * heat_capacity_j_cm3_k * &
         (temperature_c - parameters%reference_temperature_c)
    if (.not. ieee_is_finite(energy_j_m2)) then
      energy_j_m2 = 0.0_real64
      status = LMSS_INVALID_STATE
      return
    end if
    status = LMSS_OK
  end subroutine evaluate_sensible_storage

  subroutine evaluate_sensible_storage_change(dz_cm, theta_start, theta_end, temperature_start_c, &
       temperature_end_c, parameters, change, status)
    real(real64), intent(in) :: dz_cm, theta_start, theta_end, temperature_start_c, temperature_end_c
    type(linear_mixture_sensible_storage_parameters_t), intent(in) :: parameters
    type(linear_mixture_sensible_storage_change_t), intent(out) :: change
    integer, intent(out) :: status
    real(real64) :: storage_start_j_m2, storage_end_j_m2
    real(real64) :: theta_average, temperature_average_c, delta_theta, delta_temperature_c
    real(real64) :: capacity_slope_j_cm3_k

    change = linear_mixture_sensible_storage_change_t()
    status = LMSS_INVALID_STATE
    if (.not. ieee_is_finite(dz_cm) .or. dz_cm <= 0.0_real64) return
    if (.not. ieee_is_finite(temperature_start_c) .or. .not. ieee_is_finite(temperature_end_c)) return
    if (.not. valid_theta(theta_start, parameters%theta_sat) .or. &
        .not. valid_theta(theta_end, parameters%theta_sat)) return

    call evaluate_sensible_storage(dz_cm, theta_start, temperature_start_c, parameters, storage_start_j_m2, status)
    if (status /= LMSS_OK) return
    call evaluate_sensible_storage(dz_cm, theta_end, temperature_end_c, parameters, storage_end_j_m2, status)
    if (status /= LMSS_OK) return
    call evaluate_mixture_heat_capacity(theta_start, parameters, change%capacity_start_j_cm3_k, status)
    if (status /= LMSS_OK) return
    call evaluate_mixture_heat_capacity(theta_end, parameters, change%capacity_end_j_cm3_k, status)
    if (status /= LMSS_OK) return

    theta_average = 0.5_real64 * (theta_start + theta_end)
    temperature_average_c = 0.5_real64 * (temperature_start_c + temperature_end_c)
    delta_theta = theta_end - theta_start
    delta_temperature_c = temperature_end_c - temperature_start_c
    call evaluate_mixture_heat_capacity(theta_average, parameters, change%capacity_average_j_cm3_k, status)
    if (status /= LMSS_OK) return

    capacity_slope_j_cm3_k = parameters%liquid_heat_capacity_j_cm3_k - parameters%gas_heat_capacity_j_cm3_k
    change%exact_change_j_m2 = storage_end_j_m2 - storage_start_j_m2
    change%temperature_change_component_j_m2 = 1.0e4_real64 * dz_cm * change%capacity_average_j_cm3_k * &
         delta_temperature_c
    change%composition_change_component_j_m2 = 1.0e4_real64 * dz_cm * capacity_slope_j_cm3_k * &
         (temperature_average_c - parameters%reference_temperature_c) * delta_theta
    change%decomposition_residual_j_m2 = change%exact_change_j_m2 - &
         change%temperature_change_component_j_m2 - change%composition_change_component_j_m2

    if (.not. ieee_is_finite(change%exact_change_j_m2) .or. &
        .not. ieee_is_finite(change%temperature_change_component_j_m2) .or. &
        .not. ieee_is_finite(change%composition_change_component_j_m2) .or. &
        .not. ieee_is_finite(change%decomposition_residual_j_m2)) then
      change = linear_mixture_sensible_storage_change_t()
      status = LMSS_INVALID_STATE
      return
    end if
    status = LMSS_OK
  end subroutine evaluate_sensible_storage_change

  logical function valid_theta(theta, theta_sat) result(valid)
    real(real64), intent(in) :: theta, theta_sat
    valid = ieee_is_finite(theta) .and. theta >= 0.0_real64 .and. theta <= theta_sat
  end function valid_theta

end module mod_linear_mixture_sensible_storage
