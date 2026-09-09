module mod_fkt_temporal_indicator_history
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: real64
  implicit none
  private

  ! F-KT-owned lifecycle carrier for model-owned temporal continuation data.
  ! The payload is deliberately not physical state and never participates in
  ! storage or mass accounting.  It is embedded only by optional state layouts
  ! that need accepted-step derivative history.
  type, public :: fkt_temporal_indicator_history_t
    private
    real(real64), allocatable :: previous_right_derivative(:)
  contains
    procedure, public :: available => fkt_history_available
    procedure, public :: size => fkt_history_size
    procedure, public :: replace => fkt_history_replace
    procedure, public :: snapshot => fkt_history_snapshot
    procedure, public :: clear => fkt_history_clear
  end type fkt_temporal_indicator_history_t

contains

  logical function fkt_history_available(self, expected_size) result(ok)
    class(fkt_temporal_indicator_history_t), intent(in) :: self
    integer, intent(in), optional :: expected_size

    ok = allocated(self%previous_right_derivative)
    if (.not. ok) return
    ok = size(self%previous_right_derivative) > 0 .and. &
         all(ieee_is_finite(self%previous_right_derivative))
    if (ok .and. present(expected_size)) ok = expected_size > 0 .and. &
         size(self%previous_right_derivative) == expected_size
  end function fkt_history_available

  integer function fkt_history_size(self) result(n)
    class(fkt_temporal_indicator_history_t), intent(in) :: self
    if (allocated(self%previous_right_derivative)) then
      n = size(self%previous_right_derivative)
    else
      n = 0
    end if
  end function fkt_history_size

  subroutine fkt_history_replace(self, derivative, ok)
    class(fkt_temporal_indicator_history_t), intent(inout) :: self
    real(real64), intent(in) :: derivative(:)
    logical, intent(out) :: ok

    ok = size(derivative) > 0 .and. all(ieee_is_finite(derivative))
    if (.not. ok) return
    if (allocated(self%previous_right_derivative)) deallocate(self%previous_right_derivative)
    allocate(self%previous_right_derivative(size(derivative)))
    self%previous_right_derivative = derivative
  end subroutine fkt_history_replace

  subroutine fkt_history_snapshot(self, derivative, available)
    class(fkt_temporal_indicator_history_t), intent(in) :: self
    real(real64), allocatable, intent(out) :: derivative(:)
    logical, intent(out) :: available

    available = self%available()
    if (.not. available) return
    allocate(derivative(size(self%previous_right_derivative)))
    derivative = self%previous_right_derivative
  end subroutine fkt_history_snapshot

  subroutine fkt_history_clear(self)
    class(fkt_temporal_indicator_history_t), intent(inout) :: self
    if (allocated(self%previous_right_derivative)) deallocate(self%previous_right_derivative)
  end subroutine fkt_history_clear

end module mod_fkt_temporal_indicator_history
