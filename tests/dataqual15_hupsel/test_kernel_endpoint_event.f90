! Transaction plumbing fixture calling the actual F-KT owner. This tank is
! deliberately not a Rutter/soil/crop science oracle or production admission.
module endpoint_fixture
 use iso_fortran_env,only:real64,int64
 use ieee_arithmetic,only:ieee_is_finite,ieee_value,ieee_quiet_nan
 use mod_transaction_reference
 use mod_canonical_contracts
 use mod_kernel_transactions
 implicit none
 type,extends(transaction_state_t)::tank_t
  real(real64)::amount=1d0
  integer::layout=1
 contains
  procedure::clone=>clone_tank
 end type
 type,extends(kernel_parameters_t)::parameters_t
  integer(int64)::id=7
 contains
  procedure::capture_identity=>capture
  procedure::matches_physical_identity=>physical_matches
 end type
 type,extends(canonical_forcing_t)::command_t
  real(real64)::capacity=.25d0
  integer::fault=0
 end type
 type,extends(canonical_forcing_t)::foreign_t
 end type
 type,extends(kernel_model_t)::ordinary_model_t
 contains
  procedure::configure_parameters=>configure
  procedure::execution_admitted=>admit
  procedure::prepare_interval=>prepare
  procedure::advance=>advance
  procedure::storage=>storage
  procedure::storage_accounting_status=>storage_status
  procedure::temporal_error=>temporal
  procedure::matches_committed_parameter_identity=>identity_matches
 end type
 type,extends(ordinary_model_t)::event_model_t
 contains
  procedure::endpoint_event_admitted=>admit_event
  procedure::apply_endpoint_event=>apply_event
 end type
contains
 subroutine clone_tank(self,copy)
  class(tank_t),intent(in)::self
  class(transaction_state_t),allocatable,intent(out)::copy
  allocate(copy,source=self)
 end subroutine
 subroutine capture(self,identity,available)
  class(parameters_t),intent(in)::self
  type(kernel_parameter_identity_t),intent(out)::identity
  logical,intent(out)::available
  identity=kernel_parameter_identity_t()
  identity%parameter_set_id=self%id;identity%active_nodes=1
  identity%z=[0d0];identity%dz=[1d0];identity%valid=self%id>0
  available=identity%valid
 end subroutine
 logical function physical_matches(self,state)result(ok)
  class(parameters_t),intent(in)::self
  class(transaction_state_t),intent(in)::state
  ok=.false.
  select type(state)
  type is(tank_t)
   ok=self%id>0.and.state%layout==1.and.ieee_is_finite(state%amount)
  end select
 end function
 logical function identity_matches(self,identity,state)result(ok)
  class(ordinary_model_t),intent(in)::self
  type(kernel_parameter_identity_t),intent(in)::identity
  class(transaction_state_t),intent(in)::state
  ok=.false.
  select type(state)
  type is(tank_t)
   ok=identity%valid.and.identity%active_nodes==1.and.state%layout==1
  end select
  if(.not.same_type_as(self,self))ok=.false.
 end function
 subroutine configure(self,parameters)
  class(ordinary_model_t),intent(inout)::self
  class(kernel_parameters_t),intent(in)::parameters
  if(.not.same_type_as(self,self).or..not.same_type_as(parameters,parameters))error stop
 end subroutine
 logical function admit(self,parameters,numerical_config)result(ok)
  class(ordinary_model_t),intent(in)::self
  class(kernel_parameters_t),intent(in)::parameters
  type(canonical_numerical_config_t),intent(in)::numerical_config
  ok=same_type_as(self,self).and.same_type_as(parameters,parameters).and.numerical_config%max_committed_substeps>0
 end function
 subroutine prepare(self,forcing,interval,config)
  class(ordinary_model_t),intent(inout)::self
  class(canonical_forcing_t),intent(in)::forcing
  type(canonical_interval_t),intent(in)::interval
  type(canonical_numerical_config_t),intent(in)::config
  if(same_type_as(self,self).and.same_type_as(forcing,forcing).and.interval%t1>=interval%t0.and. &
     config%max_committed_substeps>0)error stop 'endpoint must not prepare an interval'
 end subroutine
 subroutine advance(self,state,t0,t1,outcome)
  class(ordinary_model_t),intent(inout)::self
  class(transaction_state_t),intent(inout)::state
  real(real64),intent(in)::t0,t1
  type(trial_outcome_t),intent(out)::outcome
  outcome=trial_outcome_t()
  if(same_type_as(self,self).and.same_type_as(state,state).and.t1>=t0)error stop 'endpoint must not advance'
 end subroutine
 real(real64)function storage(self,state)result(value)
  class(ordinary_model_t),intent(in)::self
  class(transaction_state_t),intent(in)::state
  value=0d0
  select type(state)
  type is(tank_t)
   value=state%amount
  end select
  if(.not.same_type_as(self,self))error stop
 end function
 subroutine storage_status(self,state,complete,missing_mask)
  class(ordinary_model_t),intent(in)::self
  class(transaction_state_t),intent(in)::state
  logical,intent(out)::complete
  integer(int64),intent(out)::missing_mask
  complete=same_type_as(self,self).and.same_type_as(state,state)
  missing_mask=TX_MASS_MISSING_NONE
 end subroutine
 real(real64)function temporal(self,full_state,half_state)result(value)
  class(ordinary_model_t),intent(in)::self
  class(transaction_state_t),intent(in)::full_state,half_state
  value=0d0
  if(same_type_as(self,self).and.same_type_as(full_state,full_state).and.same_type_as(half_state,half_state)) &
   error stop 'endpoint must not assess an interval'
 end function
 logical function admit_event(self,parameters,command,state)result(ok)
  class(event_model_t),intent(in)::self
  class(kernel_parameters_t),intent(in)::parameters
  class(canonical_forcing_t),intent(in)::command
  class(transaction_state_t),intent(in)::state
  ok=.false.
  select type(command)
  type is(command_t)
   ok=same_type_as(self,self).and.same_type_as(parameters,parameters).and.same_type_as(state,state)
  end select
 end function
 subroutine apply_event(self,state,command,time,outcome)
  class(event_model_t),intent(inout)::self
  class(transaction_state_t),intent(inout)::state
  class(canonical_forcing_t),intent(in)::command
  real(real64),intent(in)::time
  type(trial_outcome_t),intent(out)::outcome
  real(real64)::loss
  outcome=trial_outcome_t()
  if(.not.ieee_is_finite(time).or..not.same_type_as(self,self))return
  select type(command)
  type is(command_t)
   if(.not.ieee_is_finite(command%capacity))return
   if(command%capacity<0d0)return
   select type(state)
   type is(tank_t)
    loss=max(0d0,state%amount-command%capacity);state%amount=state%amount-loss
    outcome%mass_out=loss;outcome%solver_ok=.true.
    outcome%mass_accounting_complete=.true.;outcome%missing_mass_contribution_mask=TX_MASS_MISSING_NONE
    select case(command%fault)
    case(1);outcome%mass_out=loss+.125d0
    case(2);outcome%solver_ok=.false.
    case(3);state%layout=2
    case(4);outcome%internal_retries=1
    case(5);outcome%missing_mass_contribution_mask=TX_MASS_MISSING_UNSPECIFIED
    case(6);outcome%mass_out=ieee_value(0d0,ieee_quiet_nan)
    case(7);outcome%mass_out=-1d0
    end select
   end select
  end select
 end subroutine
 subroutine check(ok,label)
  logical,intent(in)::ok
  character(*),intent(in)::label
  if(.not.ok)then
   print *,label;error stop 1
  end if
 end subroutine
 subroutine unchanged(state,value,revision)
  type(kernel_committed_state_t),intent(in)::state
  real(real64),intent(in)::value
  integer(int64),intent(in)::revision
  class(transaction_state_t),allocatable::raw
  logical::ok
  real(real64)::time
  call state%snapshot(raw,ok);call check(ok,'snapshot')
  select type(raw)
  type is(tank_t)
   call check(raw%amount==value.and.raw%layout==1,'immutable origin physical state')
  class default
   error stop
  end select
  call state%current_time(time,ok)
  call check(ok.and.time==930d0.and.state%current_revision()==revision,'immutable time/revision')
 end subroutine
end module
program test_endpoint
 use endpoint_fixture
 implicit none
 type(ordinary_model_t),target::ordinary
 type(event_model_t),target::model
 type(kernel_executor_t)::executor,denied
 type(kernel_committed_state_t)::state,peer,unbound,uncertified
 type(kernel_candidate_state_t)::candidate,stale
 type(kernel_result_t)::result
 type(kernel_diagnostics_t)::diagnostics
 type(parameters_t)::parameters,bad
 type(command_t)::command
 type(foreign_t)::foreign
 type(canonical_numerical_config_t)::config
 class(transaction_state_t),allocatable::seed
 logical::ok
 integer::status,i
 allocate(tank_t::seed)
 call state%initialize(11_int64,seed,ok,930d0,parameters);call check(ok,'certified initialize')
 call peer%initialize(12_int64,seed,ok,930d0,parameters);call check(ok,'peer initialize')
 call unbound%initialize(13_int64,seed,ok,parameters=parameters);call check(ok,'unbound initialize')
 call uncertified%initialize(14_int64,seed,ok,930d0);call check(ok,'uncertified initialize')
 call denied%bind_model(ordinary);call executor%bind_model(model)
 call denied%sample_endpoint_event(parameters,state,command,930d0,config,result,candidate,diagnostics)
 call check(result%status==KERNEL_STATUS_NOT_ADMITTED.and..not.candidate%ready(),'default refusal')
 call executor%sample_endpoint_event(parameters,unbound,command,930d0,config,result,candidate,diagnostics)
 call check(result%status==KERNEL_STATUS_TIME_MISMATCH.and..not.candidate%ready(),'unbound refusal')
 call executor%sample_endpoint_event(parameters,uncertified,command,930d0,config,result,candidate,diagnostics)
 call check(result%status==KERNEL_STATUS_UNGUARDED_STATE.and..not.candidate%ready(),'uncertified refusal')
 call executor%sample_endpoint_event(parameters,state,foreign,930d0,config,result,candidate,diagnostics)
 call check(result%status==KERNEL_STATUS_NOT_ADMITTED.and..not.candidate%ready(),'foreign command refusal')
 call executor%sample_endpoint_event(parameters,state,command,931d0,config,result,candidate,diagnostics)
 call check(result%status==KERNEL_STATUS_TIME_MISMATCH.and..not.candidate%ready(),'wrong time refusal')
 bad%id=8
 call executor%sample_endpoint_event(bad,state,command,930d0,config,result,candidate,diagnostics)
 call check(result%status==KERNEL_STATUS_PARAMETER_MISMATCH.and..not.candidate%ready(),'wrong parameter refusal')
 call executor%sample_endpoint_event(parameters,state,command,930d0,config,result,candidate,diagnostics)
 call check(result%completed.and.result%mass%complete.and.candidate%ready(),'materialized candidate')
 call check(result%mass%total_out==.75d0.and.result%mass%residual==0d0,'certified event mass')
 call unchanged(state,1d0,0_int64)
 stale=candidate
 call executor%commit_candidate(peer,candidate,diagnostics,ok,status)
 call check(.not.ok.and.status==KERNEL_COMMIT_STATUS_LINEAGE_MISMATCH,'wrong lineage refusal')
 call unchanged(peer,1d0,0_int64)
 call executor%commit_candidate(state,candidate,diagnostics,ok,status)
 call check(ok.and.status==0,'event commit');call unchanged(state,.25d0,1_int64)
 call executor%commit_candidate(state,stale,diagnostics,ok,status)
 call check(.not.ok.and.status==KERNEL_COMMIT_STATUS_STALE_REVISION,'stale event refusal')
 call executor%rollback_candidate(stale,diagnostics);call check(.not.stale%ready(),'rollback consumes candidate')
 do i=1,7
  command%capacity=.1d0;command%fault=i
  call executor%sample_endpoint_event(parameters,state,command,930d0,config,result,candidate,diagnostics)
  call check(.not.result%completed.and..not.candidate%ready(),'invalid event never publishes')
  call unchanged(state,.25d0,1_int64)
 end do
 command%fault=0;command%capacity=-1d0
 call executor%sample_endpoint_event(parameters,state,command,930d0,config,result,candidate,diagnostics)
 call check(.not.result%completed.and..not.candidate%ready(),'negative capacity refuses')
 command%capacity=ieee_value(0d0,ieee_quiet_nan)
 call executor%sample_endpoint_event(parameters,state,command,930d0,config,result,candidate,diagnostics)
 call check(.not.result%completed.and..not.candidate%ready(),'NaN capacity refuses')
 command%capacity=.25d0
 call executor%sample_endpoint_event(parameters,state,command,930d0,config,result,candidate,diagnostics)
 call check(result%completed.and.result%mass%total_out==0d0,'repeated capacity no duplicate export')
 call executor%rollback_candidate(candidate,diagnostics)
 call unchanged(state,.25d0,1_int64)
 print '(a)','ACTUAL_KERNEL_ENDPOINT_EVENT_MASS_PROVENANCE_DEFAULT_REFUSAL_ROLLBACK_PASS'
end program
