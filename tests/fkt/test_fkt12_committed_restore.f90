program test_fkt12_committed_restore
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_transaction_reference, only: transaction_state_t
  use mod_canonical_contracts, only: canonical_numerical_config_t, canonical_mass_accounting_t, &
       CANONICAL_STATUS_COMPLETED
  use mod_kernel_transactions
  use mod_kernel_committed_persistence
  use mod_fkt05_test_model
  implicit none

  integer :: failures

  failures = 0
  call test_split_run_restore_and_provenance(failures)
  call test_fail_closed_carriers(failures)

  if (failures /= 0) then
    write(*,'(A,I0)') 'FKT12_COMMITTED_RESTORE_GATE FAIL failures=', failures
    error stop 1
  end if
  write(*,'(A)') 'FKT12_COMMITTED_RESTORE_GATE PASS'

contains

  subroutine expect_true(condition, label, failures)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    integer, intent(inout) :: failures
    if (.not. condition) then
      failures = failures + 1
      write(*,'(A,A)') 'FAIL ', trim(label)
    end if
  end subroutine expect_true

  subroutine expect_bits(actual, expected, label, failures)
    real(real64), intent(in) :: actual, expected
    character(len=*), intent(in) :: label
    integer, intent(inout) :: failures
    call expect_true(transfer(actual, 0_int64) == transfer(expected, 0_int64), label, failures)
  end subroutine expect_bits

  subroutine new_physical(state, water)
    class(transaction_state_t), allocatable, intent(out) :: state
    real(real64), intent(in) :: water
    allocate(fkt05_state_t :: state)
    select type (state)
    type is (fkt05_state_t)
      state%water = water
    class default
      error stop 'FKT12 unexpected allocation type'
    end select
  end subroutine new_physical

  subroutine new_committed(committed, lineage, water, initial_time)
    type(kernel_committed_state_t), intent(out) :: committed
    integer(int64), intent(in) :: lineage
    real(real64), intent(in) :: water, initial_time
    class(transaction_state_t), allocatable :: state
    logical :: ok

    call new_physical(state, water)
    call committed%initialize(lineage, state, ok, initial_time)
    if (.not. ok) error stop 'FKT12 initialization failed'
  end subroutine new_committed

  subroutine setup(parameters, forcing, config)
    type(fkt05_parameters_t), intent(out) :: parameters
    type(fkt05_forcing_t), intent(out) :: forcing
    type(canonical_numerical_config_t), intent(out) :: config

    parameters%rate = 0.1_real64
    forcing%scale = 1.0_real64
    config%transaction%temporal_tolerance = 1.0_real64
    config%transaction%mass_tolerance = 1.0e-12_real64
    config%transaction%retry_scale = 0.5_real64
    config%transaction%max_retries = 1
    config%max_committed_substeps = 8
    config%progress_tolerance = 0.0_real64
  end subroutine setup

  function physical_water(state) result(value)
    class(transaction_state_t), allocatable, intent(in) :: state
    real(real64) :: value
    select type (state)
    type is (fkt05_state_t)
      value = state%water
    class default
      error stop 'FKT12 physical snapshot type mismatch'
    end select
  end function physical_water

  function committed_water(committed) result(value)
    type(kernel_committed_state_t), intent(in) :: committed
    class(transaction_state_t), allocatable :: state
    logical :: ok
    real(real64) :: value

    call committed%snapshot(state, ok)
    if (.not. ok) error stop 'FKT12 committed snapshot unavailable'
    value = physical_water(state)
  end function committed_water

  subroutine committed_time(committed, value)
    type(kernel_committed_state_t), intent(in) :: committed
    real(real64), intent(out) :: value
    logical :: ok
    call committed%current_time(value, ok)
    if (.not. ok) error stop 'FKT12 committed time unavailable'
  end subroutine committed_time

  subroutine advance_once(kernel, committed, parameters, forcing, config, t0, t1, candidate, result, diagnostics)
    type(kernel_executor_t), intent(inout) :: kernel
    type(kernel_committed_state_t), intent(in) :: committed
    type(fkt05_parameters_t), intent(in) :: parameters
    type(fkt05_forcing_t), intent(in) :: forcing
    type(canonical_numerical_config_t), intent(in) :: config
    real(real64), intent(in) :: t0, t1
    type(kernel_candidate_state_t), intent(out) :: candidate
    type(kernel_result_t), intent(out) :: result
    type(kernel_diagnostics_t), intent(out) :: diagnostics

    call kernel%advance_interval(parameters, committed, forcing, config, t0, t1, result, candidate, diagnostics)
  end subroutine advance_once

  subroutine test_split_run_restore_and_provenance(failures)
    integer, intent(inout) :: failures
    real(real64), parameter :: t0 = 10.0_real64, t1 = 10.5_real64, t2 = 11.0_real64
    integer(int64), parameter :: lineage = 12001_int64, layout = 7001_int64
    type(kernel_committed_state_t) :: continuous, split, restored
    type(kernel_persistence_snapshot_t) :: persisted
    type(kernel_checkpoint_t) :: stale_checkpoint, restored_checkpoint
    type(kernel_candidate_state_t) :: continuous_c1, continuous_c2
    type(kernel_candidate_state_t) :: split_c1, stale_candidate, split_c2, rejected_candidate
    type(kernel_result_t) :: result_c1, result_c2, result_s1, result_s2, rejected_result
    type(kernel_diagnostics_t) :: diag_c1, diag_c2, diag_s1, diag_s2, rejected_diag, stale_diag
    type(fkt05_parameters_t) :: parameters_c, parameters_s
    type(fkt05_forcing_t) :: forcing_c, forcing_s
    type(canonical_numerical_config_t) :: config_c, config_s
    type(fkt05_model_t), target :: model_c, model_s
    type(kernel_executor_t) :: kernel_c, kernel_s
    type(canonical_mass_accounting_t) :: mass_c1, mass_c2, mass_s1, mass_s2
    class(transaction_state_t), allocatable :: carrier_state
    logical :: ok, did_commit, restored_ok
    integer :: commit_status, persistence_status
    real(real64) :: split_t1_water, restored_t1_water, time_value
    real(real64) :: original_carrier_water
    integer(int64) :: split_revision_before_stale

    call setup(parameters_c, forcing_c, config_c)
    call setup(parameters_s, forcing_s, config_s)
    call new_committed(continuous, lineage, 1.0_real64, t0)
    call new_committed(split, lineage, 1.0_real64, t0)
    call kernel_c%bind_model(model_c)
    call kernel_s%bind_model(model_s)

    ! Continuous reference T0 -> T1.
    call advance_once(kernel_c, continuous, parameters_c, forcing_c, config_c, t0, t1, &
         continuous_c1, result_c1, diag_c1)
    call expect_true(result_c1%status == CANONICAL_STATUS_COMPLETED, 'continuous T0-T1 completes', failures)
    call kernel_c%commit_candidate(continuous, continuous_c1, diag_c1, did_commit, commit_status, mass_c1)
    call expect_true(did_commit .and. commit_status == KERNEL_COMMIT_STATUS_COMMITTED, &
         'continuous T1 commit', failures)

    ! Split path retains revision-zero provenance intentionally so it can be
    ! tested after the process-boundary carrier has been restored.
    call split%capture_checkpoint(stale_checkpoint, ok)
    call expect_true(ok .and. stale_checkpoint%origin_revision() == 0_int64, &
         'pre-restart checkpoint captured', failures)
    call advance_once(kernel_s, split, parameters_s, forcing_s, config_s, t0, t1, &
         stale_candidate, rejected_result, stale_diag)
    call expect_true(stale_candidate%ready() .and. stale_candidate%origin_revision() == 0_int64, &
         'pre-restart stale candidate captured', failures)
    call advance_once(kernel_s, split, parameters_s, forcing_s, config_s, t0, t1, &
         split_c1, result_s1, diag_s1)
    call expect_true(result_s1%status == CANONICAL_STATUS_COMPLETED, 'split T0-T1 completes', failures)
    call kernel_s%commit_candidate(split, split_c1, diag_s1, did_commit, commit_status, mass_s1)
    call expect_true(did_commit .and. commit_status == KERNEL_COMMIT_STATUS_COMMITTED, 'split T1 commit', failures)
    call expect_true(split%current_revision() == 1_int64, 'split revision one before export', failures)
    call expect_bits(committed_water(split), committed_water(continuous), 'T1 physical identity before export', failures)
    split_t1_water = committed_water(split)

    call export_kernel_committed_state(split, layout, persisted, ok, persistence_status)
    call expect_true(ok .and. persistence_status == KERNEL_PERSISTENCE_OK, 'persistence export succeeds', failures)
    call expect_true(persisted%ready(), 'persistence carrier ready', failures)
    call expect_true(persisted%schema_version() == KERNEL_PERSISTENCE_SCHEMA_VERSION, 'schema exact', failures)
    call expect_true(persisted%layout_id() == layout, 'layout exact', failures)
    call expect_true(persisted%current_lineage_id() == lineage, 'lineage persisted', failures)
    call expect_true(persisted%current_revision() == 1_int64, 'revision persisted', failures)
    call persisted%current_time(time_value, ok)
    call expect_true(ok, 'carrier time available', failures)
    call expect_bits(time_value, t1, 'carrier time exact', failures)
    call expect_true(persisted%time_is_bound(), 'carrier time bound', failures)
    call expect_true(split%current_revision() == 1_int64, 'export leaves source revision unchanged', failures)
    call expect_bits(committed_water(split), split_t1_water, 'export leaves source physical state unchanged', failures)

    call persisted%snapshot_physical(carrier_state, ok)
    call expect_true(ok, 'carrier physical snapshot available', failures)
    original_carrier_water = physical_water(carrier_state)
    select type (carrier_state)
    type is (fkt05_state_t)
      carrier_state%water = 999.0_real64
    class default
      call expect_true(.false., 'carrier snapshot mutable clone type', failures)
    end select
    call persisted%snapshot_physical(carrier_state, ok)
    call expect_true(ok, 'carrier physical resnapshot available', failures)
    call expect_bits(physical_water(carrier_state), original_carrier_water, 'carrier physical snapshot isolated', failures)

    ! Fresh runtime object after the committed boundary.
    call restore_kernel_committed_state(persisted, layout, restored, restored_ok, persistence_status)
    call expect_true(restored_ok .and. persistence_status == KERNEL_PERSISTENCE_OK, 'restore succeeds', failures)
    call expect_true(restored%ready(), 'restored committed state ready', failures)
    call expect_true(restored%current_lineage_id() == lineage, 'restored lineage preserved', failures)
    call expect_true(restored%current_revision() == 1_int64, 'restored revision preserved', failures)
    call committed_time(restored, time_value)
    call expect_bits(time_value, t1, 'restored committed time exact', failures)
    restored_t1_water = committed_water(restored)
    call expect_bits(restored_t1_water, split_t1_water, 'restore creates zero storage transfer', failures)
    write(*,'(A)') 'FKT12_EXPORT_RESTORE_PHYSICAL_LINEAGE_REVISION_TIME_EXACT=PASS'
    write(*,'(A)') 'FKT12_RESTORE_ZERO_PHYSICAL_TRANSFER=PASS'

    ! Old candidate has same stable lineage but revision zero. It must remain
    ! stale after restore rather than being accidentally re-admitted.
    split_revision_before_stale = restored%current_revision()
    call kernel_s%commit_candidate(restored, stale_candidate, stale_diag, did_commit, commit_status)
    call expect_true(.not. did_commit, 'old candidate rejected after restore', failures)
    call expect_true(commit_status == KERNEL_COMMIT_STATUS_STALE_REVISION, 'old candidate stale revision status', failures)
    call expect_true(stale_diag%stale_revision_rejections >= 1, 'old candidate stale revision diagnosed', failures)
    call expect_true(restored%current_revision() == split_revision_before_stale, &
         'stale candidate leaves restored revision unchanged', failures)
    call expect_bits(committed_water(restored), restored_t1_water, 'stale candidate leaves restored state unchanged', failures)

    call kernel_s%advance_interval(parameters_s, restored, forcing_s, config_s, t1, t2, &
         rejected_result, rejected_candidate, rejected_diag, stale_checkpoint)
    call expect_true(rejected_result%status == KERNEL_STATUS_CHECKPOINT_MISMATCH, &
         'old checkpoint rejected after restore', failures)
    call expect_true(rejected_diag%checkpoint_revision_rejections == 1, 'old checkpoint stale revision diagnosed', failures)
    call expect_true(.not. rejected_candidate%ready(), 'old checkpoint rejected before candidate materialization', failures)
    call expect_bits(committed_water(restored), restored_t1_water, 'stale checkpoint leaves restored state unchanged', failures)
    write(*,'(A)') 'FKT12_PRE_RESTART_STALE_PROVENANCE_REMAINS_REJECTED=PASS'

    call restored%capture_checkpoint(restored_checkpoint, ok)
    call expect_true(ok .and. restored_checkpoint%origin_revision() == 1_int64, &
         'next checkpoint starts at restored revision', failures)
    call restored_checkpoint%current_time(time_value, ok)
    call expect_true(ok, 'next checkpoint restored time available', failures)
    call expect_bits(time_value, t1, 'next checkpoint restored time exact', failures)

    ! Continuous and restored paths now advance T1 -> T2 independently.
    call advance_once(kernel_c, continuous, parameters_c, forcing_c, config_c, t1, t2, &
         continuous_c2, result_c2, diag_c2)
    call expect_true(continuous_c2%origin_revision() == 1_int64, 'continuous next candidate revision', failures)
    call kernel_c%commit_candidate(continuous, continuous_c2, diag_c2, did_commit, commit_status, mass_c2)
    call expect_true(did_commit, 'continuous T2 commit', failures)

    call kernel_s%advance_interval(parameters_s, restored, forcing_s, config_s, t1, t2, &
         result_s2, split_c2, diag_s2, restored_checkpoint)
    call expect_true(result_s2%status == CANONICAL_STATUS_COMPLETED, 'restored T1-T2 completes', failures)
    call expect_true(split_c2%origin_revision() == 1_int64, 'restored next candidate revision', failures)
    call expect_true(split_c2%current_lineage_id() == lineage, 'restored next candidate lineage', failures)
    call kernel_s%commit_candidate(restored, split_c2, diag_s2, did_commit, commit_status, mass_s2)
    call expect_true(did_commit .and. commit_status == KERNEL_COMMIT_STATUS_COMMITTED, 'restored T2 commit', failures)

    call expect_true(continuous%current_revision() == 2_int64, 'continuous revision two', failures)
    call expect_true(restored%current_revision() == 2_int64, 'restored revision monotonic to two', failures)
    call expect_true(continuous%current_lineage_id() == restored%current_lineage_id(), 'T2 lineage identity', failures)
    call expect_bits(committed_water(restored), committed_water(continuous), 'continuous split endpoint physical identity', failures)
    call committed_time(continuous, time_value)
    call expect_bits(time_value, t2, 'continuous T2 time', failures)
    call committed_time(restored, time_value)
    call expect_bits(time_value, t2, 'restored T2 time', failures)
    write(*,'(A)') 'FKT12_EXACT_SPLIT_RUN_ENDPOINT_IDENTITY=PASS'
    write(*,'(A)') 'FKT12_REVISION_AND_LINEAGE_CONTINUATION=PASS'

    ! Mass is interval-authoritative. Restore adds no transfer and must not
    ! reset or double-count the next interval's starting storage.
    call expect_true(mass_c1%complete .and. mass_s1%complete .and. mass_c2%complete .and. mass_s2%complete, &
         'all accepted interval mass certificates complete', failures)
    call expect_bits(mass_s1%storage_start, mass_c1%storage_start, 'T0-T1 mass storage start identity', failures)
    call expect_bits(mass_s1%storage_end, mass_c1%storage_end, 'T0-T1 mass storage end identity', failures)
    call expect_bits(mass_s2%storage_start, mass_c2%storage_start, 'T1-T2 mass storage start identity', failures)
    call expect_bits(mass_s2%storage_end, mass_c2%storage_end, 'T1-T2 mass storage end identity', failures)
    call expect_bits(mass_s2%residual, mass_c2%residual, 'T1-T2 mass residual identity', failures)
    call expect_true(abs(mass_s1%residual) <= config_s%transaction%mass_tolerance, 'split T0-T1 mass closes', failures)
    call expect_true(abs(mass_s2%residual) <= config_s%transaction%mass_tolerance, 'restored T1-T2 mass closes', failures)
    write(*,'(A)') 'FKT12_MASS_CONTINUATION_WITHOUT_LEDGER_RESET=PASS'

    ! Parameter, forcing and numerical request objects are input-only across
    ! export/restore and continuation.
    call expect_bits(parameters_s%rate, 0.1_real64, 'parameters immutable', failures)
    call expect_bits(forcing_s%scale, 1.0_real64, 'forcing immutable', failures)
    call expect_bits(config_s%transaction%mass_tolerance, 1.0e-12_real64, 'config mass tolerance immutable', failures)
    call expect_true(config_s%max_committed_substeps == 8, 'config substep limit immutable', failures)
    write(*,'(A)') 'FKT12_REQUEST_BASE_IMMUTABILITY=PASS'
  end subroutine test_split_run_restore_and_provenance

  subroutine test_fail_closed_carriers(failures)
    integer, intent(inout) :: failures
    integer(int64), parameter :: layout = 7001_int64
    type(kernel_committed_state_t) :: source, empty_target, schema_target, layout_target, initialized_target
    type(kernel_committed_state_t) :: invalid_source
    type(kernel_persistence_snapshot_t) :: valid_snapshot, invalid_snapshot, bad_export
    logical :: ok
    integer :: status
    real(real64) :: before_water
    integer(int64) :: before_revision

    call new_committed(source, 12002_int64, 2.0_real64, 20.0_real64)
    call export_kernel_committed_state(source, layout, valid_snapshot, ok, status)
    call expect_true(ok .and. valid_snapshot%ready(), 'valid carrier fixture', failures)

    call restore_kernel_committed_state(invalid_snapshot, layout, empty_target, ok, status)
    call expect_true(.not. ok .and. status == KERNEL_PERSISTENCE_INVALID_CARRIER, 'missing carrier fails closed', failures)
    call expect_true(.not. empty_target%ready(), 'missing carrier leaves target empty', failures)

    call restore_kernel_committed_state(valid_snapshot, layout, schema_target, ok, status, &
         KERNEL_PERSISTENCE_SCHEMA_VERSION + 1)
    call expect_true(.not. ok .and. status == KERNEL_PERSISTENCE_SCHEMA_MISMATCH, 'wrong schema fails closed', failures)
    call expect_true(.not. schema_target%ready(), 'schema mismatch leaves target empty', failures)

    call restore_kernel_committed_state(valid_snapshot, layout + 1_int64, layout_target, ok, status)
    call expect_true(.not. ok .and. status == KERNEL_PERSISTENCE_LAYOUT_MISMATCH, 'wrong layout fails closed', failures)
    call expect_true(.not. layout_target%ready(), 'layout mismatch leaves target empty', failures)

    call new_committed(initialized_target, 12003_int64, 3.0_real64, 30.0_real64)
    before_water = committed_water(initialized_target)
    before_revision = initialized_target%current_revision()
    call restore_kernel_committed_state(valid_snapshot, layout, initialized_target, ok, status)
    call expect_true(.not. ok .and. status == KERNEL_PERSISTENCE_TARGET_ALREADY_INITIALIZED, &
         'restore cannot overwrite initialized committed state', failures)
    call expect_true(initialized_target%current_revision() == before_revision, 'initialized rejection revision unchanged', failures)
    call expect_bits(committed_water(initialized_target), before_water, 'initialized rejection physical state unchanged', failures)

    call export_kernel_committed_state(invalid_source, layout, bad_export, ok, status)
    call expect_true(.not. ok .and. status == KERNEL_PERSISTENCE_INVALID_SOURCE, 'invalid source export rejected', failures)
    call expect_true(.not. bad_export%ready(), 'invalid source cannot create carrier', failures)

    call export_kernel_committed_state(source, 0_int64, bad_export, ok, status)
    call expect_true(.not. ok .and. status == KERNEL_PERSISTENCE_INVALID_LAYOUT, 'nonpositive layout export rejected', failures)
    call expect_true(.not. bad_export%ready(), 'invalid layout cannot create carrier', failures)
    write(*,'(A)') 'FKT12_INVALID_SCHEMA_LAYOUT_TARGET_FAIL_CLOSED=PASS'
  end subroutine test_fail_closed_carriers

end program test_fkt12_committed_restore
