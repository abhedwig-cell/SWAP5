module mod_ribasim_surface_water_profile_contract
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_fmr_runtime_core, only: FMR_OPTIONAL_STATE_LAYOUT_FIXED_WEIR_SURFACE_WATER
  use mod_fmr_drainage_response_binding, only: fmr_drainage_response_level_parameters_t, &
       fmr_drainage_response_level_control_t, FMR_DRAIN_VARIANT_EXTENDED_SIGNED
  implicit none
  private

  integer, parameter, public :: RIBASIM_SW_PROFILE_OK = 0
  integer, parameter, public :: RIBASIM_SW_PROFILE_OWNER_CONFLICT = 1
  integer, parameter, public :: RIBASIM_SW_PROFILE_DUPLICATE_CONTROL = 2
  integer, parameter, public :: RIBASIM_SW_PROFILE_SHAPE_MISMATCH = 3
  integer, parameter, public :: RIBASIM_SW_PROFILE_UNSUPPORTED_VARIANT = 4
  integer, parameter, public :: RIBASIM_SW_PROFILE_INVALID_ACCEPTED_HEAD = 5

  real(real64), parameter, public :: RIBASIM_SW_STTAB_EPSILON_M = 1.0e-5_real64
  character(len=*), parameter, public :: RIBASIM_SW_GIT_SHA = &
       'e7fc8ade52a4bedeec10e508d2065577f33eb76a'
  character(len=*), parameter, public :: RIBASIM_SW_CORE_VERSION = '2026.1.1'
  character(len=*), parameter, public :: RIBASIM_SW_PYTHON_VERSION_AT_PIN = '2026.1.0'

  public :: ribasim_surface_water_profile_status
  public :: bind_ribasim_surface_water_controls

contains

  integer function ribasim_surface_water_profile_status(optional_state_layout_id, parameters, accepted_heads_cm, &
       controls_already_supplied) result(status)
    integer, intent(in) :: optional_state_layout_id
    type(fmr_drainage_response_level_parameters_t), intent(in) :: parameters(:)
    real(real64), intent(in) :: accepted_heads_cm(:)
    logical, intent(in) :: controls_already_supplied
    integer :: i

    status = RIBASIM_SW_PROFILE_SHAPE_MISMATCH

    if (optional_state_layout_id == FMR_OPTIONAL_STATE_LAYOUT_FIXED_WEIR_SURFACE_WATER) then
      status = RIBASIM_SW_PROFILE_OWNER_CONFLICT
      return
    end if
    if (controls_already_supplied) then
      status = RIBASIM_SW_PROFILE_DUPLICATE_CONTROL
      return
    end if
    if (size(parameters) <= 0 .or. size(accepted_heads_cm) /= size(parameters)) return

    do i = 1, size(parameters)
      if (parameters(i)%variant /= FMR_DRAIN_VARIANT_EXTENDED_SIGNED) then
        status = RIBASIM_SW_PROFILE_UNSUPPORTED_VARIANT
        return
      end if
      if (.not. ieee_is_finite(accepted_heads_cm(i))) then
        status = RIBASIM_SW_PROFILE_INVALID_ACCEPTED_HEAD
        return
      end if
    end do

    status = RIBASIM_SW_PROFILE_OK
  end function ribasim_surface_water_profile_status

  subroutine bind_ribasim_surface_water_controls(optional_state_layout_id, parameters, accepted_heads_cm, &
       controls_already_supplied, controls, status)
    integer, intent(in) :: optional_state_layout_id
    type(fmr_drainage_response_level_parameters_t), intent(in) :: parameters(:)
    real(real64), intent(in) :: accepted_heads_cm(:)
    logical, intent(in) :: controls_already_supplied
    type(fmr_drainage_response_level_control_t), allocatable, intent(out) :: controls(:)
    integer, intent(out) :: status
    integer :: i

    status = ribasim_surface_water_profile_status(optional_state_layout_id, parameters, accepted_heads_cm, &
         controls_already_supplied)
    if (status /= RIBASIM_SW_PROFILE_OK) return

    allocate(controls(size(parameters)))
    do i = 1, size(parameters)
      controls(i)%drain_head_supplied = .false.
      controls(i)%drain_head = 0.0_real64
      controls(i)%resolved_surface_water_head_supplied = .true.
      controls(i)%resolved_surface_water_head_cm = accepted_heads_cm(i)
    end do
  end subroutine bind_ribasim_surface_water_controls

end module mod_ribasim_surface_water_profile_contract
