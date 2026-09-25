! Candidate carrier only: not registered for production dispatch or restart.
module mod_ppa_irrigation_event_state
  use mod_transaction_reference, only: transaction_state_t
  use mod_fmr_serialized_reference_backend, only: fmr_b110_temporal_indicator_state_t
  use mod_irrigation_process, only: irrigation_state_t
  implicit none
  private
  public :: ppa_irrigation_event_state_t

  type, extends(fmr_b110_temporal_indicator_state_t) :: ppa_irrigation_event_state_t
    type(irrigation_state_t) :: irrigation
  contains
    procedure :: clone => clone_irrigation_event_state
  end type
contains
  subroutine clone_irrigation_event_state(self,copy)
    class(ppa_irrigation_event_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    ! Intrinsic sourced allocation retains inherited private temporal history,
    ! dynamic type and deep copies of allocatable physical arrays.
    allocate(copy,source=self)
  end subroutine
end module
