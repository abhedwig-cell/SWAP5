program test_a23bt_hupsel_worker_component
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference
  use mod_a23bt_hupsel_worker_component
  use mod_a23bt_worker_execution_context, only: a23bt_initialize_worker, a23bt_release_worker
  use variables, only: legacy_global_dt => dt, legacy_global_t1900 => t1900, legacy_global_t => t, &
       legacy_global_tcum => tcum, legacy_global_timjan1 => timjan1, legacy_global_daynr => daynr, &
       legacy_global_daycum => daycum, legacy_global_iyear => iyear, legacy_global_imonth => imonth, legacy_global_date => date, &
       legacy_nprintcount => nprintcount, legacy_cntper => cntper, legacy_ioutdat => ioutdat, legacy_ioutdatint => ioutdatint, &
       legacy_outper => outper, legacy_floutputshort => floutputshort, legacy_flbaloutput => flbaloutput, &
       legacy_flheader => flheader, legacy_floutput => floutput, legacy_flzerointr => flzerointr, legacy_flzerocumu => flzerocumu
  implicit none

  type(hupsel_worker_component_t) :: model, model_b
  class(transaction_state_t), allocatable :: seed, committed, endpoint
  class(transaction_state_t), allocatable :: a_ref, b_seed, b_ref, a_test, b_test
  type(transaction_policy_t) :: policy
  type(transaction_result_t) :: tx
  type(trial_outcome_t) :: a_ref_out, b_prep_out, b_ref_out, a_test_out, b_test_out, a_final_out
  real(real64) :: accepted_storage
  integer(kind=8) :: bal_size_before, bal_size_after, blc_size_before, blc_size_after

  call initialize_hupsel_worker_component(model, seed, 'swap.swp', 'a23bt_worker', &
                                   37256.0_real64, 37258.0_real64, 37259.0_real64)
  inquire(file='a23bt_worker.bal', size=bal_size_before)
  inquire(file='a23bt_worker.blc', size=blc_size_before)
  call print_layout(seed)
  print '(A,I0)', 'worker_scratch_payload_bytes=', hupsel_worker_scratch_payload_bytes(model)
  call require(hupsel_worker_scratch_payload_bytes(model) == 3292, 'unexpected Hupsel worker scratch payload')
  model_b%base_t1900 = model%base_t1900
  allocate(model_b%dz(size(model%dz)))
  model_b%dz = model%dz
  model_b%initialized = .true.
  call a23bt_initialize_worker(model_b%worker, size(model_b%dz), 1)
  call seed%clone(committed)

  policy%temporal_tolerance = 1.0e-12_real64
  policy%mass_tolerance = 1.0e-6_real64
  policy%retry_scale = 0.5_real64
  policy%max_retries = 0
  call execute_reference_interval(model, committed, 0.0_real64, 2.0_real64, policy, tx)
  call require(tx%status == TX_STATUS_ACCEPTED, 'always-sampled transaction not accepted')
  call require(tx%full_trials == 1 .and. tx%half_trials == 2, 'reference route not always sampled')
  call require(tx%temporal_error <= 1.0e-14_real64, 'full/two-half mismatch')
  call require(abs(tx%half_mass_residual) <= 1.0e-6_real64, 'mass gate failed')
  call require(tx%internal_retries == 20, 'total internal retry cost mismatch')
  call require(tx%accepted_internal_retries == 10, 'accepted-route retry diagnostics mismatch')
  call require(tx%headcalc_calls > 0 .and. tx%accepted_headcalc_calls > 0, 'HeadCalc call diagnostics missing')
  call require(tx%jacobian_builds == tx%linear_solves, 'Jacobian/linear solve count mismatch')
  call require(tx%accepted_jacobian_builds == tx%accepted_linear_solves, 'accepted Jacobian/linear solve count mismatch')
  call require(tx%backtracking_attempts >= tx%linear_solves, 'backtracking count below linear solves')
  call require(tx%alternative_solver_calls == 0, 'unexpected alternative solver use')
  call require(tx%headcalc_calls == 162 .and. tx%accepted_headcalc_calls == 81, 'HeadCalc call count changed')
  call require(tx%nonlinear_iterations == 956 .and. tx%accepted_nonlinear_iterations == 478, 'Newton count changed')
  call require(tx%jacobian_builds == 956 .and. tx%accepted_jacobian_builds == 478, 'Jacobian count changed')
  call require(tx%linear_solves == 956 .and. tx%accepted_linear_solves == 478, 'linear solve count changed')
  call require(tx%backtracking_attempts == 1350 .and. tx%accepted_backtracking_attempts == 675, 'backtracking count changed')
  accepted_storage = model%storage(committed)
  call require(abs(accepted_storage - 77.011710672204643_real64) <= 1.0e-12_real64, 'B1.6 storage mismatch')
  call committed%clone(endpoint)
  inquire(file='a23bt_worker.bal', size=bal_size_after)
  inquire(file='a23bt_worker.blc', size=blc_size_after)
  call require(bal_size_after == bal_size_before, 'BAL output changed during transaction trials')
  call require(blc_size_after == blc_size_before, 'BLC output changed during transaction trials')
  print '(A)', 'A23BT_TRIAL_OUTPUT_SUPPRESSION PASS'

  call seed%clone(a_ref)
  call model%advance(a_ref, 0.0_real64, 1.0_real64, a_ref_out)
  call require(a_ref_out%solver_ok, 'serial A reference failed')

  call seed%clone(b_seed)
  call model%advance(b_seed, 0.0_real64, 1.0_real64, b_prep_out)
  call require(b_prep_out%solver_ok, 'B seed preparation failed')
  call b_seed%clone(b_ref)
  call model_b%advance(b_ref, 1.0_real64, 2.0_real64, b_ref_out)
  call require(b_ref_out%solver_ok, 'serial B reference failed')

  call seed%clone(a_test)
  call b_seed%clone(b_test)
  call poison_worker(model_b)
  legacy_global_dt = -9876.54321_real64
  call poison_legacy_time(-77777.0_real64)
  call poison_legacy_reporting()
  call poison_worker_reporting(model_b)
  model_b%worker%time%day_start_event = .false.
  model_b%worker%time%day_end_event = .true.
  model_b%worker%control%last_numbit = 123456789
  model_b%worker%control%request_dt_reduction = .true.
  model_b%worker%control%at_min_dt = .true.
  call model_b%advance(b_test, 1.0_real64, 2.0_real64, b_test_out)
  call require(b_test_out%solver_ok, 'interleaved B failed')
  legacy_global_dt = 9876.54321_real64
  call poison_legacy_time(88888.0_real64)
  call poison_legacy_reporting()
  call poison_worker_reporting(model)
  model%worker%time%day_start_event = .false.
  model%worker%time%day_end_event = .true.
  model%worker%control%last_numbit = -123456789
  model%worker%control%request_dt_reduction = .true.
  model%worker%control%at_min_dt = .true.
  call model%advance(a_test, 0.0_real64, 1.0_real64, a_test_out)
  call require(a_test_out%solver_ok, 'interleaved A failed')

  print '(A,2ES24.16,2I8)', 'A serial mass/retry=', a_ref_out%mass_in, a_ref_out%mass_out, a_ref_out%nonlinear_iterations, a_ref_out%internal_retries
  print '(A,2ES24.16,2I8)', 'A inter  mass/retry=', a_test_out%mass_in, a_test_out%mass_out, a_test_out%nonlinear_iterations, a_test_out%internal_retries
  print '(A,2ES24.16,2I8)', 'B serial mass/retry=', b_ref_out%mass_in, b_ref_out%mass_out, b_ref_out%nonlinear_iterations, b_ref_out%internal_retries
  print '(A,2ES24.16,2I8)', 'B inter  mass/retry=', b_test_out%mass_in, b_test_out%mass_out, b_test_out%nonlinear_iterations, b_test_out%internal_retries
  call require(column_states_equal(a_test, a_ref), 'A state depends on prior B execution')
  call require(column_states_equal(b_test, b_ref), 'B state depends on prior A execution')
  call require(outcomes_equal(a_test_out, a_ref_out), 'A diagnostics depend on prior B execution')
  call require(outcomes_equal(b_test_out, b_ref_out), 'B diagnostics depend on prior A execution')
  print '(A)', 'A23BT_REPORTING_PROGRESSION_POISON PASS'

  call model%advance(a_test, 1.0_real64, 2.0_real64, a_final_out)
  call require(a_final_out%solver_ok, 'A final day failed after interleave')
  call require(column_states_equal(a_test, endpoint), 'interleaved A endpoint differs from transaction endpoint')

  select type (final_state => committed)
  type is (hupsel_column_state_t)
    call restore_hupsel_column_state(final_state)
  class default
    error stop 'A23BT test: committed type mismatch'
  end select
  print '(A)', 'A23BT_WORKER_COMPONENT_GATE PASS'
  print '(A,ES24.16)', 'accepted_storage=', accepted_storage
  print '(A,ES24.16)', 'mass_residual=', tx%half_mass_residual
  print '(A,I0)', 'transaction_internal_retries=', tx%internal_retries
  print '(A,I0)', 'accepted_internal_retries=', tx%accepted_internal_retries
  print '(A,I0)', 'jan4_internal_retries=', a_ref_out%internal_retries
  print '(A,I0)', 'jan5_internal_retries=', b_ref_out%internal_retries
  print '(A,I0)', 'transaction_nonlinear_iterations=', tx%nonlinear_iterations
  print '(A,I0)', 'accepted_nonlinear_iterations=', tx%accepted_nonlinear_iterations
  print '(A,I0)', 'transaction_headcalc_calls=', tx%headcalc_calls
  print '(A,I0)', 'accepted_headcalc_calls=', tx%accepted_headcalc_calls
  print '(A,I0)', 'transaction_jacobian_builds=', tx%jacobian_builds
  print '(A,I0)', 'accepted_jacobian_builds=', tx%accepted_jacobian_builds
  print '(A,I0)', 'transaction_linear_solves=', tx%linear_solves
  print '(A,I0)', 'accepted_linear_solves=', tx%accepted_linear_solves
  print '(A,I0)', 'transaction_backtracking_attempts=', tx%backtracking_attempts
  print '(A,I0)', 'accepted_backtracking_attempts=', tx%accepted_backtracking_attempts
  print '(A,I0)', 'transaction_alternative_solver_calls=', tx%alternative_solver_calls
  select type (x => committed)
  type is (hupsel_column_state_t)
    print '(A,ES24.16)', 'accepted_next_dt=', x%numerical%dt
  end select
  call a23bt_release_worker(model_b%worker)
  call finalize_hupsel_worker_component(model)
contains

  subroutine print_layout(state)
    class(transaction_state_t), intent(in) :: state
    integer :: rb, ib, lb
    integer :: physical_bytes, forcing_bytes, process_bytes, numerical_bytes, legacy_time_bytes, replay_bytes, accounting_bytes
    rb = storage_size(0.0_real64)/8
    ib = storage_size(0)/8
    lb = storage_size(.false.)/8
    select type (x => state)
    type is (hupsel_column_state_t)
      physical_bytes = (size(x%physical%h)+size(x%physical%theta)+size(x%physical%tsoil)+size(x%physical%cml))*rb + 6*rb
      forcing_bytes = 3*ib + lb
      process_bytes = 2*lb + 3*ib + 2*rb
      numerical_bytes = rb
      legacy_time_bytes = 4*rb + 4*ib + 11
      replay_bytes = size(x%replay%cmsy)*rb
      accounting_bytes = 12*rb
      print '(A,I0)', 'state_nodes=', size(x%physical%h)
      print '(A,I0)', 'physical_payload_bytes=', physical_bytes
      print '(A,I0)', 'forcing_cursor_payload_bytes=', forcing_bytes
      print '(A,I0)', 'process_cursor_payload_bytes=', process_bytes
      print '(A,I0)', 'numerical_payload_bytes=', numerical_bytes
      print '(A,I0)', 'legacy_time_projection_payload_bytes=', legacy_time_bytes
      print '(A,I0)', 'legacy_replay_payload_bytes=', replay_bytes
      print '(A,I0)', 'legacy_accounting_payload_bytes=', accounting_bytes
    class default
      error stop 'A23BT test: state layout type mismatch'
    end select
  end subroutine print_layout

  subroutine poison_worker(m)
    type(hupsel_worker_component_t), intent(inout) :: m
    m%worker%headcalc%dfdhl = 9.87654321e99_real64
    m%worker%headcalc%dfdhm = -9.87654321e99_real64
    m%worker%headcalc%dfdhu = 8.76543210e88_real64
    m%worker%headcalc%difh = -8.76543210e88_real64
    m%worker%headcalc%residual = 7.65432109e77_real64
    m%worker%headcalc%sink = -7.65432109e77_real64
    m%worker%headcalc%source = 6.54321098e66_real64
    m%worker%headcalc%hold = -6.54321098e66_real64
    m%worker%headcalc%qv = 5.43210987e55_real64
    m%worker%headcalc%hgrad = -5.43210987e55_real64
    m%worker%headcalc%flnonconv1 = .true.
    m%worker%headcalc%flnonconv2 = .true.
    m%worker%headcalc%flunsatok = .true.
  end subroutine poison_worker

  subroutine poison_legacy_reporting()
    legacy_nprintcount = -777
    legacy_cntper = 999
    legacy_ioutdat = 77
    legacy_ioutdatint = 88
    legacy_outper = -123.456_real64
    legacy_floutputshort = .true.
    legacy_flbaloutput = .true.
    legacy_flheader = .true.
    legacy_floutput = .true.
    legacy_flzerointr = .false.
    legacy_flzerocumu = .true.
  end subroutine poison_legacy_reporting

  subroutine poison_worker_reporting(m)
    type(hupsel_worker_component_t), intent(inout) :: m
    m%worker%reporting%nprintcount = -123
    m%worker%reporting%cntper = 456
    m%worker%reporting%ioutdat = 7
    m%worker%reporting%ioutdatint = 8
    m%worker%reporting%outper = 987.654_real64
    m%worker%reporting%tcumold = -987.654_real64
    m%worker%reporting%output_short = .true.
    m%worker%reporting%balance_output = .true.
    m%worker%reporting%header = .true.
    m%worker%reporting%output = .true.
    m%worker%reporting%reset_intermediate = .false.
    m%worker%reporting%reset_cumulative = .true.
  end subroutine poison_worker_reporting

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write(*,'(A)') 'FAIL: '//trim(message)
      error stop 1
    end if
  end subroutine require

  logical function outcomes_equal(a,b)
    type(trial_outcome_t), intent(in) :: a,b
    outcomes_equal = a%solver_ok .eqv. b%solver_ok
    outcomes_equal = outcomes_equal .and. abs(a%mass_in-b%mass_in) <= 0.0_real64 .and. abs(a%mass_out-b%mass_out) <= 0.0_real64
    outcomes_equal = outcomes_equal .and. a%nonlinear_iterations == b%nonlinear_iterations
    outcomes_equal = outcomes_equal .and. a%internal_retries == b%internal_retries
    outcomes_equal = outcomes_equal .and. a%headcalc_calls == b%headcalc_calls
    outcomes_equal = outcomes_equal .and. a%jacobian_builds == b%jacobian_builds
    outcomes_equal = outcomes_equal .and. a%linear_solves == b%linear_solves
    outcomes_equal = outcomes_equal .and. a%backtracking_attempts == b%backtracking_attempts
    outcomes_equal = outcomes_equal .and. a%alternative_solver_calls == b%alternative_solver_calls
  end function outcomes_equal

  logical function column_states_equal(a,b)
    class(transaction_state_t), intent(in) :: a,b
    column_states_equal = .false.
    select type (x => a)
    type is (hupsel_column_state_t)
      select type (y => b)
      type is (hupsel_column_state_t)
        column_states_equal = exact_real_array(x%physical%h,y%physical%h) .and. &
          exact_real_array(x%physical%theta,y%physical%theta) .and. &
          exact_real_array(x%physical%tsoil,y%physical%tsoil) .and. &
          exact_real_array(x%physical%cml,y%physical%cml) .and. &
          exact_real_array(x%replay%cmsy,y%replay%cmsy) .and. &
          abs(x%physical%pond-y%physical%pond) <= 0.0_real64 .and. abs(x%physical%ldwet-y%physical%ldwet) <= 0.0_real64 .and. &
          abs(x%physical%spev-y%physical%spev) <= 0.0_real64 .and. abs(x%physical%saev-y%physical%saev) <= 0.0_real64 .and. &
          abs(x%physical%gwl-y%physical%gwl) <= 0.0_real64 .and. abs(x%physical%volact-y%physical%volact) <= 0.0_real64 .and. &
          abs(x%numerical%dt-y%numerical%dt) <= 0.0_real64 .and. legacy_time_equal(x%legacy_time,y%legacy_time) .and. &
          x%forcing%meteo_rec == y%forcing%meteo_rec .and. x%forcing%rain_rec == y%forcing%rain_rec .and. &
          x%forcing%i_metdetail == y%forcing%i_metdetail .and. &
          (x%forcing%fl_update_meteo .eqv. y%forcing%fl_update_meteo) .and. &
          (x%process%flirrigate .eqv. y%process%flirrigate) .and. &
          (x%process%fl_cropcalendar .eqv. y%process%fl_cropcalendar) .and. &
          x%process%dayfix == y%process%dayfix .and. x%process%nirri == y%process%nirri .and. &
          x%process%irrigevent == y%process%irrigevent .and. abs(x%process%gird-y%process%gird) <= 0.0_real64 .and. &
          abs(x%process%dt_irr_event-y%process%dt_irr_event) <= 0.0_real64 .and. &
          accounting_equal(x%accounting,y%accounting)
      end select
    end select
  end function column_states_equal

  subroutine poison_legacy_time(base)
    real(real64), intent(in) :: base
    legacy_global_t1900 = base
    legacy_global_t = base + 1.0_real64
    legacy_global_tcum = base + 2.0_real64
    legacy_global_timjan1 = base + 3.0_real64
    legacy_global_daynr = -12345
    legacy_global_daycum = 54321
    legacy_global_iyear = -999
    legacy_global_imonth = 99
    legacy_global_date = 'POISON-TIME'
  end subroutine poison_legacy_time

  logical function legacy_time_equal(a,b)
    type(hupsel_legacy_time_projection_t), intent(in) :: a,b
    legacy_time_equal = abs(a%t1900-b%t1900) <= 0.0_real64 .and. &
      abs(a%year_time-b%year_time) <= 0.0_real64 .and. abs(a%day_time-b%day_time) <= 0.0_real64 .and. &
      abs(a%jan1_1900-b%jan1_1900) <= 0.0_real64 .and. a%daynr == b%daynr .and. a%daycum == b%daycum .and. &
      a%iyear == b%iyear .and. a%imonth == b%imonth .and. a%date == b%date
  end function legacy_time_equal

  logical function accounting_equal(a,b)
    type(hupsel_legacy_accounting_cursor_t), intent(in) :: a,b
    accounting_equal = abs(a%cgrai-b%cgrai) <= 0.0_real64 .and. &
      abs(a%cgird-b%cgird) <= 0.0_real64 .and. abs(a%crunon-b%crunon) <= 0.0_real64 .and. &
      abs(a%cqssdi-b%cqssdi) <= 0.0_real64 .and. abs(a%cqbotup-b%cqbotup) <= 0.0_real64 .and. &
      abs(a%caintc-b%caintc) <= 0.0_real64 .and. abs(a%crunoff-b%crunoff) <= 0.0_real64 .and. &
      abs(a%cqrot-b%cqrot) <= 0.0_real64 .and. abs(a%cepd-b%cepd) <= 0.0_real64 .and. &
      abs(a%cevap-b%cevap) <= 0.0_real64 .and. abs(a%cqdra-b%cqdra) <= 0.0_real64 .and. &
      abs(a%cqbotdo-b%cqbotdo) <= 0.0_real64
  end function accounting_equal

  logical function exact_real_array(a,b)
    real(real64), allocatable, intent(in) :: a(:),b(:)
    exact_real_array = allocated(a) .and. allocated(b)
    if (.not. exact_real_array) return
    exact_real_array = size(a) == size(b)
    if (.not. exact_real_array) return
    exact_real_array = maxval(abs(a-b)) <= 0.0_real64
  end function exact_real_array

end program test_a23bt_hupsel_worker_component
