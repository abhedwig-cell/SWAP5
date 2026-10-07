module mod_fmr_b111_soil_n_daily_transaction
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_transaction_reference, only: transaction_state_t, transaction_model_t, trial_outcome_t, &
       TX_MASS_MISSING_NONE, TX_MASS_MISSING_UNSPECIFIED
  use mod_soil_n_pool_state, only: soil_n_inventory_parameters_t, soil_n_pool_state_t
  use mod_b111_soil_organic_turnover, only: b111_organic_turnover_parameters_t
  use mod_b111_soil_n_daily_exchange, only: b111_soil_n_exchange_forcing_t
  use mod_b111_soil_n_daily_candidate, only: b111_soil_n_rate_environment_t, &
       b111_soil_n_daily_candidate_result_t, evaluate_b111_soil_n_daily_candidate, B111_NDAY_OK
  use mod_fmr_b111_soil_n_transaction, only: fmr_b111_soil_n_state_t, FMR_SOIL_N_OK
  implicit none
  private

  integer,parameter,public::FMR_B111_NDAY_OK=0
  integer,parameter,public::FMR_B111_NDAY_INVALID=1
  integer,parameter,public::FMR_B111_NDAY_PROCESS_FAILED=2
  integer,parameter,public::FMR_B111_NDAY_STATE_FAILED=3

  type,extends(transaction_model_t),public::fmr_b111_soil_n_daily_model_t
    private
    type(b111_organic_turnover_parameters_t)::turnover
    real(real64),allocatable::cfrac_fom(:)
    real(real64)::cfrac_biomass=0.0_real64
    real(real64)::cfrac_humus=0.0_real64
    type(b111_soil_n_rate_environment_t)::rate_environment
    type(b111_soil_n_exchange_forcing_t)::forcing
    type(b111_soil_n_daily_candidate_result_t)::last_process
    logical::configured=.false.
    integer::last_status=FMR_B111_NDAY_INVALID
  contains
    procedure::advance=>daily_advance
    procedure::storage=>daily_storage
    procedure::temporal_error=>daily_temporal_error
    procedure::storage_accounting_status=>daily_storage_accounting_status
    procedure::attempt_context_required=>daily_attempt_context_required
    procedure,public::last_status_code=>daily_last_status
    procedure,public::snapshot_process_result=>daily_snapshot_process_result
  end type

  public::configure_fmr_b111_soil_n_daily_model

contains

  subroutine configure_fmr_b111_soil_n_daily_model(turnover,cfrac_fom,cfrac_biomass,cfrac_humus, &
       rate_environment,forcing,model,status)
    type(b111_organic_turnover_parameters_t),intent(in)::turnover
    real(real64),intent(in)::cfrac_fom(:),cfrac_biomass,cfrac_humus
    type(b111_soil_n_rate_environment_t),intent(in)::rate_environment
    type(b111_soil_n_exchange_forcing_t),intent(in)::forcing
    type(fmr_b111_soil_n_daily_model_t),intent(out)::model
    integer,intent(out)::status

    model=fmr_b111_soil_n_daily_model_t()
    status=FMR_B111_NDAY_INVALID
    if(size(cfrac_fom)<1.or..not.all(ieee_is_finite(cfrac_fom)))return
    if(.not.all(ieee_is_finite([cfrac_biomass,cfrac_humus])))return
    if(any(cfrac_fom<0.0_real64).or.cfrac_biomass<0.0_real64.or.cfrac_humus<0.0_real64)return
    if(abs(forcing%dt_day-1.0_real64)>64.0_real64*epsilon(1.0_real64))return
    model%turnover=turnover
    model%cfrac_fom=cfrac_fom
    model%cfrac_biomass=cfrac_biomass
    model%cfrac_humus=cfrac_humus
    model%rate_environment=rate_environment
    model%forcing=forcing
    model%configured=.true.
    model%last_status=FMR_B111_NDAY_OK
    status=FMR_B111_NDAY_OK
  end subroutine

  subroutine daily_advance(self,state,t0,t1,outcome)
    class(fmr_b111_soil_n_daily_model_t),intent(inout)::self
    class(transaction_state_t),intent(inout)::state
    real(real64),intent(in)::t0,t1
    type(trial_outcome_t),intent(out)::outcome
    type(soil_n_inventory_parameters_t)::params
    type(soil_n_pool_state_t)::committed,candidate
    logical::available
    integer::status

    outcome=trial_outcome_t()
    self%last_status=FMR_B111_NDAY_INVALID
    self%last_process=b111_soil_n_daily_candidate_result_t()
    if(.not.self%configured.or..not.ieee_is_finite(t0).or..not.ieee_is_finite(t1))return
    if(abs((t1-t0)-1.0_real64)>64.0_real64*epsilon(1.0_real64))return

    select type(state)
    type is(fmr_b111_soil_n_state_t)
      call state%snapshot(params,committed,available)
      if(.not.available)return
      if(size(self%cfrac_fom)/=size(committed%fom_kg_m3))return

      call evaluate_b111_soil_n_daily_candidate(params,committed,self%turnover,self%cfrac_fom, &
           self%cfrac_biomass,self%cfrac_humus,self%rate_environment,self%forcing,candidate,self%last_process)
      if(self%last_process%status/=B111_NDAY_OK)then
        self%last_status=FMR_B111_NDAY_PROCESS_FAILED
        return
      end if
      call state%replace_inventory_candidate(candidate,status)
      if(status/=FMR_SOIL_N_OK)then
        self%last_status=FMR_B111_NDAY_STATE_FAILED
        return
      end if

      outcome%solver_ok=.true.
      outcome%mass_in=self%last_process%owner_receipt%external_n_input_kg_m2
      outcome%mass_out=self%last_process%owner_receipt%external_n_output_kg_m2
      outcome%mass_accounting_complete=.true.
      outcome%missing_mass_contribution_mask=TX_MASS_MISSING_NONE
      outcome%temporal_certificate_available=.true.
      outcome%temporal_indicator=0.0_real64
      self%last_status=FMR_B111_NDAY_OK
    end select
  end subroutine

  real(real64) function daily_storage(self,state) result(value)
    class(fmr_b111_soil_n_daily_model_t),intent(in)::self
    class(transaction_state_t),intent(in)::state
    type(soil_n_inventory_parameters_t)::params
    type(soil_n_pool_state_t)::inventory
    logical::available

    value=0.0_real64
    if(.not.self%configured)return
    select type(state)
    type is(fmr_b111_soil_n_state_t)
      call state%snapshot(params,inventory,available)
      if(available)value=inventory%nitrogen_total(params)
    end select
  end function

  real(real64) function daily_temporal_error(self,full_state,half_state) result(value)
    class(fmr_b111_soil_n_daily_model_t),intent(in)::self
    class(transaction_state_t),intent(in)::full_state,half_state
    value=0.0_real64
    if(.not.self%configured.or..not.same_type_as(full_state,half_state))value=huge(0.0_real64)
  end function

  subroutine daily_storage_accounting_status(self,state,complete,missing_mask)
    class(fmr_b111_soil_n_daily_model_t),intent(in)::self
    class(transaction_state_t),intent(in)::state
    logical,intent(out)::complete
    integer(int64),intent(out)::missing_mask
    type(soil_n_inventory_parameters_t)::params
    type(soil_n_pool_state_t)::inventory
    logical::available

    complete=.false.
    missing_mask=TX_MASS_MISSING_UNSPECIFIED
    if(.not.self%configured)return
    select type(state)
    type is(fmr_b111_soil_n_state_t)
      call state%snapshot(params,inventory,available)
      complete=available
      if(complete)missing_mask=TX_MASS_MISSING_NONE
    end select
  end subroutine

  logical function daily_attempt_context_required(self) result(required)
    class(fmr_b111_soil_n_daily_model_t),intent(in)::self
    required=.false.
    if(.not.same_type_as(self,self))required=.true.
  end function

  integer function daily_last_status(self) result(status)
    class(fmr_b111_soil_n_daily_model_t),intent(in)::self
    status=self%last_status
  end function

  subroutine daily_snapshot_process_result(self,result,available)
    class(fmr_b111_soil_n_daily_model_t),intent(in)::self
    type(b111_soil_n_daily_candidate_result_t),intent(out)::result
    logical,intent(out)::available
    result=self%last_process
    available=self%last_status==FMR_B111_NDAY_OK.and.self%last_process%status==B111_NDAY_OK
  end subroutine

end module
