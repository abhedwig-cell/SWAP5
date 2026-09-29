program test_ppa_wu04c_source_window_progress
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_fmr_vonhhbraden_source_window_progress
  implicit none

  type(fmr_vonhhbraden_source_window_progress_t) :: progress, restored_progress, bound_progress
  type(fmr_vonhhbraden_source_window_progress_t) :: restored_bound_progress
  type(fmr_vonhhbraden_source_window_restart_t) :: record, bound_record
  logical :: exported, restored, bound_exported, bound_restored
  integer :: status

  call fmr_initialize_vonhhbraden_source_window_progress(4401_int64, 100.0_real64, 101.0_real64, &
       0.075_real64, progress, status)
  call require(status == FMR_VONHHBRADEN_PROGRESS_OK .and. progress%ready(), 'initialize source window')
  call require(abs(progress%remaining_interception() - 0.075_real64) < 1.0e-14_real64, 'initial remaining aggregate')

  call progress%export_restart(record, exported)
  call require(exported .and. record%source_window_id == 4401_int64, 'export typed restart')
  call fmr_restore_vonhhbraden_source_window_progress(record, restored_progress, restored, status)
  call require(restored .and. status == FMR_VONHHBRADEN_PROGRESS_OK .and. restored_progress%ready(), &
       'restore typed restart')
  call require(abs(restored_progress%remaining_interception() - progress%remaining_interception()) < 1.0e-14_real64, &
       'restart preserves aggregate exactly')

  record%accepted_through_time = 101.1_real64
  call fmr_restore_vonhhbraden_source_window_progress(record, restored_progress, restored, status)
  call require(.not. restored .and. status == FMR_VONHHBRADEN_PROGRESS_INVALID_RESTART, 'invalid restart fails closed')
  call fmr_initialize_vonhhbraden_source_window_progress(4402_int64, 100.0_real64, 101.0_real64, &
       0.075_real64, bound_progress, status, 777_int64, 0_int64)
  call require(status == FMR_VONHHBRADEN_PROGRESS_OK .and. bound_progress%ready(), 'initialize bound receipt lineage')
  call bound_progress%export_restart(bound_record, bound_exported)
  call require(bound_exported .and. bound_record%receipt_binding_ready .and. &
       bound_record%receipt_lineage_id == 777_int64 .and. bound_record%expected_origin_revision == 0_int64, &
       'export receipt lineage binding')
  call fmr_restore_vonhhbraden_source_window_progress(bound_record, restored_bound_progress, bound_restored, status)
  call require(bound_restored .and. status == FMR_VONHHBRADEN_PROGRESS_OK .and. restored_bound_progress%ready(), &
       'restore receipt lineage binding')
  bound_record%receipt_lineage_id = 0_int64
  call fmr_restore_vonhhbraden_source_window_progress(bound_record, restored_bound_progress, bound_restored, status)
  call require(.not. bound_restored .and. status == FMR_VONHHBRADEN_PROGRESS_INVALID_RESTART, &
       'malformed receipt binding fails closed')
  print '(a)', 'PPA_WU04C_TYPED_RESTART_ROUNDTRIP=PASS'
  print '(a)', 'PPA_WU04C_TYPED_RESTART_FAIL_CLOSED=PASS'
  print '(a)', 'PPA_WU04C_RESTART_RECEIPT_BINDING=PASS'

contains

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(a,1x,a)') 'PPA_WU04C_PROGRESS_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require
end program test_ppa_wu04c_source_window_progress
