module mod_fmq22_p14_state
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_canonical_contracts, only: canonical_state_t
  implicit none
  private

  type, public :: optional_payload_t
    integer :: continuation_counter = 0
  end type optional_payload_t

  type, extends(canonical_state_t), public :: p14_state_t
    real(real64) :: water = 0.0_real64
    type(optional_payload_t), allocatable :: optional_payload
  contains
    procedure :: clone => clone_p14_state
  end type p14_state_t

  type, public :: immutable_parameters_t
    integer :: parameter_id = 0
  end type immutable_parameters_t

  type, public :: parameter_ref_t
    type(immutable_parameters_t), pointer :: ptr => null()
  end type parameter_ref_t

  public :: make_seed, dynamic_payload_bytes

contains

  subroutine clone_p14_state(self, copy)
    class(p14_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy

    allocate(p14_state_t :: copy)
    select type (copy)
    type is (p14_state_t)
      copy%water = self%water
      if (allocated(self%optional_payload)) then
        allocate(copy%optional_payload)
        copy%optional_payload%continuation_counter = self%optional_payload%continuation_counter
      end if
    end select
  end subroutine clone_p14_state

  subroutine make_seed(state, active, counter)
    class(transaction_state_t), allocatable, intent(out) :: state
    logical, intent(in) :: active
    integer, intent(in) :: counter

    allocate(p14_state_t :: state)
    select type (state)
    type is (p14_state_t)
      state%water = 1.0_real64
      if (active) then
        allocate(state%optional_payload)
        state%optional_payload%continuation_counter = counter
      end if
    end select
  end subroutine make_seed

  integer function dynamic_payload_bytes(state) result(bytes)
    class(transaction_state_t), allocatable, intent(in) :: state
    bytes = 0
    select type (state)
    type is (p14_state_t)
      if (allocated(state%optional_payload)) bytes = storage_size(state%optional_payload)/8
    class default
      bytes = -1
    end select
  end function dynamic_payload_bytes

end module mod_fmq22_p14_state

program test_fmq22_p14_optional_state
  use, intrinsic :: iso_fortran_env, only: int64
  use mod_transaction_reference, only: transaction_state_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t
  use mod_fmq22_p14_state
  implicit none

  type(kernel_committed_state_t) :: columns(2)
  type(kernel_checkpoint_t) :: checkpoints(2)
  type(immutable_parameters_t), target :: shared_parameters
  type(parameter_ref_t) :: parameter_refs(2)
  class(transaction_state_t), allocatable :: seed, snap
  logical :: ok
  integer :: failures, off_bytes, on_bytes

  failures = 0
  shared_parameters%parameter_id = 1401
  parameter_refs(1)%ptr => shared_parameters
  parameter_refs(2)%ptr => shared_parameters

  call make_seed(seed, .false., 0)
  call columns(1)%initialize(14001_int64, seed, ok, 1.25d0)
  call expect(ok, 'inactive column initializes', failures)
  deallocate(seed)

  call make_seed(seed, .true., 17)
  call columns(2)%initialize(14002_int64, seed, ok, 1.25d0)
  call expect(ok, 'active column initializes', failures)
  deallocate(seed)

  call columns(1)%capture_checkpoint(checkpoints(1), ok)
  call expect(ok, 'inactive checkpoint captures', failures)
  call columns(2)%capture_checkpoint(checkpoints(2), ok)
  call expect(ok, 'active checkpoint captures', failures)

  call columns(1)%snapshot(snap, ok)
  call expect(ok, 'inactive committed snapshot', failures)
  call inspect_state(snap, .false., 0, failures)
  off_bytes = dynamic_payload_bytes(snap)
  deallocate(snap)

  call columns(2)%snapshot(snap, ok)
  call expect(ok, 'active committed snapshot', failures)
  call inspect_state(snap, .true., 17, failures)
  on_bytes = dynamic_payload_bytes(snap)
  deallocate(snap)

  call checkpoints(1)%snapshot(snap, ok)
  call expect(ok, 'inactive checkpoint snapshot', failures)
  call inspect_state(snap, .false., 0, failures)
  call expect(dynamic_payload_bytes(snap) == 0, 'inactive checkpoint has zero optional payload bytes', failures)
  deallocate(snap)

  call checkpoints(2)%snapshot(snap, ok)
  call expect(ok, 'active checkpoint snapshot', failures)
  call inspect_state(snap, .true., 17, failures)
  call expect(dynamic_payload_bytes(snap) == storage_size(optional_payload_t())/8, &
       'active checkpoint owns exactly one optional payload', failures)
  deallocate(snap)

  call expect(associated(parameter_refs(1)%ptr), 'column 1 parameter reference associated', failures)
  call expect(associated(parameter_refs(2)%ptr), 'column 2 parameter reference associated', failures)
  call expect(associated(parameter_refs(1)%ptr, parameter_refs(2)%ptr), &
       'immutable parameters shared by reference', failures)
  call expect(parameter_refs(1)%ptr%parameter_id == 1401 .and. &
       parameter_refs(2)%ptr%parameter_id == 1401, 'shared parameter identity stable', failures)

  call expect(off_bytes == 0, 'module-off column allocates zero optional continuation payload', failures)
  call expect(on_bytes == storage_size(optional_payload_t())/8, &
       'module-on column allocates one optional continuation payload', failures)

  if (failures /= 0) then
    write(*,'(A,I0)') 'F-MQ22_P14_TWO_COLUMN_GATE FAIL failures=', failures
    error stop 1
  end if

  write(*,'(A,I0)') 'P14_COLUMNS ', 2
  write(*,'(A,I0)') 'P14_WORKERS ', 1
  write(*,'(A,I0)') 'P14_OFF_DYNAMIC_BYTES ', off_bytes
  write(*,'(A,I0)') 'P14_ON_DYNAMIC_BYTES ', on_bytes
  write(*,'(A,I0)') 'P14_SHARED_PARAMETER_OBJECTS ', 1
  write(*,'(A)') 'F-MQ22_P14_TWO_COLUMN_GATE PASS'

contains

  subroutine inspect_state(state, expect_active, expect_counter, failures)
    class(transaction_state_t), allocatable, intent(in) :: state
    logical, intent(in) :: expect_active
    integer, intent(in) :: expect_counter
    integer, intent(inout) :: failures

    select type (state)
    type is (p14_state_t)
      call expect(allocated(state%optional_payload) .eqv. expect_active, 'optional allocation matches physics', failures)
      if (expect_active .and. allocated(state%optional_payload)) then
        call expect(state%optional_payload%continuation_counter == expect_counter, &
             'optional continuation value preserved', failures)
      end if
    class default
      call expect(.false., 'unexpected state type', failures)
    end select
  end subroutine inspect_state

  subroutine expect(condition, label, failures)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    integer, intent(inout) :: failures
    if (.not. condition) then
      failures = failures + 1
      write(*,'(A,A)') 'FAIL ', trim(label)
    end if
  end subroutine expect

end program test_fmq22_p14_optional_state
