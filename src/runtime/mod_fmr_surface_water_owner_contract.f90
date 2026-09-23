module mod_fmr_surface_water_owner_contract
  use, intrinsic :: iso_fortran_env, only: int64
  use mod_fmr_runtime_core, only: FMR_OPTIONAL_STATE_LAYOUT_FIXED_WEIR_SURFACE_WATER
  implicit none
  private

  integer, parameter, public :: FMR_SURFACE_OWNER_NONE = 0
  integer, parameter, public :: FMR_SURFACE_OWNER_SWAP_FIXED_WEIR = 1
  integer, parameter, public :: FMR_SURFACE_OWNER_EXTERNAL_RIBASIM = 2

  integer, parameter, public :: FMR_SURFACE_OWNER_OK = 0
  integer, parameter, public :: FMR_SURFACE_OWNER_INVALID_MODE = 1
  integer, parameter, public :: FMR_SURFACE_OWNER_CONFLICT = 2
  integer, parameter, public :: FMR_SURFACE_OWNER_LAYOUT_MISMATCH = 3

  public :: fmr_surface_water_owner_status
  public :: fmr_surface_water_owner_valid

contains

  pure integer function fmr_surface_water_owner_status(owner_mode, optional_state_layout_id) result(status)
    integer, intent(in) :: owner_mode
    integer(int64), intent(in) :: optional_state_layout_id
    logical :: has_internal_fixed_weir_state

    has_internal_fixed_weir_state = &
         optional_state_layout_id == FMR_OPTIONAL_STATE_LAYOUT_FIXED_WEIR_SURFACE_WATER

    select case (owner_mode)
    case (FMR_SURFACE_OWNER_NONE)
      if (has_internal_fixed_weir_state) then
        status = FMR_SURFACE_OWNER_LAYOUT_MISMATCH
      else
        status = FMR_SURFACE_OWNER_OK
      end if
    case (FMR_SURFACE_OWNER_SWAP_FIXED_WEIR)
      if (has_internal_fixed_weir_state) then
        status = FMR_SURFACE_OWNER_OK
      else
        status = FMR_SURFACE_OWNER_LAYOUT_MISMATCH
      end if
    case (FMR_SURFACE_OWNER_EXTERNAL_RIBASIM)
      if (has_internal_fixed_weir_state) then
        status = FMR_SURFACE_OWNER_CONFLICT
      else
        status = FMR_SURFACE_OWNER_OK
      end if
    case default
      status = FMR_SURFACE_OWNER_INVALID_MODE
    end select
  end function fmr_surface_water_owner_status

  pure logical function fmr_surface_water_owner_valid(owner_mode, optional_state_layout_id) result(valid)
    integer, intent(in) :: owner_mode
    integer(int64), intent(in) :: optional_state_layout_id
    valid = fmr_surface_water_owner_status(owner_mode, optional_state_layout_id) == FMR_SURFACE_OWNER_OK
  end function fmr_surface_water_owner_valid

end module mod_fmr_surface_water_owner_contract
