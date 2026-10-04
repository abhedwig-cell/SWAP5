program test_f_mig431_int13_rutter_source_window
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_rutter_interception_process
  use mod_rutter_event_integrator, only: evaluate_rutter_forcing_interval
  use mod_interception_source_window_runtime, only: interception_source_window_t, initialize_interception_window
  use mod_rutter_source_window_processor
  use mod_fmr_rutter_source_window_application
  use mod_b110_dynamic_top_boundary_provider, only: b110_dynamic_top_boundary_request_t
  use mod_crop_root_uptake_input_contract, only: crop_root_uptake_input_t
  implicit none

  real(real64), parameter :: tol = 2.0e-13_real64
  type(interception_source_window_t) :: window
  type(rutter_source_state_t) :: state, candidate, restored
  type(rutter_source_trial_t) :: trial_a, trial_b
  type(rutter_source_restart_t) :: restart
  type(fmr_rutter_source_application_diagnostics_t) :: app_diagnostics
  type(b110_dynamic_top_boundary_request_t) :: base_top, bound_top
  type(crop_root_uptake_input_t) :: base_root, bound_root
  type(rutter_interval_input_t) :: forcing
  type(rutter_interval_result_t) :: result_a, result_b
  type(rutter_diagnostics_t) :: diagnostics
  integer :: status, event_substeps
  real(real64) :: coarse_water, refined_water, coarse_ptra, refined_ptra, storage_a, storage_b

  ! Legacy one-call semantics expose the capacity event but lose overflow if
  ! the caller does not split the forcing interval at that event.
  block
    type(rutter_state_t) :: empty
    type(rutter_interval_result_t) :: legacy
    empty%canopy_storage_cm = 0.0_real64
    forcing = rutter_interval_input_t()
    forcing%gross_rain_cm_per_day = 1.0_real64
    forcing%vegetation_cover_fraction = 1.0_real64
    forcing%canopy_storage_capacity_cm = 0.1_real64
    forcing%interval_days = 1.0_real64
    call evaluate_rutter_interval(empty, forcing, legacy, diagnostics)
    call require(diagnostics%result_produced, 1)
    call require(abs(legacy%maximum_event_timestep_days - 0.1_real64) < tol, 2)
    call require(abs(legacy%net_rain_cm_per_day) < tol, 3)
    call evaluate_rutter_forcing_interval(empty, forcing, result_a, diagnostics, event_substeps)
    call require(diagnostics%result_produced, 4)
    call require(event_substeps == 2, 5)
    call require(abs(result_a%net_rain_cm_per_day - 0.9_real64) < tol, 6)
    call require(abs(result_a%candidate_state%canopy_storage_cm - 0.1_real64) < tol, 7)
    call require(abs(result_a%candidate_state%canopy_storage_cm - 0.0_real64 - &
      (1.0_real64 - result_a%net_rain_cm_per_day - result_a%reservoir_outflow_cm_per_day)) < tol, 8)
  end block

  ! Heavy rain with non-zero wet-canopy evaporation reaches capacity, then
  ! overflows while evaporation and canopy storage remain separately booked.
  block
    type(rutter_state_t) :: empty
    empty%canopy_storage_cm = 0.0_real64
    forcing = rutter_interval_input_t()
    forcing%gross_rain_cm_per_day = 1.0_real64
    forcing%vegetation_cover_fraction = 1.0_real64
    forcing%canopy_storage_capacity_cm = 0.1_real64
    forcing%interception_evaporation_capacity_cm_per_day = 0.05_real64
    forcing%interval_days = 1.0_real64
    call evaluate_rutter_forcing_interval(empty, forcing, result_a, diagnostics, event_substeps)
    call require(diagnostics%result_produced .and. event_substeps == 2, 59)
    call require(abs(result_a%net_rain_cm_per_day - 0.85_real64) < tol, 60)
    call require(abs(result_a%reservoir_outflow_cm_per_day - 0.05_real64) < tol, 61)
    call require(abs(result_a%candidate_state%canopy_storage_cm - 0.1_real64) < tol, 62)
    call require(abs(result_a%candidate_state%canopy_storage_cm - 1.0_real64 + &
      result_a%net_rain_cm_per_day + result_a%reservoir_outflow_cm_per_day) < tol, 63)
  end block

  ! Event integration handles rain-stop drydown analytically and conserves
  ! interception evaporation exactly to floating-point roundoff.
  state = rutter_source_state_t()
  call initialize_interception_window(11_int64, 0.0_real64, 1.0_real64, 0.0_real64, window, status)
  call require(status == 0, 9)
  call initialize_rutter_source_state(window, 0.05_real64, state, status)
  call require(status == RUTTER_WINDOW_OK, 10)
  forcing = rutter_interval_input_t()
  forcing%vegetation_cover_fraction = 1.0_real64
  forcing%canopy_storage_capacity_cm = 0.1_real64
  forcing%interception_evaporation_capacity_cm_per_day = 0.1_real64
  forcing%potential_transpiration_dry_cm_per_day = 0.01_real64
  forcing%potential_transpiration_wet_cm_per_day = 0.002_real64
  call prepare_rutter_source_trial(window, state, 1.0_real64, forcing, result_a, trial_a, diagnostics, status)
  call require(status == RUTTER_WINDOW_OK, 11)
  call require(abs(result_a%reservoir_outflow_cm_per_day - 0.05_real64) < tol, 13)
  call require(abs(result_a%candidate_state%canopy_storage_cm) < tol, 14)
  call require(abs(result_a%wet_canopy_fraction - 0.5_real64) < tol, 44)
  call require(abs(result_a%potential_transpiration_cm_per_day - 0.006_real64) < tol, 45)

  ! A capacity decrease releases excess canopy liquid as throughfall.
  forcing%interception_evaporation_capacity_cm_per_day = 0.0_real64
  forcing%canopy_storage_capacity_cm = 0.025_real64
  call prepare_rutter_source_trial(window, state, 1.0_real64, forcing, result_a, trial_a, diagnostics, status)
  call require(status == RUTTER_WINDOW_OK, 15)
  call require(abs(result_a%net_rain_cm_per_day - 0.025_real64) < tol, 16)
  call require(abs(result_a%candidate_state%canopy_storage_cm - 0.025_real64) < tol, 17)

  ! Detailed-meteorology records are separate immutable source windows while
  ! canopy storage continues across their boundary.
  forcing = rutter_interval_input_t()
  forcing%vegetation_cover_fraction = 1.0_real64
  forcing%canopy_storage_capacity_cm = 0.1_real64
  call initialize_interception_window(31_int64, 0.0_real64, 0.5_real64, 0.05_real64, window, status)
  call require(status == 0, 46)
  call initialize_rutter_source_state(window, 0.0_real64, state, status)
  call require(status == RUTTER_WINDOW_OK, 47)
  call prepare_rutter_source_trial(window, state, 0.5_real64, forcing, result_a, trial_a, diagnostics, status)
  call require(status == RUTTER_WINDOW_OK, 48)
  call accept_rutter_source_trial(window, state, trial_a, candidate, status)
  call require(status == RUTTER_WINDOW_OK, 49)
  call require(abs(candidate%canopy_storage() - 0.05_real64) < tol, 50)
  call initialize_interception_window(32_int64, 0.5_real64, 1.0_real64, 0.15_real64, window, status)
  call require(status == 0, 51)
  call initialize_rutter_source_state(window, candidate%canopy_storage(), state, status)
  call require(status == RUTTER_WINDOW_OK, 52)
  call prepare_rutter_source_trial(window, state, 1.0_real64, forcing, result_a, trial_a, diagnostics, status)
  call require(status == RUTTER_WINDOW_OK, 53)
  call require(abs(result_a%net_rain_cm_per_day * 0.5_real64 - 0.1_real64) < tol, 54)
  call accept_rutter_source_trial(window, state, trial_a, candidate, status)
  call require(status == RUTTER_WINDOW_OK, 55)
  call require(abs(candidate%canopy_storage() - 0.1_real64) < tol, 56)

  ! Richards-style accepted endpoint patterns may differ. The Rutter source
  ! trajectory, final storage and integrated surface forcing must not.
  call run_pattern([0.25_real64, 0.5_real64, 1.0_real64], coarse_water, coarse_ptra, storage_a)
  call run_pattern([0.1_real64, 0.3_real64, 0.55_real64, 1.0_real64], refined_water, refined_ptra, storage_b)
  call require(abs(coarse_water - refined_water) < tol, 18)
  call require(abs(coarse_ptra - refined_ptra) < tol, 19)
  call require(abs(storage_a - storage_b) < tol, 20)
  call require(abs(coarse_water - 0.9_real64) < tol, 21)
  call require(abs(coarse_ptra - 0.002_real64) < tol, 22)
  call require(abs(storage_a - 0.1_real64) < tol, 23)

  ! Mid-window restart persists physical storage and accepted source progress;
  ! replay from the restored state equals uninterrupted execution.
  call initialize_interception_window(21_int64, 0.0_real64, 1.0_real64, 1.0_real64, window, status)
  call require(status == 0, 24)
  call initialize_rutter_source_state(window, 0.0_real64, state, status)
  forcing = rutter_interval_input_t()
  forcing%vegetation_cover_fraction = 1.0_real64
  forcing%canopy_storage_capacity_cm = 0.1_real64
  call prepare_rutter_source_trial(window, state, 0.25_real64, forcing, result_a, trial_a, diagnostics, status)
  call require(status == RUTTER_WINDOW_OK, 25)
  call accept_rutter_source_trial(window, state, trial_a, candidate, status)
  call require(status == RUTTER_WINDOW_OK, 26)
  call export_rutter_source_restart(window, candidate, restart, status)
  call require(status == RUTTER_WINDOW_OK, 27)
  call restore_rutter_source_restart(restart, window, restored, status)
  call require(status == RUTTER_WINDOW_OK, 28)
  call require(abs(restored%canopy_storage() - 0.1_real64) < tol, 29)
  call require(abs(restored%accepted_until() - 0.25_real64) < tol, 30)

  ! Prepare two alternative trials from the same accepted origin. Discard A;
  ! accepting B must advance only B's interval once.
  call prepare_rutter_source_trial(window, restored, 0.5_real64, forcing, result_a, trial_a, diagnostics, status)
  call require(status == RUTTER_WINDOW_OK, 31)
  call prepare_rutter_source_trial(window, restored, 0.75_real64, forcing, result_b, trial_b, diagnostics, status)
  call require(status == RUTTER_WINDOW_OK, 32)
  call require(abs(restored%accepted_until() - 0.25_real64) < tol, 33)
  call accept_rutter_source_trial(window, restored, trial_b, candidate, status)
  call require(status == RUTTER_WINDOW_OK, 34)
  call require(abs(candidate%accepted_until() - 0.75_real64) < tol, 35)
  call accept_rutter_source_trial(window, candidate, trial_a, state, status)
  call require(status == RUTTER_WINDOW_ORDER, 57)
  call require(abs(state%accepted_until() - 0.75_real64) < tol, 58)
  call accept_rutter_source_trial(window, restored, trial_a, state, status)
  call require(status == RUTTER_WINDOW_OK, 36)
  call require(abs(state%accepted_until() - 0.5_real64) < tol, 37)
  call require(abs(restored%accepted_until() - 0.25_real64) < tol, 38)

  ! The application seam binds event-integrated output while keeping the
  ! physical/progress candidate uncommitted for the enclosing transaction.
  call initialize_interception_window(41_int64, 0.0_real64, 1.0_real64, 1.0_real64, window, status)
  call require(status == 0, 64)
  call initialize_rutter_source_state(window, 0.0_real64, state, status)
  call require(status == RUTTER_WINDOW_OK, 65)
  forcing = rutter_interval_input_t()
  forcing%vegetation_cover_fraction = 1.0_real64
  forcing%canopy_storage_capacity_cm = 0.1_real64
  forcing%potential_transpiration_dry_cm_per_day = 0.01_real64
  forcing%potential_transpiration_wet_cm_per_day = 0.002_real64
  base_top = b110_dynamic_top_boundary_request_t()
  base_top%step_duration_day = 1.0_real64
  base_top%precipitation_rate_cm_per_day = 8.0_real64
  base_top%irrigation_rate_cm_per_day = 9.0_real64
  base_root = crop_root_uptake_input_t()
  base_root%crop_emerged = .true.
  base_root%rooted_nodes = 1
  allocate(base_root%cumulative_root_fraction(2))
  base_root%cumulative_root_fraction = [0.0_real64, 1.0_real64]
  call fmr_prepare_rutter_source_window_application(window, state, 1.0_real64, forcing, base_top, base_root, 1, &
       result_a, trial_a, bound_top, bound_root, app_diagnostics)
  call require(app_diagnostics%status == FMR_RUTTER_APP_OK .and. app_diagnostics%result_produced, 66)
  call require(abs(bound_top%precipitation_rate_cm_per_day - 0.9_real64) < tol, 67)
  call require(abs(bound_root%potential_transpiration - 0.002_real64) < tol, 68)
  call require(abs(state%canopy_storage() - 0.0_real64) < tol .and. &
    abs(state%accepted_until() - 0.0_real64) < tol, 69)
  call require(abs(result_a%candidate_state%canopy_storage_cm - 0.1_real64) < tol, 70)

  print '(A)', 'F-MIG431-INT13_RUTTER_SOURCE_WINDOW_PASS'

contains

  subroutine run_pattern(endpoints, integrated_rain, integrated_ptra, final_storage)
    real(real64), intent(in) :: endpoints(:)
    real(real64), intent(out) :: integrated_rain, integrated_ptra, final_storage
    type(interception_source_window_t) :: local_window
    type(rutter_source_state_t) :: local_state, next_state
    type(rutter_source_trial_t) :: local_trial
    type(rutter_interval_input_t) :: local_forcing
    type(rutter_interval_result_t) :: local_result
    type(rutter_diagnostics_t) :: local_diagnostics
    real(real64) :: previous, dt
    integer :: local_status, i
    call initialize_interception_window(12_int64, 0.0_real64, 1.0_real64, 1.0_real64, local_window, local_status)
    call require(local_status == 0, 40)
    call initialize_rutter_source_state(local_window, 0.0_real64, local_state, local_status)
    call require(local_status == RUTTER_WINDOW_OK, 41)
    local_forcing = rutter_interval_input_t()
    local_forcing%vegetation_cover_fraction = 1.0_real64
    local_forcing%canopy_storage_capacity_cm = 0.1_real64
    local_forcing%potential_transpiration_dry_cm_per_day = 0.01_real64
    local_forcing%potential_transpiration_wet_cm_per_day = 0.002_real64
    integrated_rain = 0.0_real64
    integrated_ptra = 0.0_real64
    previous = 0.0_real64
    do i = 1, size(endpoints)
      call prepare_rutter_source_trial(local_window, local_state, endpoints(i), local_forcing, &
                                       local_result, local_trial, local_diagnostics, local_status)
      call require(local_status == RUTTER_WINDOW_OK, 42)
      dt = endpoints(i) - previous
      integrated_rain = integrated_rain + local_result%net_rain_cm_per_day * dt
      integrated_ptra = integrated_ptra + local_result%potential_transpiration_cm_per_day * dt
      call accept_rutter_source_trial(local_window, local_state, local_trial, next_state, local_status)
      call require(local_status == RUTTER_WINDOW_OK, 43)
      local_state = next_state
      previous = endpoints(i)
    end do
    final_storage = local_state%canopy_storage()
  end subroutine run_pattern

  subroutine require(ok, case_id)
    logical, intent(in) :: ok
    integer, intent(in) :: case_id
    if (.not. ok) then
      write(*, '(A,I0)') 'INT13_FAIL=', case_id
      error stop 1
    end if
  end subroutine require

end program test_f_mig431_int13_rutter_source_window
