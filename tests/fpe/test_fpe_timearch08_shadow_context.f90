program test_fpe_timearch08_shadow_context
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_a23bu_worker_execution_context
  implicit none
  type(a23bu_worker_context_t) :: worker

  call a23bu_initialize_worker(worker, 8, 1)
  if (worker%timestep_shadow%available) error stop 'shadow unexpectedly available'
  worker%timestep_shadow%available=.true.
  worker%timestep_shadow%retain_preferred_dt=0.08_real64
  worker%timestep_shadow%evidence_preferred_dt=0.04_real64
  worker%timestep_shadow%previous_event_clamped=.true.
  call a23bu_reset_timestep_trace(worker)
  if (.not.worker%timestep_shadow%available) error stop 'trace reset destroyed shadow memory'
  if (worker%timestep_shadow%retain_preferred_dt/=0.08_real64) error stop 'retain memory changed'
  if (worker%timestep_shadow%evidence_preferred_dt/=0.04_real64) error stop 'evidence memory changed'
  if (.not.worker%timestep_shadow%previous_event_clamped) error stop 'event memory changed'
  call a23bu_release_worker(worker)
  if (worker%timestep_shadow%available) error stop 'release did not clear shadow'
  print '(A)', 'F_PE_TIMEARCH08_SHADOW_CONTEXT=PASS'
end program test_fpe_timearch08_shadow_context
