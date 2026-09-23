program test_ppa_irr_fixed_input_application
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_ppa_irr_fixed_input_normalization, only: normalize_fixed_irrigation_input
  use mod_irrigation_process
  implicit none

  integer, parameter :: vector_count = 100000, active_nodes = 12
  type(irrigation_parameters_t) :: parameters
  type(irrigation_state_t) :: committed, candidate
  type(irrigation_management_request_t) :: request
  type(irrigation_flux_result_t) :: fluxes
  type(irrigation_diagnostics_t) :: diagnostics
  real(real64) :: depth_mm, rate_mm_per_hour, depth_cm, rate_cm_day, duration
  real(real64) :: target_duration, unit_value, expected_gross_cm, tolerance
  integer(int64) :: random_state
  integer :: i, application_type, ssdi_count, first_node, last_node, node

  parameters%fixed_irrigation_enabled = .true.
  parameters%active_nodes = active_nodes
  allocate(parameters%fixed_events(1))
  committed = irrigation_state_t()
  random_state = 20260923_int64

  do i = 1, vector_count
    application_type = modulo(i-1, 3)
    ssdi_count = 1+modulo(i, 5)
    first_node = 1+modulo(i, active_nodes-ssdi_count+1)
    last_node = first_node+ssdi_count-1
    call random_unit(random_state, unit_value)
    depth_mm = 0.01_real64+29.99_real64*unit_value
    call random_unit(random_state, unit_value)
    target_duration = 0.05_real64+0.94_real64*unit_value
    rate_mm_per_hour = depth_mm/(24.0_real64*target_duration)
    call normalize_fixed_irrigation_input(depth_mm, rate_mm_per_hour, .true., application_type, ssdi_count, &
                                          depth_cm, rate_cm_day, duration)

    parameters%ssdi_first_node = first_node
    parameters%ssdi_last_node = last_node
    parameters%fixed_events(1)%event_time = 0.0_real64
    parameters%fixed_events(1)%application_type = application_type
    parameters%fixed_events(1)%depth = depth_cm
    parameters%fixed_events(1)%rate = rate_cm_day
    parameters%fixed_events(1)%concentration = 12.5_real64
    request%t0 = 0.0_real64
    request%t1 = request%t0+duration
    expected_gross_cm = 0.1_real64*depth_mm
    tolerance = 16.0_real64*epsilon(expected_gross_cm)*max(1.0_real64, expected_gross_cm)

    call evaluate_fixed_irrigation_interval(parameters, committed, request, candidate, fluxes, diagnostics)
    call require(diagnostics%status == IRRIGATION_OK, 1)
    call require(fluxes%applied .and. fluxes%event_started .and. fluxes%event_finished, 2)
    call require(candidate%next_fixed_event_index == 2 .and. .not. candidate%active_event, 3)
    call require(abs(fluxes%external_inflow_amount-expected_gross_cm) <= tolerance, 4)
    call require(abs(fluxes%event_duration-duration) <= 4.0_real64*epsilon(duration), 5)
    if (application_type == IRRIGATION_APPLICATION_SSDI) then
      call require(size(fluxes%subsurface_source) == active_nodes, 6)
      do node = 1, active_nodes
        if (node >= first_node .and. node <= last_node) then
          call require(abs(fluxes%subsurface_source(node)-rate_cm_day) <= &
                       4.0_real64*epsilon(rate_cm_day), 10)
        else
          call require(abs(fluxes%subsurface_source(node)) <= 0.0_real64, 11)
        end if
      end do
    else
      call require(abs(fluxes%surface_gross_rate-rate_cm_day) <= 4.0_real64*epsilon(rate_cm_day), 7)
      call require(abs(fluxes%concentration-12.5_real64) <= 4.0_real64*epsilon(12.5_real64), 8)
    end if
  end do

  print '(A)', 'PPA_IRR_FIXED_NORMALIZE_TO_APPLICATION_100000=PASS'
  print '(A)', 'PPA_IRR_FIXED_EVENT_GROSS_DEPTH_RECONSTRUCTION=PASS'
  print '(A)', 'PPA_IRR_FIXED_SURFACE_AND_SSDI_APPLICATIONS=PASS'
  print '(A)', 'PPA_IRR_FIXED_INPUT_APPLICATION_SOURCE_ORACLE=PASS'

contains

  subroutine random_unit(state, value)
    integer(int64), intent(inout) :: state
    real(real64), intent(out) :: value
    state = modulo(state*48271_int64, 2147483647_int64)
    value = real(modulo(state, 1000001_int64), real64)/1000000.0_real64
  end subroutine random_unit

  subroutine require(condition, code)
    logical, intent(in) :: condition
    integer, intent(in) :: code
    if (.not. condition) then
      write(*, '(A,I0)') 'PPA_IRR_FIXED_INPUT_APPLICATION_FAILURE=', code
      error stop 1
    end if
  end subroutine require

end program test_ppa_irr_fixed_input_application
