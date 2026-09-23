! Proposed opt-in solver scratch. Not connected to production HeadCalc yet.
! Positive exchange enters the matrix. Never publishes accepted model state.
module mod_ppa_wu05a4_trial_exchange
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  type, public :: macro_trial_key
    integer(int64) :: lineage = 0, revision = -1, attempt = 0, evaluation = 0
  end type

  type, public :: macro_exchange_evaluation
    type(macro_trial_key) :: key
    real(real64) :: dt = 0
    real(real64), allocatable :: head(:), rate(:), derivative(:)
  end type

  type, public :: macro_used_exchange
    private
    logical :: valid = .false.
    type(macro_exchange_evaluation) :: used
  end type

  public :: apply_macro_residual, apply_macro_diagonal, copy_matrix_transfer, discard_macro_exchange

contains

  pure logical function same_key(a,b)
    type(macro_trial_key), intent(in) :: a,b
    same_key = a%lineage == b%lineage .and. a%revision == b%revision .and. &
      a%attempt == b%attempt .and. a%evaluation == b%evaluation
  end function

  pure logical function ready(e)
    type(macro_exchange_evaluation), intent(in) :: e
    integer :: n
    ready = .false.
    if (e%key%lineage <= 0 .or. e%key%revision < 0 .or. e%key%attempt <= 0 .or. e%key%evaluation <= 0) return
    if (.not. ieee_is_finite(e%dt)) return
    if (e%dt <= 0) return
    if (.not. allocated(e%head) .or. .not. allocated(e%rate) .or. .not. allocated(e%derivative)) return
    n = size(e%head)
    if (n < 1 .or. size(e%rate) /= n .or. size(e%derivative) /= n) return
    if (.not. all(ieee_is_finite(e%head))) return
    if (.not. all(ieee_is_finite(e%rate))) return
    if (.not. all(ieee_is_finite(e%derivative))) return
    ready = .true.
  end function

  pure logical function subtractable(a,b)
    real(real64), intent(in) :: a(:), b(:)
    integer :: i
    subtractable = .false.
    if (size(a) /= size(b)) return
    if (.not. all(ieee_is_finite(a))) return
    if (.not. all(ieee_is_finite(b))) return
    do i=1,size(a)
      if (b(i) > 0) then
        if (a(i) < -huge(1.0_real64)+b(i)) return
      else if (b(i) < 0) then
        if (a(i) > huge(1.0_real64)+b(i)) return
      end if
    end do
    subtractable = .true.
  end function

  subroutine discard_macro_exchange(slot)
    type(macro_used_exchange), intent(out) :: slot
    slot%valid = .false.
  end subroutine

  ! Source order: vector_F subtracts QExcMpMtx after constructing the matrix residual.
  ! Capture a deep copy only when the subtraction succeeds. A failed evaluation
  ! invalidates old scratch, so it cannot masquerade as the final used vector.
  subroutine apply_macro_residual(e, key, head, residual, slot, ok)
    type(macro_exchange_evaluation), intent(in) :: e
    type(macro_trial_key), intent(in) :: key
    real(real64), intent(in) :: head(:)
    real(real64), intent(inout) :: residual(:)
    type(macro_used_exchange), intent(out) :: slot
    logical, intent(out) :: ok
    ok = .false.
    if (.not. ready(e)) return
    if (.not. same_key(e%key,key)) return
    if (size(head) /= size(e%head)) return
    if (.not. all(ieee_is_finite(head))) return
    ! Exact evaluation identity, not a nonlinear convergence tolerance.
    if (any(head < e%head) .or. any(head > e%head)) return
    if (.not. subtractable(residual,e%rate)) return
    residual = residual-e%rate
    slot%used = e
    slot%valid = .true.
    ok = .true.
  end subroutine

  ! Use the derivative paired with the residual evaluation, not a later provider
  ! call. The caller supplies the source branch's derivative-enabled decision.
  subroutine apply_macro_diagonal(slot,key,enabled,diagonal,ok)
    type(macro_used_exchange), intent(in) :: slot
    type(macro_trial_key), intent(in) :: key
    logical, intent(in) :: enabled
    real(real64), intent(inout) :: diagonal(:)
    logical, intent(out) :: ok
    ok = .false.
    if (.not. slot%valid) return
    if (.not. same_key(slot%used%key,key)) return
    if (size(diagonal) /= size(slot%used%rate)) return
    if (.not. all(ieee_is_finite(diagonal))) return
    if (enabled) then
      if (.not. subtractable(diagonal,slot%used%derivative)) return
      diagonal = diagonal-slot%used%derivative
    end if
    ok = .true.
  end subroutine

  ! Candidate-only integrated transfer. Does not assert nonlinear convergence or
  ! authorize a commit. The owner must identify the accepted residual evaluation.
  subroutine copy_matrix_transfer(slot,key,amount,ok)
    type(macro_used_exchange), intent(in) :: slot
    type(macro_trial_key), intent(in) :: key
    real(real64), allocatable, intent(out) :: amount(:)
    logical, intent(out) :: ok
    ok = .false.
    if (.not. slot%valid) return
    if (.not. same_key(slot%used%key,key)) return
    if (slot%used%dt > 1.0_real64) then
      if (any(abs(slot%used%rate) > huge(1.0_real64)/slot%used%dt)) return
    end if
    amount = slot%used%rate*slot%used%dt
    ok = .true.
  end subroutine
end module
