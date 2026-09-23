module mod_ribasim_surface_water_profile
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_fmr_drainage_response_binding, only: fmr_drainage_response_level_control_t
  implicit none
  private

  integer, parameter, public :: RSW_PROFILE_OK = 0
  integer, parameter, public :: RSW_PROFILE_INVALID_MODE = 1
  integer, parameter, public :: RSW_PROFILE_DUPLICATE_OWNER = 2
  integer, parameter, public :: RSW_PROFILE_INVALID_GEOMETRY_EPSILON = 3
  integer, parameter, public :: RSW_PROFILE_UNQUALIFIED_NONLINEAR_PARITY = 4
  integer, parameter, public :: RSW_PROFILE_ACCEPT_WITH_CLIP_FORBIDDEN = 5
  integer, parameter, public :: RSW_PROFILE_UNACCEPTED_HEAD_VIEW = 6
  integer, parameter, public :: RSW_PROFILE_HEAD_SHAPE_MISMATCH = 7
  integer, parameter, public :: RSW_PROFILE_NONFINITE_HEAD = 8

  real(real64), parameter, public :: RSW_PROFILE_STORAGE_GEOMETRY_EPSILON_M = 1.0e-6_real64

  type, public :: ribasim_surface_water_profile_t
    logical :: external_ribasim_active = .true.
    logical :: internal_swap_fixed_weir_state_active = .false.
    logical :: exact_nonlinear_swqhr1_parity_required = .false.
    logical :: accept_with_clip_allowed = .false.
    real(real64) :: storage_geometry_epsilon_m = RSW_PROFILE_STORAGE_GEOMETRY_EPSILON_M
  end type ribasim_surface_water_profile_t

  type, public :: accepted_ribasim_surface_water_head_view_t
    logical :: accepted = .false.
    integer(int64) :: accepted_revision = -1_int64
    real(real64) :: accepted_time = 0.0_real64
    real(real64), allocatable :: level_head_cm(:)
  end type accepted_ribasim_surface_water_head_view_t

  public :: validate_ribasim_surface_water_profile
  public :: validate_accepted_ribasim_head_view
  public :: bind_accepted_ribasim_heads

contains

  integer function validate_ribasim_surface_water_profile(profile) result(status)
    type(ribasim_surface_water_profile_t), intent(in) :: profile

    status = RSW_PROFILE_INVALID_MODE
    if (.not. profile%external_ribasim_active) return
    if (profile%internal_swap_fixed_weir_state_active) then
      status = RSW_PROFILE_DUPLICATE_OWNER
      return
    end if
    if (.not. ieee_is_finite(profile%storage_geometry_epsilon_m) .or. &
        profile%storage_geometry_epsilon_m /= RSW_PROFILE_STORAGE_GEOMETRY_EPSILON_M) then
      status = RSW_PROFILE_INVALID_GEOMETRY_EPSILON
      return
    end if
    if (profile%exact_nonlinear_swqhr1_parity_required) then
      status = RSW_PROFILE_UNQUALIFIED_NONLINEAR_PARITY
      return
    end if
    if (profile%accept_with_clip_allowed) then
      status = RSW_PROFILE_ACCEPT_WITH_CLIP_FORBIDDEN
      return
    end if
    status = RSW_PROFILE_OK
  end function validate_ribasim_surface_water_profile

  integer function validate_accepted_ribasim_head_view(view, expected_levels) result(status)
    type(accepted_ribasim_surface_water_head_view_t), intent(in) :: view
    integer, intent(in) :: expected_levels
    integer :: i

    status = RSW_PROFILE_UNACCEPTED_HEAD_VIEW
    if (.not. view%accepted .or. view%accepted_revision < 0_int64 .or. &
        .not. ieee_is_finite(view%accepted_time)) return
    if (.not. allocated(view%level_head_cm) .or. expected_levels <= 0 .or. &
        size(view%level_head_cm) /= expected_levels) then
      status = RSW_PROFILE_HEAD_SHAPE_MISMATCH
      return
    end if
    do i = 1, size(view%level_head_cm)
      if (.not. ieee_is_finite(view%level_head_cm(i))) then
        status = RSW_PROFILE_NONFINITE_HEAD
        return
      end if
    end do
    status = RSW_PROFILE_OK
  end function validate_accepted_ribasim_head_view

  subroutine bind_accepted_ribasim_heads(profile, view, controls, status)
    type(ribasim_surface_water_profile_t), intent(in) :: profile
    type(accepted_ribasim_surface_water_head_view_t), intent(in) :: view
    type(fmr_drainage_response_level_control_t), intent(out) :: controls(:)
    integer, intent(out) :: status
    integer :: i

    controls = fmr_drainage_response_level_control_t()
    status = validate_ribasim_surface_water_profile(profile)
    if (status /= RSW_PROFILE_OK) return
    status = validate_accepted_ribasim_head_view(view, size(controls))
    if (status /= RSW_PROFILE_OK) return

    do i = 1, size(controls)
      controls(i)%drain_head_supplied = .false.
      controls(i)%resolved_surface_water_head_supplied = .true.
      controls(i)%resolved_surface_water_head_cm = view%level_head_cm(i)
    end do
  end subroutine bind_accepted_ribasim_heads

end module mod_ribasim_surface_water_profile
