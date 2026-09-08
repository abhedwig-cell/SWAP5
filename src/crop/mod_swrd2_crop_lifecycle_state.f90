module mod_swrd2_crop_lifecycle_state
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_transaction_reference, only: transaction_state_t
  use mod_crop_lifecycle_state, only: crop_lifecycle_state_t, CROP_LIFECYCLE_STATE_OK
  implicit none
  private

  integer, parameter, public :: SWRD2_CROP_STATE_OK = 0
  integer, parameter, public :: SWRD2_CROP_STATE_INVALID_ACTUAL_DEPTH = 10
  integer, parameter, public :: SWRD2_CROP_STATE_INVALID_POTENTIAL_DEPTH = 11
  integer, parameter, public :: SWRD2_CROP_STATE_INVALID_DEPTH_ORDER = 12

  type, extends(crop_lifecycle_state_t), public :: swrd2_crop_lifecycle_state_t
    real(real64) :: actual_root_depth = 0.0_real64
    real(real64) :: potential_root_depth = 0.0_real64
  contains
    procedure :: clone => swrd2_crop_lifecycle_clone
    procedure, public :: validate => swrd2_crop_lifecycle_validate
  end type swrd2_crop_lifecycle_state_t

contains

  subroutine swrd2_crop_lifecycle_clone(self, copy)
    class(swrd2_crop_lifecycle_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy

    allocate(swrd2_crop_lifecycle_state_t :: copy)
    select type (typed_copy => copy)
    type is (swrd2_crop_lifecycle_state_t)
      typed_copy%crop_emerged = self%crop_emerged
      typed_copy%development_stage = self%development_stage
      typed_copy%leaf_area_index = self%leaf_area_index
      typed_copy%actual_root_depth = self%actual_root_depth
      typed_copy%potential_root_depth = self%potential_root_depth
    class default
      error stop 'SWRD2 crop lifecycle state: clone allocation failure'
    end select
  end subroutine swrd2_crop_lifecycle_clone

  integer function swrd2_crop_lifecycle_validate(self) result(status)
    class(swrd2_crop_lifecycle_state_t), intent(in) :: self

    status = self%crop_lifecycle_state_t%validate()
    if (status /= CROP_LIFECYCLE_STATE_OK) return

    if (.not. ieee_is_finite(self%actual_root_depth)) then
      status = SWRD2_CROP_STATE_INVALID_ACTUAL_DEPTH
      return
    end if
    if (self%actual_root_depth < 0.0_real64) then
      status = SWRD2_CROP_STATE_INVALID_ACTUAL_DEPTH
      return
    end if

    if (.not. ieee_is_finite(self%potential_root_depth)) then
      status = SWRD2_CROP_STATE_INVALID_POTENTIAL_DEPTH
      return
    end if
    if (self%potential_root_depth < 0.0_real64) then
      status = SWRD2_CROP_STATE_INVALID_POTENTIAL_DEPTH
      return
    end if

    if (self%actual_root_depth > self%potential_root_depth) then
      status = SWRD2_CROP_STATE_INVALID_DEPTH_ORDER
      return
    end if

    status = SWRD2_CROP_STATE_OK
  end function swrd2_crop_lifecycle_validate

end module mod_swrd2_crop_lifecycle_state
