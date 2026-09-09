program test_fmr19_restart_contract_negative
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE
  use mod_fmr_committed_restart, only: fmr_committed_restart_bundle_t, fmr_export_committed_restart, &
       fmr_restore_committed_restart, FMR_RESTART_OK, FMR_RESTART_DUPLICATE_COLUMN, &
       FMR_RESTART_COLUMN_NOT_FOUND, FMR_RESTART_TEMPLATE_MISMATCH, FMR_RESTART_PARAMETER_MISMATCH, &
       FMR_RESTART_STATE_NOT_COMMITTED, FMR_RESTART_KERNEL_PERSISTENCE_REJECTED, &
       FMR_RESTART_TARGET_ALREADY_INITIALIZED, FMR_RESTART_SCHEMA_MISMATCH, &
       FMR_RESTART_PARAMETER_SET_MISMATCH
  implicit none

  integer(int64), parameter :: parameter_set_identity = 1905001_int64
  real(real64), parameter :: committed_time = 1234.5_real64

  type, extends(transaction_state_t) :: negative_test_state_t
    integer(int64) :: token = 0_int64
  contains
    procedure :: clone => clone_negative_test_state
  end type negative_test_state_t

  type(fmr_logical_column_t), allocatable :: columns(:), bad_columns(:)
  type(fmr_template_t), allocatable :: templates(:), bad_templates(:)
  type(kernel_committed_state_t), allocatable :: committed_states(:), initialized_targets(:), restored_targets(:)
  type(fmr_committed_restart_bundle_t) :: bundle, bad_bundle
  logical :: exported, restored
  integer :: status, i

  allocate(columns(2), templates(1), committed_states(2))
  call configure_fixture(columns, templates, committed_states)
  call fmr_export_committed_restart(columns, templates, committed_states, parameter_set_identity, bundle, exported, status)
  call require(exported .and. status == FMR_RESTART_OK, 'baseline export')
  call require(allocated(bundle%records) .and. size(bundle%records) == 2, 'baseline record count')

  call expect_rejection(bundle, columns, templates, parameter_set_identity + 1_int64, &
       FMR_RESTART_PARAMETER_SET_MISMATCH, 'wrong parameter set')

  bad_bundle = bundle
  bad_bundle%records(1)%column_id = 999999_int64
  call expect_rejection(bad_bundle, columns, templates, parameter_set_identity, &
       FMR_RESTART_COLUMN_NOT_FOUND, 'missing logical column')

  bad_bundle = bundle
  bad_bundle%records(2)%column_id = bad_bundle%records(1)%column_id
  call expect_rejection(bad_bundle, columns, templates, parameter_set_identity, &
       FMR_RESTART_DUPLICATE_COLUMN, 'duplicate logical column')

  bad_bundle = bundle
  bad_bundle%schema_version = bad_bundle%schema_version + 1
  call expect_rejection(bad_bundle, columns, templates, parameter_set_identity, &
       FMR_RESTART_SCHEMA_MISMATCH, 'bundle schema mismatch')

  bad_bundle = bundle
  bad_bundle%records(1)%schema_version = bad_bundle%records(1)%schema_version + 1
  call expect_rejection(bad_bundle, columns, templates, parameter_set_identity, &
       FMR_RESTART_SCHEMA_MISMATCH, 'record schema mismatch')

  bad_bundle = bundle
  bad_bundle%records(1)%kernel_schema_version = bad_bundle%records(1)%kernel_schema_version + 1
  call expect_rejection(bad_bundle, columns, templates, parameter_set_identity, &
       FMR_RESTART_SCHEMA_MISMATCH, 'kernel schema mismatch')

  bad_bundle = bundle
  if (allocated(bad_bundle%records(1)%physical_state)) deallocate(bad_bundle%records(1)%physical_state)
  call expect_rejection(bad_bundle, columns, templates, parameter_set_identity, &
       FMR_RESTART_STATE_NOT_COMMITTED, 'missing physical continuation')

  bad_bundle = bundle
  bad_bundle%records(1)%lineage_id = 0_int64
  call expect_rejection(bad_bundle, columns, templates, parameter_set_identity, &
       FMR_RESTART_KERNEL_PERSISTENCE_REJECTED, 'invalid reconstructed provenance')

  bad_columns = columns
  bad_columns(1)%parameter_ref = bad_columns(1)%parameter_ref + 100_int64
  call expect_rejection(bundle, bad_columns, templates, parameter_set_identity, &
       FMR_RESTART_PARAMETER_MISMATCH, 'per-column parameter reference')

  bad_templates = templates
  bad_templates(1)%template_id = bad_templates(1)%template_id + 100_int64
  call expect_rejection(bundle, columns, bad_templates, parameter_set_identity, &
       FMR_RESTART_TEMPLATE_MISMATCH, 'template id')

  bad_templates = templates
  bad_templates(1)%physics_topology_id = bad_templates(1)%physics_topology_id + 1_int64
  call expect_rejection(bundle, columns, bad_templates, parameter_set_identity, &
       FMR_RESTART_TEMPLATE_MISMATCH, 'physics topology id')

  bad_templates = templates
  bad_templates(1)%vertical_layout_id = bad_templates(1)%vertical_layout_id + 1_int64
  call expect_rejection(bundle, columns, bad_templates, parameter_set_identity, &
       FMR_RESTART_TEMPLATE_MISMATCH, 'vertical layout id')

  bad_templates = templates
  bad_templates(1)%state_layout_id = bad_templates(1)%state_layout_id + 1_int64
  call expect_rejection(bundle, columns, bad_templates, parameter_set_identity, &
       FMR_RESTART_TEMPLATE_MISMATCH, 'state layout id')

  bad_templates = templates
  bad_templates(1)%solver_interface_id = bad_templates(1)%solver_interface_id + 1_int64
  call expect_rejection(bundle, columns, bad_templates, parameter_set_identity, &
       FMR_RESTART_TEMPLATE_MISMATCH, 'solver interface id')

  bad_templates = templates
  bad_templates(1)%optional_state_layout_id = bad_templates(1)%optional_state_layout_id + 1_int64
  call expect_rejection(bundle, columns, bad_templates, parameter_set_identity, &
       FMR_RESTART_TEMPLATE_MISMATCH, 'optional state layout id')

  bad_templates = templates
  bad_templates(1)%numerical_continuation_layout_id = bad_templates(1)%numerical_continuation_layout_id + 1_int64
  call expect_rejection(bundle, columns, bad_templates, parameter_set_identity, &
       FMR_RESTART_TEMPLATE_MISMATCH, 'numerical continuation layout id')

  bad_templates = templates
  bad_templates(1)%compatible_backend_id = bad_templates(1)%compatible_backend_id + 1
  call expect_rejection(bundle, columns, bad_templates, parameter_set_identity, &
       FMR_RESTART_TEMPLATE_MISMATCH, 'backend compatibility')

  initialized_targets = committed_states
  call fmr_restore_committed_restart(bundle, parameter_set_identity, columns, templates, initialized_targets, restored, status)
  call require(.not. restored .and. status == FMR_RESTART_TARGET_ALREADY_INITIALIZED, 'initialized target rejected')
  do i = 1, size(initialized_targets)
    call require(initialized_targets(i)%ready(), 'initialized target remains ready')
    call require(initialized_targets(i)%current_lineage_id() == committed_states(i)%current_lineage_id(), &
         'initialized target lineage unchanged')
    call require(initialized_targets(i)%current_revision() == committed_states(i)%current_revision(), &
         'initialized target revision unchanged')
  end do

  allocate(restored_targets(size(columns)))
  call fmr_restore_committed_restart(bundle, parameter_set_identity, columns, templates, restored_targets, restored, status)
  call require(restored .and. status == FMR_RESTART_OK, 'baseline restore')
  do i = 1, size(restored_targets)
    call require(restored_targets(i)%ready(), 'baseline restored target ready')
    call require(restored_targets(i)%current_lineage_id() == committed_states(i)%current_lineage_id(), &
         'baseline restored lineage')
    call require(restored_targets(i)%current_revision() == committed_states(i)%current_revision(), &
         'baseline restored revision')
  end do

  write(*,'(A)') 'FMR19_NEGATIVE_PARAMETER_SET=PASS'
  write(*,'(A)') 'FMR19_NEGATIVE_MISSING_COLUMN=PASS'
  write(*,'(A)') 'FMR19_NEGATIVE_DUPLICATE_COLUMN=PASS'
  write(*,'(A)') 'FMR19_NEGATIVE_BUNDLE_SCHEMA=PASS'
  write(*,'(A)') 'FMR19_NEGATIVE_RECORD_SCHEMA=PASS'
  write(*,'(A)') 'FMR19_NEGATIVE_KERNEL_SCHEMA=PASS'
  write(*,'(A)') 'FMR19_NEGATIVE_PHYSICAL_CONTINUATION=PASS'
  write(*,'(A)') 'FMR19_NEGATIVE_RECONSTRUCTION_PROVENANCE=PASS'
  write(*,'(A)') 'FMR19_NEGATIVE_PARAMETER_REF=PASS'
  write(*,'(A)') 'FMR19_NEGATIVE_TEMPLATE_ID=PASS'
  write(*,'(A)') 'FMR19_NEGATIVE_PHYSICS_TOPOLOGY=PASS'
  write(*,'(A)') 'FMR19_NEGATIVE_VERTICAL_LAYOUT=PASS'
  write(*,'(A)') 'FMR19_NEGATIVE_STATE_LAYOUT=PASS'
  write(*,'(A)') 'FMR19_NEGATIVE_SOLVER_INTERFACE=PASS'
  write(*,'(A)') 'FMR19_NEGATIVE_OPTIONAL_STATE_LAYOUT=PASS'
  write(*,'(A)') 'FMR19_NEGATIVE_NUMERICAL_CONTINUATION_LAYOUT=PASS'
  write(*,'(A)') 'FMR19_NEGATIVE_BACKEND_COMPATIBILITY=PASS'
  write(*,'(A)') 'FMR19_NEGATIVE_INITIALIZED_TARGET=PASS'
  write(*,'(A)') 'FMR19_NEGATIVE_ATOMIC_PUBLICATION=PASS'
  write(*,'(A)') 'FMR19_RESTART_CONTRACT_NEGATIVE_TEST PASS'

contains

  subroutine clone_negative_test_state(self, copy)
    class(negative_test_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy

    allocate(negative_test_state_t :: copy)
    select type (typed_copy => copy)
    type is (negative_test_state_t)
      typed_copy%token = self%token
    end select
  end subroutine clone_negative_test_state

  subroutine configure_fixture(fixture_columns, fixture_templates, fixture_states)
    type(fmr_logical_column_t), intent(out) :: fixture_columns(:)
    type(fmr_template_t), intent(out) :: fixture_templates(:)
    type(kernel_committed_state_t), intent(inout) :: fixture_states(:)
    class(transaction_state_t), allocatable :: initial_state
    logical :: initialized
    integer :: j

    call require(size(fixture_columns) == 2 .and. size(fixture_templates) == 1 .and. size(fixture_states) == 2, &
         'fixture shape')

    fixture_templates(1)%template_id = 1905_int64
    fixture_templates(1)%physics_topology_id = 190501_int64
    fixture_templates(1)%vertical_layout_id = 190502_int64
    fixture_templates(1)%state_layout_id = 190503_int64
    fixture_templates(1)%solver_interface_id = 190504_int64
    fixture_templates(1)%optional_state_layout_id = 190505_int64
    fixture_templates(1)%numerical_continuation_layout_id = 190506_int64
    fixture_templates(1)%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE

    do j = 1, 2
      fixture_columns(j)%column_id = 190500_int64 + int(j, int64)
      fixture_columns(j)%template_id = fixture_templates(1)%template_id
      fixture_columns(j)%parameter_ref = int(j, int64)
      fixture_columns(j)%state_handle = int(j, int64)
      fixture_columns(j)%forcing_handle = int(j, int64)
      fixture_columns(j)%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE

      allocate(negative_test_state_t :: initial_state)
      select type (typed_state => initial_state)
      type is (negative_test_state_t)
        typed_state%token = 9000_int64 + int(j, int64)
      end select
      call fixture_states(j)%initialize(fixture_columns(j)%column_id, initial_state, initialized, committed_time)
      call require(initialized .and. fixture_states(j)%ready(), 'fixture committed initialization')
      deallocate(initial_state)
    end do
  end subroutine configure_fixture

  subroutine expect_rejection(candidate_bundle, candidate_columns, candidate_templates, supplied_parameter_set, &
                              expected_status, label)
    type(fmr_committed_restart_bundle_t), intent(in) :: candidate_bundle
    type(fmr_logical_column_t), intent(in) :: candidate_columns(:)
    type(fmr_template_t), intent(in) :: candidate_templates(:)
    integer(int64), intent(in) :: supplied_parameter_set
    integer, intent(in) :: expected_status
    character(len=*), intent(in) :: label
    type(kernel_committed_state_t), allocatable :: targets(:)
    logical :: local_restored
    integer :: local_status, j

    allocate(targets(size(candidate_columns)))
    call fmr_restore_committed_restart(candidate_bundle, supplied_parameter_set, candidate_columns, candidate_templates, &
         targets, local_restored, local_status)
    call require(.not. local_restored, trim(label)//' rejected')
    call require(local_status == expected_status, trim(label)//' status')
    do j = 1, size(targets)
      call require(.not. targets(j)%ready(), trim(label)//' atomic target')
    end do
  end subroutine expect_rejection

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A)') 'FAIL: '//trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fmr19_restart_contract_negative
