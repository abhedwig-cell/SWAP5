program fvq09_real_b1_10_temporal_probe
  use, intrinsic :: iso_fortran_env, only: real64
  use MOD_arrays, only: fillen
  use MOD_grid, only: numnod
  use variables, only: tstart, t1900
  use swap_exchange, only: swap_input, swap_output
  use mod_transaction_reference, only: trial_outcome_t
  use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t, a23bu_initialize_worker
  use mod_b1_10_process_checkpoint, only: b1_10_process_state_t, capture_b1_10_process_state
  use mod_b1_10_legacy_trial_capsule, only: b1_10_legacy_trial_capsule_t, &
       capture_b1_10_legacy_trial_capsule, restore_b1_10_legacy_trial_capsule
  use mod_b1_10_recoverable_reference_model, only: b1_10_recoverable_reference_model_t
  use mod_b1_10_temporal_characterization, only: b1_10_temporal_characterization_t, &
       characterize_b1_10_temporal_difference
  implicit none

  real(real64), parameter :: HARD_MASS_LIMIT_CM = 1.0e-6_real64

  interface
    subroutine SWAP(iCaller, iTask, tstart_in, tend_in, swp_file, outfile, toswap, fromswap, worker, trial_mass, interval)
      use MOD_arrays, only: fillen
      use swap_exchange, only: swap_input, swap_output
      use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t
      use mod_b1_10_trial_mass, only: b1_10_trial_mass_t
      use mod_b1_10_interval_seam, only: b1_10_interval_seam_t
      integer, intent(in) :: iCaller, iTask
      real(8), intent(inout) :: tstart_in, tend_in
      character(len=fillen), intent(in), optional :: swp_file
      character(len=fillen), intent(in), optional :: outfile
      type(swap_input), intent(in), optional :: toswap
      type(swap_output), intent(out), optional :: fromswap
      type(a23bu_worker_context_t), intent(inout), optional :: worker
      type(b1_10_trial_mass_t), intent(inout), optional :: trial_mass
      type(b1_10_interval_seam_t), intent(inout), optional :: interval
    end subroutine SWAP
  end interface

  type(a23bu_worker_context_t), target :: worker
  type(b1_10_recoverable_reference_model_t) :: model
  type(b1_10_process_state_t) :: day_state, start_state, full_state, split_state
  type(b1_10_legacy_trial_capsule_t) :: start_capsule
  type(trial_outcome_t) :: prefix_out, full_out, half1_out, half2_out
  type(b1_10_temporal_characterization_t) :: delta
  real(real64) :: init_t0, init_t1, base, day_t0
  real(real64) :: char_t0, tmid, char_t1, prefix_days, duration_days
  real(real64) :: storage0, storage_full, storage_split
  real(real64) :: split_mass_in, split_mass_out, full_residual, split_residual
  integer :: offset
  character(len=64) :: arg

  offset = 760
  prefix_days = 0.25_real64
  duration_days = 1.0_real64
  call get_command_argument(1, arg)
  if (len_trim(arg) > 0) read(arg, *) offset
  call get_command_argument(2, arg)
  if (len_trim(arg) > 0) read(arg, *) prefix_days
  call get_command_argument(3, arg)
  if (len_trim(arg) > 0) read(arg, *) duration_days
  if (offset < 1) error stop 'F-VQ09: offset must be positive'
  if (prefix_days < 0.0_real64) error stop 'F-VQ09: prefix must be non-negative'
  if (duration_days <= 0.0_real64) error stop 'F-VQ09: duration must be positive'

  init_t0 = 0.0_real64
  init_t1 = 0.0_real64
  call SWAP(0, 1, init_t0, init_t1)
  call a23bu_initialize_worker(worker, numnod, 909)
  call model%bind_worker(worker)
  base = tstart

  ! Reach a real committed Hupsel state using the already-qualified physical
  ! continuation route. The characterization time is taken from observed t1900,
  ! not reconstructed from a midnight/day assumption.
  init_t0 = base
  init_t1 = base + real(offset - 1, real64)
  call SWAP(0, 21, init_t0, init_t1, worker=worker)
  call SWAP(0, 2, init_t0, init_t1, worker=worker)
  day_t0 = t1900
  call capture_b1_10_process_state(day_state)

  if (prefix_days > 0.0_real64) then
    call model%advance(day_state, day_t0, day_t0 + prefix_days, prefix_out)
    if (.not. prefix_out%solver_ok) error stop 'F-VQ09: prefix physical interval did not succeed'
  end if

  start_state = day_state
  call capture_b1_10_legacy_trial_capsule(start_capsule)
  char_t0 = day_t0 + prefix_days
  tmid = char_t0 + 0.5_real64 * duration_days
  char_t1 = char_t0 + duration_days
  full_state = start_state
  split_state = start_state
  storage0 = model%storage(start_state)

  ! Full path: restore the exact trial-only capsule paired with the captured
  ! committed physical state, then execute one generic interval.
  call restore_b1_10_legacy_trial_capsule(start_capsule)
  call model%advance(full_state, char_t0, char_t1, full_out)
  if (.not. full_out%solver_ok) error stop 'F-VQ09: full path did not succeed'
  storage_full = model%storage(full_state)

  ! Split path: restore the exact same start capsule and start state. Do not
  ! restore between halves; the second half continues from the first-half state.
  call restore_b1_10_legacy_trial_capsule(start_capsule)
  call model%advance(split_state, char_t0, tmid, half1_out)
  if (.not. half1_out%solver_ok) error stop 'F-VQ09: first half did not succeed'
  call model%advance(split_state, tmid, char_t1, half2_out)
  if (.not. half2_out%solver_ok) error stop 'F-VQ09: second half did not succeed'
  storage_split = model%storage(split_state)

  split_mass_in = half1_out%mass_in + half2_out%mass_in
  split_mass_out = half1_out%mass_out + half2_out%mass_out
  full_residual = storage0 + full_out%mass_in - full_out%mass_out - storage_full
  split_residual = storage0 + split_mass_in - split_mass_out - storage_split

  call characterize_b1_10_temporal_difference(full_state, split_state, delta)
  if (.not. delta%compatible) error stop 'F-VQ09: full/split endpoint states are incompatible'
  if (abs(full_residual) > HARD_MASS_LIMIT_CM) error stop 'F-VQ09: full path violates hard mass gate'
  if (abs(split_residual) > HARD_MASS_LIMIT_CM) error stop 'F-VQ09: split path violates hard mass gate'

  call emit_real('T0_DAYS', char_t0)
  call emit_real('TMID_DAYS', tmid)
  call emit_real('T1_DAYS', char_t1)
  call emit_real('PREFIX_DAYS', prefix_days)
  call emit_real('DURATION_DAYS', duration_days)
  call emit_real('H_CM', delta%max_abs_h_cm)
  call emit_real('THETA', delta%max_abs_theta)
  call emit_real('POND_CM', delta%abs_pond_cm)
  call emit_real('GWL_CM', delta%abs_gwl_cm)
  call emit_real('VOLACT_CM', delta%abs_volact_cm)
  call emit_real('LDWET_CM', delta%abs_ldwet)
  call emit_real('SPEV_CM', delta%abs_spev)
  call emit_real('SAEV_CM', delta%abs_saev)
  call emit_real('HM1_CM', delta%max_abs_hm1_cm)
  call emit_real('THETM1', delta%max_abs_thetm1)
  call emit_real('PONDM1_CM', delta%abs_pondm1_cm)
  call emit_real('GWLM1_CM', delta%abs_gwlm1_cm)
  call emit_real('FULL_STORAGE_T0_CM', storage0)
  call emit_real('FULL_MASS_IN_CM', full_out%mass_in)
  call emit_real('FULL_MASS_OUT_CM', full_out%mass_out)
  call emit_real('FULL_STORAGE_T1_CM', storage_full)
  call emit_real('FULL_RESIDUAL_CM', full_residual)
  call emit_real('SPLIT_STORAGE_T0_CM', storage0)
  call emit_real('SPLIT_MASS_IN_CM', split_mass_in)
  call emit_real('SPLIT_MASS_OUT_CM', split_mass_out)
  call emit_real('SPLIT_STORAGE_T1_CM', storage_split)
  call emit_real('SPLIT_RESIDUAL_CM', split_residual)
  call emit_real('HARD_MASS_LIMIT_CM', HARD_MASS_LIMIT_CM)
  call emit_int('COMPATIBLE', merge(1, 0, delta%compatible))
  call emit_int('WATER_SCOPE_COMPLETE', merge(1, 0, delta%water_scope_complete))
  call emit_int('OPTIONAL_PROCESS_STATE_PRESENT', merge(1, 0, delta%optional_process_state_present))
  call emit_int('PROCESS_SCOPE_COMPLETE', merge(1, 0, delta%process_scope_complete))
  call emit_int('ALLOCATION_MISMATCHES', delta%allocation_mismatches)
  write(*, '(A)') 'FVQ09_REAL_TEMPORAL_PROBE_PASS'

contains

  subroutine emit_real(name, value)
    character(len=*), intent(in) :: name
    real(real64), intent(in) :: value
    write(*, '(A,"=",ES25.17E3)') trim(name), value
  end subroutine emit_real

  subroutine emit_int(name, value)
    character(len=*), intent(in) :: name
    integer, intent(in) :: value
    write(*, '(A,"=",I0)') trim(name), value
  end subroutine emit_int

end program fvq09_real_b1_10_temporal_probe
