program test_rm06_management_transaction
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_candidate_state_t, kernel_executor_t, &
       kernel_result_t, kernel_diagnostics_t, KERNEL_COMMIT_STATUS_COMMITTED
  use mod_tcs1_dcs2_sprinkling_irrigation_process, only: tcs1_dcs2_sprinkling_parameters_t, &
       tcs1_dcs2_sprinkling_state_t, tcs1_dcs2_sprinkling_request_t
  use mod_rutter_interception_process, only: rutter_state_t, rutter_interval_input_t
  use mod_fmr_hupsel_management_transaction
  implicit none

  integer(int64), parameter :: lineage_id = 630006_int64
  integer(int64), parameter :: crop_revision = 77_int64
  real(real64), parameter :: t0 = 237.0_real64
  real(real64), parameter :: event_duration = 2.0_real64/36.0_real64
  real(real64), parameter :: t1 = t0 + event_duration
  real(real64), parameter :: tol = 1.0e-13_real64

  type(tcs1_dcs2_sprinkling_parameters_t) :: irrigation_parameters
  type(tcs1_dcs2_sprinkling_state_t) :: irrigation0, irr_a, irr_b, irr_commit, irr_restart
  type(rutter_state_t) :: rutter0, rut_a, rut_b, rut_commit, rut_restart
  type(rutter_interval_input_t) :: rutter_template
  type(tcs1_dcs2_sprinkling_request_t) :: request
  type(fmr_hupsel_management_state_t) :: physical0, restart_state
  type(fmr_hupsel_management_parameters_t) :: parameters
  type(fmr_hupsel_management_forcing_t) :: forcing, partial_forcing, invalid_forcing
  type(fmr_hupsel_management_model_t), target :: model
  type(fmr_hupsel_management_observation_t) :: obs_a, obs_b, obs_partial
  type(fmr_hupsel_management_persistence_t) :: persistence
  type(kernel_executor_t) :: executor
  type(kernel_committed_state_t) :: committed, committed_partial
  type(kernel_candidate_state_t) :: candidate_a, candidate_b, candidate_partial
  type(kernel_result_t) :: result_a, result_b, result_partial
  type(kernel_diagnostics_t) :: diag_a, diag_b, diag_partial
  type(canonical_numerical_config_t) :: config
  class(transaction_state_t), allocatable :: initial, candidate_snapshot_a, candidate_snapshot_b
  class(transaction_state_t), allocatable :: committed_snapshot
  logical :: ok, available, exported, reconstructed, did_commit
  integer :: status, commit_status

  call setup_irrigation(irrigation_parameters)
  irrigation0 = tcs1_dcs2_sprinkling_state_t()
  irrigation0%dayfix = 12
  rutter0 = rutter_state_t()
  rutter0%canopy_storage_cm = 0.0_real64

  call initialize_fmr_hupsel_management_state(irrigation0, rutter0, physical0, status)
  call require(status == FMR_RM_OK .and. physical0%ready(), 'initial management state')

  call construct_fmr_hupsel_management_parameters(irrigation_parameters, parameters, status)
  call require(status == FMR_RM_OK .and. parameters%ready(), 'management parameters')

  call physical0%clone(initial)
  call committed%initialize(lineage_id, initial, ok, initial_time=t0)
  call require(ok .and. committed%ready(), 'committed origin')
  call executor%bind_model(model)
  call setup_config(config)

  call setup_request(request)
  call setup_rutter(rutter_template)

  call prepare_fmr_hupsel_management_forcing(request, rutter_template, crop_revision, &
       2.0_real64, 2.0_real64, forcing, status)
  call require(status == FMR_RM_OK .and. forcing%ready(), 'full-realization forcing')

  ! First trial: candidate only. Committed state must remain untouched.
  call executor%advance_interval(parameters, committed, forcing, config, t0, t1, result_a, candidate_a, diag_a)
  call require(result_a%completed .and. candidate_a%ready(), 'first candidate materialized')
  call require(committed%current_revision() == 0_int64, 'first trial does not commit')
  call model%observation(obs_a)
  call require_observation(obs_a, 'first observation')
  call candidate_a%snapshot(candidate_snapshot_a, available)
  call require(available .and. allocated(candidate_snapshot_a), 'first candidate snapshot')
  call unpack_management(candidate_snapshot_a, irr_a, rut_a)

  call executor%rollback_candidate(candidate_a, diag_a)
  call require(.not. candidate_a%ready(), 'first candidate rolled back')
  call require(committed%current_revision() == 0_int64, 'rollback leaves revision unchanged')
  call committed%snapshot(committed_snapshot, available)
  call require(available, 'origin snapshot after rollback')
  call unpack_management(committed_snapshot, irr_commit, rut_commit)
  call require(same_irrigation(irr_commit, irrigation0), 'rollback restores irrigation origin')
  call require(same_rutter(rut_commit, rutter0), 'rollback restores Rutter origin')
  if (allocated(committed_snapshot)) deallocate(committed_snapshot)

  ! Replay from exactly the same accepted origin.
  call executor%advance_interval(parameters, committed, forcing, config, t0, t1, result_b, candidate_b, diag_b)
  call require(result_b%completed .and. candidate_b%ready(), 'replay candidate materialized')
  call model%observation(obs_b)
  call candidate_b%snapshot(candidate_snapshot_b, available)
  call require(available .and. allocated(candidate_snapshot_b), 'replay candidate snapshot')
  call unpack_management(candidate_snapshot_b, irr_b, rut_b)
  call require(same_irrigation(irr_a, irr_b), 'irrigation retry identity')
  call require(same_rutter(rut_a, rut_b), 'Rutter retry identity')
  call require(same_observation(obs_a, obs_b), 'management observation retry identity')

  ! Gross supplied water and net irrigation are deliberately not the same.
  call require(abs(obs_b%requested_depth_cm-2.0_real64) <= tol, 'requested depth')
  call require(abs(obs_b%allocated_depth_cm-2.0_real64) <= tol, 'allocated depth')
  call require(abs(obs_b%supplied_depth_cm-2.0_real64) <= tol, 'physically supplied gross depth')
  call require(obs_b%net_surface_irrigation_amount_cm >= 0.0_real64, 'net irrigation nonnegative')
  call require(obs_b%net_surface_irrigation_amount_cm < obs_b%supplied_depth_cm, 'Rutter net distinct from gross')
  call require(obs_b%crop_origin_revision == crop_revision, 'crop origin identity retained')

  call executor%commit_candidate(committed, candidate_b, diag_b, did_commit, commit_status)
  call require(did_commit .and. commit_status == KERNEL_COMMIT_STATUS_COMMITTED, 'candidate commit')
  call require(committed%current_revision() == 1_int64, 'commit advances revision once')
  call require(.not. candidate_b%ready(), 'committed candidate consumed')

  call committed%snapshot(committed_snapshot, available)
  call require(available .and. allocated(committed_snapshot), 'committed snapshot')
  call unpack_management(committed_snapshot, irr_commit, rut_commit)
  call require(same_irrigation(irr_commit, irr_b), 'committed irrigation equals candidate')
  call require(same_rutter(rut_commit, rut_b), 'committed Rutter equals candidate')

  ! Accepted persistence must reconstruct exactly.
  select type (typed => committed_snapshot)
  type is (fmr_hupsel_management_state_t)
    call export_fmr_hupsel_management_persistence(typed, persistence, exported, status)
  class default
    call require(.false., 'committed snapshot type')
  end select
  call require(exported .and. status == FMR_RM_OK .and. persistence%ready(), 'persistence export')
  call reconstruct_fmr_hupsel_management_from_persistence(persistence, restart_state, reconstructed, status)
  call require(reconstructed .and. status == FMR_RM_OK .and. restart_state%ready(), 'persistence reconstruction')
  call restart_state%snapshot(irr_restart, rut_restart, available)
  call require(available, 'restart snapshot')
  call require(same_irrigation(irr_commit, irr_restart), 'restart irrigation identity')
  call require(same_rutter(rut_commit, rut_restart), 'restart Rutter identity')
  if (allocated(committed_snapshot)) deallocate(committed_snapshot)

  ! supplied > allocated must fail before any candidate can exist.
  call prepare_fmr_hupsel_management_forcing(request, rutter_template, crop_revision, &
       1.0_real64, 1.1_real64, invalid_forcing, status)
  call require(status == FMR_RM_INVALID_FORCING .and. .not. invalid_forcing%ready(), 'supply bounded by allocation')

  ! Partial realization is an explicit fail-closed nonclaim in this profile.
  call physical0%clone(initial)
  call committed_partial%initialize(lineage_id+1_int64, initial, ok, initial_time=t0)
  call require(ok, 'partial origin initialized')
  call prepare_fmr_hupsel_management_forcing(request, rutter_template, crop_revision, &
       1.0_real64, 1.0_real64, partial_forcing, status)
  call require(status == FMR_RM_OK, 'partial forcing structurally valid')
  call executor%advance_interval(parameters, committed_partial, partial_forcing, config, t0, t1, &
       result_partial, candidate_partial, diag_partial)
  call model%observation(obs_partial)
  call require(.not. result_partial%completed .and. .not. candidate_partial%ready(), 'partial supply no candidate')
  call require(model%last_status_code() == FMR_RM_PARTIAL_SUPPLY_NOT_ADMITTED, 'partial supply fail closed')
  call require(committed_partial%current_revision() == 0_int64, 'partial rejection does not commit')
  call require(abs(obs_partial%requested_depth_cm-2.0_real64) <= tol, 'partial request diagnostic')
  call require(abs(obs_partial%allocation_shortage_cm-1.0_real64) <= tol, 'allocation shortage diagnostic')
  call require(abs(obs_partial%realization_shortage_cm) <= tol, 'realization shortage diagnostic')

  write(*,'(A)') 'RM06_CANDIDATE_NONMUTATING=PASS'
  write(*,'(A)') 'RM06_REJECT_RETRY_IRRIGATION_IDENTITY=PASS'
  write(*,'(A)') 'RM06_REJECT_RETRY_RUTTER_IDENTITY=PASS'
  write(*,'(A)') 'RM06_REJECT_RETRY_OBSERVATION_IDENTITY=PASS'
  write(*,'(A)') 'RM06_REQUEST_ALLOCATION_SUPPLY_DISTINCT=PASS'
  write(*,'(A)') 'RM06_GROSS_NET_APPLICATION_DISTINCT=PASS'
  write(*,'(A)') 'RM06_EXACTLY_ONCE_COMMIT=PASS'
  write(*,'(A)') 'RM06_RESTART_PERSISTENCE_IDENTITY=PASS'
  write(*,'(A)') 'RM06_SUPPLY_LE_ALLOCATION=PASS'
  write(*,'(A)') 'RM06_PARTIAL_SUPPLY_FAIL_CLOSED=PASS'
  write(*,'(A)') 'RM06 MANAGEMENT TRANSACTION QUALIFICATION PASS'

contains

  subroutine setup_irrigation(p)
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
  end subroutine setup_irrigation

  subroutine setup_request(r)
    type(tcs1_dcs2_sprinkling_request_t), intent(out) :: r
    r = tcs1_dcs2_sprinkling_request_t()
    r%t0 = t0
    r%t1 = t1
    r%dvs = 1.5060476190476193_real64
    r%potential_transpiration_day_cm = 0.31534971046284993_real64
    r%dry_reduction_day_cm = 0.11551480616973946_real64
    r%salinity_reduction_day_cm = 0.0_real64
    r%selection_opportunity = .true.
    r%irrigation_enabled = .true.
    r%schedule_enabled = .true.
    r%crop_emerged = .true.
    r%irrigation_window_open = .true.
  end subroutine setup_request

  subroutine setup_rutter(r)
    type(rutter_interval_input_t), intent(out) :: r
    r = rutter_interval_input_t()
    r%gross_rain_cm_per_day = 0.0_real64
    r%vegetation_cover_fraction = 0.5_real64
    r%canopy_storage_capacity_cm = 0.5_real64
    r%interception_evaporation_capacity_cm_per_day = 0.0_real64
    r%potential_transpiration_dry_cm_per_day = 0.0_real64
    r%potential_transpiration_wet_cm_per_day = 0.0_real64
    r%interval_days = event_duration
  end subroutine setup_rutter

  subroutine setup_config(c)
    type(canonical_numerical_config_t), intent(out) :: c
    c = canonical_numerical_config_t()
    c%transaction%temporal_mode = TX_TEMPORAL_MODEL_CERTIFICATE
    c%transaction%temporal_tolerance = 0.0_real64
    c%transaction%mass_tolerance = 0.0_real64
    c%transaction%retry_scale = 0.5_real64
    c%transaction%max_retries = 0
    c%max_committed_substeps = 1
    c%progress_tolerance = 0.0_real64
  end subroutine setup_config

  subroutine unpack_management(box, irrigation, rutter)
    class(transaction_state_t), allocatable, intent(in) :: box
    type(tcs1_dcs2_sprinkling_state_t), intent(out) :: irrigation
    type(rutter_state_t), intent(out) :: rutter
    logical :: got
    call require(allocated(box), 'management box allocated')
    select type (typed => box)
    type is (fmr_hupsel_management_state_t)
      call typed%snapshot(irrigation, rutter, got)
      call require(got, 'management snapshot ready')
    class default
      call require(.false., 'management box type')
    end select
  end subroutine unpack_management

  logical function same_irrigation(a,b)
    type(tcs1_dcs2_sprinkling_state_t), intent(in) :: a,b
    same_irrigation = a%dayfix == b%dayfix .and. a%active_event .eqv. b%active_event .and. &
         transfer(a%active_event_start,0_int64) == transfer(b%active_event_start,0_int64) .and. &
         transfer(a%active_event_end,0_int64) == transfer(b%active_event_end,0_int64)
  end function same_irrigation

  logical function same_rutter(a,b)
    type(rutter_state_t), intent(in) :: a,b
    same_rutter = transfer(a%canopy_storage_cm,0_int64) == transfer(b%canopy_storage_cm,0_int64)
  end function same_rutter

  logical function same_observation(a,b)
    type(fmr_hupsel_management_observation_t), intent(in) :: a,b
    same_observation = a%decision_evaluated .eqv. b%decision_evaluated
    same_observation = same_observation .and. (a%irrigation_requested .eqv. b%irrigation_requested)
    same_observation = same_observation .and. a%crop_origin_revision == b%crop_origin_revision
    same_observation = same_observation .and. same_real(a%requested_depth_cm,b%requested_depth_cm)
    same_observation = same_observation .and. same_real(a%allocated_depth_cm,b%allocated_depth_cm)
    same_observation = same_observation .and. same_real(a%supplied_depth_cm,b%supplied_depth_cm)
    same_observation = same_observation .and. same_real(a%allocation_shortage_cm,b%allocation_shortage_cm)
    same_observation = same_observation .and. same_real(a%realization_shortage_cm,b%realization_shortage_cm)
    same_observation = same_observation .and. same_real(a%gross_surface_rate_cm_per_day,b%gross_surface_rate_cm_per_day)
    same_observation = same_observation .and. same_real(a%net_surface_irrigation_amount_cm,b%net_surface_irrigation_amount_cm)
  end function same_observation

  logical function same_real(a,b)
    real(real64), intent(in) :: a,b
    same_real = transfer(a,0_int64) == transfer(b,0_int64)
  end function same_real

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'RM06_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

  subroutine require_observation(o, label)
    type(fmr_hupsel_management_observation_t), intent(in) :: o
    character(len=*), intent(in) :: label
    call require(o%decision_evaluated, trim(label)//' decision')
    call require(o%irrigation_requested, trim(label)//' requested')
    call require(abs(o%requested_depth_cm-2.0_real64) <= tol, trim(label)//' request depth')
    call require(abs(o%allocated_depth_cm-2.0_real64) <= tol, trim(label)//' allocation depth')
    call require(abs(o%supplied_depth_cm-2.0_real64) <= tol, trim(label)//' supply depth')
  end subroutine require_observation

end program test_rm06_management_transaction
