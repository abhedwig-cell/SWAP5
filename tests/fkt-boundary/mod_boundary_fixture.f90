! Synthetic owner for generic transaction tests; no crop/harvest science claim.
module mod_boundary_fixture
 use iso_fortran_env,only:real64,int64
 use mod_transaction_reference,only:transaction_state_t,trial_outcome_t,TX_MASS_MISSING_NONE,TX_MASS_MISSING_UNSPECIFIED
 use mod_canonical_contracts,only:canonical_forcing_t,canonical_interval_t,canonical_numerical_config_t
 use mod_kernel_transactions
 implicit none
 type,extends(transaction_state_t)::event_state_t
  real(real64)::nitrogen=10d0,water=30d0,history(2)=[1d0,2d0]
  integer(int64)::last_event=0_int64
 contains
  procedure::clone=>clone_event
 end type
 type,extends(kernel_parameters_t)::event_parameters_t
  integer(int64)::grid_id=17_int64
 contains
  procedure::capture_identity=>capture_grid
  procedure::matches_physical_identity=>match_grid
 end type
 type,extends(canonical_forcing_t)::event_forcing_t
  real(real64)::export_n=2d0
 end type
 type,extends(kernel_boundary_model_t)::event_model_t
  logical::admitted=.true.,reject_stage=.false.,reject_validate=.false.
  integer::fault=0
 contains
  procedure::event_admitted=>admitted_event
  procedure::stage_event=>stage_event
  procedure::validate_event=>validate_event
 end type
 type,extends(kernel_model_t)::interval_model_t
 contains
  procedure::configure_parameters=>interval_configure
  procedure::execution_admitted=>interval_admitted
  procedure::prepare_interval=>interval_prepare
  procedure::advance=>interval_advance
  procedure::storage=>interval_storage
  procedure::storage_accounting_status=>interval_storage_status
  procedure::temporal_error=>interval_error
  procedure::matches_committed_parameter_identity=>interval_identity
 end type
contains
 subroutine interval_configure(self,parameters)
  class(interval_model_t),intent(inout)::self
  class(kernel_parameters_t),intent(in)::parameters
 end subroutine
 logical function interval_admitted(self,parameters,numerical_config)result(ok)
  class(interval_model_t),intent(in)::self
  class(kernel_parameters_t),intent(in)::parameters
  type(canonical_numerical_config_t),intent(in)::numerical_config
  ok=numerical_config%max_committed_substeps>0
 end function
 subroutine interval_prepare(self,forcing,interval,config)
  class(interval_model_t),intent(inout)::self
  class(canonical_forcing_t),intent(in)::forcing
  type(canonical_interval_t),intent(in)::interval
  type(canonical_numerical_config_t),intent(in)::config
 end subroutine
 subroutine interval_advance(self,state,t0,t1,outcome)
  class(interval_model_t),intent(inout)::self
  class(transaction_state_t),intent(inout)::state
  real(real64),intent(in)::t0,t1
  type(trial_outcome_t),intent(out)::outcome
  ! Synthetic closed, quiescent owner: tests executor interoperability only.
  outcome=trial_outcome_t()
  select type(state)
  type is(event_state_t)
   outcome%solver_ok=t1>t0
   outcome%mass_in=0d0;outcome%mass_out=0d0
   outcome%mass_accounting_complete=.true.
   outcome%missing_mass_contribution_mask=TX_MASS_MISSING_NONE
  end select
 end subroutine
 function interval_storage(self,state)result(value)
  class(interval_model_t),intent(in)::self
  class(transaction_state_t),intent(in)::state
  real(real64)::value
  value=huge(0d0)
  select type(state)
  type is(event_state_t)
   value=state%water
  end select
 end function
 subroutine interval_storage_status(self,state,complete,missing_mask)
  class(interval_model_t),intent(in)::self
  class(transaction_state_t),intent(in)::state
  logical,intent(out)::complete
  integer(int64),intent(out)::missing_mask
  complete=.false.;missing_mask=TX_MASS_MISSING_UNSPECIFIED
  select type(state)
  type is(event_state_t)
   complete=.true.;missing_mask=TX_MASS_MISSING_NONE
  end select
 end subroutine
 function interval_error(self,full_state,half_state)result(value)
  class(interval_model_t),intent(in)::self
  class(transaction_state_t),intent(in)::full_state,half_state
  real(real64)::value
  value=0d0
 end function
 logical function interval_identity(self,identity,state)result(ok)
  class(interval_model_t),intent(in)::self
  type(kernel_parameter_identity_t),intent(in)::identity
  class(transaction_state_t),intent(in)::state
  type(event_parameters_t)::parameters
  type(kernel_parameter_identity_t)::expected
  logical::available
  call parameters%capture_identity(expected,available)
  ok=identity%matches(expected).and.parameters%matches_physical_identity(state)
 end function
 subroutine clone_event(self,copy)
  class(event_state_t),intent(in)::self
  class(transaction_state_t),allocatable,intent(out)::copy
  allocate(copy,source=self)
 end subroutine
 subroutine capture_grid(self,identity,available)
  class(event_parameters_t),intent(in)::self
  type(kernel_parameter_identity_t),intent(out)::identity
  logical,intent(out)::available
  identity=kernel_parameter_identity_t()
  identity%valid=.true.;identity%parameter_set_id=self%grid_id;identity%active_nodes=1
  identity%z=[-.5d0];identity%dz=[1d0];available=.true.
 end subroutine
 logical function match_grid(self,state)result(ok)
  class(event_parameters_t),intent(in)::self
  class(transaction_state_t),intent(in)::state
  ok=.false.
  if(self%grid_id<=0)return
  select type(state)
  type is(event_state_t)
   ok=state%water==30d0.and.all(state%history==[1d0,2d0])
  end select
 end function
 logical function admitted_event(self,parameters,forcing,request)result(ok)
  class(event_model_t),intent(in)::self
  class(kernel_parameters_t),intent(in)::parameters
  class(canonical_forcing_t),intent(in)::forcing
  type(kernel_boundary_request_t),intent(in)::request
  ok=.false.
  select type(parameters)
  type is(event_parameters_t)
   select type(forcing)
   type is(event_forcing_t)
    ok=self%admitted.and.request%subject_id==7_int64.and.request%phase==1.and. &
       parameters%grid_id>0.and.forcing%export_n==2d0
   end select
  end select
 end function
 subroutine stage_event(self,parameters,forcing,request,before,after,balance,ok)
  class(event_model_t),intent(in)::self
  class(kernel_parameters_t),intent(in)::parameters
  class(canonical_forcing_t),intent(in)::forcing
  type(kernel_boundary_request_t),intent(in)::request
  class(transaction_state_t),intent(in)::before
  class(transaction_state_t),allocatable,intent(out)::after
  type(kernel_boundary_balance_t),intent(out)::balance
  logical,intent(out)::ok
  balance=kernel_boundary_balance_t();ok=.false.
  if(self%reject_stage.or..not.self%event_admitted(parameters,forcing,request))return
  select type(before)
  type is(event_state_t)
   select type(forcing)
   type is(event_forcing_t)
    if(before%last_event>=request%event_id.or.before%nitrogen<forcing%export_n)return
    allocate(after,source=before)
    select type(after)
    type is(event_state_t)
     after%nitrogen=before%nitrogen-forcing%export_n;after%last_event=request%event_id
     if(self%fault==1)after%water=99d0
     if(self%fault==2)after%history=0d0
     if(self%fault==3)after%last_event=0_int64
    end select
    balance%complete=.true.;balance%count=1;balance%quantity_id(1)=1
    balance%before(1)=before%nitrogen;balance%after(1)=before%nitrogen-forcing%export_n
    balance%external_out(1)=forcing%export_n
    if(self%fault==4)balance%complete=.false.
    if(self%fault==5)balance%external_out(1)=0d0
    if(self%fault==6)balance%after(1)=0d0
    if(self%fault==7)balance%count=0
    ok=.true.
   end select
  end select
 end subroutine
 logical function validate_event(self,parameters,forcing,request,before,after,balance)result(ok)
  class(event_model_t),intent(in)::self
  class(kernel_parameters_t),intent(in)::parameters
  class(canonical_forcing_t),intent(in)::forcing
  type(kernel_boundary_request_t),intent(in)::request
  class(transaction_state_t),intent(in)::before,after
  type(kernel_boundary_balance_t),intent(in)::balance
  ok=.false.
  if(self%reject_validate.or..not.self%event_admitted(parameters,forcing,request))return
  select type(before)
  type is(event_state_t)
   select type(after)
   type is(event_state_t)
    select type(forcing)
    type is(event_forcing_t)
     ok=before%last_event<request%event_id.and.after%last_event==request%event_id.and. &
        after%nitrogen==before%nitrogen-forcing%export_n.and.after%water==before%water.and. &
        all(after%history==before%history).and.balance%count==1.and.balance%quantity_id(1)==1.and. &
        balance%before(1)==before%nitrogen.and.balance%after(1)==after%nitrogen.and. &
        balance%external_in(1)==0d0.and.balance%external_out(1)==forcing%export_n
    end select
   end select
  end select
 end function
end module
