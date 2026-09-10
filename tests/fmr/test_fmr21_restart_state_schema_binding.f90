module mod_fmr21_restart_test_state
  use, intrinsic :: iso_fortran_env, only: int64
  use mod_transaction_reference, only: transaction_state_t
  implicit none
  private

  type, extends(transaction_state_t), public :: fmr21_wrong_state_t
    integer(int64) :: poison = 0_int64
  contains
    procedure :: clone => clone_wrong_state
  end type fmr21_wrong_state_t

contains

  subroutine clone_wrong_state(self, copy)
    class(fmr21_wrong_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(fmr21_wrong_state_t :: copy)
    select type (typed => copy)
    type is (fmr21_wrong_state_t)
      typed%poison = self%poison
    end select
  end subroutine clone_wrong_state

end module mod_fmr21_restart_test_state

program test_fmr21_restart_state_schema_binding
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_NUMERICAL_CONTINUATION_NONE, FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_b110_temporal_indicator_state_t, &
       fmr_new_b110_committed_state
  use mod_fmr_restart_state_contract, only: fmr_restart_state_matches_template
  use mod_fmr_committed_restart, only: fmr_committed_restart_bundle_t, fmr_export_committed_restart, &
       fmr_restore_committed_restart, FMR_RESTART_OK, FMR_RESTART_KERNEL_PERSISTENCE_REJECTED
  use mod_fmr21_restart_test_state, only: fmr21_wrong_state_t
  implicit none

  integer(int64), parameter :: parameter_set_identity = 210001_int64
  real(real64), parameter :: committed_time = 3125.4375_real64
  type(fmr_logical_column_t) :: columns(2)
  type(fmr_template_t) :: templates(1), temporal_template, unknown_template
  type(fmr_b110_physical_state_t) :: seed, base_probe
  type(fmr_b110_temporal_indicator_state_t) :: temporal_probe
  type(fmr21_wrong_state_t) :: wrong_probe
  type(kernel_committed_state_t) :: source_states(2), targets(2)
  type(fmr_committed_restart_bundle_t) :: bundle, bad_bundle
  logical :: ok, exported, restored
  integer :: status, i

  call configure_fixture(columns, templates)
  call configure_seed(seed)

  ! Direct contract checks prove that the discriminator comes from declared
  ! runtime template identity, not from the decoded payload itself.
  base_probe = seed
  temporal_template = templates(1)
  temporal_template%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  unknown_template = templates(1)
  unknown_template%compatible_backend_id = 999
  call require(fmr_restart_state_matches_template(base_probe, templates(1)), 'base B110 admitted for NONE layout')
  call require(.not. fmr_restart_state_matches_template(temporal_probe, templates(1)), 'temporal subtype rejected for NONE layout')
  call require(fmr_restart_state_matches_template(temporal_probe, temporal_template), 'temporal subtype admitted for temporal layout')
  call require(.not. fmr_restart_state_matches_template(base_probe, temporal_template), 'base state rejected for temporal layout')
  call require(.not. fmr_restart_state_matches_template(wrong_probe, templates(1)), 'unregistered type rejected')
  call require(.not. fmr_restart_state_matches_template(base_probe, unknown_template), 'unknown backend rejected')
  write(*,'(A)') 'FMR21_TEMPLATE_STATE_TYPE_DISCRIMINATOR=PASS'

  do i = 1, 2
    call fmr_new_b110_committed_state(source_states(i), columns(i)%column_id, seed, committed_time, ok)
    call require(ok .and. source_states(i)%ready(), 'source state initialization')
  end do

  call fmr_export_committed_restart(columns, templates, source_states, parameter_set_identity, bundle, exported, status)
  call require(exported .and. status == FMR_RESTART_OK, 'baseline production-state export')
  write(*,'(A)') 'FMR21_PRODUCTION_B110_EXPORT=PASS'

  ! Existing atomicity control: a later record failure must publish nothing.
  bad_bundle = bundle
  bad_bundle%records(2)%lineage_id = 0_int64
  call fmr_restore_committed_restart(bad_bundle, parameter_set_identity, columns, templates, targets, restored, status)
  call require(.not. restored .and. status == FMR_RESTART_KERNEL_PERSISTENCE_REJECTED, 'late provenance rejected')
  call require(all_unready(targets), 'late provenance atomicity')
  write(*,'(A)') 'FMR21_LATE_RECORD_ATOMIC_CONTROL=PASS'

  ! Reproduce F-MQ25 exactly at the semantic boundary: preserve record and
  ! template metadata, replace only the decoded dynamic physical-state type.
  bad_bundle = bundle
  if (allocated(bad_bundle%records(2)%physical_state)) deallocate(bad_bundle%records(2)%physical_state)
  allocate(fmr21_wrong_state_t :: bad_bundle%records(2)%physical_state)
  select type (typed_bad => bad_bundle%records(2)%physical_state)
  type is (fmr21_wrong_state_t)
    typed_bad%poison = 999999_int64
  end select

  call fmr_restore_committed_restart(bad_bundle, parameter_set_identity, columns, templates, targets, restored, status)
  call require(.not. restored .and. status == FMR_RESTART_KERNEL_PERSISTENCE_REJECTED, 'malformed concrete state rejected')
  call require(all_unready(targets), 'malformed state atomicity')
  write(*,'(A)') 'FMR21_MALFORMED_CONCRETE_STATE_REJECTED=PASS'
  write(*,'(A)') 'FMR21_MALFORMED_STATE_WHOLE_REGISTRY_ATOMICITY=PASS'

  ! Positive restore remains exact for the same production record.
  call fmr_restore_committed_restart(bundle, parameter_set_identity, columns, templates, targets, restored, status)
  call require(restored .and. status == FMR_RESTART_OK, 'valid production restore')
  call require(all_ready(targets), 'valid production restore publication')
  write(*,'(A)') 'FMR21_VALID_PRODUCTION_RESTORE=PASS'
  write(*,'(A)') 'FMR21_RESTART_STATE_SCHEMA_BINDING_TEST PASS'

contains

  subroutine configure_fixture(fixture_columns, fixture_templates)
    type(fmr_logical_column_t), intent(out) :: fixture_columns(:)
    type(fmr_template_t), intent(out) :: fixture_templates(:)
    integer :: j

    fixture_templates(1)%template_id = 21001_int64
    fixture_templates(1)%physics_topology_id = 210011_int64
    fixture_templates(1)%vertical_layout_id = 210012_int64
    fixture_templates(1)%state_layout_id = 210013_int64
    fixture_templates(1)%solver_interface_id = 210014_int64
    fixture_templates(1)%optional_state_layout_id = 0_int64
    fixture_templates(1)%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_NONE
    fixture_templates(1)%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE

    do j = 1, size(fixture_columns)
      fixture_columns(j)%column_id = 210100_int64 + int(17*j,int64)
      fixture_columns(j)%template_id = fixture_templates(1)%template_id
      fixture_columns(j)%parameter_ref = 1_int64
      fixture_columns(j)%state_handle = int(j,int64)
      fixture_columns(j)%forcing_handle = int(j,int64)
      fixture_columns(j)%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
    end do
  end subroutine configure_fixture

  subroutine configure_seed(state)
    type(fmr_b110_physical_state_t), intent(out) :: state
    state%active_nodes = 1
    allocate(state%pressure_head(1), state%water_content(1))
    state%pressure_head = -75.0_real64
    state%water_content = 0.25_real64
    state%ponding_depth = 0.0_real64
    state%groundwater_level = -2.0_real64
  end subroutine configure_seed

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

  logical function all_ready(states) result(ready)
    type(kernel_committed_state_t), intent(in) :: states(:)
    integer :: j
    ready = .true.
    do j = 1, size(states)
      if (.not. states(j)%ready()) then
        ready = .false.
        return
      end if
    end do
  end function all_ready

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A)') 'FAIL: '//trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fmr21_restart_state_schema_binding
