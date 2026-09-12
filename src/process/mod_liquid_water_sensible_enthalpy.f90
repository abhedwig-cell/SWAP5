module mod_liquid_water_sensible_enthalpy
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: LWSE_OK = 0
  integer, parameter, public :: LWSE_INVALID_PROPERTIES = 1
  integer, parameter, public :: LWSE_INVALID_STORAGE_INPUT = 2
  integer, parameter, public :: LWSE_INVALID_TRANSPORT_INPUT = 3

  real(real64), parameter :: CM_TO_M = 0.01_real64

  type, public :: liquid_water_sensible_enthalpy_parameters_t
    real(real64) :: density_kg_m3 = 0.0_real64
    real(real64) :: specific_heat_j_kg_k = 0.0_real64
    real(real64) :: reference_temperature_c = 0.0_real64
    logical :: initialized = .false.
  contains
    procedure, public :: ready => liquid_water_sensible_enthalpy_parameters_ready
  end type liquid_water_sensible_enthalpy_parameters_t

  type, public :: liquid_water_storage_change_t
    real(real64) :: exact_change_j_m2 = 0.0_real64
    real(real64) :: temperature_change_component_j_m2 = 0.0_real64
    real(real64) :: water_content_change_component_j_m2 = 0.0_real64
    real(real64) :: decomposition_residual_j_m2 = 0.0_real64
  end type liquid_water_storage_change_t

  public :: initialize_liquid_water_sensible_enthalpy_parameters
  public :: liquid_water_sensible_storage_j_m2
  public :: evaluate_liquid_water_storage_change
  public :: evaluate_liquid_water_sensible_transport

contains

  subroutine initialize_liquid_water_sensible_enthalpy_parameters(density_kg_m3, specific_heat_j_kg_k, &
       reference_temperature_c, parameters, status)
    real(real64), intent(in) :: density_kg_m3
    real(real64), intent(in) :: specific_heat_j_kg_k
    real(real64), intent(in) :: reference_temperature_c
    type(liquid_water_sensible_enthalpy_parameters_t), intent(out) :: parameters
    integer, intent(out) :: status

    parameters = liquid_water_sensible_enthalpy_parameters_t()
    status = LWSE_INVALID_PROPERTIES
    if (.not. ieee_is_finite(density_kg_m3) .or. density_kg_m3 <= 0.0_real64) return
    if (.not. ieee_is_finite(specific_heat_j_kg_k) .or. specific_heat_j_kg_k <= 0.0_real64) return
    if (.not. ieee_is_finite(reference_temperature_c)) return

    parameters%density_kg_m3 = density_kg_m3
    parameters%specific_heat_j_kg_k = specific_heat_j_kg_k
    parameters%reference_temperature_c = reference_temperature_c
    parameters%initialized = .true.
    status = LWSE_OK
  end subroutine initialize_liquid_water_sensible_enthalpy_parameters

  logical function liquid_water_sensible_enthalpy_parameters_ready(self) result(ready)
    class(liquid_water_sensible_enthalpy_parameters_t), intent(in) :: self

    ready = self%initialized
    if (.not. ready) return
    ready = ieee_is_finite(self%density_kg_m3) .and. self%density_kg_m3 > 0.0_real64 .and. &
            ieee_is_finite(self%specific_heat_j_kg_k) .and. self%specific_heat_j_kg_k > 0.0_real64 .and. &
            ieee_is_finite(self%reference_temperature_c)
  end function liquid_water_sensible_enthalpy_parameters_ready

  subroutine liquid_water_sensible_storage_j_m2(water_depth_cm, temperature_c, parameters, energy_j_m2, status)
    real(real64), intent(in) :: water_depth_cm
    real(real64), intent(in) :: temperature_c
    type(liquid_water_sensible_enthalpy_parameters_t), intent(in) :: parameters
    real(real64), intent(out) :: energy_j_m2
    integer, intent(out) :: status
    real(real64) :: capacity_per_cm_j_m2_k

    energy_j_m2 = 0.0_real64
    status = LWSE_INVALID_STORAGE_INPUT
    if (.not. parameters%ready()) then
      status = LWSE_INVALID_PROPERTIES
      return
    end if
    if (.not. ieee_is_finite(water_depth_cm) .or. water_depth_cm < 0.0_real64) return
    if (.not. ieee_is_finite(temperature_c)) return

    capacity_per_cm_j_m2_k = CM_TO_M * parameters%density_kg_m3 * parameters%specific_heat_j_kg_k
    energy_j_m2 = capacity_per_cm_j_m2_k * water_depth_cm * &
         (temperature_c - parameters%reference_temperature_c)
    if (.not. ieee_is_finite(energy_j_m2)) return
    status = LWSE_OK
  end subroutine liquid_water_sensible_storage_j_m2

  subroutine evaluate_liquid_water_storage_change(dz_cm, theta_start, theta_end, temperature_start_c, &
       temperature_end_c, parameters, result, status)
    real(real64), intent(in) :: dz_cm
    real(real64), intent(in) :: theta_start
    real(real64), intent(in) :: theta_end
    real(real64), intent(in) :: temperature_start_c
    real(real64), intent(in) :: temperature_end_c
    type(liquid_water_sensible_enthalpy_parameters_t), intent(in) :: parameters
    type(liquid_water_storage_change_t), intent(out) :: result
    integer, intent(out) :: status
    real(real64) :: coefficient_j_m2_k, theta_average, temperature_average_c

    result = liquid_water_storage_change_t()
    status = LWSE_INVALID_STORAGE_INPUT
    if (.not. parameters%ready()) then
      status = LWSE_INVALID_PROPERTIES
      return
    end if
    if (.not. ieee_is_finite(dz_cm) .or. dz_cm <= 0.0_real64) return
    if (.not. ieee_is_finite(theta_start) .or. theta_start < 0.0_real64 .or. theta_start > 1.0_real64) return
    if (.not. ieee_is_finite(theta_end) .or. theta_end < 0.0_real64 .or. theta_end > 1.0_real64) return
    if (.not. ieee_is_finite(temperature_start_c) .or. .not. ieee_is_finite(temperature_end_c)) return

    coefficient_j_m2_k = CM_TO_M * parameters%density_kg_m3 * parameters%specific_heat_j_kg_k * dz_cm
    theta_average = 0.5_real64 * (theta_start + theta_end)
    temperature_average_c = 0.5_real64 * (temperature_start_c + temperature_end_c)

    result%exact_change_j_m2 = coefficient_j_m2_k * &
         (theta_end * (temperature_end_c - parameters%reference_temperature_c) - &
          theta_start * (temperature_start_c - parameters%reference_temperature_c))
    result%temperature_change_component_j_m2 = coefficient_j_m2_k * theta_average * &
         (temperature_end_c - temperature_start_c)
    result%water_content_change_component_j_m2 = coefficient_j_m2_k * &
         (temperature_average_c - parameters%reference_temperature_c) * (theta_end - theta_start)
    result%decomposition_residual_j_m2 = result%exact_change_j_m2 - &
         result%temperature_change_component_j_m2 - result%water_content_change_component_j_m2

    if (.not. ieee_is_finite(result%exact_change_j_m2)) return
    if (.not. ieee_is_finite(result%temperature_change_component_j_m2)) return
    if (.not. ieee_is_finite(result%water_content_change_component_j_m2)) return
    if (.not. ieee_is_finite(result%decomposition_residual_j_m2)) return
    status = LWSE_OK
  end subroutine evaluate_liquid_water_storage_change

  subroutine evaluate_liquid_water_sensible_transport(oriented_transport_cm, advected_temperature_c, &
       parameters, energy_transport_j_m2, status)
    real(real64), intent(in) :: oriented_transport_cm
    real(real64), intent(in) :: advected_temperature_c
    type(liquid_water_sensible_enthalpy_parameters_t), intent(in) :: parameters
    real(real64), intent(out) :: energy_transport_j_m2
    integer, intent(out) :: status
    real(real64) :: capacity_per_cm_j_m2_k

    energy_transport_j_m2 = 0.0_real64
    status = LWSE_INVALID_TRANSPORT_INPUT
    if (.not. parameters%ready()) then
      status = LWSE_INVALID_PROPERTIES
      return
    end if
    if (.not. ieee_is_finite(oriented_transport_cm)) return
    if (.not. ieee_is_finite(advected_temperature_c)) return

    ! The sign/orientation belongs to the supplied water transport.  EB-I04
    ! does not infer a donor temperature or silently upwind from soil state.
    capacity_per_cm_j_m2_k = CM_TO_M * parameters%density_kg_m3 * parameters%specific_heat_j_kg_k
    energy_transport_j_m2 = capacity_per_cm_j_m2_k * oriented_transport_cm * &
         (advected_temperature_c - parameters%reference_temperature_c)
    if (.not. ieee_is_finite(energy_transport_j_m2)) return
    status = LWSE_OK
  end subroutine evaluate_liquid_water_sensible_transport

end module mod_liquid_water_sensible_enthalpy
