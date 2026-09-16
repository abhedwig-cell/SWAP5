program test_fwof40_consumer
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_canonical_contracts, only: canonical_numerical_config_t, CANONICAL_STATUS_TRANSACTION_FAILED
  use mod_kernel_transactions
  use mod_wofost_crop_owner_state, only: wofost_crop_owner_state_t
  use mod_wofost_one_day_structural_evolution, only: wofost_one_day_forcing_t
  use mod_fmr_wofost_accepted_window_lineage, only: fmr_wofost_accepted_window_t
  use mod_fmr_wofost_crop_transaction
  use mod_fwof34_test_model
  use mod_fwof40_restart_fixture
  use mod_fwof40_external_crop_restart_adapter
  implicit none
  character(len=512) :: input_path, output_path
  type(kernel_committed_state_t) :: physical, crop
  type(kernel_executor_t) :: physical_kernel, stale_kernel, next_kernel
  type(fwof34_model_t), target :: physical_model
  type(fwof34_parameters_t) :: physical_parameters
  type(fwof34_forcing_t) :: physical_forcing
  type(canonical_numerical_config_t) :: physical_config, crop_config
  type(fmr_wofost_accepted_window_t) :: window1, window2
  type(wofost_crop_owner_state_t) :: seed
  type(fmr_wofost_crop_transaction_parameters_t) :: crop_parameters
  type(wofost_one_day_forcing_t) :: daily_forcing
  type(fmr_wofost_crop_transaction_model_t), target :: stale_model, next_model
  type(fmr_wofost_crop_event_forcing_t) :: stale_forcing
  type(kernel_candidate_state_t) :: stale_candidate
  type(kernel_result_t) :: stale_result
  type(kernel_diagnostics_t) :: stale_diagnostics
  logical :: ok, written
  integer :: status

  call get_command_argument(1, input_path)
  call get_command_argument(2, output_path)
  call fwof40_require(len_trim(input_path) > 0 .and. len_trim(output_path) > 0, 'consumer paths')

  call read_fwof40_crop_restart_artifact(trim(input_path), crop, ok, status)
  call fwof40_require(ok, 'consumer restore available')
  call fwof40_require(status == FWO40_EXTERNAL_OK, 'consumer restore status')
  call fwof40_require(crop%ready(), 'consumer restored crop ready')
  call fwof40_require(crop%current_lineage_id() == 4001_int64, 'restored crop lineage')
  call fwof40_require(crop%current_revision() == 1_int64, 'restored crop revision one')
  write(*,'(A)') 'FWOF40_FRESH_PROCESS_RECONSTRUCTION=PASS'

  ! Recreate source events independently. None of this state came through the
  ! restart artifact. Window 1 is used only to prove stale receipt rejection;
  ! window 2 is the new event that must continue normally.
  call fwof40_setup_physical_source(physical, physical_kernel, physical_model, physical_parameters, &
       physical_forcing, physical_config, 40001_int64, 100.0_real64)
  call fwof40_build_accepted_event(physical_kernel, physical, physical_parameters, physical_forcing, physical_config, &
       100.0_real64, 101.0_real64, 3.0_real64, 5.0_real64, window1)
  call fwof40_build_accepted_event(physical_kernel, physical, physical_parameters, physical_forcing, physical_config, &
       101.0_real64, 102.0_real64, 4.0_real64, 6.0_real64, window2)
  call fwof40_setup_crop_inputs(seed, crop_parameters, crop_config, daily_forcing)

  call fwof40_prepare_crop_forcing(window1, daily_forcing, stale_forcing)
  call stale_kernel%bind_model(stale_model)
  call stale_kernel%advance_interval(crop_parameters, crop, stale_forcing, crop_config, 101.0_real64, 102.0_real64, &
       stale_result, stale_candidate, stale_diagnostics)
  call fwof40_require(stale_result%status == CANONICAL_STATUS_TRANSACTION_FAILED, 'restored stale event rejected')
  call fwof40_require(.not. stale_candidate%ready(), 'restored stale event no candidate')
  call fwof40_require(crop%current_revision() == 1_int64, 'stale replay leaves revision unchanged')
  write(*,'(A)') 'FWOF40_RESTORED_RECEIPT_REJECTS_STALE_EVENT=PASS'

  call fwof40_commit_crop_event(next_kernel, next_model, crop_parameters, crop_config, crop, window2, daily_forcing, &
       101.0_real64, 102.0_real64)
  call fwof40_retire_window(window2, crop)
  call fwof40_require(crop%current_revision() == 2_int64, 'consumer revision two')
  call write_fwof40_crop_restart_artifact(trim(output_path), crop, written, status)
  call fwof40_require(written .and. status == FWO40_EXTERNAL_OK, 'consumer endpoint artifact')
  write(*,'(A)') 'FWOF40_NEW_EVENT_CONTINUES_AFTER_RESTART=PASS'
end program test_fwof40_consumer
