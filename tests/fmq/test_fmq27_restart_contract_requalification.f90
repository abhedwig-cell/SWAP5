module mod_fmq27_wrong_state
  use, intrinsic :: iso_fortran_env, only: int64
  use mod_transaction_reference, only: transaction_state_t
  implicit none
  private

  type, extends(transaction_state_t), public :: fmq27_wrong_state_t
    integer(int64) :: poison = 0_int64
  contains
    procedure :: clone => clone_wrong
  end type fmq27_wrong_state_t

contains

  subroutine clone_wrong(self, copy)
    class(fmq27_wrong_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(fmq27_wrong_state_t :: copy)
    select type (typed => copy)
    type is (fmq27_wrong_state_t)
      typed%poison = self%poison
    end select
  end subroutine clone_wrong

end module mod_fmq27_wrong_state

program test_fmq27_restart_contract_requalification
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, &
       FMR_BACKEND_SERIALIZED_REFERENCE, FMR_NUMERICAL_CONTINUATION_NONE, &
       FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, &
       fmr_b110_temporal_indicator_state_t, fmr_new_b110_committed_state
  use mod_fmr_restart_state_contract, only: fmr_restart_state_matches_template
  use mod_fmr_committed_restart, only: fmr_committed_restart_bundle_t, fmr_export_committed_restart, &
       fmr_restore_committed_restart, FMR_RESTART_OK, FMR_RESTART_DUPLICATE_COLUMN, &
       FMR_RESTART_COLUMN_NOT_FOUND, FMR_RESTART_TEMPLATE_MISMATCH, FMR_RESTART_PARAMETER_MISMATCH, &
       FMR_RESTART_STATE_NOT_COMMITTED, FMR_RESTART_KERNEL_PERSISTENCE_REJECTED, &
       FMR_RESTART_TARGET_ALREADY_INITIALIZED, FMR_RESTART_SCHEMA_MISMATCH, &
       FMR_RESTART_PARAMETER_SET_MISMATCH
  use mod_fmq27_wrong_state, only: fmq27_wrong_state_t
  implicit none

  integer(int64), parameter :: parameter_set_identity = 270001_int64
  real(real64), parameter :: committed_time = 3100.4375_real64
  type(fmr_logical_column_t) :: columns(2), bad_columns(2)
  type(fmr_template_t) :: templates(1), bad_templates(1), temporal_template, unknown_template
  type(fmr_b110_physical_state_t) :: seed, base_probe
  type(fmr_b110_temporal_indicator_state_t) :: temporal_probe
  type(fmq27_wrong_state_t) :: wrong_probe
  type(kernel_committed_state_t) :: source_states(2), targets(2), initialized_targets(2)
  type(fmr_committed_restart_bundle_t) :: bundle, bad_bundle
  logical :: ok, exported, restored
  integer :: status, i

  call configure_fixture(columns, templates)
  call configure_seed(seed)
  base_probe = seed

  temporal_template = templates(1)
  temporal_template%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  unknown_template = templates(1)
  unknown_template%compatible_backend_id = 999

  call require(fmr_restart_state_matches_template(base_probe, templates(1)), 'base state matches base template')
  call require(.not. fmr_restart_state_matches_template(temporal_probe, templates(1)), 'temporal state rejected by base template')
  call require(fmr_restart_state_matches_template(temporal_probe, temporal_template), 'temporal state matches temporal template')
  call require(.not. fmr_restart_state_matches_template(base_probe, temporal_template), 'base state rejected by temporal template')
  call require(.not. fmr_restart_state_matches_template(wrong_probe, templates(1)), 'unregistered concrete type rejected')
  call require(.not. fmr_restart_state_matches_template(base_probe, unknown_template), 'unknown backend rejected')
  write(*,'(A)') 'FMQ27_STATE_FAMILY_DISCRIMINATOR=PASS'

  do i = 1, 2
    call fmr_new_b110_committed_state(source_states(i), columns(i)%column_id, seed, committed_time, ok)
    call require(ok .and. source_states(i)%ready(), 'source state initialization')
  end do

  call fmr_export_committed_restart(columns, templates, source_states, parameter_set_identity, bundle, exported, status)
  call require(exported .and. status == FMR_RESTART_OK, 'baseline production export')
  call require(allocated(bundle%records) .and. size(bundle%records) == 2, 'baseline record count')
  write(*,'(A)') 'FMQ27_PRODUCTION_B110_EXPORT=PASS'

  call expect_rejection(bundle, columns, templates, parameter_set_identity + 1_int64, &
       FMR_RESTART_PARAMETER_SET_MISMATCH, 'wrong parameter set')

  bad_bundle = bundle
  bad_bundle%records(1)%column_id = 999999_int64
  call expect_rejection(bad_bundle, columns, templates, parameter_set_identity, &
       FMR_RESTART_COLUMN_NOT_FOUND, 'unknown column record')

  bad_bundle = bundle
  bad_bundle%records(2)%column_id = bad_bundle%records(1)%column_id
  call expect_rejection(bad_bundle, columns, templates, parameter_set_identity, &
       FMR_RESTART_DUPLICATE_COLUMN, 'duplicate column')

  bad_bundle = bundle
  bad_bundle%schema_version = bad_bundle%schema_version + 1
  call expect_rejection(bad_bundle, columns, templates, parameter_set_identity, &
       FMR_RESTART_SCHEMA_MISMATCH, 'bundle schema')

  bad_bundle = bundle
  bad_bundle%records(1)%schema_version = bad_bundle%records(1)%schema_version + 1
  call expect_rejection(bad_bundle, columns, templates, parameter_set_identity, &
       FMR_RESTART_SCHEMA_MISMATCH, 'record schema')

  bad_bundle = bundle
  bad_bundle%records(1)%kernel_schema_version = bad_bundle%records(1)%kernel_schema_version + 1
  call expect_rejection(bad_bundle, columns, templates, parameter_set_identity, &
       FMR_RESTART_SCHEMA_MISMATCH, 'kernel schema')

  bad_bundle = bundle
  if (allocated(bad_bundle%records(1)%physical_state)) deallocate(bad_bundle%records(1)%physical_state)
  call expect_rejection(bad_bundle, columns, templates, parameter_set_identity, &
       FMR_RESTART_STATE_NOT_COMMITTED, 'missing physical state')

  ! Late-record hard negative: preserve every declared identity and replace only
  ! the decoded dynamic type. No partial publication may occur.
  bad_bundle = bundle
  if (allocated(bad_bundle%records(2)%physical_state)) deallocate(bad_bundle%records(2)%physical_state)
  allocate(fmq27_wrong_state_t :: bad_bundle%records(2)%physical_state)
  select type (typed_bad => bad_bundle%records(2)%physical_state)
  type is (fmq27_wrong_state_t)
    typed_bad%poison = 270999_int64
  end select
  call expect_rejection(bad_bundle, columns, templates, parameter_set_identity, &
       FMR_RESTART_KERNEL_PERSISTENCE_REJECTED, 'malformed concrete state')
  write(*,'(A)') 'FMQ27_MALFORMED_CONCRETE_STATE_REJECTED=PASS'
  write(*,'(A)') 'FMQ27_LATE_RECORD_ATOMICITY=PASS'

  ! A registered state family is still invalid when bound to the wrong declared
  ! continuation layout. This prevents a weak whitelist from replacing binding.
  bad_bundle = bundle
  if (allocated(bad_bundle%records(2)%physical_state)) deallocate(bad_bundle%records(2)%physical_state)
  allocate(fmr_b110_temporal_indicator_state_t :: bad_bundle%records(2)%physical_state)
  call expect_rejection(bad_bundle, columns, templates, parameter_set_identity, &
       FMR_RESTART_KERNEL_PERSISTENCE_REJECTED, 'registered but mismatched state family')
  write(*,'(A)') 'FMQ27_REGISTERED_WRONG_FAMILY_REJECTED=PASS'

  bad_bundle = bundle
  bad_bundle%records(2)%lineage_id = 0_int64
  call expect_rejection(bad_bundle, columns, templates, parameter_set_identity, &
       FMR_RESTART_KERNEL_PERSISTENCE_REJECTED, 'late invalid lineage')
  write(*,'(A)') 'FMQ27_LATE_PROVENANCE_ATOMICITY=PASS'

  bad_bundle = bundle
  bad_bundle%records(1)%committed_time = ieee_value(0.0_real64, ieee_quiet_nan)
  call expect_rejection(bad_bundle, columns, templates, parameter_set_identity, &
       FMR_RESTART_KERNEL_PERSISTENCE_REJECTED, 'nonfinite committed time')

  bad_columns = columns
  bad_columns(1)%parameter_ref = bad_columns(1)%parameter_ref + 100_int64
  call expect_rejection(bundle, bad_columns, templates, parameter_set_identity, &
       FMR_RESTART_PARAMETER_MISMATCH, 'wrong parameter ref')

  bad_templates = templates
  bad_templates(1)%template_id = bad_templates(1)%template_id + 100_int64
  call expect_rejection(bundle, columns, bad_templates, parameter_set_identity, &
       FMR_RESTART_TEMPLATE_MISMATCH, 'template id')

  bad_templates = templates
  bad_templates(1)%physics_topology_id = bad_templates(1)%physics_topology_id + 1_int64
  call expect_rejection(bundle, columns, bad_templates, parameter_set_identity, &
       FMR_RESTART_TEMPLATE_MISMATCH, 'physics topology')

  bad_templates = templates
  bad_templates(1)%vertical_layout_id = bad_templates(1)%vertical_layout_id + 1_int64
  call expect_rejection(bundle, columns, bad_templates, parameter_set_identity, &
       FMR_RESTART_TEMPLATE_MISMATCH, 'vertical layout')

  bad_templates = templates
  bad_templates(1)%state_layout_id = bad_templates(1)%state_layout_id + 1_int64
  call expect_rejection(bundle, columns, bad_templates, parameter_set_identity, &
       FMR_RESTART_TEMPLATE_MISMATCH, 'state layout')

  bad_templates = templates
  bad_templates(1)%solver_interface_id = bad_templates(1)%solver_interface_id + 1_int64
  call expect_rejection(bundle, columns, bad_templates, parameter_set_identity, &
       FMR_RESTART_TEMPLATE_MISMATCH, 'solver interface')

  bad_templates = templates
  bad_templates(1)%optional_state_layout_id = bad_templates(1)%optional_state_layout_id + 1_int64
  call expect_rejection(bundle, columns, bad_templates, parameter_set_identity, &
       FMR_RESTART_TEMPLATE_MISMATCH, 'optional state layout')

  bad_templates = templates
  bad_templates(1)%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  call expect_rejection(bundle, columns, bad_templates, parameter_set_identity, &
       FMR_RESTART_TEMPLATE_MISMATCH, 'numerical continuation layout')

  bad_templates = templates
  bad_templates(1)%compatible_backend_id = bad_templates(1)%compatible_backend_id + 1
  call expect_rejection(bundle, columns, bad_templates, parameter_set_identity, &
       FMR_RESTART_TEMPLATE_MISMATCH, 'backend compatibility')

  initialized_targets = source_states
  call fmr_restore_committed_restart(bundle, parameter_set_identity, columns, templates, initialized_targets, restored, status)
  call require(.not. restored .and. status == FMR_RESTART_TARGET_ALREADY_INITIALIZED, 'initialized target rejected')
  do i = 1, 2
    call require(initialized_targets(i)%ready(), 'initialized target remains ready')
    call require(initialized_targets(i)%current_lineage_id() == source_states(i)%current_lineage_id(), 'initialized lineage unchanged')
    call require(initialized_targets(i)%current_revision() == source_states(i)%current_revision(), 'initialized revision unchanged')
  end do

  call fmr_restore_committed_restart(bundle, parameter_set_identity, columns, templates, targets, restored, status)
  call require(restored .and. status == FMR_RESTART_OK, 'baseline valid restore')
  do i = 1, 2
    call require(targets(i)%ready(), 'restored target ready')
    call require(targets(i)%current_lineage_id() == source_states(i)%current_lineage_id(), 'restored lineage exact')
    call require(targets(i)%current_revision() == source_states(i)%current_revision(), 'restored revision exact')
  end do
  write(*,'(A)') 'FMQ27_FULL_NEGATIVE_MATRIX=PASS'
  write(*,'(A)') 'FMQ27_VALID_PRODUCTION_RESTORE=PASS'
  write(*,'(A)') 'FMQ27_RESTART_CONTRACT_REQUALIFICATION_TEST PASS'

contains

  subroutine configure_fixture(fixture_columns, fixture_templates)
    type(fmr_logical_column_t), intent(out) :: fixture_columns(:)
    type(fmr_template_t), intent(out) :: fixture_templates(:)
    integer :: j

    fixture_templates(1)%template_id = 27001_int64
    fixture_templates(1)%physics_topology_id = 270011_int64
    fixture_templates(1)%vertical_layout_id = 270012_int64
    fixture_templates(1)%state_layout_id = 270013_int64
    fixture_templates(1)%solver_interface_id = 270014_int64
    fixture_templates(1)%optional_state_layout_id = 0_int64
    fixture_templates(1)%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_NONE
    fixture_templates(1)%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE

    do j = 1, size(fixture_columns)
      fixture_columns(j)%column_id = 270100_int64 + int(17*j,int64)
      fixture_columns(j)%template_id = fixture_templates(1)%template_id
      fixture_columns(j)%parameter_ref = 1_int64
      fixture_columns(j)%state_handle = int(j,int64)
      fixture_columns(j)%forcing_handle = int(j,int64)
      fixture_columns(j)%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
    end do
  end subroutine configure_fixture

  subroutine configure_seed(state)
    type(fmr_b110_physical_state_t), intent(out) :: state
    state%active_nodes = 2
    allocate(state%pressure_head(2), state%water_content(2))
    state%pressure_head = [-75.0_real64, -80.0_real64]
    state%water_content = [0.25_real64, 0.24_real64]
    state%ponding_depth = 0.0_real64
    state%groundwater_level = -2.0_real64
  end subroutine configure_seed

  subroutine expect_rejection(candidate_bundle, candidate_columns, candidate_templates, supplied_parameter_set, expected_status, label)
    type(fmr_committed_restart_bundle_t), intent(in) :: candidate_bundle
    type(fmr_logical_column_t), intent(in) :: candidate_columns(:)
    type(fmr_template_t), intent(in) :: candidate_templates(:)
    integer(int64), intent(in) :: supplied_parameter_set
    integer, intent(in) :: expected_status
    character(len=*), intent(in) :: label
    type(kernel_committed_state_t), allocatable :: local_targets(:)
    logical :: local_restored
    integer :: local_status, j

    allocate(local_targets(size(candidate_columns)))
    call fmr_restore_committed_restart(candidate_bundle, supplied_parameter_set, candidate_columns, candidate_templates, &
         local_targets, local_restored, local_status)
    call require(.not. local_restored, trim(label)//' rejected')
    call require(local_status == expected_status, trim(label)//' expected status')
    do j = 1, size(local_targets)
      call require(.not. local_targets(j)%ready(), trim(label)//' whole-registry atomicity')
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

end program test_fmq27_restart_contract_requalification
