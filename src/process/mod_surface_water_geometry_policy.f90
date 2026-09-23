module mod_surface_water_geometry_policy
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: SW_GEOMETRY_NONE = 0
  integer, parameter, public :: SW_GEOMETRY_LEGACY_STTAB_EPSILON = 1
  integer, parameter, public :: SW_GEOMETRY_RIBASIM_NATIVE = 2

  integer, parameter, public :: SW_GEOMETRY_POLICY_OK = 0
  integer, parameter, public :: SW_GEOMETRY_POLICY_MISSING = 1
  integer, parameter, public :: SW_GEOMETRY_POLICY_INVALID_EPSILON = 2
  integer, parameter, public :: SW_GEOMETRY_POLICY_INVALID_ERROR_BUDGET = 3
  integer, parameter, public :: SW_GEOMETRY_POLICY_NATIVE_ID_MISSING = 4

  type, public :: surface_water_geometry_policy_t
    integer :: mode = SW_GEOMETRY_NONE
    real(real64) :: transition_epsilon_m = 0.0_real64
    real(real64) :: declared_max_storage_error_m3_per_m2 = 0.0_real64
    character(len=64) :: native_geometry_contract_id = ''
  end type surface_water_geometry_policy_t

  public :: validate_surface_water_geometry_policy

contains

  pure logical function same_real_bits(a, b) result(same)
    real(real64), intent(in) :: a, b
    same = transfer(a, 0_int64) == transfer(b, 0_int64)
  end function same_real_bits

  integer function validate_surface_water_geometry_policy(policy) result(status)
    type(surface_water_geometry_policy_t), intent(in) :: policy

    select case (policy%mode)
    case (SW_GEOMETRY_LEGACY_STTAB_EPSILON)
      if (.not. ieee_is_finite(policy%transition_epsilon_m) .or. policy%transition_epsilon_m <= 0.0_real64) then
        status = SW_GEOMETRY_POLICY_INVALID_EPSILON
        return
      end if
      if (.not. ieee_is_finite(policy%declared_max_storage_error_m3_per_m2) .or. &
          policy%declared_max_storage_error_m3_per_m2 <= 0.0_real64) then
        status = SW_GEOMETRY_POLICY_INVALID_ERROR_BUDGET
        return
      end if
      if (len_trim(policy%native_geometry_contract_id) /= 0) then
        status = SW_GEOMETRY_POLICY_INVALID_ERROR_BUDGET
        return
      end if
      status = SW_GEOMETRY_POLICY_OK

    case (SW_GEOMETRY_RIBASIM_NATIVE)
      if (len_trim(policy%native_geometry_contract_id) == 0) then
        status = SW_GEOMETRY_POLICY_NATIVE_ID_MISSING
        return
      end if
      if (.not. same_real_bits(policy%transition_epsilon_m, 0.0_real64) .or. &
          .not. same_real_bits(policy%declared_max_storage_error_m3_per_m2, 0.0_real64)) then
        status = SW_GEOMETRY_POLICY_INVALID_ERROR_BUDGET
        return
      end if
      status = SW_GEOMETRY_POLICY_OK

    case default
      status = SW_GEOMETRY_POLICY_MISSING
    end select
  end function validate_surface_water_geometry_policy

end module mod_surface_water_geometry_policy
