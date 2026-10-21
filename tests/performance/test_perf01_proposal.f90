module perf01_proposal_fixture
  use iso_fortran_env, only: real64
  use mod_low_air_policy_oracle
  use mod_transaction_reference, only: transaction_state_t, trial_outcome_t
  implicit none
  type, extends(fci04_model_t) :: rejecting_model_t
    real(real64) :: step_limit=huge(1.0_real64), fail_after=huge(1.0_real64), last_t1=-1.0_real64
  contains
    procedure :: advance => controlled_advance
  end type
contains
  subroutine controlled_advance(self,state,t0,t1,outcome)
    class(rejecting_model_t),intent(inout)::self
    class(transaction_state_t),intent(inout)::state
    real(real64),intent(in)::t0,t1
    type(trial_outcome_t),intent(out)::outcome
    call self%fci04_model_t%advance(state,t0,t1,outcome)
    self%last_t1=t1
    ! Mutate the candidate before rejecting, to expose leaked rejected state.
    if(t1-t0>self%step_limit.or.t0>=self%fail_after)outcome%solver_ok=.false.
  end subroutine
end module

program test_perf01_proposal
  use iso_fortran_env,only:real64
  use mod_transaction_reference,only:transaction_state_t,TX_TEMPORAL_EXTERNAL_FULL_HALF
  use mod_canonical_contracts
  use mod_canonical_interval_runtime
  use perf01_proposal_fixture
  implicit none
  class(transaction_state_t),allocatable::a,b
  type(rejecting_model_t)::ma,mb
  type(fci04_forcing_t)::forcing
  type(canonical_interval_t)::interval
  type(canonical_numerical_config_t)::cfg
  type(canonical_result_t)::ra,rb
  real(real64)::wa,wb
  interval%t0=0.0_real64;interval%t1=1.0_real64
  cfg%transaction%temporal_mode=TX_TEMPORAL_EXTERNAL_FULL_HALF
  cfg%transaction%temporal_tolerance=1.e-3_real64
  cfg%transaction%mass_tolerance=1.e-13_real64
  cfg%transaction%max_retries=30;cfg%transaction%retry_scale=.5_real64
  cfg%max_committed_substeps=100000
  call initial(a);call initial(b)
  ma%step_limit=.125_real64;mb%step_limit=.125_real64
  call run_canonical_interval(ma,a,forcing,interval,cfg,ra)
  cfg%retain_accepted_step_proposal=.true.
  call run_canonical_interval(mb,b,forcing,interval,cfg,rb)
  call require(ra%completed.and.rb%completed,'both limited routes complete')
  call require(rb%diagnostics%solver_rejections>0,'actual solver rejection exercised')
  call require(ra%diagnostics%attempts==rb%diagnostics%attempts,'fallback uses incumbent attempts')
  wa=water(a);wb=water(b)
  call require(wa==wb.and.abs(wb-exp(-1.0_real64))<.02_real64,'fallback physical analytic oracle')

  ! The proposal memory must reset even when the model instance is reused.
  call initial(a);call initial(b)
  ma=rejecting_model_t();mb%step_limit=huge(1.0_real64)
  cfg%transaction%temporal_tolerance=1.e-6_real64
  call run_canonical_interval(ma,a,forcing,interval,cfg,ra)
  call run_canonical_interval(mb,b,forcing,interval,cfg,rb)
  call require(ra%completed.and.rb%completed,'reset routes complete')
  call require(ra%diagnostics%attempts==rb%diagnostics%attempts.and.water(a)==water(b),'interval-local reset')

  ! Even a large progress tolerance cannot publish a shortened optional route.
  ! First full trial fails, then a half interval is accepted before fallback.
  call initial(b);mb=rejecting_model_t();mb%step_limit=.5_real64
  forcing%k=0.0_real64;cfg%progress_tolerance=.6_real64
  call run_canonical_interval(mb,b,forcing,interval,cfg,rb)
  call require(rb%completed.and.rb%completed_t==1.0_real64.and.mb%last_t1==1.0_real64,'exact endpoint after fallback')
  call require(rb%diagnostics%committed_substeps==2,'near-endpoint is not relabelled')
  cfg%retain_accepted_step_proposal=.false.;call initial(a);ma=rejecting_model_t();ma%step_limit=.5_real64
  call run_canonical_interval(ma,a,forcing,interval,cfg,ra)
  call require(ra%completed.and.ra%completed_t==.5_real64,'incumbent OFF completion semantics preserved')

  cfg%retain_accepted_step_proposal=.true.;cfg%progress_tolerance=0.0_real64
  cfg%transaction%temporal_tolerance=1.0_real64
  forcing%k=1.0_real64
  ! Exhaust retries after a genuinely accepted private first half interval.
  call initial(b);mb=rejecting_model_t();mb%step_limit=.5_real64;mb%fail_after=.5_real64
  call run_canonical_interval(mb,b,forcing,interval,cfg,rb)
  call require(rb%status==CANONICAL_STATUS_TRANSACTION_FAILED.and.rb%completed_t==.5_real64,'late solver failure')
  call require(water(b)==1.0_real64.and.rb%diagnostics%external_commits==0,'late rejected candidate atomicity')
  call initial(b);mb=rejecting_model_t();mb%inject_mass_defect=.true.;mb%mass_defect=.001_real64
  call run_canonical_interval(mb,b,forcing,interval,cfg,rb)
  call require(.not.rb%completed.and.water(b)==1.0_real64.and.rb%diagnostics%mass_rejections>0,'hard mass atomicity')
  call initial(b);mb=rejecting_model_t();mb%step_limit=.5_real64;cfg%max_committed_substeps=1
  call run_canonical_interval(mb,b,forcing,interval,cfg,rb)
  call require(rb%status==CANONICAL_STATUS_SUBSTEP_LIMIT.and.water(b)==1.0_real64,'substep exhaustion atomicity')
  print '(A)','PROPOSAL_EXACT_FALLBACK_ATOMIC_RESET=PASS'
contains
  subroutine initial(s)
    class(transaction_state_t),allocatable,intent(inout)::s
    if(allocated(s))deallocate(s)
    allocate(fci04_state_t::s)
    select type(s);type is(fci04_state_t);s%water=1.0_real64;end select
  end subroutine
  real(real64)function water(s)result(value)
    class(transaction_state_t),intent(in)::s
    value=-1.0_real64
    select type(s);type is(fci04_state_t);value=s%water;end select
  end function
  subroutine require(ok,label)
    logical,intent(in)::ok
    character(*),intent(in)::label
    if(.not.ok)then
      print *,label
      error stop 1
    end if
  end subroutine
end program
