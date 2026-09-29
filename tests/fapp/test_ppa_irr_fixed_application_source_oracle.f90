program test_ppa_irr_fixed_application_source_oracle
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_irrigation_process
  implicit none

  integer, parameter :: vector_count = 100000
  type(irrigation_parameters_t) :: parameters
  type(irrigation_state_t) :: committed, candidate
  type(irrigation_management_request_t) :: request
  type(irrigation_flux_result_t) :: fluxes
  type(irrigation_diagnostics_t) :: diagnostics
  real(real64) :: depth, rate, duration, concentration, active_duration, expected_amount, value
  integer(int64) :: random_state
  integer :: i, j, app_type, first_node, last_node

  parameters%fixed_irrigation_enabled = .true.
  parameters%active_nodes = 5
  allocate(parameters%fixed_events(1))
  committed = irrigation_state_t()
  random_state = 20260923_int64

  do i = 1, vector_count
    app_type = modulo(i-1,3)
    call random_unit(random_state, depth)
    depth = 0.001_real64 + 9.999_real64*depth
    call random_unit(random_state, duration)
    duration = 0.1_real64 + 0.9_real64*duration
    rate = depth/duration
    call random_unit(random_state, concentration)
    concentration = 100.0_real64*concentration
    call random_unit(random_state, value)
    first_node = 1 + min(4, int(5*value))
    call random_unit(random_state, value)
    last_node = first_node + min(parameters%active_nodes-first_node, &
                                 int((parameters%active_nodes-first_node+1)*value))

    parameters%ssdi_first_node = first_node
    parameters%ssdi_last_node = last_node
    parameters%fixed_events(1)%event_time = 10.0_real64
    parameters%fixed_events(1)%application_type = app_type
    parameters%fixed_events(1)%depth = depth
    parameters%fixed_events(1)%rate = rate
    parameters%fixed_events(1)%concentration = concentration

    request%t0 = 10.0_real64
    request%t1 = request%t0 + parameters%fixed_events(1)%depth/parameters%fixed_events(1)%rate
    active_duration = request%t1-request%t0
    call evaluate_fixed_irrigation_interval(parameters, committed, request, candidate, fluxes, diagnostics)
    call require(diagnostics%status == IRRIGATION_OK, 1)
    call require(diagnostics%event_match .and. fluxes%applied, 2)
    call require(fluxes%event_started .and. fluxes%event_finished, 3)
    call require(candidate%next_fixed_event_index == 2 .and. .not. candidate%active_event, 4)
    call require(abs(fluxes%event_duration-depth/rate) <= 4.0_real64*epsilon(duration), 5)

    if (app_type < IRRIGATION_APPLICATION_SSDI) then
      expected_amount = rate*active_duration
      call require(abs(fluxes%surface_gross_rate-rate) <= 0.0_real64, 6)
      call require(abs(fluxes%concentration-concentration) <= 0.0_real64, 7)
      call require(.not. allocated(fluxes%subsurface_source), 8)
    else
      expected_amount = sum([(rate, j=first_node,last_node)])*active_duration
      call require(allocated(fluxes%subsurface_source), 9)
      call require(size(fluxes%subsurface_source) == parameters%active_nodes, 10)
      if (first_node > 1) &
        call require(maxval(abs(fluxes%subsurface_source(1:first_node-1))) <= 0.0_real64, 11)
      call require(maxval(abs(fluxes%subsurface_source(first_node:last_node)-rate)) <= 0.0_real64, 12)
      if (last_node < parameters%active_nodes) &
        call require(maxval(abs(fluxes%subsurface_source(last_node+1:parameters%active_nodes))) <= 0.0_real64, 13)
    end if
    call require(abs(fluxes%external_inflow_amount-expected_amount) <= &
                 16.0_real64*epsilon(expected_amount)*max(1.0_real64,abs(expected_amount)), 14)
  end do

  print '(A)', 'PPA_IRR_FIXED_APPLICATION_SOURCE_ORACLE_100000=PASS'
  print '(A)', 'PPA_IRR_FIXED_SURFACE_RATE_CONCENTRATION_AND_AMOUNT=PASS'
  print '(A)', 'PPA_IRR_FIXED_SSDI_NODE_RANGE_AND_SUM=PASS'
  print '(A)', 'PPA_IRR_FIXED_APPLICATION_SOURCE_ORACLE=PASS'

contains

  subroutine random_unit(state, result)
    integer(int64), intent(inout) :: state
    real(real64), intent(out) :: result
    state = modulo(state*48271_int64, 2147483647_int64)
    result = real(modulo(state, 1000001_int64), real64)/1000000.0_real64
  end subroutine random_unit

  subroutine require(ok, code)
    logical, intent(in) :: ok
    integer, intent(in) :: code
    if (.not. ok) then
      write(*,'(A,I0)') 'PPA_IRR_FIXED_APPLICATION_FAIL=', code
      error stop 1
    end if
  end subroutine require

end program test_ppa_irr_fixed_application_source_oracle
