module mod_crop_lifecycle_state
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_transaction_reference, only: transaction_state_t
  implicit none
  private

  integer, parameter, public :: CROP_LIFECYCLE_STATE_OK = 0
  integer, parameter, public :: CROP_LIFECYCLE_STATE_INVALID_DVS = 1
  integer, parameter, public :: CROP_LIFECYCLE_STATE_INVALID_LAI = 2

  type, extends(transaction_state_t), public :: crop_lifecycle_state_t
    logical :: crop_emerged = .false.
    real(real64) :: development_stage = 0.0_real64
    real(real64) :: leaf_area_index = 0.0_real64
  contains
    procedure :: clone => crop_lifecycle_clone
    procedure, public :: validate => crop_lifecycle_validate
  end type crop_lifecycle_state_t

contains

  subroutine crop_lifecycle_clone(self, copy)
    class(crop_lifecycle_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy

    allocate(crop_lifecycle_state_t :: copy)
    select type (typed_copy => copy)
    type is (crop_lifecycle_state_t)
      typed_copy%crop_emerged = self%crop_emerged
      typed_copy%development_stage = self%development_stage
      typed_copy%leaf_area_index = self%leaf_area_index
    class default
      error stop 'crop lifecycle state: clone allocation failure'
    end select
  end subroutine crop_lifecycle_clone

  integer function crop_lifecycle_validate(self) result(status)
    class(crop_lifecycle_state_t), intent(in) :: self

    status = CROP_LIFECYCLE_STATE_OK

    if (.not. ieee_is_finite(self%development_stage)) then
      status = CROP_LIFECYCLE_STATE_INVALID_DVS
      return
    end if

    if (.not. ieee_is_finite(self%leaf_area_index)) then
      status = CROP_LIFECYCLE_STATE_INVALID_LAI
      return
    end if
    if (self%leaf_area_index < 0.0_real64) then
      status = CROP_LIFECYCLE_STATE_INVALID_LAI
      return
    end if
  end function crop_lifecycle_validate

end module mod_crop_lifecycle_state
