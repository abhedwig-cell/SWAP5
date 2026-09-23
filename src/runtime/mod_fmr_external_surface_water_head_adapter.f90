module mod_fmr_external_surface_water_head_adapter
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_surface_water_ownership_profile, only: surface_water_ownership_profile_t, &
       validate_surface_water_ownership_profile, SURFACE_WATER_OWNER_EXTERNAL_RIBASIM, SURFACE_WATER_OWNERSHIP_OK
  use mod_fmr_drainage_response_binding, only: fmr_drainage_response_level_parameters_t, &
       fmr_drainage_response_level_control_t, FMR_DRAIN_VARIANT_EXTENDED_SIGNED
  implicit none
  private

  integer, parameter, public :: EXT_SW_HEAD_BIND_OK = 0
  integer, parameter, public :: EXT_SW_HEAD_BIND_INVALID_OWNER = 1
  integer, parameter, public :: EXT_SW_HEAD_BIND_UNACCEPTED_SNAPSHOT = 2
  integer, parameter, public :: EXT_SW_HEAD_BIND_SHAPE_MISMATCH = 3
  integer, parameter, public :: EXT_SW_HEAD_BIND_NONFINITE_HEAD = 4

  type, public :: external_surface_water_head_snapshot_t
    logical :: accepted = .false.
    integer :: accepted_revision = -1
    real(real64), allocatable :: head_cm_by_level(:)
  end type external_surface_water_head_snapshot_t

  public :: bind_external_surface_water_heads

contains

  subroutine bind_external_surface_water_heads(profile, snapshot, parameters, controls, status)
    type(surface_water_ownership_profile_t), intent(in) :: profile
    type(external_surface_water_head_snapshot_t), intent(in) :: snapshot
    type(fmr_drainage_response_level_parameters_t), intent(in) :: parameters(:)
    type(fmr_drainage_response_level_control_t), allocatable, intent(out) :: controls(:)
    integer, intent(out) :: status
    integer :: i

    status = EXT_SW_HEAD_BIND_INVALID_OWNER
    if (profile%owner /= SURFACE_WATER_OWNER_EXTERNAL_RIBASIM) return
    if (validate_surface_water_ownership_profile(profile) /= SURFACE_WATER_OWNERSHIP_OK) return

    status = EXT_SW_HEAD_BIND_UNACCEPTED_SNAPSHOT
    if (.not. snapshot%accepted .or. snapshot%accepted_revision < 0) return

    status = EXT_SW_HEAD_BIND_SHAPE_MISMATCH
    if (.not. allocated(snapshot%head_cm_by_level)) return
    if (size(snapshot%head_cm_by_level) /= size(parameters)) return

    allocate(controls(size(parameters)))
    controls = fmr_drainage_response_level_control_t()

    do i = 1, size(parameters)
      if (parameters(i)%variant == FMR_DRAIN_VARIANT_EXTENDED_SIGNED) then
        if (.not. ieee_is_finite(snapshot%head_cm_by_level(i))) then
          status = EXT_SW_HEAD_BIND_NONFINITE_HEAD
          deallocate(controls)
          return
        end if
        controls(i)%resolved_surface_water_head_supplied = .true.
        controls(i)%resolved_surface_water_head_cm = snapshot%head_cm_by_level(i)
      end if
    end do

    status = EXT_SW_HEAD_BIND_OK
  end subroutine bind_external_surface_water_heads

end module mod_fmr_external_surface_water_head_adapter
