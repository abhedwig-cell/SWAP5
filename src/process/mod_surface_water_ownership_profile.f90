module mod_surface_water_ownership_profile
  implicit none
  private

  integer, parameter, public :: SURFACE_WATER_OWNER_NONE = 0
  integer, parameter, public :: SURFACE_WATER_OWNER_SWAP_FIXED_WEIR = 1
  integer, parameter, public :: SURFACE_WATER_OWNER_EXTERNAL_RIBASIM = 2

  integer, parameter, public :: SURFACE_WATER_OWNERSHIP_OK = 0
  integer, parameter, public :: SURFACE_WATER_OWNERSHIP_INVALID_MODE = 1
  integer, parameter, public :: SURFACE_WATER_OWNERSHIP_DUPLICATE_STATE_OWNER = 2
  integer, parameter, public :: SURFACE_WATER_OWNERSHIP_EXTERNAL_HEAD_MISSING = 3
  integer, parameter, public :: SURFACE_WATER_OWNERSHIP_INTERNAL_STATE_FORBIDDEN = 4

  type, public :: surface_water_ownership_profile_t
    integer :: owner = SURFACE_WATER_OWNER_NONE
    logical :: internal_fixed_weir_state_active = .false.
    logical :: external_surface_water_head_available = .false.
  end type surface_water_ownership_profile_t

  public :: validate_surface_water_ownership_profile

contains

  integer function validate_surface_water_ownership_profile(profile) result(status)
    type(surface_water_ownership_profile_t), intent(in) :: profile

    status = SURFACE_WATER_OWNERSHIP_INVALID_MODE
    select case (profile%owner)
    case (SURFACE_WATER_OWNER_NONE)
      if (profile%internal_fixed_weir_state_active) then
        status = SURFACE_WATER_OWNERSHIP_INVALID_MODE
      else
        status = SURFACE_WATER_OWNERSHIP_OK
      end if

    case (SURFACE_WATER_OWNER_SWAP_FIXED_WEIR)
      if (.not. profile%internal_fixed_weir_state_active) then
        status = SURFACE_WATER_OWNERSHIP_INVALID_MODE
      else if (profile%external_surface_water_head_available) then
        status = SURFACE_WATER_OWNERSHIP_DUPLICATE_STATE_OWNER
      else
        status = SURFACE_WATER_OWNERSHIP_OK
      end if

    case (SURFACE_WATER_OWNER_EXTERNAL_RIBASIM)
      if (profile%internal_fixed_weir_state_active) then
        status = SURFACE_WATER_OWNERSHIP_INTERNAL_STATE_FORBIDDEN
      else if (.not. profile%external_surface_water_head_available) then
        status = SURFACE_WATER_OWNERSHIP_EXTERNAL_HEAD_MISSING
      else
        status = SURFACE_WATER_OWNERSHIP_OK
      end if

    case default
      status = SURFACE_WATER_OWNERSHIP_INVALID_MODE
    end select
  end function validate_surface_water_ownership_profile

end module mod_surface_water_ownership_profile
