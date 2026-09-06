program test_a23bt_worker_context
  use, intrinsic :: iso_fortran_env, only: real64
  use omp_lib
  use mod_a23bt_worker_execution_context
  implicit none
  integer, parameter :: nworkers=8, nchecks=1000
  type(a23bt_worker_context_t) :: workers(nworkers)
  integer :: i, j, failures

  failures = 0
  do i=1,nworkers
    call a23bt_initialize_worker(workers(i), 34, i)
  end do

!$omp parallel do default(none) shared(workers) reduction(+:failures) private(i,j)
  do i=1,nworkers
    do j=1,nchecks
      call a23bt_reset_attempt_diagnostics(workers(i))
      call a23bt_reset_all_numerical_control(workers(i))
      workers(i)%control%at_min_dt = mod(i+j,2) == 0
      workers(i)%control%last_numbit = i + j
      workers(i)%time%interval_t0 = real(1000*i+j,real64)
      workers(i)%time%interval_t1 = workers(i)%time%interval_t0 + 0.5_real64
      workers(i)%time%legacy_start = real(40000+i,real64)
      workers(i)%time%legacy_end = workers(i)%time%legacy_start
      workers(i)%time%day_start_event = mod(i+j,3) == 0
      workers(i)%time%day_end_event = mod(i+j,5) == 0
      workers(i)%reporting%nprintcount = i+j
      workers(i)%reporting%cntper = j
      workers(i)%reporting%ioutdat = i
      workers(i)%reporting%ioutdatint = i+j
      workers(i)%reporting%outper = real(i*100+j,real64)
      workers(i)%reporting%tcumold = -real(i*100+j,real64)
      workers(i)%reporting%output = mod(i+j,2) == 0
      workers(i)%reporting%output_short = mod(i+j,3) == 0
      workers(i)%reporting%balance_output = mod(i+j,5) == 0
      workers(i)%reporting%header = mod(i+j,7) == 0
      workers(i)%reporting%reset_intermediate = mod(i+j,11) == 0
      workers(i)%reporting%reset_cumulative = mod(i+j,13) == 0
      call a23bt_request_dt_reduction(workers(i))
      workers(i)%headcalc%residual = real(i*100000+j,real64)
      workers(i)%headcalc%dkdh = -real(i*100000+j,real64)
      workers(i)%history%nstep = mod(j,11)
      workers(i)%diagnostics%headcalc_calls = j
      workers(i)%diagnostics%nonlinear_iterations = 2*j
      call a23bt_record_internal_retry(workers(i))
      if (workers(i)%worker_id /= i) failures=failures+1
      if (workers(i)%active_nodes /= 34) failures=failures+1
      if (maxval(abs(workers(i)%headcalc%residual-real(i*100000+j,real64))) > 0.0_real64) failures=failures+1
      if (maxval(abs(workers(i)%headcalc%dkdh+real(i*100000+j,real64))) > 0.0_real64) failures=failures+1
      if (workers(i)%diagnostics%headcalc_calls /= j) failures=failures+1
      if (workers(i)%diagnostics%nonlinear_iterations /= 2*j) failures=failures+1
      if (workers(i)%diagnostics%internal_retries /= 1) failures=failures+1
      if (workers(i)%control%last_numbit /= i+j) failures=failures+1
      if (.not. workers(i)%control%request_dt_reduction) failures=failures+1
      if (workers(i)%control%at_min_dt .neqv. (mod(i+j,2) == 0)) failures=failures+1
      if (abs(workers(i)%time%interval_t0-real(1000*i+j,real64)) > 0.0_real64) failures=failures+1
      if (abs(workers(i)%time%interval_t1-(real(1000*i+j,real64)+0.5_real64)) > 0.0_real64) failures=failures+1
      if (workers(i)%time%day_start_event .neqv. (mod(i+j,3) == 0)) failures=failures+1
      if (workers(i)%time%day_end_event .neqv. (mod(i+j,5) == 0)) failures=failures+1
      if (workers(i)%reporting%nprintcount /= i+j) failures=failures+1
      if (workers(i)%reporting%cntper /= j) failures=failures+1
      if (workers(i)%reporting%ioutdat /= i) failures=failures+1
      if (workers(i)%reporting%ioutdatint /= i+j) failures=failures+1
      if (abs(workers(i)%reporting%outper-real(i*100+j,real64)) > 0.0_real64) failures=failures+1
      if (abs(workers(i)%reporting%tcumold+real(i*100+j,real64)) > 0.0_real64) failures=failures+1
      if (workers(i)%reporting%output .neqv. (mod(i+j,2) == 0)) failures=failures+1
      if (workers(i)%reporting%output_short .neqv. (mod(i+j,3) == 0)) failures=failures+1
      if (workers(i)%reporting%balance_output .neqv. (mod(i+j,5) == 0)) failures=failures+1
      if (workers(i)%reporting%header .neqv. (mod(i+j,7) == 0)) failures=failures+1
      if (workers(i)%reporting%reset_intermediate .neqv. (mod(i+j,11) == 0)) failures=failures+1
      if (workers(i)%reporting%reset_cumulative .neqv. (mod(i+j,13) == 0)) failures=failures+1
      call a23bt_reset_attempt_control(workers(i))
      if (workers(i)%control%last_numbit /= 0) failures=failures+1
      if (workers(i)%control%request_dt_reduction) failures=failures+1
      if (workers(i)%control%at_min_dt .neqv. (mod(i+j,2) == 0)) failures=failures+1
    end do
  end do
!$omp end parallel do

  do i=1,nworkers
    if (workers(i)%diagnostics%headcalc_calls /= nchecks) failures=failures+1
    if (maxval(abs(workers(i)%headcalc%residual-real(i*100000+nchecks,real64))) > 0.0_real64) failures=failures+1
  end do

  if (failures /= 0) then
    print '(A,I0)', 'A23BT_WORKER_CONTEXT_GATE FAIL failures=',failures
    error stop 1
  end if
  print '(A)', 'A23BT_WORKER_CONTEXT_GATE PASS'
  print '(A,I0)', 'workers=',nworkers
  print '(A,I0)', 'checks=',nworkers*nchecks
  print '(A,I0)', 'parallel_failures=',failures
  print '(A,I0)', 'scratch_payload_bytes_per_worker=',a23bt_scratch_payload_bytes(workers(1))
  print '(A,I0)', 'reporting_shim_payload_bytes_per_worker=',a23bt_reporting_shim_payload_bytes()
  if (a23bt_reporting_shim_payload_bytes() /= 56) error stop 'A23BT reporting shim payload changed'

  do i=1,nworkers
    call a23bt_release_worker(workers(i))
  end do
end program test_a23bt_worker_context
