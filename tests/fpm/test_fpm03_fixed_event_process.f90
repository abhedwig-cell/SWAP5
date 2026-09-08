program test_fpm03_fixed_event_process
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_irrigation_process, only: fixed_irrigation_event_t, irrigation_parameters_t, irrigation_state_t, &
       irrigation_management_request_t, irrigation_flux_result_t, irrigation_diagnostics_t, &
       evaluate_fixed_irrigation_interval, IRRIGATION_OK, IRRIGATION_INVALID_EVENT, IRRIGATION_SPLIT_REQUIRED, &
       IRRIGATION_APPLICATION_SPRINKLER, IRRIGATION_APPLICATION_SURFACE, IRRIGATION_APPLICATION_SSDI
  implicit none

  call case_inactive()
  call case_no_trigger()
  call case_surface_continuation()
  call case_surface_type_zero()
  call case_ssdi_full_event()
  call case_split_no_mutation()
  call case_invalid_event()
  call case_replay_and_aba()

  write(*,'(A)') 'FPM03_FIXED_INACTIVE=PASS'
  write(*,'(A)') 'FPM03_FIXED_NO_TRIGGER=PASS'
  write(*,'(A)') 'FPM03_FIXED_SURFACE=PASS'
  write(*,'(A)') 'FPM03_FIXED_SSDI=PASS'
  write(*,'(A)') 'FPM03_FIXED_CONTINUATION=PASS'
  write(*,'(A)') 'FPM03_FIXED_SPLIT_NO_MUTATION=PASS'
  write(*,'(A)') 'FPM03_FIXED_ROLLBACK_REPLAY=PASS'
  write(*,'(A)') 'FPM03_FIXED_A_B_A=PASS'
  write(*,'(A)') 'FPM03_FIXED_B110_EQUATION_IDENTITY=PASS'
  write(*,'(A)') 'FPM03_FIXED_EVENT_PROCESS_TEST PASS'

contains

  subroutine case_inactive()
    type(irrigation_parameters_t) :: p
    type(irrigation_state_t) :: committed, candidate
    type(irrigation_management_request_t) :: req
    type(irrigation_flux_result_t) :: flux
    type(irrigation_diagnostics_t) :: diag

    req%t0 = 5.25_real64; req%t1 = 5.75_real64
    call evaluate_fixed_irrigation_interval(p, committed, req, candidate, flux, diag)
    call require(diag%status == IRRIGATION_OK, 'inactive status')
    call require(.not. flux%applied .and. .not. allocated(flux%subsurface_source), 'inactive allocation')
    call require(state_identical(committed,candidate), 'inactive state')
  end subroutine case_inactive

  subroutine case_no_trigger()
    type(irrigation_parameters_t) :: p
    type(irrigation_state_t) :: committed, candidate
    type(irrigation_management_request_t) :: req
    type(irrigation_flux_result_t) :: flux
    type(irrigation_diagnostics_t) :: diag

    call one_event_parameters(p, 8.0_real64, IRRIGATION_APPLICATION_SURFACE, 0.4_real64, 0.8_real64, 7.5_real64)
    req%t0 = 7.0_real64; req%t1 = 7.5_real64
    call evaluate_fixed_irrigation_interval(p, committed, req, candidate, flux, diag)
    call require(diag%status == IRRIGATION_OK .and. .not. diag%event_match, 'no trigger status')
    call require(.not. flux%applied .and. .not. allocated(flux%subsurface_source), 'no trigger allocation')
    call require(state_identical(committed,candidate), 'no trigger cursor')
  end subroutine case_no_trigger

  subroutine case_surface_continuation()
    type(irrigation_parameters_t) :: p
    type(irrigation_state_t) :: committed, half_state, final_state
    type(irrigation_management_request_t) :: req
    type(irrigation_flux_result_t) :: first, second
    type(irrigation_diagnostics_t) :: diag

    call one_event_parameters(p, 10.0_real64, IRRIGATION_APPLICATION_SURFACE, 0.4_real64, 0.8_real64, 12.5_real64)
    req%t0 = 10.0_real64; req%t1 = 10.25_real64
    call evaluate_fixed_irrigation_interval(p, committed, req, half_state, first, diag)
    call require(diag%status == IRRIGATION_OK .and. diag%event_match, 'surface first status')
    call require(first%applied .and. first%event_started .and. .not. first%event_finished, 'surface first flags')
    call require(first%event_remains_active, 'surface remains active')
    call require(same_bits(first%surface_gross_rate,0.8_real64), 'surface legacy gird=irrate')
    call require(same_bits(first%concentration,12.5_real64), 'surface legacy cirr=irconc')
    call require(same_bits(first%event_duration,0.5_real64), 'surface duration=depth/rate')
    call require(same_bits(first%external_inflow_amount,0.2_real64), 'surface first amount')
    call require(.not. allocated(first%subsurface_source), 'surface no ssdi allocation')
    call require(half_state%next_fixed_event_index == 2 .and. half_state%active_event, 'surface candidate cursor')
    call require(same_bits(half_state%active_event_start,10.0_real64) .and. &
                 same_bits(half_state%active_event_end,10.5_real64), 'surface active timing')

    req%t0 = 10.25_real64; req%t1 = 10.5_real64
    call evaluate_fixed_irrigation_interval(p, half_state, req, final_state, second, diag)
    call require(diag%status == IRRIGATION_OK, 'surface continuation status')
    call require(second%applied .and. .not. second%event_started .and. second%event_finished, 'surface finish flags')
    call require(.not. second%event_remains_active, 'surface finish active flag')
    call require(same_bits(second%external_inflow_amount,0.2_real64), 'surface second amount')
    call require(final_state%next_fixed_event_index == 2 .and. .not. final_state%active_event, 'surface final cursor')
  end subroutine case_surface_continuation

  subroutine case_surface_type_zero()
    type(irrigation_parameters_t) :: p
    type(irrigation_state_t) :: committed, candidate
    type(irrigation_management_request_t) :: req
    type(irrigation_flux_result_t) :: flux
    type(irrigation_diagnostics_t) :: diag

    call one_event_parameters(p, 20.0_real64, IRRIGATION_APPLICATION_SPRINKLER, 0.1_real64, 0.4_real64, 3.0_real64)
    req%t0 = 20.0_real64; req%t1 = 20.25_real64
    call evaluate_fixed_irrigation_interval(p, committed, req, candidate, flux, diag)
    call require(diag%status == IRRIGATION_OK .and. flux%applied, 'sprinkler type zero admitted')
    call require(same_bits(flux%surface_gross_rate,0.4_real64), 'sprinkler legacy gird')
    call require(same_bits(flux%concentration,3.0_real64), 'sprinkler concentration')
  end subroutine case_surface_type_zero

  subroutine case_ssdi_full_event()
    type(irrigation_parameters_t) :: p
    type(irrigation_state_t) :: committed, candidate
    type(irrigation_management_request_t) :: req
    type(irrigation_flux_result_t) :: flux
    type(irrigation_diagnostics_t) :: diag

    call one_event_parameters(p, 30.0_real64, IRRIGATION_APPLICATION_SSDI, 0.2_real64, 0.4_real64, 99.0_real64)
    p%active_nodes = 5; p%ssdi_first_node = 2; p%ssdi_last_node = 4
    req%t0 = 30.0_real64; req%t1 = 30.5_real64
    call evaluate_fixed_irrigation_interval(p, committed, req, candidate, flux, diag)
    call require(diag%status == IRRIGATION_OK .and. diag%event_match, 'ssdi status')
    call require(flux%applied .and. flux%event_started .and. flux%event_finished, 'ssdi flags')
    call require(allocated(flux%subsurface_source) .and. size(flux%subsurface_source) == 5, 'ssdi allocation')
    call require(same_bits(flux%subsurface_source(1),0.0_real64) .and. &
                 all_bits(flux%subsurface_source(2:4),0.4_real64) .and. &
                 same_bits(flux%subsurface_source(5),0.0_real64), 'ssdi legacy qssdi range=irrate')
    call require(same_bits(flux%event_duration,0.5_real64), 'ssdi duration=per-node-depth/rate')
    call require(same_bits(flux%external_inflow_amount,0.6_real64), 'ssdi total source identity')
    call require(same_bits(flux%concentration,0.0_real64), 'ssdi legacy cirr remains reset')
    call require(candidate%next_fixed_event_index == 2 .and. .not. candidate%active_event, 'ssdi cursor')
  end subroutine case_ssdi_full_event

  subroutine case_split_no_mutation()
    type(irrigation_parameters_t) :: p
    type(irrigation_state_t) :: committed, candidate, active, active_after
    type(irrigation_management_request_t) :: req
    type(irrigation_flux_result_t) :: flux
    type(irrigation_diagnostics_t) :: diag

    call one_event_parameters(p, 40.0_real64, IRRIGATION_APPLICATION_SURFACE, 0.4_real64, 0.8_real64, 0.0_real64)
    req%t0 = 40.0_real64; req%t1 = 40.75_real64
    call evaluate_fixed_irrigation_interval(p, committed, req, candidate, flux, diag)
    call require(diag%status == IRRIGATION_SPLIT_REQUIRED .and. diag%split_required, 'initial split status')
    call require(same_bits(diag%split_time,40.5_real64), 'initial split time')
    call require(state_identical(committed,candidate), 'initial split state unchanged')
    call require(.not. flux%applied, 'initial split no flux')

    req%t0 = 40.0_real64; req%t1 = 40.25_real64
    call evaluate_fixed_irrigation_interval(p, committed, req, active, flux, diag)
    call require(diag%status == IRRIGATION_OK .and. active%active_event, 'active fixture')
    req%t0 = 40.25_real64; req%t1 = 40.75_real64
    call evaluate_fixed_irrigation_interval(p, active, req, active_after, flux, diag)
    call require(diag%status == IRRIGATION_SPLIT_REQUIRED .and. diag%split_required, 'continuation split status')
    call require(state_identical(active,active_after), 'continuation split state unchanged')
    call require(.not. flux%applied, 'continuation split no flux')
  end subroutine case_split_no_mutation

  subroutine case_invalid_event()
    type(irrigation_parameters_t) :: p
    type(irrigation_state_t) :: committed, candidate
    type(irrigation_management_request_t) :: req
    type(irrigation_flux_result_t) :: flux
    type(irrigation_diagnostics_t) :: diag

    call one_event_parameters(p, 50.0_real64, IRRIGATION_APPLICATION_SURFACE, 2.0_real64, 1.0_real64, 0.0_real64)
    req%t0 = 50.0_real64; req%t1 = 50.5_real64
    call evaluate_fixed_irrigation_interval(p, committed, req, candidate, flux, diag)
    call require(diag%status == IRRIGATION_INVALID_EVENT, 'duration > one day rejected')
    call require(state_identical(committed,candidate) .and. .not. flux%applied, 'invalid event no mutation')
  end subroutine case_invalid_event

  subroutine case_replay_and_aba()
    type(irrigation_parameters_t) :: pa, pb
    type(irrigation_state_t) :: committed, ca1, ca2, ca3, cb
    type(irrigation_management_request_t) :: req
    type(irrigation_flux_result_t) :: fa1, fa2, fa3, fb
    type(irrigation_diagnostics_t) :: da1, da2, da3, db

    call one_event_parameters(pa, 60.0_real64, IRRIGATION_APPLICATION_SURFACE, 0.4_real64, 0.8_real64, 4.0_real64)
    call one_event_parameters(pb, 70.0_real64, IRRIGATION_APPLICATION_SSDI, 0.1_real64, 0.2_real64, 0.0_real64)
    pb%active_nodes = 4; pb%ssdi_first_node = 2; pb%ssdi_last_node = 3

    req%t0 = 60.0_real64; req%t1 = 60.25_real64
    call evaluate_fixed_irrigation_interval(pa, committed, req, ca1, fa1, da1)
    call evaluate_fixed_irrigation_interval(pa, committed, req, ca2, fa2, da2)
    call require(state_identical(ca1,ca2) .and. flux_identical(fa1,fa2) .and. diagnostics_identical(da1,da2), &
                 'rollback replay identity')
    call require(committed%next_fixed_event_index == 1 .and. .not. committed%active_event, 'committed cursor protected')

    req%t0 = 70.0_real64; req%t1 = 70.25_real64
    call evaluate_fixed_irrigation_interval(pb, committed, req, cb, fb, db)
    call require(db%status == IRRIGATION_OK .and. fb%applied, 'B event')

    req%t0 = 60.0_real64; req%t1 = 60.25_real64
    call evaluate_fixed_irrigation_interval(pa, committed, req, ca3, fa3, da3)
    call require(state_identical(ca1,ca3) .and. flux_identical(fa1,fa3) .and. diagnostics_identical(da1,da3), &
                 'A/B/A identity')
  end subroutine case_replay_and_aba

  subroutine one_event_parameters(p, event_time, application_type, depth, rate, concentration)
    type(irrigation_parameters_t), intent(out) :: p
    real(real64), intent(in) :: event_time, depth, rate, concentration
    integer, intent(in) :: application_type
    allocate(p%fixed_events(1))
    p%fixed_irrigation_enabled = .true.
    p%fixed_events(1) = fixed_irrigation_event_t(event_time,application_type,depth,rate,concentration)
  end subroutine one_event_parameters

  logical function state_identical(a,b)
    type(irrigation_state_t), intent(in) :: a,b
    state_identical = a%next_fixed_event_index == b%next_fixed_event_index .and. &
         (a%active_event .eqv. b%active_event) .and. a%active_event_index == b%active_event_index .and. &
         same_bits(a%active_event_start,b%active_event_start) .and. same_bits(a%active_event_end,b%active_event_end)
  end function state_identical

  logical function flux_identical(a,b)
    type(irrigation_flux_result_t), intent(in) :: a,b
    flux_identical = (a%applied .eqv. b%applied) .and. (a%event_started .eqv. b%event_started) .and. &
         (a%event_finished .eqv. b%event_finished) .and. (a%event_remains_active .eqv. b%event_remains_active) .and. &
         a%event_index == b%event_index .and. a%application_type == b%application_type .and. &
         same_bits(a%concentration,b%concentration) .and. same_bits(a%event_duration,b%event_duration) .and. &
         same_bits(a%active_duration,b%active_duration) .and. same_bits(a%surface_gross_rate,b%surface_gross_rate) .and. &
         same_bits(a%external_inflow_amount,b%external_inflow_amount) .and. &
         (allocated(a%subsurface_source) .eqv. allocated(b%subsurface_source))
    if (.not. flux_identical) return
    if (allocated(a%subsurface_source)) then
      flux_identical = size(a%subsurface_source) == size(b%subsurface_source)
      if (flux_identical) flux_identical = all_vector_bits(a%subsurface_source,b%subsurface_source)
    end if
  end function flux_identical

  logical function diagnostics_identical(a,b)
    type(irrigation_diagnostics_t), intent(in) :: a,b
    diagnostics_identical = a%status == b%status .and. (a%event_match .eqv. b%event_match) .and. &
         (a%split_required .eqv. b%split_required) .and. same_bits(a%split_time,b%split_time) .and. &
         (a%external_inflow_is_reconciliation_only .eqv. b%external_inflow_is_reconciliation_only)
  end function diagnostics_identical

  logical function all_bits(values,expected)
    real(real64), intent(in) :: values(:), expected
    integer :: i
    all_bits = .true.
    do i=1,size(values)
      if (.not. same_bits(values(i),expected)) then
        all_bits = .false.; return
      end if
    end do
  end function all_bits

  logical function all_vector_bits(a,b)
    real(real64), intent(in) :: a(:),b(:)
    integer :: i
    all_vector_bits = size(a) == size(b)
    if (.not. all_vector_bits) return
    do i=1,size(a)
      if (.not. same_bits(a(i),b(i))) then
        all_vector_bits = .false.; return
      end if
    end do
  end function all_vector_bits

  logical function same_bits(a,b)
    real(real64), intent(in) :: a,b
    integer(int64) :: ia,ib
    ia = transfer(a,ia); ib = transfer(b,ib)
    same_bits = ia == ib
  end function same_bits

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FPM03_FIXED_EVENT_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require
end program test_fpm03_fixed_event_process
