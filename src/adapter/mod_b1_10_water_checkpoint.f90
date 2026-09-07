module mod_b1_10_water_checkpoint
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_canonical_contracts, only: canonical_state_t
  use mod_transaction_reference, only: transaction_state_t
  use MOD_grid, only: numnod
  use variables, only: h, theta, hm1, thetm1, pond, pondm1, gwl, gwlm1, &
                       volact, ldwet, spev, saev
  implicit none
  private

  type, extends(canonical_state_t), public :: b1_10_water_state_t
    real(real64), allocatable :: h(:)
    real(real64), allocatable :: theta(:)
    real(real64), allocatable :: hm1(:)
    real(real64), allocatable :: thetm1(:)
    real(real64) :: pond = 0.0_real64
    real(real64) :: pondm1 = 0.0_real64
    real(real64) :: gwl = 0.0_real64
    real(real64) :: gwlm1 = 0.0_real64
    real(real64) :: volact = 0.0_real64
    real(real64) :: ldwet = 0.0_real64
    real(real64) :: spev = 0.0_real64
    real(real64) :: saev = 0.0_real64
  contains
    procedure :: clone => b1_10_water_clone
  end type b1_10_water_state_t

  public :: capture_b1_10_water_state, restore_b1_10_water_state

contains

  subroutine ensure_shape(state)
    type(b1_10_water_state_t), intent(inout) :: state
    if (numnod <= 0) error stop 'B1.10 water checkpoint: numnod must be positive'
    if (allocated(state%h)) then
      if (size(state%h) == numnod .and. allocated(state%theta) .and. &
          allocated(state%hm1) .and. allocated(state%thetm1)) return
      deallocate(state%h, state%theta, state%hm1, state%thetm1)
    end if
    allocate(state%h(numnod), state%theta(numnod), state%hm1(numnod), state%thetm1(numnod))
  end subroutine ensure_shape

  subroutine capture_b1_10_water_state(state)
    type(b1_10_water_state_t), intent(inout) :: state
    call ensure_shape(state)
    state%h = h(1:numnod)
    state%theta = theta(1:numnod)
    state%hm1 = hm1(1:numnod)
    state%thetm1 = thetm1(1:numnod)
    state%pond = pond
    state%pondm1 = pondm1
    state%gwl = gwl
    state%gwlm1 = gwlm1
    state%volact = volact
    state%ldwet = ldwet
    state%spev = spev
    state%saev = saev
  end subroutine capture_b1_10_water_state

  subroutine restore_b1_10_water_state(state)
    type(b1_10_water_state_t), intent(in) :: state
    if (.not. allocated(state%h) .or. .not. allocated(state%theta) .or. &
        .not. allocated(state%hm1) .or. .not. allocated(state%thetm1)) then
      error stop 'B1.10 water checkpoint: incomplete state'
    end if
    if (size(state%h) /= numnod .or. size(state%theta) /= numnod .or. &
        size(state%hm1) /= numnod .or. size(state%thetm1) /= numnod) then
      error stop 'B1.10 water checkpoint: state/grid shape mismatch'
    end if
    h(1:numnod) = state%h
    theta(1:numnod) = state%theta
    hm1(1:numnod) = state%hm1
    thetm1(1:numnod) = state%thetm1
    pond = state%pond
    pondm1 = state%pondm1
    gwl = state%gwl
    gwlm1 = state%gwlm1
    volact = state%volact
    ldwet = state%ldwet
    spev = state%spev
    saev = state%saev
  end subroutine restore_b1_10_water_state

  subroutine b1_10_water_clone(self, copy)
    class(b1_10_water_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(b1_10_water_state_t :: copy)
    select type (target => copy)
    type is (b1_10_water_state_t)
      target%h = self%h
      target%theta = self%theta
      target%hm1 = self%hm1
      target%thetm1 = self%thetm1
      target%pond = self%pond
      target%pondm1 = self%pondm1
      target%gwl = self%gwl
      target%gwlm1 = self%gwlm1
      target%volact = self%volact
      target%ldwet = self%ldwet
      target%spev = self%spev
      target%saev = self%saev
    class default
      error stop 'B1.10 water checkpoint: clone allocation failure'
    end select
  end subroutine b1_10_water_clone

end module mod_b1_10_water_checkpoint
