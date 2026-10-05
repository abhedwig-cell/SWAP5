program test_f_mig431_int13_capacity_event
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_rutter_interception_process
  implicit none

  type(rutter_state_t) :: accepted, split_state
  type(rutter_interval_input_t) :: input
  type(rutter_interval_result_t) :: one_day, first_event, after_event
  type(rutter_diagnostics_t) :: d
  real(real64) :: one_day_residual, split_residual, split_net

  input%gross_rain_cm_per_day = 1.0_real64
  input%vegetation_cover_fraction = 1.0_real64
  input%canopy_storage_capacity_cm = 0.1_real64
  input%interception_evaporation_capacity_cm_per_day = 0.0_real64
  input%interval_days = 1.0_real64
  accepted%canopy_storage_cm = 0.0_real64

  call evaluate_rutter_interval(accepted, input, one_day, d)
  call require(d%result_produced, 1)
  one_day_residual = input%gross_rain_cm_per_day * input%interval_days - &
      one_day%net_rain_cm_per_day * input%interval_days - &
      (one_day%candidate_state%canopy_storage_cm - accepted%canopy_storage_cm) - &
      one_day%reservoir_outflow_cm_per_day * input%interval_days

  ! Drive the advertised fill event explicitly, then process the rest of the
  ! same immutable rain window from the accepted full-canopy state.
  input%interval_days = one_day%maximum_event_timestep_days
  call evaluate_rutter_interval(accepted, input, first_event, d)
  call require(d%result_produced, 2)
  split_state = first_event%candidate_state
  input%interval_days = 1.0_real64 - one_day%maximum_event_timestep_days
  call evaluate_rutter_interval(split_state, input, after_event, d)
  call require(d%result_produced, 3)
  split_net = first_event%net_rain_cm_per_day * one_day%maximum_event_timestep_days + &
      after_event%net_rain_cm_per_day * input%interval_days
  split_residual = 1.0_real64 - split_net - &
      (after_event%candidate_state%canopy_storage_cm - accepted%canopy_storage_cm) - &
      (first_event%reservoir_outflow_cm_per_day * one_day%maximum_event_timestep_days + &
       after_event%reservoir_outflow_cm_per_day * input%interval_days)

  call require(abs(one_day_residual - 0.9_real64) < 1.0e-12_real64, 4)
  call require(abs(split_residual) < 1.0e-12_real64, 5)
  call require(abs(split_net - 0.9_real64) < 1.0e-12_real64, 6)
  write(*,'(A,ES24.16)') 'ONE_DAY_UNACCOUNTED_CM=', one_day_residual
  write(*,'(A,ES24.16)') 'EVENT_SPLIT_CLOSURE_CM=', split_residual
  write(*,'(A)') 'F_MIG431_INT13_CAPACITY_EVENT_FALSIFICATION=PASS'

contains

  subroutine require(ok, n)
    logical, intent(in) :: ok
    integer, intent(in) :: n
    if (.not. ok) then
      write(*,'(A,I0)') 'FAIL=', n
      error stop 1
    end if
  end subroutine

end program
