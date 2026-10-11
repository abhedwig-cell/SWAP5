module pub_me_d1_test_state
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t
  implicit none
  private
  public :: d1_scalar_state_t

  type, extends(transaction_state_t) :: d1_scalar_state_t
    real(real64) :: value = 0.0_real64
  contains
    procedure :: clone => d1_scalar_clone
  end type d1_scalar_state_t

contains

  subroutine d1_scalar_clone(self, copy)
    class(d1_scalar_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy

    allocate(d1_scalar_state_t :: copy)
    select type (typed => copy)
    type is (d1_scalar_state_t)
      typed%value = self%value
    end select
  end subroutine d1_scalar_clone
end module pub_me_d1_test_state

program test_pub_me_d1_clone_isolation
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use pub_me_d1_test_state, only: d1_scalar_state_t
  implicit none

  integer(int64), parameter :: lineage = 920101_int64
  real(real64), parameter :: initial_value = 12.5_real64
  real(real64), parameter :: mutant_value = -9876.5_real64
  type(kernel_committed_state_t) :: committed
  class(transaction_state_t), allocatable :: initial, before, extracted, after
  integer(int64) :: revision_before, revision_after
  real(real64) :: time_before, time_after
  logical :: initialized, before_ok, extracted_ok, after_ok, time_before_ok, time_after_ok

  allocate(d1_scalar_state_t :: initial)
  select type (typed => initial)
  type is (d1_scalar_state_t)
    typed%value = initial_value
  end select

  call committed%initialize(lineage, initial, initialized, 0.0_real64)
  call require(initialized, 'committed state initialized')

  revision_before = committed%current_revision()
  call committed%current_time(time_before, time_before_ok)
  call committed%snapshot(before, before_ok)
  call committed%snapshot(extracted, extracted_ok)
  call require(before_ok .and. extracted_ok .and. time_before_ok, 'public snapshots available')

  ! Qualification-only mutation of the object returned by the public snapshot
  ! API. If snapshot() leaked an alias to authoritative storage, this write
  ! would contaminate the committed scientific state.
  select type (typed => extracted)
  type is (d1_scalar_state_t)
    typed%value = mutant_value
  class default
    call require(.false., 'snapshot preserves dynamic state type')
  end select

  call committed%snapshot(after, after_ok)
  revision_after = committed%current_revision()
  call committed%current_time(time_after, time_after_ok)
  call require(after_ok .and. time_after_ok, 'post-mutation committed snapshot available')

  call require(state_value(before) == initial_value, 'pre-mutation authoritative value')
  call require(state_value(extracted) == mutant_value, 'qualification-only snapshot mutation occurred')
  call require(state_value(after) == initial_value, 'snapshot mutation cannot write through to committed state')
  call require(revision_after == revision_before, 'snapshot mutation cannot change committed revision')
  call require(time_after == time_before, 'snapshot mutation cannot change committed time')

  write(*,'(A,ES26.17E3)') 'PUB_ME_D1_EXTRACTED_MUTANT_VALUE=', state_value(extracted)
  write(*,'(A,ES26.17E3)') 'PUB_ME_D1_COMMITTED_VALUE_AFTER_MUTATION=', state_value(after)
  write(*,'(A,I0)') 'PUB_ME_D1_COMMITTED_REVISION_AFTER_MUTATION=', revision_after
  write(*,'(A)') 'PUB_ME_D1_PUBLIC_SNAPSHOT_CLONE_ISOLATION=PASS'

contains

  real(real64) function state_value(state) result(value)
    class(transaction_state_t), allocatable, intent(in) :: state
    value = huge(0.0_real64)
    if (.not. allocated(state)) return
    select type (typed => state)
    type is (d1_scalar_state_t)
      value = typed%value
    end select
  end function state_value

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'PUB_ME_D1_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require
end program test_pub_me_d1_clone_isolation
