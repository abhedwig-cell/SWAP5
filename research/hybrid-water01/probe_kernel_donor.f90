program run_kernel_donor
  use probe_kernel_donor
  implicit none
  type(kernel_executor_t) :: executor
  type(model_t), target :: model
  type(parameters_t) :: parameters
  type(forcing_t) :: forcing
  type(kernel_committed_state_t) :: committed(2)
  type(kernel_reference_floor_candidate_t) :: candidate
  type(kernel_reference_floor_result_t) :: result
  type(kernel_diagnostics_t) :: diagnostics
  class(transaction_state_t), allocatable :: initial, snapshot
  logical :: ok
  integer :: i
  real(real64) :: stock

  character(len=32) :: mode
  type(materializer_t) :: materializer
  type(groundwater_head_datum_t) :: datum
  type(groundwater_coupling_window_t) :: window
  type(groundwater_swap_transaction_participant_t) :: participant
  type(groundwater_swap_trial_t) :: exchange
  integer :: status
  type(canonical_numerical_config_t) :: numerical
  real(real64) :: time

  call get_command_argument(1,mode)
  read(*,*) stock
  call executor%bind_model(model)
  do i=1,2
    allocate(initial, source=state_t(column=i, ticket=0, stock=stock))
    call committed(i)%initialize(int(i,int64),initial,ok,35799d0)
    if (.not. ok) error stop 'initialization'
    deallocate(initial)
  end do
  if (mode == 'temporal' .or. mode == 'water-metric' .or. mode == 'coupled' .or. mode == 'bracketed' .or. mode == 'origin-predictor') then
    numerical%transaction%mass_tolerance = 1e-6_real64
    numerical%transaction%max_retries = 0
    numerical%max_committed_substeps = 1
    model%water_metric = mode /= 'temporal'
    numerical%transaction%temporal_tolerance = 0.05_real64
    if (model%water_metric) numerical%transaction%temporal_tolerance = 1e-4_real64
    datum%available = .true.
    datum%datum_id = 91_int64
    datum%bottom_boundary_elevation_m = -1d0
    call participant%capture_origin(committed(1),status)
    if (status /= GW_SWAP_PARTICIPANT_OK) error stop 'capture temporal origin'
    window%t0 = 35799d0
    if (mode == 'coupled' .or. mode == 'bracketed' .or. mode == 'origin-predictor') then
      call coupled_window()
      stop
    end if
    if (model%water_metric) then
      window%t1 = 35799.0625d0
      call participant%trial_from_origin(executor,parameters,committed(1),materializer,numerical, &
                                        datum,window,-0.5d0,exchange,status)
      if (status /= GW_SWAP_PARTICIPANT_TRIAL_FAILED .or. exchange%valid .or. &
          participant%has_live_candidate()) error stop 'water defect negative control'
      call committed(1)%current_time(time,ok)
      if (.not. ok .or. time /= window%t0 .or. committed(1)%current_revision() /= 0) error stop 'changed origin'
      print '(a,1x,i0)', 'WATER_REJECTED', status
      window%t1 = 35799.5d0
      call participant%trial_from_origin(executor,parameters,committed(1),materializer,numerical, &
                                        datum,window,-0.5d0,exchange,status)
      if (status /= GW_SWAP_PARTICIPANT_OK .or. .not. exchange%valid) error stop 'water positive control'
      if (.not. participant%publication_ready(committed(1),window)) error stop 'water publication preflight'
      if (committed(1)%current_revision() /= 0) error stop 'candidate published early'
      call participant%commit_candidate(executor,committed(1),window,ok,status)
      if (.not. ok .or. status /= GW_SWAP_PARTICIPANT_OK) error stop 'water commit'
      call committed(1)%current_time(time,ok)
      if (.not. ok .or. time /= window%t1 .or. committed(1)%current_revision() /= 1) error stop 'water endpoint'
      call committed(1)%snapshot(snapshot,ok)
      if (.not. ok) error stop 'water snapshot'
      select type(snapshot)
      type is(state_t)
        print '(a,1x,i0,2(1x,es24.16))', 'WATER_COMMITTED', snapshot%ticket, &
            exchange%bottom_outward_exchange_cm, exchange%q_swap_m_per_s
      class default
        error stop 'water snapshot type'
      end select
      stop
    end if
    do i=1,3
      select case (i)
      case (1)
        window%t1 = 35799.5d0
      case (2)
        window%t1 = 35799.0625d0
      case (3)
        window%t1 = 35799.000244140625d0
      end select
      call participant%trial_from_origin(executor,parameters,committed(1),materializer,numerical, &
                                        datum,window,-0.5d0,exchange,status)
      if (status /= GW_SWAP_PARTICIPANT_TRIAL_FAILED .or. exchange%valid .or. &
          participant%has_live_candidate()) error stop 'expected normal participant rejection'
      call committed(1)%current_time(time,ok)
      if (.not. ok .or. time /= window%t0 .or. committed(1)%current_revision() /= 0 .or. &
          committed(2)%current_revision() /= 0) error stop 'temporal rejection mutated state'
      print '(a,1x,f24.15,1x,i0)', 'TEMPORAL_REJECTED', window%t1-window%t0, status
    end do
    stop
  end if
  call trial(1,35799d0,35799.5d0,-90d0,.false.)
  if (any([committed(1)%current_revision(),committed(2)%current_revision()] /= 0)) error stop 'discard changed origin'
  call trial(2,35799d0,35799.5d0,-90d0,.true.)
  call trial(1,35799d0,35799.5d0,-50d0,.true.)
  call trial(1,35799.5d0,35800d0,-90d0,.true.)
  call trial(2,35799.5d0,35800d0,-50d0,.true.)
  if (any([committed(1)%current_revision(),committed(2)%current_revision()] /= 2)) error stop 'revision'
contains
  subroutine coupled_window()
    type(groundwater_interface_mass_ledger_t) :: ledger
    type(groundwater_interface_mass_snapshot_t) :: ledger_snapshot
    type(groundwater_interface_mass_prepared_t) :: prepared
    type(groundwater_interface_lineage_t) :: lineage
    real(real64), parameter :: head_tolerance = 1e-8_real64, initial_head = -0.493_real64
    real(real64) :: guess, response, volume, native_exchange, native_storage, last_feasible
    real(real64) :: lower, upper, residual
    integer :: iteration, unit, rc, selected, discarded, gw_solves, max_trials
    logical :: converged

    window%t1 = 35799.5d0
    lineage = groundwater_interface_lineage_t(1_int64,1_int64,0_int64,2_int64,0_int64,1_int64)
    call ledger%bind_identity(1_int64,status)
    if (status /= GW_MASS_LEDGER_OK) error stop 'ledger identity'
    guess = -0.5d0
    max_trials = 14
    if (mode == 'origin-predictor') then
      guess = initial_head
      max_trials = 1
    end if
    converged = .false.
    discarded = 0
    gw_solves = 0
    last_feasible = guess
    lower = -huge(guess)
    upper = huge(guess)
    do iteration=1,max_trials
      call participant%trial_from_origin(executor,parameters,committed(1),materializer,numerical, &
                                        datum,window,guess,exchange,status)
      if (status /= GW_SWAP_PARTICIPANT_OK .or. .not. exchange%valid) then
        print '(a,1x,i0,1x,es24.16,1x,i0)', 'COUPLED_TEMPORAL_REJECTION', iteration,guess,status
        if (status /= GW_SWAP_PARTICIPANT_TRIAL_FAILED .or. participant%has_live_candidate() .or. &
            committed(1)%current_revision() /= 0) error stop 'corrector failure'
        if (gw_solves == 0) exit
        guess = 0.5d0*(last_feasible+guess)
        cycle
      end if
      last_feasible = guess
      gw_solves = gw_solves + 1
      volume = exchange%bottom_outward_exchange_cm*0.01d0 ! Unit-area groundwater cell.
      open(newunit=unit,file='request',status='replace',action='write')
      write(unit,*) 'GW ', iteration, initial_head, volume
      close(unit)
      call execute_command_line('./worker',exitstat=rc)
      if (rc /= 0) error stop 'MODFLOW worker failed'
      open(newunit=unit,file='reply',status='old',action='read')
      read(unit,*) response,native_exchange,native_storage
      close(unit)
      if (.not. all(ieee_is_finite([response,native_exchange,native_storage]))) error stop 'nonfinite MODFLOW result'
      if (abs(native_exchange-volume) > 1e-12_real64 .or. &
          abs(native_storage+native_exchange) > 1e-10_real64) error stop 'MODFLOW water budget'
      call ledger%stage_exchange(window,lineage,native_exchange,status)
      if (status /= GW_MASS_LEDGER_OK) error stop 'stage interface'
      print '(a,1x,i0,4(1x,es24.16))', 'COUPLED_CORRECTOR',iteration,guess,response,native_exchange,native_storage
      if (abs(response-guess) <= head_tolerance) then
        converged = .true.
        exit
      end if
      call participant%discard_candidate(executor)
      call ledger%discard_trial(status)
      discarded = discarded + 1
      if (status /= GW_MASS_LEDGER_OK .or. committed(1)%current_revision() /= 0) error stop 'discard changed origin'
      if (mode == 'bracketed') then
        residual = response-guess
        ! Residual orientation is defined for this one-cell storage experiment.
        if (residual > 0d0 .and. guess < upper) lower = max(lower,guess)
        if (residual < 0d0 .and. guess > lower) upper = min(upper,guess)
        if (lower /= -huge(guess) .and. upper /= huge(guess)) then
          guess = lower + 0.5d0*(upper-lower)
          cycle
        end if
      end if
      guess = response
    end do
    if (.not. converged) then
      call ledger%snapshot(ledger_snapshot)
      if (ledger_snapshot%committed_exchange_count /= 0 .or. participant%has_live_candidate() .or. &
          committed(1)%current_revision() /= 0) error stop 'unconverged corrector changed accepted state'
      print '(a)', 'COUPLED_NO_COMMIT'
      return
    end if
    if (gw_solves <= 1 .and. mode /= 'origin-predictor') error stop 'expected coupled correction'
    if (.not. participant%publication_ready(committed(1),window)) error stop 'coupled publication preflight'
    call ledger%prepare_trial(prepared,status)
    if (status /= GW_MASS_LEDGER_OK .or. .not. ledger%prepared_ready_for_commit(prepared)) error stop 'ledger preflight'
    call participant%commit_candidate(executor,committed(1),window,ok,status)
    if (.not. ok .or. status /= GW_SWAP_PARTICIPANT_OK) error stop 'coupled commit'
    call ledger%commit_prepared(prepared)
    call ledger%snapshot(ledger_snapshot)
    if (ledger_snapshot%committed_exchange_count /= 1 .or. &
        ledger_snapshot%discarded_trial_count /= discarded .or. &
        abs(ledger_snapshot%conservation_residual_m) > 1e-12_real64) error stop 'interface ledger'
    call committed(1)%current_time(time,ok)
    if (.not. ok .or. time /= window%t1 .or. committed(1)%current_revision() /= 1) error stop 'coupled endpoint'
    call committed(1)%snapshot(snapshot,ok)
    if (.not. ok) error stop 'coupled snapshot'
    select type(snapshot)
    type is(state_t)
      selected = snapshot%ticket
    class default
      error stop 'coupled snapshot type'
    end select
    print '(a,2(1x,i0),1x,es24.16)', 'COUPLED_COMMITTED',iteration,selected,ledger_snapshot%conservation_residual_m
  end subroutine
  subroutine trial(column,t0,t1,head,accept)
    integer, intent(in) :: column
    real(real64), intent(in) :: t0,t1,head
    logical, intent(in) :: accept
    integer :: ticket
    forcing%head = head
    call executor%sample_reference_floor_interval(parameters,committed(column),forcing,t0,t1,1e-6_real64, &
                                                   result,candidate,diagnostics)
    if (.not. candidate%ready() .or. .not. result%mass%complete) then
      print *, result%status, result%mass%residual
      error stop 'donor candidate rejected'
    end if
    call candidate%snapshot(snapshot,ok)
    if (.not. ok) error stop 'snapshot'
    select type(snapshot)
    type is(state_t)
      ticket = snapshot%ticket
    class default
      error stop 'unexpected snapshot type'
    end select
    if (accept) then
      call executor%commit_reference_floor_candidate(committed(column),candidate,diagnostics,ok)
      if (.not. ok) error stop 'commit'
    else
      call executor%discard_reference_floor_candidate(candidate,diagnostics)
    end if
    if (candidate%ready()) error stop 'uncleared candidate'
    print '(a,1x,i0,1x,i0,1x,l1,1x,i0,1x,es24.16,1x,es24.16)', &
      'DONOR',column,ticket,accept,committed(column)%current_revision(),result%mass%residual, &
      result%bottom_outward_exchange_native
  end subroutine
end program
