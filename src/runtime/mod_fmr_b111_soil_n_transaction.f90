module mod_fmr_b111_soil_n_transaction
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_transaction_reference, only: transaction_state_t, transaction_model_t, trial_outcome_t, &
       TX_MASS_MISSING_NONE, TX_MASS_MISSING_UNSPECIFIED
  use mod_soil_n_pool_state, only: soil_n_inventory_parameters_t, soil_n_pool_state_t, soil_n_transfer_t, &
       soil_n_receipt_t, apply_soil_n_transfer, SOIL_N_OK
  implicit none
  private

  integer, parameter, public :: FMR_SOIL_N_OK = 0
  integer, parameter, public :: FMR_SOIL_N_INVALID = 1
  integer, parameter, public :: FMR_SOIL_N_TRANSFER_FAILED = 2
  integer, parameter, public :: FMR_SOIL_N_EVENT_ALREADY_CONSUMED = 3

  type, extends(transaction_state_t), public :: fmr_b111_soil_n_state_t
    private
    type(soil_n_inventory_parameters_t) :: params
    type(soil_n_pool_state_t) :: inventory
    integer(int64) :: last_management_event_id = 0_int64
    logical :: management_event_consumed = .false.
    logical :: initialized = .false.
  contains
    procedure :: clone => soil_n_clone
    procedure, public :: ready => soil_n_ready
    procedure, public :: snapshot => soil_n_snapshot
    procedure, public :: consumed_management_event => soil_n_consumed_management_event
    procedure, public :: snapshot_management_event => soil_n_snapshot_management_event
  end type

  type, extends(transaction_model_t), public :: fmr_b111_soil_n_model_t
    private
    type(soil_n_inventory_parameters_t) :: params
    type(soil_n_transfer_t) :: rate_per_day
    logical :: configured = .false.
    integer :: last_status = FMR_SOIL_N_INVALID
  contains
    procedure :: advance => soil_n_advance
    procedure :: storage => soil_n_storage
    procedure :: temporal_error => soil_n_temporal_error
    procedure :: storage_accounting_status => soil_n_storage_accounting_status
    procedure :: attempt_context_required => soil_n_attempt_context_required
    procedure, public :: last_status_code => soil_n_last_status
  end type

  public :: initialize_fmr_b111_soil_n_state, configure_fmr_b111_soil_n_model
  public :: apply_fmr_b111_soil_n_management_event

contains

  subroutine initialize_fmr_b111_soil_n_state(params, inventory, state, status, last_management_event_id, management_event_consumed)
    type(soil_n_inventory_parameters_t), intent(in) :: params
    type(soil_n_pool_state_t), intent(in) :: inventory
    type(fmr_b111_soil_n_state_t), intent(out) :: state
    integer, intent(out) :: status
    integer(int64), intent(in), optional :: last_management_event_id
    logical, intent(in), optional :: management_event_consumed

    state = fmr_b111_soil_n_state_t()
    status = FMR_SOIL_N_INVALID
    if (.not. params%valid() .or. .not. inventory%valid()) return
    if (size(params%nfrac_fom) /= size(inventory%fom_kg_m3)) return
    state%params = params
    state%inventory = inventory
    if (present(last_management_event_id) .neqv. present(management_event_consumed)) return
    if (present(last_management_event_id)) then
      if (management_event_consumed .and. last_management_event_id <= 0_int64) return
      if (.not. management_event_consumed .and. last_management_event_id /= 0_int64) return
      state%last_management_event_id = last_management_event_id
      state%management_event_consumed = management_event_consumed
    end if
    state%initialized = .true.
    status = FMR_SOIL_N_OK
  end subroutine

  subroutine configure_fmr_b111_soil_n_model(params, rate_per_day, model, status)
    type(soil_n_inventory_parameters_t), intent(in) :: params
    type(soil_n_transfer_t), intent(in) :: rate_per_day
    type(fmr_b111_soil_n_model_t), intent(out) :: model
    integer, intent(out) :: status

    model = fmr_b111_soil_n_model_t()
    status = FMR_SOIL_N_INVALID
    if (.not. params%valid()) return
    if (.not. valid_rate(params, rate_per_day)) return
    model%params = params
    model%rate_per_day = rate_per_day
    model%configured = .true.
    model%last_status = FMR_SOIL_N_OK
    status = FMR_SOIL_N_OK
  end subroutine

  subroutine soil_n_clone(self, copy)
    class(fmr_b111_soil_n_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(fmr_b111_soil_n_state_t :: copy)
    select type (copy)
    type is (fmr_b111_soil_n_state_t)
      copy%params = self%params
      copy%inventory = self%inventory
      copy%last_management_event_id = self%last_management_event_id
      copy%management_event_consumed = self%management_event_consumed
      copy%initialized = self%initialized
    end select
  end subroutine

  logical function soil_n_ready(self) result(ready)
    class(fmr_b111_soil_n_state_t), intent(in) :: self
    ready = self%initialized .and. self%params%valid() .and. self%inventory%valid()
    if (ready) ready = size(self%params%nfrac_fom) == size(self%inventory%fom_kg_m3)
  end function

  subroutine soil_n_snapshot(self, params, inventory, available)
    class(fmr_b111_soil_n_state_t), intent(in) :: self
    type(soil_n_inventory_parameters_t), intent(out) :: params
    type(soil_n_pool_state_t), intent(out) :: inventory
    logical, intent(out) :: available

    params = soil_n_inventory_parameters_t()
    inventory = soil_n_pool_state_t()
    available = self%ready()
    if (available) then
      params = self%params
      inventory = self%inventory
    end if
  end subroutine


  logical function soil_n_consumed_management_event(self,event_id) result(consumed)
    class(fmr_b111_soil_n_state_t),intent(in)::self
    integer(int64),intent(in)::event_id
    consumed=self%management_event_consumed.and.event_id>0_int64.and.self%last_management_event_id==event_id
  end function


  subroutine soil_n_snapshot_management_event(self,event_id,consumed,available)
    class(fmr_b111_soil_n_state_t),intent(in)::self
    integer(int64),intent(out)::event_id
    logical,intent(out)::consumed,available
    event_id=0_int64
    consumed=.false.
    available=self%ready()
    if(.not.available)return
    event_id=self%last_management_event_id
    consumed=self%management_event_consumed
  end subroutine

  subroutine apply_fmr_b111_soil_n_management_event(state,event_id,transfer,status,receipt)
    type(fmr_b111_soil_n_state_t),intent(inout)::state
    integer(int64),intent(in)::event_id
    type(soil_n_transfer_t),intent(in)::transfer
    integer,intent(out)::status
    type(soil_n_receipt_t),intent(out)::receipt
    type(soil_n_pool_state_t)::candidate

    receipt=soil_n_receipt_t()
    status=FMR_SOIL_N_INVALID
    if(.not.state%ready().or.event_id<=0_int64)return
    if(state%consumed_management_event(event_id))then
      status=FMR_SOIL_N_EVENT_ALREADY_CONSUMED
      return
    end if
    call apply_soil_n_transfer(state%params,state%inventory,transfer,candidate,receipt)
    if(receipt%status/=SOIL_N_OK)then
      status=FMR_SOIL_N_TRANSFER_FAILED
      return
    end if
    state%inventory=candidate
    state%last_management_event_id=event_id
    state%management_event_consumed=.true.
    status=FMR_SOIL_N_OK
  end subroutine

  subroutine soil_n_advance(self, state, t0, t1, outcome)
    class(fmr_b111_soil_n_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    type(soil_n_transfer_t) :: transfer
    type(soil_n_pool_state_t) :: candidate
    type(soil_n_receipt_t) :: receipt

    outcome = trial_outcome_t()
    self%last_status = FMR_SOIL_N_INVALID
    if (.not. self%configured) return
    if (.not. ieee_is_finite(t0) .or. .not. ieee_is_finite(t1) .or. t1 <= t0) return
    call scale_rate(self%rate_per_day, t1 - t0, transfer)

    select type (state)
    type is (fmr_b111_soil_n_state_t)
      if (.not. state%ready()) return
      call apply_soil_n_transfer(self%params, state%inventory, transfer, candidate, receipt)
      if (receipt%status /= SOIL_N_OK) then
        self%last_status = FMR_SOIL_N_TRANSFER_FAILED
        return
      end if
      state%inventory = candidate
      outcome%solver_ok = .true.
      outcome%mass_in = receipt%external_n_input_kg_m2
      outcome%mass_out = receipt%external_n_output_kg_m2
      outcome%mass_accounting_complete = .true.
      outcome%missing_mass_contribution_mask = TX_MASS_MISSING_NONE
      outcome%temporal_certificate_available = .true.
      outcome%temporal_indicator = 0.0_real64
      self%last_status = FMR_SOIL_N_OK
    end select
  end subroutine

  real(real64) function soil_n_storage(self, state) result(storage)
    class(fmr_b111_soil_n_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state

    storage = 0.0_real64
    if (.not. self%configured) return
    select type (state)
    type is (fmr_b111_soil_n_state_t)
      if (state%ready()) storage = state%inventory%nitrogen_total(self%params)
    end select
  end function

  real(real64) function soil_n_temporal_error(self, full_state, half_state) result(error)
    class(fmr_b111_soil_n_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state
    class(transaction_state_t), intent(in) :: half_state

    error = 0.0_real64
    if (.not. self%configured .or. .not. same_type_as(full_state, half_state)) error = huge(0.0_real64)
  end function

  subroutine soil_n_storage_accounting_status(self, state, complete, missing_mask)
    class(fmr_b111_soil_n_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    logical, intent(out) :: complete
    integer(int64), intent(out) :: missing_mask

    complete = .false.
    missing_mask = TX_MASS_MISSING_UNSPECIFIED
    if (.not. self%configured) return
    select type (state)
    type is (fmr_b111_soil_n_state_t)
      complete = state%ready()
      if (complete) missing_mask = TX_MASS_MISSING_NONE
    end select
  end subroutine

  logical function soil_n_attempt_context_required(self) result(required)
    class(fmr_b111_soil_n_model_t), intent(in) :: self
    required = .false.
    if (.not. same_type_as(self, self)) required = .true.
  end function

  integer function soil_n_last_status(self) result(status)
    class(fmr_b111_soil_n_model_t), intent(in) :: self
    status = self%last_status
  end function

  logical function valid_rate(params, transfer) result(valid)
    type(soil_n_inventory_parameters_t), intent(in) :: params
    type(soil_n_transfer_t), intent(in) :: transfer

    valid = .false.
    if (.not. allocated(transfer%fom_delta_kg_m3)) return
    if (size(transfer%fom_delta_kg_m3) /= size(params%nfrac_fom)) return
    if (.not. all(ieee_is_finite(transfer%fom_delta_kg_m3))) return
    if (.not. all(ieee_is_finite([transfer%biomass_delta_kg_m3, transfer%humus_delta_kg_m3, &
         transfer%ammonium_n_delta_kg_m2, transfer%nitrate_n_delta_kg_m2, &
         transfer%external_n_input_kg_m2, transfer%external_n_output_kg_m2]))) return
    if (transfer%external_n_input_kg_m2 < 0.0_real64 .or. transfer%external_n_output_kg_m2 < 0.0_real64) return
    valid = .true.
  end function

  subroutine scale_rate(rate, dt, transfer)
    type(soil_n_transfer_t), intent(in) :: rate
    real(real64), intent(in) :: dt
    type(soil_n_transfer_t), intent(out) :: transfer

    transfer = soil_n_transfer_t()
    transfer%fom_delta_kg_m3 = rate%fom_delta_kg_m3 * dt
    transfer%biomass_delta_kg_m3 = rate%biomass_delta_kg_m3 * dt
    transfer%humus_delta_kg_m3 = rate%humus_delta_kg_m3 * dt
    transfer%ammonium_n_delta_kg_m2 = rate%ammonium_n_delta_kg_m2 * dt
    transfer%nitrate_n_delta_kg_m2 = rate%nitrate_n_delta_kg_m2 * dt
    transfer%external_n_input_kg_m2 = rate%external_n_input_kg_m2 * dt
    transfer%external_n_output_kg_m2 = rate%external_n_output_kg_m2 * dt
  end subroutine
end module
