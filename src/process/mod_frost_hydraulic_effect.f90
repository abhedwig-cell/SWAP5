module mod_frost_hydraulic_effect
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: FROST_EFFECT_OK = 0
  integer, parameter, public :: FROST_EFFECT_INVALID_CONFIGURATION = 1
  integer, parameter, public :: FROST_EFFECT_INVALID_TEMPERATURE = 2
  integer, parameter, public :: FROST_EFFECT_INVALID_SHAPE = 3
  integer, parameter, public :: FROST_EFFECT_INVALID_HYDRAULICS = 4
  real(real64), parameter, public :: FROST_LEGACY_RESIDUAL_K_CM_PER_DAY = 1.0e-10_real64

  type, public :: frost_hydraulic_parameters_t
    logical :: active = .false.
    real(real64) :: reduction_start_c = 0.0_real64
    real(real64) :: reduction_end_c = 0.0_real64
  contains
    procedure, public :: valid => frost_hydraulic_parameters_valid
  end type frost_hydraulic_parameters_t

  public :: initialize_frost_hydraulic_parameters
  public :: evaluate_frost_hydraulic_factor
  public :: apply_frost_hydraulic_conductivity

contains

  subroutine initialize_frost_hydraulic_parameters(start_c, end_c, parameters, status)
    real(real64), intent(in) :: start_c, end_c
    type(frost_hydraulic_parameters_t), intent(out) :: parameters
    integer, intent(out) :: status

    parameters = frost_hydraulic_parameters_t()
    status = FROST_EFFECT_INVALID_CONFIGURATION
    if (.not. ieee_is_finite(start_c) .or. .not. ieee_is_finite(end_c)) return
    if (start_c <= end_c) return
    parameters%active = .true.
    parameters%reduction_start_c = start_c
    parameters%reduction_end_c = end_c
    status = FROST_EFFECT_OK
  end subroutine initialize_frost_hydraulic_parameters

  pure logical function frost_hydraulic_parameters_valid(self) result(ok)
    class(frost_hydraulic_parameters_t), intent(in) :: self
    ok = .true.
    if (.not. self%active) return
    ok = ieee_is_finite(self%reduction_start_c) .and. ieee_is_finite(self%reduction_end_c) .and. &
         self%reduction_start_c > self%reduction_end_c
  end function frost_hydraulic_parameters_valid

  subroutine evaluate_frost_hydraulic_factor(parameters, temperature_c, factor, status)
    type(frost_hydraulic_parameters_t), intent(in) :: parameters
    real(real64), intent(in) :: temperature_c(:)
    real(real64), intent(out) :: factor(:)
    integer, intent(out) :: status
    integer :: i

    factor = 1.0_real64
    status = FROST_EFFECT_INVALID_CONFIGURATION
    if (.not. parameters%valid()) return
    if (size(factor) /= size(temperature_c)) then
      status = FROST_EFFECT_INVALID_SHAPE
      return
    end if
    if (.not. parameters%active) then
      status = FROST_EFFECT_OK
      return
    end if
    do i = 1, size(temperature_c)
      if (.not. ieee_is_finite(temperature_c(i))) then
        factor = 1.0_real64
        status = FROST_EFFECT_INVALID_TEMPERATURE
        return
      end if
      if (temperature_c(i) >= parameters%reduction_start_c) then
        factor(i) = 1.0_real64
      else if (temperature_c(i) <= parameters%reduction_end_c) then
        factor(i) = 0.0_real64
      else
        factor(i) = (temperature_c(i) - parameters%reduction_end_c) / &
             (parameters%reduction_start_c - parameters%reduction_end_c)
      end if
    end do
    status = FROST_EFFECT_OK
  end subroutine evaluate_frost_hydraulic_factor

  subroutine apply_frost_hydraulic_conductivity(factor, conductivity, dconductivity_dhead, status)
    real(real64), intent(in) :: factor(:)
    real(real64), intent(inout) :: conductivity(:), dconductivity_dhead(:)
    integer, intent(out) :: status
    integer :: i, n

    status = FROST_EFFECT_INVALID_SHAPE
    n = size(factor)
    if (size(conductivity) /= n .or. size(dconductivity_dhead) /= n) return
    status = FROST_EFFECT_INVALID_HYDRAULICS
    do i = 1, n
      if (.not. ieee_is_finite(factor(i)) .or. factor(i) < 0.0_real64 .or. factor(i) > 1.0_real64) return
      if (.not. ieee_is_finite(conductivity(i)) .or. conductivity(i) < 0.0_real64 .or. &
          .not. ieee_is_finite(dconductivity_dhead(i))) return
    end do
    conductivity = conductivity * factor + FROST_LEGACY_RESIDUAL_K_CM_PER_DAY * (1.0_real64 - factor)
    dconductivity_dhead = dconductivity_dhead * factor
    status = FROST_EFFECT_OK
  end subroutine apply_frost_hydraulic_conductivity

end module mod_frost_hydraulic_effect
