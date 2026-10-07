module mod_fmr_fixed_crop_transaction
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_transaction_reference, only: transaction_state_t, trial_outcome_t, &
       TX_MASS_MISSING_NONE, TX_MASS_MISSING_UNSPECIFIED, TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_forcing_t, canonical_interval_t, canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_parameters_t, kernel_model_t
  use mod_fixed_crop_owner, only: fixed_crop_parameters_t, fixed_crop_owner_state_t, &
       fixed_crop_daily_forcing_t, fixed_crop_daily_diagnostics_t, &
       evaluate_fixed_crop_daily_candidate, FIXED_CROP_OK
  use mod_wofost_one_day_structural_evolution, only: wofost_accepted_window_aggregates_t
  use mod_crop_calendar_end_event, only: crop_end_event_request_t, crop_end_event_result_t, &
       evaluate_crop_end_event, CROP_END_OK, CROP_END_BY_CALENDAR, CROP_END_BY_DVS_OR_CALENDAR
  use mod_fmr_wofost_accepted_window_lineage, only: fmr_wofost_accepted_window_t, &
       fmr_wofost_crop_event_token_t, fmr_wofost_crop_event_identity_t, &
       fmr_wofost_crop_event_identity_persistence_t, prepare_wofost_crop_event_delivery, &
       identify_wofost_crop_event, same_wofost_crop_event_identity, crop_event_identity_matches_interval, &
       export_wofost_crop_event_identity_persistence, reconstruct_wofost_crop_event_identity_from_persistence, &
       FMR_WOFOST_LINEAGE_OK
  implicit none
  private

  integer, parameter, public :: FMR_FIXED_OK=0
  integer, parameter, public :: FMR_FIXED_INVALID_OWNER=1
  integer, parameter, public :: FMR_FIXED_INVALID_PARAMETERS=2
  integer, parameter, public :: FMR_FIXED_INVALID_EVENT=3
  integer, parameter, public :: FMR_FIXED_INVALID_POLICY=4
  integer, parameter, public :: FMR_FIXED_INTERVAL_MISMATCH=5
  integer, parameter, public :: FMR_FIXED_EVENT_ALREADY_CONSUMED=6
  integer, parameter, public :: FMR_FIXED_EVOLUTION_ERROR=7
  integer, parameter, public :: FMR_FIXED_END_EVENT_ERROR=8

  integer, parameter, public :: FMR_FIXED_PERSISTENCE_OK=0
  integer, parameter, public :: FMR_FIXED_PERSISTENCE_INVALID=1

  type, extends(transaction_state_t), public :: fmr_fixed_crop_transaction_state_t
    private
    logical :: initialized=.false.
    type(fixed_crop_owner_state_t) :: owner
    type(fmr_wofost_crop_event_identity_t) :: last_consumed_event
  contains
    procedure :: clone=>fmr_fixed_crop_transaction_clone
    procedure, public :: ready=>fmr_fixed_crop_transaction_ready
    procedure, public :: snapshot_owner=>fmr_fixed_crop_snapshot_owner
    procedure, public :: receipt_ready=>fmr_fixed_crop_receipt_ready
    procedure, public :: consumed_event=>fmr_fixed_crop_consumed_event
  end type

  type, public :: fmr_fixed_crop_persistence_t
    logical :: valid=.false.
    type(fixed_crop_owner_state_t) :: owner
    logical :: receipt_present=.false.
    type(fmr_wofost_crop_event_identity_persistence_t) :: receipt
  contains
    procedure, public :: ready=>fmr_fixed_crop_persistence_ready
  end type

  type, extends(kernel_parameters_t), public :: fmr_fixed_crop_transaction_parameters_t
    private
    logical :: initialized=.false.
    type(fixed_crop_parameters_t) :: crop
    integer :: crop_end_mode=CROP_END_BY_CALENDAR
    real(real64) :: configured_crop_end_day=0.0_real64
    real(real64) :: development_stage_end=2.0_real64
  contains
    procedure, public :: ready=>fmr_fixed_crop_parameters_ready
  end type

  type, extends(canonical_forcing_t), public :: fmr_fixed_crop_event_forcing_t
    private
    logical :: initialized=.false.
    type(fixed_crop_daily_forcing_t) :: daily
    real(real64) :: source_t1900=0.0_real64
    type(fmr_wofost_crop_event_identity_t) :: event_identity
  contains
    procedure, public :: ready=>fmr_fixed_crop_event_forcing_ready
  end type

  type, extends(kernel_model_t), public :: fmr_fixed_crop_transaction_model_t
    private
    type(fixed_crop_parameters_t) :: crop
    integer :: crop_end_mode=CROP_END_BY_CALENDAR
    real(real64) :: configured_crop_end_day=0.0_real64
    real(real64) :: development_stage_end=2.0_real64
    logical :: parameters_ready=.false.
    type(fmr_fixed_crop_event_forcing_t) :: event_forcing
    logical :: interval_ready=.false.
    integer :: last_status=FMR_FIXED_OK
  contains
    procedure :: configure_parameters=>fmr_fixed_configure_parameters
    procedure :: execution_admitted=>fmr_fixed_execution_admitted
    procedure :: prepare_interval=>fmr_fixed_prepare_interval
    procedure :: advance=>fmr_fixed_advance
    procedure :: storage=>fmr_fixed_storage
    procedure :: temporal_error=>fmr_fixed_temporal_error
    procedure :: storage_accounting_status=>fmr_fixed_storage_accounting_status
    procedure, public :: last_status_code=>fmr_fixed_last_status
  end type

  public :: initialize_fmr_fixed_crop_transaction_state
  public :: construct_fmr_fixed_crop_transaction_parameters
  public :: prepare_fmr_fixed_crop_event_forcing
  public :: export_fmr_fixed_crop_persistence
  public :: reconstruct_fmr_fixed_crop_from_persistence

contains

  subroutine initialize_fmr_fixed_crop_transaction_state(owner,state,status)
    type(fixed_crop_owner_state_t),intent(in)::owner
    type(fmr_fixed_crop_transaction_state_t),intent(out)::state
    integer,intent(out)::status
    state=fmr_fixed_crop_transaction_state_t()
    status=FMR_FIXED_INVALID_OWNER
    if(owner%validate()/=FIXED_CROP_OK)return
    state%owner=owner
    state%initialized=.true.
    status=FMR_FIXED_OK
  end subroutine

  subroutine construct_fmr_fixed_crop_transaction_parameters(crop,crop_end_mode,configured_crop_end_day, &
       development_stage_end,parameters,status)
    type(fixed_crop_parameters_t),intent(in)::crop
    integer,intent(in)::crop_end_mode
    real(real64),intent(in)::configured_crop_end_day,development_stage_end
    type(fmr_fixed_crop_transaction_parameters_t),intent(out)::parameters
    integer,intent(out)::status
    parameters=fmr_fixed_crop_transaction_parameters_t()
    status=FMR_FIXED_INVALID_PARAMETERS
    if(.not.crop%ready())return
    if(crop_end_mode/=CROP_END_BY_CALENDAR.and.crop_end_mode/=CROP_END_BY_DVS_OR_CALENDAR)return
    if(.not.ieee_is_finite(configured_crop_end_day).or.configured_crop_end_day<0.0_real64)return
    if(.not.ieee_is_finite(development_stage_end).or.development_stage_end<0.0_real64)return
    parameters%crop=crop
    parameters%crop_end_mode=crop_end_mode
    parameters%configured_crop_end_day=configured_crop_end_day
    parameters%development_stage_end=development_stage_end
    parameters%initialized=.true.
    status=FMR_FIXED_OK
  end subroutine

  subroutine prepare_fmr_fixed_crop_event_forcing(window,average_temperature_c,source_t1900,forcing,status)
    type(fmr_wofost_accepted_window_t),intent(in)::window
    real(real64),intent(in)::average_temperature_c,source_t1900
    type(fmr_fixed_crop_event_forcing_t),intent(out)::forcing
    integer,intent(out)::status
    type(fmr_wofost_crop_event_token_t)::token
    type(wofost_accepted_window_aggregates_t)::ignored_aggregates
    logical::available
    integer::lineage_status
    forcing=fmr_fixed_crop_event_forcing_t()
    status=FMR_FIXED_INVALID_EVENT
    if(.not.ieee_is_finite(average_temperature_c).or..not.ieee_is_finite(source_t1900))return
    call prepare_wofost_crop_event_delivery(window,ignored_aggregates,token,available,lineage_status)
    if(lineage_status/=FMR_WOFOST_LINEAGE_OK.or..not.available.or..not.token%ready())return
    call identify_wofost_crop_event(token,forcing%event_identity,lineage_status)
    if(lineage_status/=FMR_WOFOST_LINEAGE_OK.or..not.forcing%event_identity%ready())return
    forcing%daily%average_temperature_c=average_temperature_c
    forcing%source_t1900=source_t1900
    forcing%initialized=.true.
    status=FMR_FIXED_OK
  end subroutine

  subroutine fmr_fixed_crop_transaction_clone(self,copy)
    class(fmr_fixed_crop_transaction_state_t),intent(in)::self
    class(transaction_state_t),allocatable,intent(out)::copy
    allocate(fmr_fixed_crop_transaction_state_t::copy)
    select type(t=>copy)
    type is(fmr_fixed_crop_transaction_state_t)
      t%initialized=self%initialized
      t%owner=self%owner
      t%last_consumed_event=self%last_consumed_event
    class default
      error stop 'fixed crop transaction clone failure'
    end select
  end subroutine

  logical function fmr_fixed_crop_transaction_ready(self) result(ready)
    class(fmr_fixed_crop_transaction_state_t),intent(in)::self
    ready=self%initialized.and.self%owner%validate()==FIXED_CROP_OK
  end function

  subroutine fmr_fixed_crop_snapshot_owner(self,owner,available)
    class(fmr_fixed_crop_transaction_state_t),intent(in)::self
    type(fixed_crop_owner_state_t),intent(out)::owner
    logical,intent(out)::available
    owner=fixed_crop_owner_state_t()
    available=self%ready()
    if(available)owner=self%owner
  end subroutine

  logical function fmr_fixed_crop_receipt_ready(self) result(ready)
    class(fmr_fixed_crop_transaction_state_t),intent(in)::self
    ready=self%ready().and.self%last_consumed_event%ready()
  end function

  logical function fmr_fixed_crop_consumed_event(self,identity) result(consumed)
    class(fmr_fixed_crop_transaction_state_t),intent(in)::self
    type(fmr_wofost_crop_event_identity_t),intent(in)::identity
    consumed=.false.
    if(.not.self%receipt_ready().or..not.identity%ready())return
    consumed=same_wofost_crop_event_identity(self%last_consumed_event,identity)
  end function

  logical function fmr_fixed_crop_persistence_ready(self) result(ready)
    class(fmr_fixed_crop_persistence_t),intent(in)::self
    ready=.false.
    if(.not.self%valid)return
    if(self%owner%validate()/=FIXED_CROP_OK)return
    if(self%receipt_present)then
      if(.not.self%receipt%ready())return
    else
      if(self%receipt%valid)return
    end if
    ready=.true.
  end function

  subroutine export_fmr_fixed_crop_persistence(state,view,exported,status)
    type(fmr_fixed_crop_transaction_state_t),intent(in)::state
    type(fmr_fixed_crop_persistence_t),intent(out)::view
    logical,intent(out)::exported
    integer,intent(out)::status
    logical::receipt_ok
    view=fmr_fixed_crop_persistence_t()
    exported=.false.;status=FMR_FIXED_PERSISTENCE_INVALID
    if(.not.state%ready())return
    view%owner=state%owner
    if(state%last_consumed_event%ready())then
      call export_wofost_crop_event_identity_persistence(state%last_consumed_event,view%receipt,receipt_ok)
      if(.not.receipt_ok)return
      view%receipt_present=.true.
    end if
    view%valid=.true.
    if(.not.view%ready())then
      view=fmr_fixed_crop_persistence_t();return
    end if
    exported=.true.;status=FMR_FIXED_PERSISTENCE_OK
  end subroutine

  subroutine reconstruct_fmr_fixed_crop_from_persistence(view,state,reconstructed,status)
    type(fmr_fixed_crop_persistence_t),intent(in)::view
    type(fmr_fixed_crop_transaction_state_t),intent(out)::state
    logical,intent(out)::reconstructed
    integer,intent(out)::status
    integer::receipt_status
    state=fmr_fixed_crop_transaction_state_t()
    reconstructed=.false.;status=FMR_FIXED_PERSISTENCE_INVALID
    if(.not.view%ready())return
    state%owner=view%owner
    if(view%receipt_present)then
      call reconstruct_wofost_crop_event_identity_from_persistence(view%receipt,state%last_consumed_event,receipt_status)
      if(receipt_status/=FMR_WOFOST_LINEAGE_OK)return
    end if
    state%initialized=.true.
    if(.not.state%ready())then
      state=fmr_fixed_crop_transaction_state_t();return
    end if
    reconstructed=.true.;status=FMR_FIXED_PERSISTENCE_OK
  end subroutine

  logical function fmr_fixed_crop_parameters_ready(self) result(ready)
    class(fmr_fixed_crop_transaction_parameters_t),intent(in)::self
    ready=.false.
    if(.not.self%initialized.or..not.self%crop%ready())return
    if(self%crop_end_mode/=CROP_END_BY_CALENDAR.and.self%crop_end_mode/=CROP_END_BY_DVS_OR_CALENDAR)return
    if(.not.ieee_is_finite(self%configured_crop_end_day).or.self%configured_crop_end_day<0.0_real64)return
    if(.not.ieee_is_finite(self%development_stage_end).or.self%development_stage_end<0.0_real64)return
    ready=.true.
  end function

  logical function fmr_fixed_crop_event_forcing_ready(self) result(ready)
    class(fmr_fixed_crop_event_forcing_t),intent(in)::self
    ready=self%initialized.and.self%event_identity%ready().and. &
         ieee_is_finite(self%daily%average_temperature_c).and.ieee_is_finite(self%source_t1900)
  end function

  subroutine fmr_fixed_configure_parameters(self,parameters)
    class(fmr_fixed_crop_transaction_model_t),intent(inout)::self
    class(kernel_parameters_t),intent(in)::parameters
    self%parameters_ready=.false.;self%last_status=FMR_FIXED_INVALID_PARAMETERS
    select type(p=>parameters)
    type is(fmr_fixed_crop_transaction_parameters_t)
      if(.not.p%ready())return
      self%crop=p%crop
      self%crop_end_mode=p%crop_end_mode
      self%configured_crop_end_day=p%configured_crop_end_day
      self%development_stage_end=p%development_stage_end
      self%parameters_ready=.true.;self%last_status=FMR_FIXED_OK
    class default
      return
    end select
  end subroutine

  logical function fmr_fixed_execution_admitted(self,parameters,numerical_config) result(admitted)
    class(fmr_fixed_crop_transaction_model_t),intent(in)::self
    class(kernel_parameters_t),intent(in)::parameters
    type(canonical_numerical_config_t),intent(in)::numerical_config
    admitted=.false.
    if(.not.same_type_as(self,self))return
    if(numerical_config%transaction%temporal_mode/=TX_TEMPORAL_MODEL_CERTIFICATE)return
    if(numerical_config%transaction%max_retries/=0.or.numerical_config%max_committed_substeps/=1)return
    select type(p=>parameters)
    type is(fmr_fixed_crop_transaction_parameters_t)
      admitted=p%ready()
    class default
      admitted=.false.
    end select
  end function

  subroutine fmr_fixed_prepare_interval(self,forcing,interval,config)
    class(fmr_fixed_crop_transaction_model_t),intent(inout)::self
    class(canonical_forcing_t),intent(in)::forcing
    type(canonical_interval_t),intent(in)::interval
    type(canonical_numerical_config_t),intent(in)::config
    self%interval_ready=.false.;self%last_status=FMR_FIXED_INVALID_EVENT
    if(config%transaction%temporal_mode/=TX_TEMPORAL_MODEL_CERTIFICATE.or. &
       config%transaction%max_retries/=0.or.config%max_committed_substeps/=1)then
      self%last_status=FMR_FIXED_INVALID_POLICY;return
    end if
    select type(f=>forcing)
    type is(fmr_fixed_crop_event_forcing_t)
      if(.not.f%ready())return
      if(.not.crop_event_identity_matches_interval(f%event_identity,interval%t0,interval%t1))then
        self%last_status=FMR_FIXED_INTERVAL_MISMATCH;return
      end if
      self%event_forcing=f
      self%interval_ready=.true.;self%last_status=FMR_FIXED_OK
    class default
      return
    end select
  end subroutine

  subroutine fmr_fixed_advance(self,state,t0,t1,outcome)
    class(fmr_fixed_crop_transaction_model_t),intent(inout)::self
    class(transaction_state_t),intent(inout)::state
    real(real64),intent(in)::t0,t1
    type(trial_outcome_t),intent(out)::outcome
    type(fixed_crop_owner_state_t)::candidate
    type(fixed_crop_daily_diagnostics_t)::diagnostics
    type(crop_end_event_request_t)::end_request
    type(crop_end_event_result_t)::end_result
    integer::status

    outcome=trial_outcome_t()
    self%last_status=FMR_FIXED_INVALID_OWNER
    if(.not.self%parameters_ready.or..not.self%interval_ready)return
    if(.not.crop_event_identity_matches_interval(self%event_forcing%event_identity,t0,t1))then
      self%last_status=FMR_FIXED_INTERVAL_MISMATCH;return
    end if

    select type(s=>state)
    type is(fmr_fixed_crop_transaction_state_t)
      if(.not.s%ready())return
      if(s%consumed_event(self%event_forcing%event_identity))then
        self%last_status=FMR_FIXED_EVENT_ALREADY_CONSUMED;return
      end if
      call evaluate_fixed_crop_daily_candidate(self%crop,s%owner,self%event_forcing%daily,candidate,diagnostics,status)
      if(status/=FIXED_CROP_OK.or..not.diagnostics%candidate_built)then
        self%last_status=FMR_FIXED_EVOLUTION_ERROR;return
      end if
      end_request%mode=self%crop_end_mode
      end_request%current_time_day=self%event_forcing%source_t1900
      end_request%configured_crop_end_day=self%configured_crop_end_day
      end_request%development_stage=candidate%development_stage
      end_request%development_stage_end=self%development_stage_end
      call evaluate_crop_end_event(end_request,end_result,status)
      if(status/=CROP_END_OK)then
        self%last_status=FMR_FIXED_END_EVENT_ERROR;return
      end if
      if(end_result%end_crop)candidate%crop_emerged=.false.
      if(candidate%validate()/=FIXED_CROP_OK)then
        self%last_status=FMR_FIXED_EVOLUTION_ERROR;return
      end if
      s%owner=candidate
      s%last_consumed_event=self%event_forcing%event_identity
      s%initialized=.true.
      outcome%solver_ok=.true.
      outcome%mass_accounting_complete=.true.
      outcome%missing_mass_contribution_mask=TX_MASS_MISSING_NONE
      outcome%mass_in=0.0_real64;outcome%mass_out=0.0_real64
      outcome%temporal_certificate_available=.true.
      outcome%temporal_indicator=0.0_real64
      self%last_status=FMR_FIXED_OK
    class default
      return
    end select
  end subroutine

  real(real64) function fmr_fixed_storage(self,state) result(value)
    class(fmr_fixed_crop_transaction_model_t),intent(in)::self
    class(transaction_state_t),intent(in)::state
    value=0.0_real64
    if(.not.same_type_as(self,self).or..not.same_type_as(state,state))return
  end function

  real(real64) function fmr_fixed_temporal_error(self,full_state,half_state) result(value)
    class(fmr_fixed_crop_transaction_model_t),intent(in)::self
    class(transaction_state_t),intent(in)::full_state,half_state
    value=0.0_real64
    if(.not.same_type_as(self,self).or..not.same_type_as(full_state,half_state))value=huge(0.0_real64)
  end function

  subroutine fmr_fixed_storage_accounting_status(self,state,complete,missing_mask)
    class(fmr_fixed_crop_transaction_model_t),intent(in)::self
    class(transaction_state_t),intent(in)::state
    logical,intent(out)::complete
    integer(kind=8),intent(out)::missing_mask
    complete=.false.;missing_mask=TX_MASS_MISSING_UNSPECIFIED
    select type(s=>state)
    type is(fmr_fixed_crop_transaction_state_t)
      complete=s%ready()
      if(complete)missing_mask=TX_MASS_MISSING_NONE
    class default
      complete=.false.
    end select
  end subroutine

  integer function fmr_fixed_last_status(self) result(status)
    class(fmr_fixed_crop_transaction_model_t),intent(in)::self
    status=self%last_status
  end function

end module mod_fmr_fixed_crop_transaction
