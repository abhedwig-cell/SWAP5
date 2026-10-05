program test_mig431_crop_reference_observation
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: iso_fortran_env, only: int64
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_state_t, &
       fmr_new_b110_committed_state
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t
  use mod_soil_temperature_contract, only: initialize_soil_temperature_state, SOIL_TEMP_OK
  use mod_crop_calendar_management_process, only: crop_calendar_management_observation_t
  use mod_fmr_crop_calendar_reference_observation
  implicit none
  type(fmr_b110_physical_parameters_t) :: parameters
  type(fmr_b110_physical_state_t) :: state
  type(crop_calendar_management_observation_t) :: observation
  type(kernel_committed_state_t) :: committed
  type(fmr_serialized_column_result_t) :: result
  logical :: ready
  integer :: status

  parameters%active_nodes = 2
  parameters%dz = [10.0_real64,20.0_real64]
  state%active_nodes = 2
  state%pressure_head = [-10.0_real64,-100.0_real64]
  call bind_crop_calendar_reference_observation(parameters,state,0.0_real64,15.0_real64, &
       30.0_real64,10.0_real64,16.0_real64,observation,status)
  if (status /= CROP_REFERENCE_OBSERVATION_INVALID) error stop 1
  parameters%soil_temperature_active = .true.
  allocate(state%soil_temperature)
  call initialize_soil_temperature_state([7.0_real64,12.0_real64],state%soil_temperature,status)
  if (status /= SOIL_TEMP_OK) error stop 2
  call bind_crop_calendar_reference_observation(parameters,state,0.0_real64,15.0_real64, &
       30.0_real64,10.0_real64,16.0_real64,observation,status)
  if (status /= CROP_REFERENCE_OBSERVATION_OK .or. &
      abs(observation%sowing_average_head_cm+10.0_real64**(4.0_real64/3.0_real64)) > 1.e-12_real64 .or. &
      observation%sowing_soil_temperature_c /= 7.0_real64) error stop 3
  call fmr_new_b110_committed_state(committed,42_int64,state,100.0_real64,ready)
  if (.not. ready) error stop 4
  result%column_id = 42_int64
  result%final_revision = 0_int64
  result%final_committed_time = 100.0_real64
  result%final_committed_time_bound = .true.
  result%completed = .true.
  result%committed = .true.
  result%mass%complete = .true.
  call bind_accepted_crop_calendar_reference_observation(parameters,committed,result, &
       0.0_real64,15.0_real64,30.0_real64,10.0_real64,16.0_real64,observation,status)
  if (status /= CROP_REFERENCE_OBSERVATION_OK) error stop 5
  result%column_id = 43_int64
  call bind_accepted_crop_calendar_reference_observation(parameters,committed,result, &
       0.0_real64,15.0_real64,30.0_real64,10.0_real64,16.0_real64,observation,status)
  if (status /= CROP_REFERENCE_OBSERVATION_INVALID) error stop 6
  print '(a)', 'F_MIG431_CROP_REFERENCE_STATE_OBSERVATION=PASS'
end program
