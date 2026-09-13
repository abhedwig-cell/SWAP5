program test_fwof40_reference
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions
  use mod_wofost_crop_owner_state, only: wofost_crop_owner_state_t
  use mod_wofost_one_day_structural_evolution, only: wofost_one_day_forcing_t
  use mod_fmr_wofost_accepted_window_lineage, only: fmr_wofost_accepted_window_t
  use mod_fmr_wofost_crop_transaction
  use mod_fwof34_test_model
  use mod_fwof40_restart_fixture
  use mod_fwof40_external_crop_restart_adapter
  implicit none
  character(len=512) :: path
  type(kernel_committed_state_t) :: physical, crop
  type(kernel_executor_t) :: physical_kernel, crop_kernel
  type(fwof34_model_t), target :: physical_model
  type(fwof34_parameters_t) :: physical_parameters
  type(fwof34_forcing_t) :: physical_forcing
  type(canonical_numerical_config_t) :: physical_config, crop_config
  type(fmr_wofost_accepted_window_t) :: window1, window2
  type(wofost_crop_owner_state_t) :: seed
  type(fmr_wofost_crop_transaction_parameters_t) :: crop_parameters
  type(wofost_one_day_forcing_t) :: daily_forcing
  type(fmr_wofost_crop_transaction_model_t), target :: crop_model
  logical :: ok
  integer :: status

  call get_command_argument(1, path)
  call fwof40_require(len_trim(path) > 0, 'reference output path')
  call fwof40_setup_physical_source(physical, physical_kernel, physical_model, physical_parameters, &
       physical_forcing, physical_config, 40001_int64, 100.0_real64)
  call fwof40_build_accepted_event(physical_kernel, physical, physical_parameters, physical_forcing, physical_config, &
       100.0_real64, 101.0_real64, 3.0_real64, 5.0_real64, window1)
  call fwof40_build_accepted_event(physical_kernel, physical, physical_parameters, physical_forcing, physical_config, &
       101.0_real64, 102.0_real64, 4.0_real64, 6.0_real64, window2)

  call fwof40_setup_crop_inputs(seed, crop_parameters, crop_config, daily_forcing)
  call fwof40_initialize_crop_committed(seed, crop, 4001_int64, 100.0_real64)
  call fwof40_commit_crop_event(crop_kernel, crop_model, crop_parameters, crop_config, crop, window1, daily_forcing, &
       100.0_real64, 101.0_real64)
  call fwof40_retire_window(window1, crop)
  call fwof40_commit_crop_event(crop_kernel, crop_model, crop_parameters, crop_config, crop, window2, daily_forcing, &
       101.0_real64, 102.0_real64)
  call fwof40_retire_window(window2, crop)
  call fwof40_require(crop%current_revision() == 2_int64, 'reference revision two')
  call write_fwof40_crop_restart_artifact(trim(path), crop, ok, status)
  call fwof40_require(ok .and. status == FWO40_EXTERNAL_OK, 'reference artifact write')
  write(*,'(A)') 'FWOF40_CONTINUOUS_TWO_EVENT_REFERENCE=PASS'
end program test_fwof40_reference
