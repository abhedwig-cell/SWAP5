module probe_kernel_donor
  use iso_fortran_env, only: real64, int64, output_unit
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
    real(real64) :: stock = 0, component_stock(6) = 0
    real(real64), allocatable :: pressure(:)
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
    logical :: daily_pipe = .false.
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
    real(real64) :: ending, water_in, water_out, bottom, terminal, components(6)
    real(real64), allocatable :: pressure(:)
    outcome = trial_outcome_t()
    select type(state)
    type is(state_t)
      if (.not. allocated(state%pressure)) return
      if (size(state%pressure)<1) return
      allocate(pressure(size(state%pressure)))
      if (self%daily_pipe) then
        write(*,'(a,2(1x,i0),2(1x,f16.8))') 'DAILY_REQUEST', state%column, state%ticket, t0, t1
        flush(output_unit)
        read(*,*,iostat=status) ticket, ending, water_in, water_out, bottom, terminal, pressure, components
        if (status /= 0) return
        if (ticket /= state%ticket+1) return
      else
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
      end if
      if (status /= 0) return
      if (.not. all(ieee_is_finite([ending,water_in,water_out,bottom,terminal,pressure,components]))) return
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
        if (.not. allocated(full_state%pressure) .or. .not. allocated(half_state%pressure)) return
        if (size(full_state%pressure)<1 .or. size(full_state%pressure)/=size(half_state%pressure)) return
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
