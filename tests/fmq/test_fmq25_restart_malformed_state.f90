module mod_fmq25_state_fixtures
  use, intrinsic :: iso_fortran_env, only: int64
  use mod_transaction_reference, only: transaction_state_t
  implicit none
  private

  type, extends(transaction_state_t), public :: fmq25_good_state_t
    integer(int64) :: token = 0_int64
  contains
    procedure :: clone => clone_good
  end type fmq25_good_state_t

  type, extends(transaction_state_t), public :: fmq25_malformed_state_t
    integer(int64) :: poison = 0_int64
  contains
    procedure :: clone => clone_malformed
  end type fmq25_malformed_state_t

contains

  subroutine clone_good(self, copy)
    class(fmq25_good_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(fmq25_good_state_t :: copy)
    select type (typed => copy)
    type is (fmq25_good_state_t)
      typed%token = self%token
    end select
  end subroutine clone_good

  subroutine clone_malformed(self, copy)
    class(fmq25_malformed_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(fmq25_malformed_state_t :: copy)
    select type (typed => copy)
    type is (fmq25_malformed_state_t)
      typed%poison = self%poison
    end select
  end subroutine clone_malformed

end module mod_fmq25_state_fixtures

program test_fmq25_restart_malformed_state
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE
  use mod_fmr_committed_restart, only: fmr_committed_restart_bundle_t, fmr_export_committed_restart, &
       fmr_restore_committed_restart, FMR_RESTART_OK, FMR_RESTART_KERNEL_PERSISTENCE_REJECTED
  use mod_fmq25_state_fixtures, only: fmq25_good_state_t, fmq25_malformed_state_t
  implicit none

  integer(int64), parameter :: parameter_set_identity = 250001_int64
  real(real64), parameter :: committed_time = 3100.4375_real64
  type(fmr_logical_column_t) :: columns(2)
  type(fmr_template_t) :: templates(1)
  type(kernel_committed_state_t) :: source_states(2), targets(2)
  type(fmr_committed_restart_bundle_t) :: bundle, bad_bundle
  class(transaction_state_t), allocatable :: initial_state
  logical :: ok, exported, restored
  integer :: status, i

  call configure_fixture(columns, templates)
  do i = 1, 2
    allocate(fmq25_good_state_t :: initial_state)
    select type (typed => initial_state)
    type is (fmq25_good_state_t)
      typed%token = 250000_int64 + int(i,int64)
    end select
    call source_states(i)%initialize(columns(i)%column_id, initial_state, ok, committed_time)
    call require(ok .and. source_states(i)%ready(), 'source state initialization')
    deallocate(initial_state)
  end do

  call fmr_export_committed_restart(columns, templates, source_states, parameter_set_identity, bundle, exported, status)
  call require(exported .and. status == FMR_RESTART_OK, 'baseline export')

  ! Control: a late-record provenance defect must reject atomically.
  bad_bundle = bundle
  bad_bundle%records(2)%lineage_id = 0_int64
  call fmr_restore_committed_restart(bad_bundle, parameter_set_identity, columns, templates, targets, restored, status)
  call require(.not. restored .and. status == FMR_RESTART_KERNEL_PERSISTENCE_REJECTED, 'late provenance rejected')
  call require(all_unready(targets), 'late provenance leaves complete target registry fresh')
  write(*,'(A)') 'FMQ25_LATE_RECORD_ATOMIC_CONTROL=PASS'

  ! Independent hard-negative attack: preserve all metadata but replace the
  ! decoded physical payload of the LAST record by a different concrete
  ! transaction_state_t type.  A committed-boundary restore admission must not
  ! publish a registry whose physical state is incompatible with the declared
  ! runtime/template contract.
  bad_bundle = bundle
  if (allocated(bad_bundle%records(2)%physical_state)) deallocate(bad_bundle%records(2)%physical_state)
  allocate(fmq25_malformed_state_t :: bad_bundle%records(2)%physical_state)
  select type (typed_bad => bad_bundle%records(2)%physical_state)
  type is (fmq25_malformed_state_t)
    typed_bad%poison = 999999_int64
  end select

  call fmr_restore_committed_restart(bad_bundle, parameter_set_identity, columns, templates, targets, restored, status)
  if (restored .or. status == FMR_RESTART_OK) then
    write(*,'(A)') 'FMQ25_MALFORMED_CONCRETE_STATE_REJECTED=FAIL'
    write(*,'(A,I0)') 'FMQ25_OBSERVED_RESTORE_STATUS=', status
    write(*,'(A,L1)') 'FMQ25_OBSERVED_RESTORED=', restored
    write(*,'(A,L1)') 'FMQ25_TARGET1_READY=', targets(1)%ready()
    write(*,'(A,L1)') 'FMQ25_TARGET2_READY=', targets(2)%ready()
    error stop 25
  end if

  call require(all_unready(targets), 'malformed decoded state leaves target registry fresh')
  write(*,'(A)') 'FMQ25_MALFORMED_CONCRETE_STATE_REJECTED=PASS'
  write(*,'(A)') 'FMQ25_HARD_NEGATIVE_GATE=PASS'

contains

  subroutine configure_fixture(fixture_columns, fixture_templates)
    type(fmr_logical_column_t), intent(out) :: fixture_columns(:)
    type(fmr_template_t), intent(out) :: fixture_templates(:)
    integer :: j

    fixture_templates(1)%template_id = 25001_int64
    fixture_templates(1)%physics_topology_id = 250011_int64
    fixture_templates(1)%vertical_layout_id = 250012_int64
    fixture_templates(1)%state_layout_id = 250013_int64
    fixture_templates(1)%solver_interface_id = 250014_int64
    fixture_templates(1)%optional_state_layout_id = 0_int64
    fixture_templates(1)%numerical_continuation_layout_id = 0_int64
    fixture_templates(1)%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE

    do j = 1, size(fixture_columns)
      fixture_columns(j)%column_id = 250100_int64 + int(17*j,int64)
      fixture_columns(j)%template_id = fixture_templates(1)%template_id
      fixture_columns(j)%parameter_ref = 1_int64
      fixture_columns(j)%state_handle = int(j,int64)
      fixture_columns(j)%forcing_handle = int(j,int64)
      fixture_columns(j)%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
    end do
  end subroutine configure_fixture

  logical function all_unready(states) result(unready)
    type(kernel_committed_state_t), intent(in) :: states(:)
    integer :: j
    unready = .true.
    do j = 1, size(states)
      if (states(j)%ready()) then
        unready = .false.
        return
      end if
    end do
  end function all_unready

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A)') 'FAIL: '//trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fmq25_restart_malformed_state
