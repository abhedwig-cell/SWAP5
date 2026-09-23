program test_rm05_hupsel_management_transaction
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_numerical_config_t, CANONICAL_STATUS_COMPLETED, &
       CANONICAL_STATUS_TRANSACTION_FAILED
  use mod_kernel_transactions
  use mod_tcs1_dcs2_sprinkling_irrigation_process
  use mod_rutter_interception_process
  use mod_fmr_hupsel_management_transaction
  implicit none

  type(tcs1_dcs2_sprinkling_parameters_t) :: irrigation_parameters
  type(tcs1_dcs2_sprinkling_state_t) :: irrigation_seed, irrigation_view1, irrigation_view2
  type(tcs1_dcs2_sprinkling_request_t) :: request
  type(rutter_state_t) :: rutter_seed, rutter_view1, rutter_view2
  type(rutter_interval_input_t) :: rutter_template
  type(fmr_hupsel_management_state_t) :: initial_state, reconstructed_state
  type(fmr_hupsel_management_persistence_t) :: persistence
  type(fmr_hupsel_management_parameters_t) :: parameters
  type(fmr_hupsel_management_forcing_t) :: forcing, partial_forcing, no_event_forcing
  type(fmr_hupsel_management_model_t), target :: model, partial_model, no_event_model
  type(fmr_hupsel_management_observation_t) :: observation
  type(kernel_executor_t) :: kernel, partial_kernel, no_event_kernel
  type(kernel_committed_state_t) :: committed, partial_committed, no_event_committed
  type(kernel_checkpoint_t) :: checkpoint, partial_checkpoint, no_event_checkpoint
  type(kernel_candidate_state_t) :: candidate1, candidate2, partial_candidate, no_event_candidate
  type(kernel_result_t) :: result1, result2, partial_result, no_event_result
  type(kernel_diagnostics_t) :: diagnostics1, diagnostics2, partial_diagnostics, no_event_diagnostics
  type(canonical_numerical_config_t) :: config
  class(transaction_state_t), allocatable :: snapshot
  logical :: ok, available, did_commit, exported, reconstructed
  integer :: status, commit_status
  integer(int64) :: revision_before
  real(real64), parameter :: tol = 1.0e-12_real64

  call setup_hupsel(irrigation_parameters)
  call construct_fmr_hupsel_management_parameters(irrigation_parameters, parameters, status)
  call require(status == FMR_RM_OK, 'parameters construction status')
  call require(parameters%ready(), 'parameters ready')

  irrigation_seed = tcs1_dcs2_sprinkling_state_t()
  irrigation_seed%dayfix = 366
  rutter_seed = rutter_state_t()
  rutter_seed%canopy_storage_cm = 0.02_real64
  call initialize_fmr_hupsel_management_state(irrigation_seed, rutter_seed, initial_state, status)
  call require(status == FMR_RM_OK, 'initial state construction status')
  call require(initial_state%ready(), 'initial state ready')

  call setup_trigger_request(request, 218.0_real64)
  call setup_rutter_template(rutter_template)
  call prepare_fmr_hupsel_management_forcing(request, rutter_template, 41_int64, 2.0_real64, 2.0_real64, &
       forcing, status)
  call require(status == FMR_RM_OK, 'full supply forcing status')
  call require(forcing%ready(), 'full supply forcing ready')
  call setup_config(config)
  call initialize_committed(initial_state, committed, 51001_int64, 218.0_real64)
  call committed%capture_checkpoint(checkpoint, ok)
  call require(ok, 'checkpoint capture status')
  call require(checkpoint%ready(), 'checkpoint ready')
  call kernel%bind_model(model)

  call kernel%advance_interval(parameters, committed, forcing, config, 218.0_real64, 219.0_real64, &
       result1, candidate1, diagnostics1, checkpoint)
  call require(result1%status == CANONICAL_STATUS_COMPLETED, 'first trial status')
  call require(result1%completed, 'first trial completes')
  call require(candidate1%ready(), 'first candidate ready')
  call model%observation(observation)
  call require(observation%decision_evaluated .and. observation%irrigation_requested, 'demand evaluated')
  call require(abs(observation%requested_depth_cm-2.0_real64) < tol, 'requested depth exact')
  call require(abs(observation%allocated_depth_cm-2.0_real64) < tol, 'allocated distinct value exact')
  call require(abs(observation%supplied_depth_cm-2.0_real64) < tol, 'supplied distinct value exact')
  call require(abs(observation%allocation_shortage_cm) < tol .and. abs(observation%realization_shortage_cm) < tol, &
       'zero shortage explicit')
  call require(observation%net_surface_irrigation_amount_cm > 0.0_real64 .and. &
       observation%net_surface_irrigation_amount_cm < observation%supplied_depth_cm, 'Rutter gross to net bounded')
  call require(observation%crop_origin_revision == 41_int64, 'crop origin revision carried')

  call kernel%advance_interval(parameters, committed, forcing, config, 218.0_real64, 219.0_real64, &
       result2, candidate2, diagnostics2, checkpoint)
  call require(result2%status == CANONICAL_STATUS_COMPLETED, 'replay trial status')
  call require(candidate2%ready(), 'replay candidate ready')
  call compare_candidate_states(candidate1, candidate2, 'same-origin candidate replay')

  call kernel%rollback_candidate(candidate1, diagnostics1)
  call require(.not. candidate1%ready(), 'discarded candidate invalidated')
  call committed%snapshot(snapshot, available)
  call require(available, 'committed snapshot after rollback')
  call extract_state(snapshot, irrigation_view1, rutter_view1)
  call require(irrigation_view1%dayfix == 366, 'rollback keeps dayfix')
  call require(abs(rutter_view1%canopy_storage_cm-0.02_real64) < tol, 'rollback keeps Rutter storage')

  revision_before = committed%current_revision()
  call kernel%commit_candidate(committed, candidate2, diagnostics2, did_commit, commit_status)
  call require(did_commit .and. commit_status == KERNEL_COMMIT_STATUS_COMMITTED, 'candidate commits')
  call require(committed%current_revision() == revision_before+1_int64, 'one revision publication')
  if (allocated(snapshot)) deallocate(snapshot)
  call committed%snapshot(snapshot, available)
  call require(available, 'committed snapshot after commit')
  call extract_state(snapshot, irrigation_view1, rutter_view1)
  call require(irrigation_view1%dayfix == 1 .and. .not. irrigation_view1%active_event, 'accepted irrigation continuation')
  call require(rutter_view1%canopy_storage_cm > 0.02_real64 .and. rutter_view1%canopy_storage_cm <= &
       rutter_template%canopy_storage_capacity_cm+tol, 'accepted Rutter continuation')

  select type (typed => snapshot)
  type is (fmr_hupsel_management_state_t)
    call export_fmr_hupsel_management_persistence(typed, persistence, exported, status)
  class default
    call require(.false., 'committed snapshot type for persistence')
  end select
  call require(exported .and. status == FMR_RM_OK, 'persistence export status')
  call require(persistence%ready(), 'persistence export ready')
  call reconstruct_fmr_hupsel_management_from_persistence(persistence, reconstructed_state, reconstructed, status)
  call require(reconstructed .and. status == FMR_RM_OK, 'persistence reconstruct status')
  call require(reconstructed_state%ready(), 'persistence reconstruct ready')
  call reconstructed_state%snapshot(irrigation_view2, rutter_view2, available)
  call require(available .and. same_irrigation(irrigation_view1, irrigation_view2), 'restart irrigation identity')
  call require(abs(rutter_view1%canopy_storage_cm-rutter_view2%canopy_storage_cm) < tol, 'restart Rutter identity')

  ! Positive partial realization is deliberately outside RM05 admission.
  call initialize_committed(initial_state, partial_committed, 51002_int64, 218.0_real64)
  call partial_committed%capture_checkpoint(partial_checkpoint, ok)
  call require(ok, 'partial checkpoint')
  call partial_kernel%bind_model(partial_model)
  call prepare_fmr_hupsel_management_forcing(request, rutter_template, 41_int64, 1.0_real64, 1.0_real64, &
       partial_forcing, status)
  call require(status == FMR_RM_OK, 'partial forcing structurally ready')
  call partial_kernel%advance_interval(parameters, partial_committed, partial_forcing, config, 218.0_real64, &
       219.0_real64, partial_result, partial_candidate, partial_diagnostics, partial_checkpoint)
  call require(partial_result%status == CANONICAL_STATUS_TRANSACTION_FAILED, 'partial supply fails closed')
  call require(partial_model%last_status_code() == FMR_RM_PARTIAL_SUPPLY_NOT_ADMITTED, 'partial policy status')
  call require(.not. partial_candidate%ready() .and. partial_committed%current_revision() == 0_int64, &
       'partial supply zero accepted mutation')

  ! No-event management evaluation may still advance dayfix as accepted process continuation.
  irrigation_seed%dayfix = 6
  call initialize_fmr_hupsel_management_state(irrigation_seed, rutter_seed, initial_state, status)
  call require(status == FMR_RM_OK, 'no-event seed')
  call initialize_committed(initial_state, no_event_committed, 51003_int64, 224.0_real64)
  call no_event_committed%capture_checkpoint(no_event_checkpoint, ok)
  call require(ok, 'no-event checkpoint')
  call no_event_kernel%bind_model(no_event_model)
  call setup_no_stress_request(request, 224.0_real64)
  call prepare_fmr_hupsel_management_forcing(request, rutter_template, 42_int64, 0.0_real64, 0.0_real64, &
       no_event_forcing, status)
  call require(status == FMR_RM_OK, 'no-event forcing')
  call no_event_kernel%advance_interval(parameters, no_event_committed, no_event_forcing, config, &
       224.0_real64, 225.0_real64, no_event_result, no_event_candidate, no_event_diagnostics, no_event_checkpoint)
  call require(no_event_result%status == CANONICAL_STATUS_COMPLETED, 'no-event trial status')
  call require(no_event_candidate%ready(), 'no-event candidate')
  call no_event_kernel%commit_candidate(no_event_committed, no_event_candidate, no_event_diagnostics, &
       did_commit, commit_status)
  call require(did_commit, 'no-event commit')
  if (allocated(snapshot)) deallocate(snapshot)
  call no_event_committed%snapshot(snapshot, available)
  call require(available, 'no-event snapshot')
  call extract_state(snapshot, irrigation_view1, rutter_view1)
  call require(irrigation_view1%dayfix == 7, 'no-event accepted dayfix advancement')
  call require(abs(rutter_view1%canopy_storage_cm-0.02_real64) < tol, 'no-event Rutter unchanged')

  print '(a)', 'RM05_DEMAND_ALLOCATION_SUPPLY_SEPARATION=PASS'
  print '(a)', 'RM05_SAME_ORIGIN_REPLAY=PASS'
  print '(a)', 'RM05_ROLLBACK_IMMUTABILITY=PASS'
  print '(a)', 'RM05_ATOMIC_MANAGEMENT_STATE_COMMIT=PASS'
  print '(a)', 'RM05_RUTTER_EVENT_SPLIT_CONTINUATION=PASS'
  print '(a)', 'RM05_RESTART_ROUNDTRIP=PASS'
  print '(a)', 'RM05_PARTIAL_SUPPLY_FAIL_CLOSED=PASS'
  print '(a)', 'RM05_NO_EVENT_DAYFIX_CONTINUATION=PASS'
  print '(a)', 'RM05_HUPSEL_MANAGEMENT_TRANSACTION_GATE PASS'

contains

  subroutine setup_hupsel(p)
    type(tcs1_dcs2_sprinkling_parameters_t), intent(out) :: p
    p = tcs1_dcs2_sprinkling_parameters_t()
    p%enabled = .true.
    p%rate_cm_per_day = 36.0_real64
    p%threshold_knot_count = 2
    p%threshold_dvs(1:2) = [0.0_real64, 2.0_real64]
    p%threshold_trel(1:2) = [0.85_real64, 0.85_real64]
    p%depth_knot_count = 2
    p%depth_dvs(1:2) = [0.0_real64, 2.0_real64]
    p%depth_cm(1:2) = [2.0_real64, 2.0_real64]
    p%minimum_interval_days = 7
  end subroutine setup_hupsel

  subroutine setup_trigger_request(r, t0)
    type(tcs1_dcs2_sprinkling_request_t), intent(out) :: r
    real(real64), intent(in) :: t0
    r = tcs1_dcs2_sprinkling_request_t()
    r%t0 = t0
    r%t1 = t0 + 1.0_real64
    r%dvs = 1.3505714285714288_real64
    r%potential_transpiration_day_cm = 0.5471354589029818_real64
    r%dry_reduction_day_cm = 0.2123937335777891_real64
    r%salinity_reduction_day_cm = 0.0_real64
    r%selection_opportunity = .true.
    r%irrigation_enabled = .true.
    r%schedule_enabled = .true.
    r%crop_emerged = .true.
    r%irrigation_window_open = .true.
  end subroutine setup_trigger_request

  subroutine setup_no_stress_request(r, t0)
    type(tcs1_dcs2_sprinkling_request_t), intent(out) :: r
    real(real64), intent(in) :: t0
    call setup_trigger_request(r, t0)
    r%potential_transpiration_day_cm = 0.5_real64
    r%dry_reduction_day_cm = 0.0_real64
    r%salinity_reduction_day_cm = 0.0_real64
  end subroutine setup_no_stress_request

  subroutine setup_rutter_template(r)
    type(rutter_interval_input_t), intent(out) :: r
    r = rutter_interval_input_t()
    r%gross_rain_cm_per_day = 0.0_real64
    r%vegetation_cover_fraction = 0.5_real64
    r%canopy_storage_capacity_cm = 0.12_real64
    r%interception_evaporation_capacity_cm_per_day = 0.01_real64
    r%potential_transpiration_dry_cm_per_day = 0.011621209174202582_real64
    r%potential_transpiration_wet_cm_per_day = 0.0047014973566050335_real64
  end subroutine setup_rutter_template

  subroutine setup_config(c)
    type(canonical_numerical_config_t), intent(out) :: c
    c%transaction%temporal_mode = TX_TEMPORAL_MODEL_CERTIFICATE
    c%transaction%temporal_tolerance = 0.0_real64
    c%transaction%mass_tolerance = 0.0_real64
    c%transaction%retry_scale = 0.5_real64
    c%transaction%max_retries = 0
    c%max_committed_substeps = 1
    c%progress_tolerance = 0.0_real64
  end subroutine setup_config

  subroutine initialize_committed(initial, state, lineage, time0)
    type(fmr_hupsel_management_state_t), intent(in) :: initial
    type(kernel_committed_state_t), intent(out) :: state
    integer(int64), intent(in) :: lineage
    real(real64), intent(in) :: time0
    class(transaction_state_t), allocatable :: physical
    logical :: initialized

    allocate(fmr_hupsel_management_state_t :: physical)
    select type (typed => physical)
    type is (fmr_hupsel_management_state_t)
      typed = initial
    class default
      error stop 'RM05 allocation type failure'
    end select
    call state%initialize(lineage, physical, initialized, time0)
    call require(initialized, 'kernel committed initialization')
  end subroutine initialize_committed

  subroutine compare_candidate_states(a, b, message)
    type(kernel_candidate_state_t), intent(in) :: a, b
    character(len=*), intent(in) :: message
    class(transaction_state_t), allocatable :: sa, sb
    type(tcs1_dcs2_sprinkling_state_t) :: ia, ib
    type(rutter_state_t) :: ra, rb
    logical :: aa, ab

    call a%snapshot(sa, aa)
    call b%snapshot(sb, ab)
    call require(aa .and. ab, trim(message)//' snapshots')
    call extract_state(sa, ia, ra)
    call extract_state(sb, ib, rb)
    call require(same_irrigation(ia, ib), trim(message)//' irrigation')
    call require(abs(ra%canopy_storage_cm-rb%canopy_storage_cm) < tol, trim(message)//' Rutter')
  end subroutine compare_candidate_states

  subroutine extract_state(s, irrigation, rutter)
    class(transaction_state_t), allocatable, intent(in) :: s
    type(tcs1_dcs2_sprinkling_state_t), intent(out) :: irrigation
    type(rutter_state_t), intent(out) :: rutter
    logical :: state_available

    call require(allocated(s), 'state snapshot allocated')
    select type (typed => s)
    type is (fmr_hupsel_management_state_t)
      call typed%snapshot(irrigation, rutter, state_available)
      call require(state_available, 'typed management snapshot ready')
    class default
      call require(.false., 'unexpected management state type')
    end select
  end subroutine extract_state

  logical function same_irrigation(a, b) result(same)
    type(tcs1_dcs2_sprinkling_state_t), intent(in) :: a, b
    same = a%dayfix == b%dayfix .and. a%active_event .eqv. b%active_event .and. &
         abs(a%active_event_start-b%active_event_start) < tol .and. &
         abs(a%active_event_end-b%active_event_end) < tol
  end function same_irrigation

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write(*,'(a,1x,a)') 'RM05_FAIL:', trim(message)
      error stop 1
    end if
  end subroutine require

end program test_rm05_hupsel_management_transaction
