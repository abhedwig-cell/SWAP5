program test_fmr04_serialized_physical
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use MOD_swap_base, only: swmacro
  use MOD_snow, only: melt
  use MOD_drain, only: legacy_qdra => qdra
  use MOD_irrigation, only: legacy_qssdi => qssdi
  use variables, only: legacy_qrot => qrot
  use mod_transaction_reference, only: transaction_state_t
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_candidate_state_t, &
       kernel_result_t, kernel_diagnostics_t, kernel_executor_t, KERNEL_STATUS_NOT_ADMITTED, &
       KERNEL_STATUS_CHECKPOINT_MISMATCH
  use mod_fmr_checkpoint_orchestrator, only: fmr_capture_checkpoint, fmr_commit_candidate, fmr_discard_candidate
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_serialized_reference_backend_t, fmr_serialized_physical_observation_t, &
       fmr_new_b110_committed_state
  use mod_fmr04_fixed_top_provider, only: fmr04_fixed_flux_top_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  implicit none

  real(real64), parameter :: t0 = 1000.125_real64
  real(real64), parameter :: t1 = 1000.625_real64
  real(real64), parameter :: head0 = -75.0_real64
  integer(int64), parameter :: column_id = 40401_int64
  integer(int64), parameter :: template_id = 404_int64
  integer(int64), parameter :: lineage_id = 40401_int64

  type(fmr_logical_column_t) :: column
  type(fmr_template_t) :: template
  type(fmr_b110_physical_parameters_t) :: parameters, bad_parameters
  type(fmr_b110_physical_forcing_t) :: forcing, bad_forcing
  type(fmr_b110_physical_state_t) :: initial_state
  type(fmr_serialized_reference_backend_t), target :: backend
  type(fmr04_fixed_flux_top_provider_t), target :: top_provider
  type(kernel_committed_state_t) :: committed
  type(kernel_checkpoint_t) :: checkpoint, committed_checkpoint
  type(kernel_candidate_state_t) :: candidate, replay_candidate, rejected_candidate
  type(kernel_result_t) :: result, replay_result, rejected_result
  type(kernel_diagnostics_t) :: diagnostics, replay_diagnostics, rejected_diagnostics
  type(kernel_executor_t) :: transaction_control
  type(fmr_serialized_physical_observation_t) :: observation
  type(canonical_numerical_config_t) :: config
  integer(int64) :: committed_fp0, committed_fp_after_rollback, candidate_fp1, candidate_fp2
  integer(int64) :: revision0, revision1
  real(real64) :: committed_time, initial_storage, endpoint_storage
  real(real64) :: shadow_total_in, shadow_total_out, shadow_residual
  logical :: ok, available, did_commit
  integer :: commit_status

  call configure_fixture(column, template, parameters, forcing, initial_state, initial_storage)
  call configure_transaction(config)
  call backend%initialize(top_provider)
  call fmr_new_b110_committed_state(committed, lineage_id, initial_state, t0, ok)
  call require(ok, 'committed state initialization')
  revision0 = committed%current_revision()
  call require(revision0 == 0_int64, 'initial revision')
  call committed%current_time(committed_time, available)
  call require(available .and. same_real(committed_time,t0), 'initial committed time')
  committed_fp0 = committed_fingerprint(committed)

  call fmr_capture_checkpoint(committed, checkpoint, ok)
  call require(ok .and. checkpoint%ready(), 'checkpoint capture')
  call backend%run_trial(column, template, parameters, committed, forcing, config, t0, t1, checkpoint, &
       result, candidate, diagnostics)
  call require(result%completed .and. candidate%ready(), 'physical candidate materialized')
  call require(.not. result%mass%complete, 'F-KT full interval mass boundary remains explicitly incomplete')
  call require(diagnostics%mass_rejections == 0, 'hard per-trial mass gate accepted physical route')
  call require(diagnostics%max_abs_step_mass_residual <= 1.0e-12_real64, 'hard per-trial mass residual')
  call require(committed%current_revision() == revision0, 'trial did not mutate committed revision')
  call committed%current_time(committed_time, available)
  call require(available .and. same_real(committed_time,t0), 'trial did not mutate committed time')
  call require(committed_fingerprint(committed) == committed_fp0, 'trial did not mutate committed physics')

  observation = backend%observation()
  call require(observation%solver_executed, 'real F-SI solver executed')
  call require(trim(observation%solver_diagnostics%route) == 'legacy-reference-bound', 'real HeadCalc route')
  call require(observation%solver_diagnostics%nonlinear_iterations >= 1, 'solver iterations recorded')
  call require(.not. observation%solver_equation_residual_available, 'solver equation residual not invented')
  candidate_fp1 = candidate_fingerprint(candidate)
  endpoint_storage = candidate_storage(candidate, parameters%dz)
  call shadow_profile_mass(forcing, observation, t1-t0, initial_storage, endpoint_storage, &
       shadow_total_in, shadow_total_out, shadow_residual)
  call require(abs(shadow_residual) <= 1.0e-12_real64, 'diagnostic profile accounting closes')

  call fmr_discard_candidate(transaction_control, candidate, diagnostics)
  call require(.not. candidate%ready(), 'candidate discarded')
  committed_fp_after_rollback = committed_fingerprint(committed)
  call require(committed_fp_after_rollback == committed_fp0, 'rollback committed state unchanged')
  call require(committed%current_revision() == revision0, 'rollback revision unchanged')

  call backend%run_trial(column, template, parameters, committed, forcing, config, t0, t1, checkpoint, &
       replay_result, replay_candidate, replay_diagnostics)
  call require(replay_result%completed .and. replay_candidate%ready(), 'replay candidate materialized')
  call require(.not. replay_result%mass%complete, 'replay preserves explicit full-mass hold')
  candidate_fp2 = candidate_fingerprint(replay_candidate)
  call require(candidate_fp2 == candidate_fp1, 'checkpoint replay candidate identity')
  call require(replay_diagnostics%max_abs_step_mass_residual == diagnostics%max_abs_step_mass_residual, &
       'replay per-trial mass diagnostic identity')

  bad_parameters = parameters
  bad_parameters%root_extraction_active = .true.
  call expect_not_admitted('active-root-parameter', bad_parameters)
  bad_parameters = parameters
  bad_parameters%macropore_active = .true.
  call expect_not_admitted('macropore', bad_parameters)
  bad_parameters = parameters
  bad_parameters%snow_active = .true.
  call expect_not_admitted('snow', bad_parameters)
  bad_parameters = parameters
  bad_parameters%swkimpl = 1
  call expect_not_admitted('swkimpl1', bad_parameters)

  bad_forcing = forcing
  bad_forcing%root_extraction_sink(1) = 1.0e-8_real64
  call backend%run_trial(column, template, parameters, committed, bad_forcing, config, t0, t1, checkpoint, &
       rejected_result, rejected_candidate, rejected_diagnostics)
  call require(.not. rejected_result%completed .and. .not. rejected_candidate%ready(), 'nonzero qrot forcing rejected')
  call require(committed_fingerprint(committed) == committed_fp0, 'qrot rejection leaves committed state unchanged')

  ! This commit is transaction/composition evidence only. It does not admit the physical backend
  ! because F-KT has not yet materialized complete accepted full-interval mass accounting.
  call fmr_commit_candidate(transaction_control, committed, replay_candidate, replay_diagnostics, did_commit, commit_status)
  call require(did_commit, 'physical candidate transaction commit')
  revision1 = committed%current_revision()
  call require(revision1 == revision0 + 1_int64, 'commit revision increments once')
  call committed%current_time(committed_time, available)
  call require(available .and. same_real(committed_time,t1), 'commit advances committed time to t1')
  call require(committed_fingerprint(committed) == candidate_fp2, 'committed endpoint equals replay candidate')

  ! Start from the current committed time so the stale-revision guard is tested directly,
  ! without the earlier committed-time-origin guard masking the checkpoint mismatch.
  call backend%run_trial(column, template, parameters, committed, forcing, config, t1, t1+(t1-t0), checkpoint, &
       rejected_result, rejected_candidate, rejected_diagnostics)
  call require(rejected_result%status == KERNEL_STATUS_CHECKPOINT_MISMATCH, 'stale checkpoint rejected')
  call require(.not. rejected_candidate%ready(), 'stale checkpoint produces no candidate')
  call require(rejected_diagnostics%checkpoint_revision_rejections == 1, 'stale revision diagnosed')

  call fmr_capture_checkpoint(committed, committed_checkpoint, ok)
  call require(ok .and. committed_checkpoint%origin_revision() == revision1, 'new committed checkpoint provenance')

  write(*,'(A,I0)') 'FMR04_COLUMN_ID=', column_id
  write(*,'(A,I0)') 'FMR04_TEMPLATE_ID=', template_id
  write(*,'(A,F0.12)') 'FMR04_T0=', t0
  write(*,'(A,F0.12)') 'FMR04_T1=', t1
  write(*,'(A,I0)') 'FMR04_INITIAL_REVISION=', revision0
  write(*,'(A,I0)') 'FMR04_FINAL_REVISION=', revision1
  write(*,'(A,ES26.17E3)') 'FMR04_DIAGNOSTIC_STORAGE_START=', initial_storage
  write(*,'(A,ES26.17E3)') 'FMR04_DIAGNOSTIC_STORAGE_END=', endpoint_storage
  write(*,'(A,ES26.17E3)') 'FMR04_DIAGNOSTIC_TOTAL_IN=', shadow_total_in
  write(*,'(A,ES26.17E3)') 'FMR04_DIAGNOSTIC_TOTAL_OUT=', shadow_total_out
  write(*,'(A,ES26.17E3)') 'FMR04_DIAGNOSTIC_MASS_RESIDUAL=', shadow_residual
  write(*,'(A,L1)') 'FMR04_KERNEL_FULL_INTERVAL_MASS_COMPLETE=', result%mass%complete
  write(*,'(A,ES26.17E3)') 'FMR04_MAX_ABS_STEP_MASS_RESIDUAL=', diagnostics%max_abs_step_mass_residual
  write(*,'(A,I0)') 'FMR04_CANDIDATE_FINGERPRINT=', candidate_fp2
  write(*,'(A,I0)') 'FMR04_SOLVER_ITERATIONS=', observation%solver_diagnostics%nonlinear_iterations
  write(*,'(A,A)') 'FMR04_SOLVER_ROUTE=', trim(observation%solver_diagnostics%route)
  write(*,'(A)') 'FMR04_REAL_HEADCALC_EXECUTED=TRUE'
  write(*,'(A)') 'FMR04_ROLLBACK=PASS'
  write(*,'(A)') 'FMR04_REPLAY=PASS'
  write(*,'(A)') 'FMR04_COMMIT_TRANSACTION_SEMANTICS=PASS'
  write(*,'(A)') 'FMR04_ACTIVE_ROOT_FAIL_CLOSED=PASS'
  write(*,'(A)') 'FMR04_MACROPORE_FAIL_CLOSED=PASS'
  write(*,'(A)') 'FMR04_SNOW_FAIL_CLOSED=PASS'
  write(*,'(A)') 'FMR04_SWKIMPL1_FAIL_CLOSED=PASS'
  write(*,'(A)') 'FMR04_RETRY_SUBGATE=NOT_TESTED_NO_SAFE_PHYSICAL_FAILURE_INDUCTION'
  write(*,'(A)') 'FMR04_FULL_INTERVAL_MASS_ADMISSION=BLOCKED_FKT_RESULT_BOUNDARY_INCOMPLETE'
  write(*,'(A)') 'FMR04_SERIALIZED_PHYSICAL_COMPOSITION_TEST PASS'

contains

  subroutine configure_fixture(column, template, parameters, forcing, state, storage0)
    type(fmr_logical_column_t), intent(out) :: column
    type(fmr_template_t), intent(out) :: template
    type(fmr_b110_physical_parameters_t), intent(out) :: parameters
    type(fmr_b110_physical_forcing_t), intent(out) :: forcing
    type(fmr_b110_physical_state_t), intent(out) :: state
    real(real64), intent(out) :: storage0
    type(b110_default_mvg_parameters_t), target :: hyd_parameters
    type(b110_default_mvg_provider_t) :: constitutive
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    integer :: i

    column%column_id = column_id
    column%template_id = template_id
    column%parameter_ref = 1_int64
    column%state_handle = 1_int64
    column%forcing_handle = 1_int64
    column%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
    template%template_id = template_id
    template%physics_topology_id = 40401_int64
    template%vertical_layout_id = 40402_int64
    template%state_layout_id = 40403_int64
    template%solver_interface_id = 40404_int64
    template%optional_state_layout_id = 0_int64
    template%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE

    parameters%parameter_set_id = 40401_int64
    parameters%active_nodes = numnod
    allocate(parameters%z(numnod), parameters%dz(numnod), parameters%node_distance(numnod))
    parameters%z = z
    parameters%dz = dz
    parameters%node_distance = disnod(1:numnod)
    allocate(parameters%cofgen(24,numnod))
    parameters%cofgen = 0.0_real64
    do i = 1, numnod
      parameters%cofgen(1,i) = 0.032_real64
      parameters%cofgen(2,i) = 0.423_real64
      parameters%cofgen(3,i) = 4.75_real64
      parameters%cofgen(4,i) = 0.0135_real64
      parameters%cofgen(5,i) = 0.365_real64
      parameters%cofgen(6,i) = 1.455_real64
      parameters%cofgen(7,i) = 1.0_real64 - 1.0_real64/parameters%cofgen(6,i)
      parameters%cofgen(8,i) = parameters%cofgen(4,i)
      parameters%cofgen(9,i) = 0.0_real64
      parameters%cofgen(10,i) = parameters%cofgen(3,i)
      parameters%cofgen(11,i) = 0.999_real64
      parameters%cofgen(12,i) = 0.99_real64*parameters%cofgen(3,i)
      parameters%cofgen(22,i) = -1.0e6_real64
      parameters%cofgen(23,i) = 1.0e-12_real64
    end do
    parameters%bottom_mode = 7
    parameters%swkimpl = 0
    parameters%swkmean = 1
    parameters%swsophy = 0
    parameters%root_extraction_active = .false.
    parameters%macropore_active = .false.
    parameters%snow_active = .false.
    parameters%hysteresis_active = .false.
    parameters%tabulated_hydraulics_active = .false.
    parameters%elasticity_active = .false.
    parameters%frost_active = .false.

    call initialize_b110_default_mvg_parameters(hyd_parameters, parameters%cofgen)
    call bind_b110_default_mvg_provider(constitutive, hyd_parameters, t1-t0)
    heads = head0
    call constitutive%evaluate(heads, water, conductivity, capacity, dkdh)
    call require(all(conductivity == conductivity(1)), 'fixture uniform conductivity')

    state%active_nodes = numnod
    allocate(state%pressure_head(numnod), state%water_content(numnod))
    state%pressure_head = heads
    state%water_content = water
    state%ponding_depth = 0.0_real64
    state%groundwater_level = -2.0_real64
    storage0 = sum(dz*water)

    forcing%top_flux = -conductivity(1)
    forcing%top_head = head0
    forcing%bottom_flux = -conductivity(1)
    forcing%bottom_head = -100.0_real64
    allocate(forcing%drainage_flux_by_level(2,numnod), forcing%subsurface_irrigation_source(numnod), &
             forcing%root_extraction_sink(numnod))
    do i = 1, numnod
      forcing%drainage_flux_by_level(1,i) = 1.0e-5_real64*real(i,real64)
      forcing%drainage_flux_by_level(2,i) = -2.0e-6_real64*real(i+1,real64)
      forcing%subsurface_irrigation_source(i) = forcing%drainage_flux_by_level(1,i) + &
                                                forcing%drainage_flux_by_level(2,i)
      forcing%root_extraction_sink(i) = 0.0_real64
    end do

    legacy_qdra = 12345.0_real64
    legacy_qssdi = -54321.0_real64
    legacy_qrot = 0.0_real64
    swmacro = 0
    melt = 0.0_real64
  end subroutine configure_fixture

  subroutine configure_transaction(config)
    type(canonical_numerical_config_t), intent(out) :: config
    config%transaction%temporal_tolerance = 0.0_real64
    config%transaction%mass_tolerance = 1.0e-12_real64
    config%transaction%retry_scale = 0.5_real64
    config%transaction%max_retries = 2
    config%max_committed_substeps = 8
    config%progress_tolerance = 0.0_real64
  end subroutine configure_transaction

  subroutine expect_not_admitted(label, bad)
    character(len=*), intent(in) :: label
    type(fmr_b110_physical_parameters_t), intent(in) :: bad
    call backend%run_trial(column, template, bad, committed, forcing, config, t0, t1, checkpoint, &
         rejected_result, rejected_candidate, rejected_diagnostics)
    call require(rejected_result%status == KERNEL_STATUS_NOT_ADMITTED, trim(label)//' status')
    call require(.not. rejected_candidate%ready(), trim(label)//' no candidate')
    call require(rejected_diagnostics%admission_rejections == 1, trim(label)//' admission diagnostic')
    call require(committed_fingerprint(committed) == committed_fp0, trim(label)//' committed state unchanged')
  end subroutine expect_not_admitted

  integer(int64) function committed_fingerprint(state) result(fp)
    type(kernel_committed_state_t), intent(in) :: state
    class(transaction_state_t), allocatable :: snapshot
    logical :: got
    call state%snapshot(snapshot, got)
    call require(got, 'committed snapshot')
    fp = physical_fingerprint(snapshot)
  end function committed_fingerprint

  integer(int64) function candidate_fingerprint(state) result(fp)
    type(kernel_candidate_state_t), intent(in) :: state
    class(transaction_state_t), allocatable :: snapshot
    logical :: got
    call state%snapshot(snapshot, got)
    call require(got, 'candidate snapshot')
    fp = physical_fingerprint(snapshot)
  end function candidate_fingerprint

  real(real64) function candidate_storage(state, layer_dz) result(value)
    type(kernel_candidate_state_t), intent(in) :: state
    real(real64), intent(in) :: layer_dz(:)
    class(transaction_state_t), allocatable :: snapshot
    logical :: got
    call state%snapshot(snapshot, got)
    call require(got, 'candidate storage snapshot')
    select type (physical => snapshot)
    type is (fmr_b110_physical_state_t)
      call require(size(layer_dz) == physical%active_nodes, 'candidate storage shape')
      value = sum(layer_dz*physical%water_content) + physical%ponding_depth
    class default
      error stop 'F-MR04 unexpected state in candidate storage'
    end select
  end function candidate_storage

  subroutine shadow_profile_mass(f, obs, duration, storage_start, storage_end, total_in, total_out, residual)
    type(fmr_b110_physical_forcing_t), intent(in) :: f
    type(fmr_serialized_physical_observation_t), intent(in) :: obs
    real(real64), intent(in) :: duration, storage_start, storage_end
    real(real64), intent(out) :: total_in, total_out, residual
    integer :: i, level
    real(real64) :: amount

    total_in = max(0.0_real64,-obs%top_flux)*duration + max(0.0_real64,obs%bottom_flux)*duration
    total_out = max(0.0_real64,obs%top_flux)*duration + max(0.0_real64,-obs%bottom_flux)*duration
    do i = 1, size(f%subsurface_irrigation_source)
      amount = f%subsurface_irrigation_source(i)*duration
      if (amount >= 0.0_real64) then
        total_in = total_in + amount
      else
        total_out = total_out - amount
      end if
    end do
    do level = 1, size(f%drainage_flux_by_level,1)
      do i = 1, size(f%drainage_flux_by_level,2)
        amount = f%drainage_flux_by_level(level,i)*duration
        if (amount >= 0.0_real64) then
          total_out = total_out + amount
        else
          total_in = total_in - amount
        end if
      end do
    end do
    residual = storage_start + total_in - total_out - storage_end
  end subroutine shadow_profile_mass

  integer(int64) function physical_fingerprint(snapshot) result(fp)
    class(transaction_state_t), intent(in) :: snapshot
    integer :: i
    fp = 1469598103934665603_int64
    select type (physical => snapshot)
    type is (fmr_b110_physical_state_t)
      fp = ieor(fp, int(physical%active_nodes,int64))
      do i = 1, physical%active_nodes
        fp = ieor(fp, transfer(physical%pressure_head(i),fp))
        fp = ieor(fp, transfer(physical%water_content(i),fp))
      end do
      fp = ieor(fp, transfer(physical%ponding_depth,fp))
      fp = ieor(fp, transfer(physical%groundwater_level,fp))
    class default
      error stop 'F-MR04 unexpected physical state type'
    end select
  end function physical_fingerprint

  logical function same_real(a,b)
    real(real64), intent(in) :: a,b
    real(real64) :: scale
    scale = max(1.0_real64,abs(a),abs(b))
    same_real = abs(a-b) <= 16.0_real64*epsilon(1.0_real64)*scale
  end function same_real

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FMR04_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fmr04_serialized_physical