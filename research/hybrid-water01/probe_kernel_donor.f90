module probe_kernel_donor
  use iso_fortran_env, only: real64, int64
  use ieee_arithmetic, only: ieee_is_finite
  use mod_transaction_reference, only: transaction_state_t, trial_outcome_t, TX_MASS_MISSING_NONE
  use mod_canonical_contracts
  use mod_kernel_transactions
  use mod_groundwater_swap_forcing_adapter, only: groundwater_swap_forcing_materializer_t, GW_SWAP_FORCING_OK
  use mod_groundwater_coupling_contract, only: groundwater_head_datum_t, groundwater_coupling_window_t, &
       groundwater_interface_lineage_t
  use mod_groundwater_interface_mass_ledger, only: groundwater_interface_mass_ledger_t, &
       groundwater_interface_mass_snapshot_t, groundwater_interface_mass_prepared_t, GW_MASS_LEDGER_OK
  use mod_groundwater_swap_transaction_participant, only: groundwater_swap_transaction_participant_t, &
       groundwater_swap_trial_t, GW_SWAP_PARTICIPANT_OK, GW_SWAP_PARTICIPANT_TRIAL_FAILED
  implicit none
  type, extends(canonical_state_t) :: state_t
    integer :: column = 0, ticket = 0
    real(real64) :: stock = 0, pressure(112) = 0, component_stock(6) = 0
  contains
    procedure :: clone
  end type
  type, extends(canonical_forcing_t) :: forcing_t
    real(real64) :: head = 0
  end type
  type, extends(groundwater_swap_forcing_materializer_t) :: materializer_t
  contains
    procedure :: profile_admitted
    procedure :: materialize
  end type
  type, extends(kernel_parameters_t) :: parameters_t
  end type
  type, extends(kernel_model_t) :: model_t
    real(real64) :: head = 0
    logical :: water_metric = .false.
  contains
    procedure :: configure_parameters
    procedure :: execution_admitted
    procedure :: prepare_interval
    procedure :: advance
    procedure :: storage
    procedure :: storage_accounting_status
    procedure :: temporal_error
    procedure :: temporal_assessment
  end type
contains
  logical function profile_admitted(self, parameters) result(ok)
    class(materializer_t), intent(in) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    ok = same_type_as(parameters,parameters_t())
  end function
  subroutine materialize(self, interface_head_m, datum, forcing, status)
    class(materializer_t), intent(in) :: self
    real(real64), intent(in) :: interface_head_m
    type(groundwater_head_datum_t), intent(in) :: datum
    class(canonical_forcing_t), allocatable, intent(out) :: forcing
    integer, intent(out) :: status
    if (.not. datum%valid()) error stop 'invalid test datum'
    allocate(forcing, source=forcing_t(head=100*interface_head_m))
    status = GW_SWAP_FORCING_OK
  end subroutine
  subroutine clone(self, copy)
    class(state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(copy, source=self)
  end subroutine
  subroutine configure_parameters(self, parameters)
    class(model_t), intent(inout) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    if (.not. same_type_as(parameters,parameters_t())) error stop 'parameters'
    self%head = 0
  end subroutine
  logical function execution_admitted(self, parameters, numerical_config) result(ok)
    class(model_t), intent(in) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    type(canonical_numerical_config_t), intent(in) :: numerical_config
    ok = same_type_as(parameters,parameters_t()) .and. numerical_config%max_committed_substeps == 1
  end function
  subroutine prepare_interval(self, forcing, interval, config)
    class(model_t), intent(inout) :: self
    class(canonical_forcing_t), intent(in) :: forcing
    type(canonical_interval_t), intent(in) :: interval
    type(canonical_numerical_config_t), intent(in) :: config
    select type(forcing)
    type is(forcing_t)
      self%head = forcing%head
    class default
      error stop 'forcing type'
    end select
  end subroutine
  subroutine advance(self, state, t0, t1, outcome)
    class(model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    integer :: unit, status, command_status, ticket
    real(real64) :: ending, water_in, water_out, bottom, terminal, pressure(112), components(6)
    outcome = trial_outcome_t()
    select type(state)
    type is(state_t)
      open(newunit=unit,file='request',status='replace',action='write')
      write(unit,*) state%column, state%ticket, t0, t1, self%head
      close(unit)
      status = 1
      call execute_command_line('./worker', exitstat=status, cmdstat=command_status)
      if (command_status /= 0 .or. status /= 0) return
      open(newunit=unit,file='reply',status='old',action='read',iostat=status)
      if (status /= 0) return
      read(unit,*,iostat=status) ticket, ending, water_in, water_out, bottom, terminal, pressure, components
      close(unit)
      if (status /= 0) return
      state%stock = ending
      state%pressure = pressure
      state%component_stock = components
      state%ticket = ticket
      outcome%solver_ok = .true.
      outcome%mass_accounting_complete = .true.
      outcome%missing_mass_contribution_mask = TX_MASS_MISSING_NONE
      outcome%mass_in = water_in
      outcome%mass_out = water_out
      outcome%bottom_interface_exchange_available = .true.
      outcome%bottom_outward_exchange_native = bottom
      outcome%terminal_bottom_outward_flux_native = terminal
    end select
  end subroutine
  function storage(self, state) result(value)
    class(model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    real(real64) :: value
    value = huge(0.0_real64)
    select type(state)
    type is(state_t)
      value = state%stock
    end select
  end function
  subroutine storage_accounting_status(self, state, complete, missing_mask)
    class(model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    logical, intent(out) :: complete
    integer(int64), intent(out) :: missing_mask
    complete = same_type_as(state,state_t())
    missing_mask = TX_MASS_MISSING_NONE
  end subroutine
  function temporal_error(self, full_state, half_state) result(value)
    class(model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state
    real(real64) :: value
    value = huge(0.0_real64)
    select type(full_state)
    type is(state_t)
      select type(half_state)
      type is(state_t)
        value = maxval(abs(full_state%pressure - half_state%pressure))
        print *, 'TEMPORAL_HEAD_DEFECT_CM', value
      end select
    end select
  end function
  function temporal_assessment(self, full_state, half_state, full_outcome, half1_outcome, half2_outcome, &
                               attempt_dt) result(value)
    class(model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state
    type(trial_outcome_t), intent(in) :: full_outcome, half1_outcome, half2_outcome
    real(real64), intent(in) :: attempt_dt
    real(real64) :: value, pressure_defect, defects(3)
    pressure_defect = self%temporal_error(full_state, half_state)
    value = pressure_defect
    if (.not. self%water_metric) return
    value = huge(0.0_real64)
    if (attempt_dt <= 0 .or. .not. ieee_is_finite(attempt_dt)) return
    if (.not. full_outcome%bottom_interface_exchange_available .or. &
        .not. half1_outcome%bottom_interface_exchange_available .or. &
        .not. half2_outcome%bottom_interface_exchange_available) return
    select type(full_state)
    type is(state_t)
      select type(half_state)
      type is(state_t)
        defects = [abs(full_state%stock-half_state%stock), &
                   maxval(abs(full_state%component_stock-half_state%component_stock)), &
                   abs(full_outcome%bottom_outward_exchange_native - &
                       (half1_outcome%bottom_outward_exchange_native + half2_outcome%bottom_outward_exchange_native))]
        if (.not. all(ieee_is_finite(defects))) return
        value = maxval(defects)
        print *, 'TEMPORAL_WATER_DEFECTS_CM', defects
      end select
    end select
  end function
end module

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
