program test_fpm08d7_restart_lifecycle
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_NUMERICAL_CONTINUATION_NONE, FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  use mod_fmr_optional_state_layouts, only: FMR_OPTIONAL_STATE_FIXED_WEIR_SURFACE_WATER
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, &
       fmr_b110_fixed_weir_surface_water_state_t, fmr_new_b110_fixed_weir_surface_water_committed_state
  use mod_fmr_restart_state_contract, only: fmr_restart_state_matches_template
  use mod_fmr_committed_restart, only: fmr_committed_restart_bundle_t, fmr_export_committed_restart, &
       fmr_restore_committed_restart, FMR_RESTART_OK, FMR_RESTART_TEMPLATE_MISMATCH, &
       FMR_RESTART_PARAMETER_SET_MISMATCH
  implicit none

  integer(int64), parameter :: column_id = 807001_int64
  integer(int64), parameter :: parameter_set_identity = 8079001_int64
  real(real64), parameter :: committed_time = 8123.375_real64

  type(fmr_logical_column_t) :: columns(1)
  type(fmr_template_t) :: templates(1), plain_template, history_template
  type(kernel_committed_state_t) :: source_states(1), restored_states(1), rejected_states(1)
  type(fmr_b110_fixed_weir_surface_water_state_t) :: initial
  type(fmr_b110_physical_state_t) :: plain
  type(fmr_committed_restart_bundle_t) :: bundle, roundtrip
  class(transaction_state_t), allocatable :: snapshot
  logical :: ok, exported, restored
  integer :: status

  call configure_template(templates(1))
  call configure_column(columns(1), templates(1))
  call configure_state(initial)
  call fmr_new_b110_fixed_weir_surface_water_committed_state(source_states(1), column_id, initial, committed_time, ok)
  call require(ok .and. source_states(1)%ready(), 'D7 committed-state initialization')

  call fmr_export_committed_restart(columns, templates, source_states, parameter_set_identity, bundle, exported, status)
  call require(exported .and. status == FMR_RESTART_OK, 'D7 restart export')
  call require(allocated(bundle%records) .and. size(bundle%records) == 1, 'D7 restart record count')
  call require(bundle%records(1)%lineage_id == column_id, 'export lineage')
  call require(bundle%records(1)%revision == 0_int64, 'export revision')
  call require(bundle%records(1)%time_bound, 'export time bound')
  call require(same_bits(bundle%records(1)%committed_time, committed_time), 'export committed time')
  call require(allocated(bundle%records(1)%physical_state), 'export physical payload')
  call require(fmr_restart_state_matches_template(bundle%records(1)%physical_state, templates(1)), &
       'D7 payload matches D7 template')
  call verify_d7_state(bundle%records(1)%physical_state, initial, 'export payload')
  write(*,'(A)') 'FPM08D7_RESTART_EXPORT_EXACT_STATE=PASS'

  plain_template = templates(1)
  plain_template%optional_state_layout_id = 0_int64
  call require(.not. fmr_restart_state_matches_template(bundle%records(1)%physical_state, plain_template), &
       'D7 payload rejected by plain template')
  call require(.not. fmr_restart_state_matches_template(plain, templates(1)), &
       'plain state rejected by D7 template')
  history_template = templates(1)
  history_template%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  call require(.not. fmr_restart_state_matches_template(bundle%records(1)%physical_state, history_template), &
       'D7 plus temporal history held')
  write(*,'(A)') 'FPM08D7_RESTART_LAYOUT_TYPE_FAIL_CLOSED=PASS'

  call fmr_restore_committed_restart(bundle, parameter_set_identity + 1_int64, columns, templates, rejected_states, &
       restored, status)
  call require(.not. restored .and. status == FMR_RESTART_PARAMETER_SET_MISMATCH, &
       'wrong parameter-set identity rejected')
  call require(.not. rejected_states(1)%ready(), 'parameter-set reject no target mutation')

  plain_template = templates(1)
  plain_template%optional_state_layout_id = 0_int64
  call fmr_restore_committed_restart(bundle, parameter_set_identity, columns, [plain_template], rejected_states, &
       restored, status)
  call require(.not. restored .and. status == FMR_RESTART_TEMPLATE_MISMATCH, 'wrong optional layout rejected')
  call require(.not. rejected_states(1)%ready(), 'template reject no target mutation')
  write(*,'(A)') 'FPM08D7_RESTART_REJECTION_ATOMIC=PASS'

  call fmr_restore_committed_restart(bundle, parameter_set_identity, columns, templates, restored_states, restored, status)
  call require(restored .and. status == FMR_RESTART_OK, 'D7 restart restore')
  call require(restored_states(1)%ready(), 'D7 restored state ready')
  call require(restored_states(1)%current_lineage_id() == source_states(1)%current_lineage_id(), 'restored lineage')
  call require(restored_states(1)%current_revision() == source_states(1)%current_revision(), 'restored revision')
  call restored_states(1)%snapshot(snapshot, ok)
  call require(ok .and. allocated(snapshot), 'restored snapshot')
  call verify_d7_state(snapshot, initial, 'restored payload')

  call fmr_export_committed_restart(columns, templates, restored_states, parameter_set_identity, roundtrip, exported, status)
  call require(exported .and. status == FMR_RESTART_OK, 'restored re-export')
  call require(roundtrip%records(1)%lineage_id == bundle%records(1)%lineage_id, 'roundtrip lineage')
  call require(roundtrip%records(1)%revision == bundle%records(1)%revision, 'roundtrip revision')
  call require(roundtrip%records(1)%time_bound .eqv. bundle%records(1)%time_bound, 'roundtrip time binding')
  call require(same_bits(roundtrip%records(1)%committed_time, bundle%records(1)%committed_time), 'roundtrip committed time')
  call verify_d7_state(roundtrip%records(1)%physical_state, initial, 'roundtrip payload')
  write(*,'(A)') 'FPM08D7_RESTART_ROUNDTRIP_EXACT=PASS'
  write(*,'(A)') 'FPM08D7_RESTART_LIFECYCLE_OWNER_TEST PASS'

contains

  subroutine configure_template(template)
    type(fmr_template_t), intent(out) :: template
    template%template_id = 80701_int64
    template%physics_topology_id = 80702_int64
    template%vertical_layout_id = 80703_int64
    template%state_layout_id = 80704_int64
    template%solver_interface_id = 80705_int64
    template%optional_state_layout_id = FMR_OPTIONAL_STATE_FIXED_WEIR_SURFACE_WATER
    template%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_NONE
    template%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine configure_template

  subroutine configure_column(column, template)
    type(fmr_logical_column_t), intent(out) :: column
    type(fmr_template_t), intent(in) :: template
    column%column_id = column_id
    column%template_id = template%template_id
    column%parameter_ref = 1_int64
    column%state_handle = 1_int64
    column%forcing_handle = 1_int64
    column%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine configure_column

  subroutine configure_state(state)
    type(fmr_b110_fixed_weir_surface_water_state_t), intent(out) :: state
    state%active_nodes = 3
    allocate(state%pressure_head(3), state%water_content(3))
    state%pressure_head = [-12.5_real64, -87.25_real64, -314.0_real64]
    state%water_content = [0.381_real64, 0.297_real64, 0.244_real64]
    state%ponding_depth = 0.037_real64
    state%groundwater_level = -1.875_real64
    state%surface_water%storage = 93.625_real64
  end subroutine configure_state

  subroutine verify_d7_state(state, expected, label)
    class(transaction_state_t), intent(in) :: state
    type(fmr_b110_fixed_weir_surface_water_state_t), intent(in) :: expected
    character(len=*), intent(in) :: label
    select type (typed => state)
    type is (fmr_b110_fixed_weir_surface_water_state_t)
      call require(typed%active_nodes == expected%active_nodes, trim(label)//' active nodes')
      call require(allocated(typed%pressure_head) .and. allocated(typed%water_content), trim(label)//' arrays')
      call require(size(typed%pressure_head) == size(expected%pressure_head), trim(label)//' head shape')
      call require(size(typed%water_content) == size(expected%water_content), trim(label)//' water shape')
      call require(all(same_bits(typed%pressure_head, expected%pressure_head)), trim(label)//' pressure heads')
      call require(all(same_bits(typed%water_content, expected%water_content)), trim(label)//' water contents')
      call require(same_bits(typed%ponding_depth, expected%ponding_depth), trim(label)//' ponding')
      call require(same_bits(typed%groundwater_level, expected%groundwater_level), trim(label)//' groundwater')
      call require(.not. allocated(typed%snow), trim(label)//' no snow payload')
      call require(same_bits(typed%surface_water%storage, expected%surface_water%storage), trim(label)//' SWST')
    class default
      call require(.false., trim(label)//' dynamic type')
    end select
  end subroutine verify_d7_state

  pure elemental logical function same_bits(a, b) result(equal)
    real(real64), intent(in) :: a, b
    integer(int64) :: ia, ib
    ia = transfer(a, ia)
    ib = transfer(b, ib)
    equal = ia == ib
  end function same_bits

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FPM08D7_RESTART_TEST_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fpm08d7_restart_lifecycle
