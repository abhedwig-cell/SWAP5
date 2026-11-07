module probe_kernel_donor
  use iso_fortran_env, only: real64, int64
  use mod_transaction_reference, only: transaction_state_t, trial_outcome_t, TX_MASS_MISSING_NONE
  use mod_canonical_contracts
  use mod_kernel_transactions
  implicit none
  type, extends(canonical_state_t) :: state_t
    integer :: column = 0, ticket = 0
    real(real64) :: stock = 0
  contains
    procedure :: clone
  end type
  type, extends(canonical_forcing_t) :: forcing_t
    real(real64) :: head = 0
  end type
  type, extends(kernel_parameters_t) :: parameters_t
  end type
  type, extends(kernel_model_t) :: model_t
    real(real64) :: head = 0
  contains
    procedure :: configure_parameters
    procedure :: execution_admitted
    procedure :: prepare_interval
    procedure :: advance
    procedure :: storage
    procedure :: storage_accounting_status
    procedure :: temporal_error
  end type
contains
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
    real(real64) :: ending, water_in, water_out, bottom, terminal
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
      read(unit,*,iostat=status) ticket, ending, water_in, water_out, bottom, terminal
      close(unit)
      if (status /= 0) return
      state%stock = ending
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

  read(*,*) stock
  call executor%bind_model(model)
  do i=1,2
    allocate(initial, source=state_t(column=i, ticket=0, stock=stock))
    call committed(i)%initialize(int(i,int64),initial,ok,35799d0)
    if (.not. ok) error stop 'initialization'
    deallocate(initial)
  end do
  call trial(1,35799d0,35799.5d0,-90d0,.false.)
  if (any([committed(1)%current_revision(),committed(2)%current_revision()] /= 0)) error stop 'discard changed origin'
  call trial(2,35799d0,35799.5d0,-90d0,.true.)
  call trial(1,35799d0,35799.5d0,-50d0,.true.)
  call trial(1,35799.5d0,35800d0,-90d0,.true.)
  call trial(2,35799.5d0,35800d0,-50d0,.true.)
  if (any([committed(1)%current_revision(),committed(2)%current_revision()] /= 2)) error stop 'revision'
contains
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
