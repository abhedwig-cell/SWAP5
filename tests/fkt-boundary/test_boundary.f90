program test_boundary
 use iso_fortran_env,only:real64,int64
 use ieee_arithmetic,only:ieee_value,ieee_quiet_nan,ieee_positive_inf
 use mod_transaction_reference,only:transaction_state_t
 use mod_kernel_transactions
 use mod_boundary_fixture
 implicit none
 type(kernel_committed_state_t)::state,copy,unbound
 type(kernel_boundary_executor_t)::executor,other,empty
 type(kernel_boundary_candidate_t)::candidate,sibling,invalid
 type(kernel_boundary_request_t)::request,bad
 type(kernel_boundary_balance_t)::balance
 type(event_model_t),target::model,second
 type(event_parameters_t)::parameters,wrong
 type(event_forcing_t)::forcing,changed
 type(kernel_parameter_identity_t)::identity
 class(transaction_state_t),allocatable::initial,snapshot
 real(real64)::time
 integer::status,i,checks
 logical::ok
 checks=0
 allocate(event_state_t::initial)
 call state%initialize(9_int64,initial,ok,4d0,parameters)
 call require(ok,'certified initial state');copy=state
 request=kernel_boundary_request_t(9_int64,0_int64,101_int64,7_int64,1,4d0)
 call executor%bind_model(model);call other%bind_model(second)
 call empty%prepare_event(parameters,forcing,state,request,0d0,candidate,status)
 call require(status==KERNEL_BOUNDARY_NOT_BOUND.and..not.candidate%ready(),'unbound executor')
 call unbound%initialize(9_int64,initial,ok,parameters=parameters)
 call executor%prepare_event(parameters,forcing,unbound,request,0d0,candidate,status)
 call require(status==KERNEL_BOUNDARY_ORIGIN_MISMATCH,'unbound physical clock')
 do i=1,8
  bad=request
  select case(i)
  case(1);bad%lineage=10_int64
  case(2);bad%revision=1_int64
  case(3);bad%time=5d0
  case(4);bad%event_id=0_int64
  case(5);bad%subject_id=0_int64
  case(6);bad%phase=0
  case(7);bad%time=ieee_value(0d0,ieee_quiet_nan)
  case(8);bad%time=ieee_value(0d0,ieee_positive_inf)
  end select
  call executor%prepare_event(parameters,forcing,state,bad,0d0,candidate,status)
  call require(status/=0.and..not.candidate%ready(),'invalid origin/request')
  call unchanged(state,0_int64,10d0)
 end do
 model%admitted=.false.
 call executor%prepare_event(parameters,forcing,state,request,0d0,candidate,status)
 call require(status==KERNEL_BOUNDARY_NOT_ADMITTED,'explicit owner admission')
 model%admitted=.true.
 do i=1,7
  model%fault=i
  call executor%prepare_event(parameters,forcing,state,request,0d0,candidate,status)
  call require(status/=0.and..not.candidate%ready(),'bad physical/balance proposal')
  call unchanged(state,0_int64,10d0)
 end do
 model%fault=0;model%reject_stage=.true.
 call executor%prepare_event(parameters,forcing,state,request,0d0,candidate,status)
 call require(status==KERNEL_BOUNDARY_MODEL_REJECTED,'rejected staging')
 model%reject_stage=.false.
 wrong%grid_id=18_int64
 call executor%prepare_event(wrong,forcing,state,request,0d0,candidate,status)
 call require(status==KERNEL_BOUNDARY_IDENTITY_FAILED,'foreign grid')
 call executor%prepare_event(parameters,forcing,state,request,-1d0,candidate,status)
 call require(status==KERNEL_BOUNDARY_INVALID,'negative tolerance')
 call executor%prepare_event(parameters,forcing,state,request,ieee_value(0d0,ieee_quiet_nan),candidate,status)
 call require(status==KERNEL_BOUNDARY_INVALID,'nonfinite tolerance')
 call executor%prepare_event(parameters,forcing,state,request,0d0,candidate,status)
 call require(status==0.and.candidate%ready(),'valid proposal');call unchanged(state,0_int64,10d0)
 sibling=candidate
 call other%commit_event(parameters,forcing,state,candidate,status)
 call require(status==KERNEL_BOUNDARY_OWNER_MISMATCH.and.candidate%ready(),'foreign executor')
 call executor%commit_event(wrong,forcing,state,candidate,status)
 call require(status==KERNEL_BOUNDARY_IDENTITY_FAILED.and.candidate%ready(),'changed certificate')
 changed%export_n=3d0
 call executor%commit_event(parameters,changed,state,candidate,status)
 call require(status/=0.and.candidate%ready(),'changed forcing')
 model%reject_validate=.true.
 call executor%commit_event(parameters,forcing,state,candidate,status)
 call require(status==KERNEL_BOUNDARY_MODEL_REJECTED.and.candidate%ready(),'late owner rejection')
 call unchanged(state,0_int64,10d0);model%reject_validate=.false.
 call executor%discard_event(candidate)
 call require(.not.candidate%ready(),'explicit discard');call unchanged(state,0_int64,10d0)
 call executor%prepare_event(parameters,forcing,state,request,0d0,candidate,status)
 call require(status==0,'retry')
 call executor%commit_event(parameters,forcing,state,candidate,status)
 call require(status==0.and..not.candidate%ready(),'single atomic publication')
 call unchanged(state,1_int64,8d0)
 call state%certified_parameter_identity(identity,ok)
 call require(ok.and.identity%parameter_set_id==17_int64,'original grid identity retained')
 call executor%commit_event(parameters,forcing,state,sibling,status)
 call require(status==KERNEL_BOUNDARY_STALE.and.sibling%ready(),'stale sibling')
 call executor%commit_event(parameters,forcing,state,candidate,status)
 call require(status==KERNEL_BOUNDARY_INVALID,'consumed candidate')
 call executor%prepare_event(parameters,forcing,state,request,0d0,candidate,status)
 call require(status==KERNEL_BOUNDARY_ORIGIN_MISMATCH,'old request replay')
 request%revision=1_int64
 call executor%prepare_event(parameters,forcing,state,request,0d0,candidate,status)
 call require(status==KERNEL_BOUNDARY_MODEL_REJECTED,'same event cannot mint a fresh revision')
 call unchanged(state,1_int64,8d0);call unchanged(copy,0_int64,10d0)
 request%event_id=102_int64
 call executor%prepare_event(parameters,forcing,state,request,0d0,candidate,status)
 call require(status==0,'next distinct event')
 call executor%commit_event(parameters,forcing,state,candidate,status)
 call require(status==0,'next publication');call unchanged(state,2_int64,6d0)
 balance%complete=.true.;balance%count=2;balance%quantity_id=[1,1,0,0]
 call require(.not.balance%valid(0d0),'duplicate quantity identities')
 balance%count=1;balance%quantity_id=[1,0,0,0];balance%before(4)=1d0
 call require(.not.balance%valid(0d0),'unreported balance tail')
 balance%before=0d0;balance%before(1)=ieee_value(0d0,ieee_quiet_nan)
 call require(.not.balance%valid(0d0),'nonfinite balance')
 balance%before=0d0;balance%external_out(1)=-1d0
 call require(.not.balance%valid(0d0),'negative export')
 print '(A,I0)','KERNEL_BOUNDARY_SYNTHETIC_ASSERTIONS=',checks
 print '(A)','KERNEL_BOUNDARY_TRANSACTION_CONTRACT=PASS'
contains
 subroutine require(condition,label)
  logical,intent(in)::condition
  character(*),intent(in)::label
  if(.not.condition)then;print *,'FAIL ',label;error stop 1;end if
  checks=checks+1
 end subroutine
 subroutine unchanged(s,revision,nitrogen)
  type(kernel_committed_state_t),intent(in)::s
  integer(int64),intent(in)::revision
  real(real64),intent(in)::nitrogen
  call s%current_time(time,ok)
  call require(ok.and.time==4d0.and.s%current_lineage_id()==9_int64,'physical clock/lineage retained')
  call require(s%current_revision()==revision,'biological revision')
  call s%snapshot(snapshot,ok);call require(ok,'state snapshot')
  select type(snapshot)
  type is(event_state_t)
   call require(snapshot%nitrogen==nitrogen.and.snapshot%water==30d0.and. &
    all(snapshot%history==[1d0,2d0]),'complete physical state')
  class default
   error stop 'wrong physical type'
  end select
 end subroutine
end program
