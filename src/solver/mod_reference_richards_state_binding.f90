module mod_reference_richards_state_binding
  use, intrinsic :: iso_fortran_env, only: real64
  implicit none
  private

  type, public :: reference_richards_state_binding_t
     integer :: active_nodes = 0
     real(real64), allocatable :: h(:)
     real(real64), allocatable :: theta(:)
     real(real64), allocatable :: hm1(:)
     real(real64), allocatable :: thetm1(:)
     real(real64), allocatable :: k(:)
     real(real64), allocatable :: kmean(:)
     real(real64), allocatable :: dimoca(:)
     real(real64) :: pond = 0.0_real64
     real(real64) :: pondm1 = 0.0_real64
     real(real64) :: gwl = 0.0_real64
     real(real64) :: gwlm1 = 0.0_real64
     real(real64) :: qtop = 0.0_real64
     real(real64) :: qbot = 0.0_real64
     real(real64) :: hbot = 0.0_real64
     real(real64) :: gwlinp = 0.0_real64
     logical :: fllowgwl = .false.
     logical :: fldecdt = .false.
     integer :: numbit = 0
   contains
     procedure :: ensure_shape => reference_state_ensure_shape
     procedure :: clear_outcome => reference_state_clear_outcome
  end type reference_richards_state_binding_t

  public :: copy_reference_state

contains

  subroutine reference_state_ensure_shape(self, n)
    class(reference_richards_state_binding_t), intent(inout) :: self
    integer, intent(in) :: n

    if (n <= 0) error stop 'reference state binding: active node count must be positive'
    if (self%active_nodes == n .and. allocated(self%h) .and. allocated(self%theta) .and. &
        allocated(self%hm1) .and. allocated(self%thetm1) .and. allocated(self%k) .and. &
        allocated(self%kmean) .and. allocated(self%dimoca)) then
       if (size(self%h) == n .and. size(self%theta) == n .and. size(self%hm1) == n .and. &
           size(self%thetm1) == n .and. size(self%k) == n .and. size(self%kmean) == n+1 .and. &
           size(self%dimoca) == n) return
    end if

    if (allocated(self%h)) deallocate(self%h)
    if (allocated(self%theta)) deallocate(self%theta)
    if (allocated(self%hm1)) deallocate(self%hm1)
    if (allocated(self%thetm1)) deallocate(self%thetm1)
    if (allocated(self%k)) deallocate(self%k)
    if (allocated(self%kmean)) deallocate(self%kmean)
    if (allocated(self%dimoca)) deallocate(self%dimoca)

    allocate(self%h(n), self%theta(n), self%hm1(n), self%thetm1(n))
    allocate(self%k(n), self%kmean(n+1), self%dimoca(n))
    self%active_nodes = n
  end subroutine reference_state_ensure_shape

  subroutine reference_state_clear_outcome(self)
    class(reference_richards_state_binding_t), intent(inout) :: self
    self%fllowgwl = .false.
    self%fldecdt = .false.
    self%numbit = 0
  end subroutine reference_state_clear_outcome

  subroutine copy_reference_state(source, target)
    type(reference_richards_state_binding_t), intent(in) :: source
    type(reference_richards_state_binding_t), intent(inout) :: target

    if (source%active_nodes <= 0) error stop 'reference state binding: cannot copy unshaped state'
    call target%ensure_shape(source%active_nodes)
    target%h = source%h
    target%theta = source%theta
    target%hm1 = source%hm1
    target%thetm1 = source%thetm1
    target%k = source%k
    target%kmean = source%kmean
    target%dimoca = source%dimoca
    target%pond = source%pond
    target%pondm1 = source%pondm1
    target%gwl = source%gwl
    target%gwlm1 = source%gwlm1
    target%qtop = source%qtop
    target%qbot = source%qbot
    target%hbot = source%hbot
    target%gwlinp = source%gwlinp
    target%fllowgwl = source%fllowgwl
    target%fldecdt = source%fldecdt
    target%numbit = source%numbit
  end subroutine copy_reference_state

end module mod_reference_richards_state_binding
