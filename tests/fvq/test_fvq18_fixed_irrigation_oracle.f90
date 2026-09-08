program test_fvq18_fixed_irrigation_oracle
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_irrigation_process, only: irrigation_parameters_t, irrigation_state_t, irrigation_management_request_t, &
       irrigation_flux_result_t, irrigation_diagnostics_t, fixed_irrigation_event_t, evaluate_fixed_irrigation_interval, &
       IRRIGATION_OK, IRRIGATION_SPLIT_REQUIRED, IRRIGATION_FIXED_EVENT_MATCH_TOLERANCE, &
       IRRIGATION_APPLICATION_SPRINKLER, IRRIGATION_APPLICATION_SURFACE, IRRIGATION_APPLICATION_SSDI
  implicit none

  call test_inactive_and_no_event()
  call test_legacy_match_boundary()
  call test_surface_oracle()
  call test_ssdi_translation_oracle()
  call test_split_and_replay()
  call test_event_end_numerical_policy()
  call test_a_b_a()

  write(*,'(A)') 'FVQ18_FIXED_INACTIVE_NO_EVENT=PASS'
  write(*,'(A)') 'FVQ18_FIXED_LEGACY_MATCH_BOUNDARY=PASS'
  write(*,'(A)') 'FVQ18_FIXED_SURFACE_ORACLE=PASS'
  write(*,'(A)') 'FVQ18_FIXED_SSDI_TRANSLATION_ORACLE=PASS'
  write(*,'(A)') 'FVQ18_FIXED_TRANSACTION_REPLAY=PASS'
  write(*,'(A)') 'FVQ18_FIXED_EVENT_END_POLICY=PASS'
  write(*,'(A)') 'FVQ18_FIXED_A_B_A=PASS'
  write(*,'(A)') 'FVQ18_FIXED_IRRIGATION_SCIENTIFIC_ORACLE PASS'

contains

  subroutine test_inactive_and_no_event()
    type(irrigation_parameters_t) :: p
    type(irrigation_state_t) :: committed, candidate
    type(irrigation_management_request_t) :: req
    type(irrigation_flux_result_t) :: flux
    type(irrigation_diagnostics_t) :: diag

    req%t0 = 1.0_real64
    req%t1 = 1.25_real64
    call evaluate_fixed_irrigation_interval(p, committed, req, candidate, flux, diag)
    call require(diag%status == IRRIGATION_OK, 'inactive status')
    call require(.not. flux%applied .and. .not. allocated(flux%subsurface_source), 'inactive no source')
    call require(state_equal(committed, candidate), 'inactive state identity')

    p%fixed_irrigation_enabled = .true.
    allocate(p%fixed_events(1))
    p%fixed_events(1)%event_time = 2.0_real64
    p%fixed_events(1)%application_type = IRRIGATION_APPLICATION_SPRINKLER
    p%fixed_events(1)%depth = 0.25_real64
    p%fixed_events(1)%rate = 0.5_real64
    call evaluate_fixed_irrigation_interval(p, committed, req, candidate, flux, diag)
    call require(diag%status == IRRIGATION_OK .and. .not. diag%event_match, 'no event status')
    call require(.not. flux%applied .and. .not. allocated(flux%subsurface_source), 'no event no source')
    call require(state_equal(committed, candidate), 'no event state identity')
  end subroutine test_inactive_and_no_event

  subroutine test_legacy_match_boundary()
    type(irrigation_parameters_t) :: p
    type(irrigation_state_t) :: committed, candidate
    type(irrigation_management_request_t) :: req
    type(irrigation_flux_result_t) :: flux
    type(irrigation_diagnostics_t) :: diag

    p%fixed_irrigation_enabled = .true.
    allocate(p%fixed_events(1))
    p%fixed_events(1)%application_type = IRRIGATION_APPLICATION_SURFACE
    p%fixed_events(1)%depth = 0.25_real64
    p%fixed_events(1)%rate = 1.0_real64
    p%fixed_events(1)%concentration = 0.125_real64
    req%t0 = 0.0_real64
    req%t1 = 0.125_real64

    p%fixed_events(1)%event_time = 0.5_real64 * IRRIGATION_FIXED_EVENT_MATCH_TOLERANCE
    call evaluate_fixed_irrigation_interval(p, committed, req, candidate, flux, diag)
    call require(diag%status == IRRIGATION_OK .and. diag%event_match .and. flux%applied, 'inside 1e-3 must match')

    p%fixed_events(1)%event_time = IRRIGATION_FIXED_EVENT_MATCH_TOLERANCE
    call evaluate_fixed_irrigation_interval(p, committed, req, candidate, flux, diag)
    call require(diag%status == IRRIGATION_OK .and. .not. diag%event_match, 'exact 1e-3 must not match')
    call require(.not. flux%applied, 'exact boundary no application')
    call require(state_equal(committed, candidate), 'exact boundary cursor unchanged')
  end subroutine test_legacy_match_boundary

  subroutine test_surface_oracle()
    type(irrigation_parameters_t) :: p
    type(irrigation_state_t) :: committed, candidate, finished
    type(irrigation_management_request_t) :: req
    type(irrigation_flux_result_t) :: flux
    type(irrigation_diagnostics_t) :: diag
    integer :: app

    do app = IRRIGATION_APPLICATION_SPRINKLER, IRRIGATION_APPLICATION_SURFACE
      p = irrigation_parameters_t()
      committed = irrigation_state_t()
      p%fixed_irrigation_enabled = .true.
      allocate(p%fixed_events(1))
      p%fixed_events(1)%event_time = 10.0_real64 + 10.0_real64*real(app,real64)
      p%fixed_events(1)%application_type = app
      p%fixed_events(1)%depth = 0.375_real64
      p%fixed_events(1)%rate = 0.75_real64
      p%fixed_events(1)%concentration = 0.1875_real64
      req%t0 = p%fixed_events(1)%event_time
      req%t1 = req%t0 + 0.25_real64

      call evaluate_fixed_irrigation_interval(p, committed, req, candidate, flux, diag)
      call require(diag%status == IRRIGATION_OK .and. diag%event_match, 'surface match')
      call require(flux%applied .and. flux%event_started .and. flux%event_remains_active, 'surface active event')
      call require(flux%application_type == app, 'surface type identity')
      call require(same_bits(flux%surface_gross_rate,0.75_real64), 'gird equals irrate')
      call require(same_bits(flux%concentration,0.1875_real64), 'cirr equals irconc')
      call require(same_bits(flux%event_duration,0.5_real64), 'duration depth/rate')
      call require(same_bits(flux%active_duration,0.25_real64), 'surface partial duration')
      call require(same_bits(flux%external_inflow_amount,0.1875_real64), 'surface amount rate*time')
      call require(.not. allocated(flux%subsurface_source), 'surface no SSDI allocation')
      call require(candidate%next_fixed_event_index == 2, 'surface cursor increment')
      call require(candidate%active_event .and. candidate%active_event_index == 1, 'surface active history')

      req%t0 = req%t1
      req%t1 = p%fixed_events(1)%event_time + 0.5_real64
      call evaluate_fixed_irrigation_interval(p, candidate, req, finished, flux, diag)
      call require(diag%status == IRRIGATION_OK .and. flux%event_finished, 'surface completion')
      call require(.not. finished%active_event .and. finished%next_fixed_event_index == 2, 'task9-equivalent clear')
      call require(same_bits(flux%active_duration,0.25_real64), 'surface continuation duration')
    end do
  end subroutine test_surface_oracle

  subroutine test_ssdi_translation_oracle()
    type(irrigation_parameters_t) :: p
    type(irrigation_state_t) :: committed, candidate
    type(irrigation_management_request_t) :: req
    type(irrigation_flux_result_t) :: flux
    type(irrigation_diagnostics_t) :: diag
    real(real64) :: original_total_depth

    p%fixed_irrigation_enabled = .true.
    p%active_nodes = 5
    p%ssdi_first_node = 2
    p%ssdi_last_node = 4
    allocate(p%fixed_events(1))
    p%fixed_events(1)%event_time = 30.0_real64
    p%fixed_events(1)%application_type = IRRIGATION_APPLICATION_SSDI
    ! B1.10 read translation divides total fixed-event depth over the three SSDI nodes,
    ! while rate is kept per node. 0.125 is therefore the post-translation per-node depth.
    p%fixed_events(1)%depth = 0.125_real64
    p%fixed_events(1)%rate = 0.25_real64
    p%fixed_events(1)%concentration = 77.0_real64
    req%t0 = 30.0_real64
    req%t1 = 30.5_real64

    call evaluate_fixed_irrigation_interval(p, committed, req, candidate, flux, diag)
    call require(diag%status == IRRIGATION_OK .and. flux%applied .and. flux%event_finished, 'SSDI application')
    call require(allocated(flux%subsurface_source) .and. size(flux%subsurface_source) == 5, 'SSDI array shape')
    call require(same_bits(flux%subsurface_source(1),0.0_real64), 'SSDI outside first')
    call require(all(flux%subsurface_source(2:4) == 0.25_real64), 'qssdi equals irrate on range')
    call require(same_bits(flux%subsurface_source(5),0.0_real64), 'SSDI outside last')
    call require(same_bits(flux%concentration,0.0_real64), 'legacy SSDI does not set cirr')
    call require(same_bits(flux%surface_gross_rate,0.0_real64), 'SSDI no surface rate')
    call require(same_bits(flux%event_duration,0.5_real64), 'SSDI duration per-node depth/rate')
    original_total_depth = 3.0_real64 * 0.125_real64
    call require(same_bits(flux%external_inflow_amount,original_total_depth), 'translated SSDI total-water identity')
    call require(candidate%next_fixed_event_index == 2 .and. .not. candidate%active_event, 'SSDI cursor/completion')
  end subroutine test_ssdi_translation_oracle

  subroutine test_split_and_replay()
    type(irrigation_parameters_t) :: p
    type(irrigation_state_t) :: committed, cand1, cand2
    type(irrigation_management_request_t) :: req
    type(irrigation_flux_result_t) :: flux1, flux2
    type(irrigation_diagnostics_t) :: diag1, diag2

    p%fixed_irrigation_enabled = .true.
    allocate(p%fixed_events(1))
    p%fixed_events(1) = fixed_irrigation_event_t(40.0_real64, IRRIGATION_APPLICATION_SURFACE, &
         0.25_real64, 0.5_real64, 0.0625_real64)
    req%t0 = 40.0_real64
    req%t1 = 40.75_real64

    call evaluate_fixed_irrigation_interval(p, committed, req, cand1, flux1, diag1)
    call evaluate_fixed_irrigation_interval(p, committed, req, cand2, flux2, diag2)
    call require(diag1%status == IRRIGATION_SPLIT_REQUIRED .and. diag1%split_required, 'split required')
    call require(same_bits(diag1%split_time,40.5_real64), 'split at event end')
    call require(state_equal(committed,cand1), 'split trial does not consume cursor')
    call require(.not. flux1%applied .and. .not. allocated(flux1%subsurface_source), 'split trial adds no water')
    call require(state_equal(cand1,cand2) .and. flux_equal(flux1,flux2) .and. diag_equal(diag1,diag2), &
         'replay from same committed state exact')
  end subroutine test_split_and_replay

  subroutine test_event_end_numerical_policy()
    type(irrigation_parameters_t) :: p
    type(irrigation_state_t) :: committed, active, finished, split_candidate
    type(irrigation_management_request_t) :: req
    type(irrigation_flux_result_t) :: flux
    type(irrigation_diagnostics_t) :: diag
    real(real64) :: event_end

    p%fixed_irrigation_enabled = .true.
    allocate(p%fixed_events(1))
    p%fixed_events(1) = fixed_irrigation_event_t(50.0_real64, IRRIGATION_APPLICATION_SURFACE, &
         0.25_real64, 0.5_real64, 0.0_real64)
    event_end = 50.5_real64

    req%t0 = 50.0_real64
    req%t1 = 50.25_real64
    call evaluate_fixed_irrigation_interval(p, committed, req, active, flux, diag)
    call require(diag%status == IRRIGATION_OK .and. active%active_event, 'create active continuation state')

    req%t0 = 50.25_real64
    req%t1 = nearest(event_end,1.0_real64)
    call evaluate_fixed_irrigation_interval(p, active, req, finished, flux, diag)
    call require(diag%status == IRRIGATION_OK .and. flux%event_finished, 'one-ulp end accepted')
    call require(.not. finished%active_event, 'one-ulp completion clears event')
    call require(same_bits(flux%active_duration,0.25_real64), 'one-ulp duration clamps to event end')
    call require(same_bits(flux%external_inflow_amount,0.125_real64), 'one-ulp mass clamps to event end')

    req%t1 = event_end + 1.0e-9_real64
    call evaluate_fixed_irrigation_interval(p, active, req, split_candidate, flux, diag)
    call require(diag%status == IRRIGATION_SPLIT_REQUIRED .and. diag%split_required, 'material crossing fails closed')
    call require(state_equal(active,split_candidate), 'material crossing preserves active committed history')
  end subroutine test_event_end_numerical_policy

  subroutine test_a_b_a()
    type(irrigation_parameters_t) :: pa, pb
    type(irrigation_state_t) :: committed, ca1, cb, ca2
    type(irrigation_management_request_t) :: ra, rb
    type(irrigation_flux_result_t) :: fa1, fb, fa2
    type(irrigation_diagnostics_t) :: da1, db, da2

    pa%fixed_irrigation_enabled = .true.
    allocate(pa%fixed_events(1))
    pa%fixed_events(1) = fixed_irrigation_event_t(60.0_real64, IRRIGATION_APPLICATION_SPRINKLER, &
         0.125_real64, 0.5_real64, 0.03125_real64)
    ra%t0 = 60.0_real64
    ra%t1 = 60.125_real64

    pb%fixed_irrigation_enabled = .true.
    pb%active_nodes = 4
    pb%ssdi_first_node = 2
    pb%ssdi_last_node = 3
    allocate(pb%fixed_events(1))
    pb%fixed_events(1) = fixed_irrigation_event_t(70.0_real64, IRRIGATION_APPLICATION_SSDI, &
         0.0625_real64, 0.25_real64, 9.0_real64)
    rb%t0 = 70.0_real64
    rb%t1 = 70.125_real64

    call evaluate_fixed_irrigation_interval(pa, committed, ra, ca1, fa1, da1)
    call evaluate_fixed_irrigation_interval(pb, committed, rb, cb, fb, db)
    call evaluate_fixed_irrigation_interval(pa, committed, ra, ca2, fa2, da2)
    call require(da1%status == IRRIGATION_OK .and. db%status == IRRIGATION_OK .and. da2%status == IRRIGATION_OK, &
         'A/B/A status')
    call require(state_equal(ca1,ca2) .and. flux_equal(fa1,fa2) .and. diag_equal(da1,da2), 'A/B/A exact replay')
  end subroutine test_a_b_a

  logical function state_equal(a,b)
    type(irrigation_state_t), intent(in) :: a,b
    state_equal = a%next_fixed_event_index == b%next_fixed_event_index .and. &
         (a%active_event .eqv. b%active_event) .and. a%active_event_index == b%active_event_index .and. &
         same_bits(a%active_event_start,b%active_event_start) .and. same_bits(a%active_event_end,b%active_event_end)
  end function state_equal

  logical function flux_equal(a,b)
    type(irrigation_flux_result_t), intent(in) :: a,b
    integer :: i
    flux_equal = (a%applied .eqv. b%applied) .and. (a%event_started .eqv. b%event_started) .and. &
         (a%event_finished .eqv. b%event_finished) .and. (a%event_remains_active .eqv. b%event_remains_active) .and. &
         a%event_index == b%event_index .and. a%application_type == b%application_type .and. &
         same_bits(a%concentration,b%concentration) .and. same_bits(a%event_duration,b%event_duration) .and. &
         same_bits(a%active_duration,b%active_duration) .and. same_bits(a%surface_gross_rate,b%surface_gross_rate) .and. &
         same_bits(a%external_inflow_amount,b%external_inflow_amount)
    if (.not. flux_equal) return
    if (allocated(a%subsurface_source) .neqv. allocated(b%subsurface_source)) then
      flux_equal = .false.
      return
    end if
    if (allocated(a%subsurface_source)) then
      if (size(a%subsurface_source) /= size(b%subsurface_source)) then
        flux_equal = .false.
        return
      end if
      do i=1,size(a%subsurface_source)
        if (.not. same_bits(a%subsurface_source(i),b%subsurface_source(i))) then
          flux_equal = .false.
          return
        end if
      end do
    end if
  end function flux_equal

  logical function diag_equal(a,b)
    type(irrigation_diagnostics_t), intent(in) :: a,b
    diag_equal = a%status == b%status .and. (a%event_match .eqv. b%event_match) .and. &
         (a%split_required .eqv. b%split_required) .and. same_bits(a%split_time,b%split_time) .and. &
         (a%external_inflow_is_reconciliation_only .eqv. b%external_inflow_is_reconciliation_only)
  end function diag_equal

  logical function same_bits(a,b)
    real(real64), intent(in) :: a,b
    integer(int64) :: ia, ib
    ia = transfer(a,ia)
    ib = transfer(b,ib)
    same_bits = ia == ib
  end function same_bits

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FVQ18_FIXED_ORACLE_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fvq18_fixed_irrigation_oracle
