module mod_wofost81_crop_owner_state
  use mod_transaction_reference, only: transaction_state_t
  use mod_wofost_crop_owner_state, only: wofost_crop_owner_state_t, WOFOST_CROP_OWNER_OK
  use mod_wofost81_n_owner_state, only: wofost81_n_owner_state_t, WOFOST81_N_OWNER_OK
  implicit none
  private

  integer, parameter, public :: WOFOST81_CROP_OWNER_OK = 0
  integer, parameter, public :: WOFOST81_CROP_OWNER_INVALID_CROP_STATE = 1
  integer, parameter, public :: WOFOST81_CROP_OWNER_INVALID_N_STATE = 2

  type, extends(transaction_state_t), public :: wofost81_crop_owner_state_t
    type(wofost_crop_owner_state_t) :: crop
    type(wofost81_n_owner_state_t) :: nitrogen
  contains
    procedure :: clone => clone_wofost81_crop_owner_state
    procedure, public :: validate => validate_wofost81_crop_owner_state
  end type wofost81_crop_owner_state_t

contains

  subroutine clone_wofost81_crop_owner_state(self, copy)
    class(wofost81_crop_owner_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(wofost81_crop_owner_state_t :: copy)
    select type (typed_copy => copy)
    type is (wofost81_crop_owner_state_t)
      typed_copy%crop = self%crop
      typed_copy%nitrogen = self%nitrogen
    class default
      error stop 'WOFOST81 crop owner state: clone allocation failure'
    end select
  end subroutine clone_wofost81_crop_owner_state

  integer function validate_wofost81_crop_owner_state(self) result(status)
    class(wofost81_crop_owner_state_t), intent(in) :: self
    status = WOFOST81_CROP_OWNER_INVALID_CROP_STATE
    if (self%crop%validate() /= WOFOST_CROP_OWNER_OK) return
    status = WOFOST81_CROP_OWNER_INVALID_N_STATE
    if (self%nitrogen%validate() /= WOFOST81_N_OWNER_OK) return
    status = WOFOST81_CROP_OWNER_OK
  end function validate_wofost81_crop_owner_state

end module mod_wofost81_crop_owner_state
