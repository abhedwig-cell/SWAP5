program test_low_air_step_policy
 use iso_fortran_env,only:real64
 use mod_low_air_policy_oracle
 use mod_transaction_reference,only:transaction_state_t,TX_TEMPORAL_EXTERNAL_FULL_HALF,TX_TEMPORAL_MODEL_CERTIFICATE
 use mod_canonical_contracts
 use mod_canonical_interval_runtime
 implicit none
 class(transaction_state_t),allocatable::a,b,replay
 type(fci04_model_t)::ma,mb,mr
 type(fci04_forcing_t)::forcing
 type(canonical_interval_t)::interval
 type(canonical_numerical_config_t)::cfg
 type(canonical_result_t)::ra,rb,rr
 real(real64)::wa,wb,wrep
 integer::i
 interval%t0=0._real64;interval%t1=1._real64
 cfg%transaction%temporal_mode=TX_TEMPORAL_EXTERNAL_FULL_HALF
 cfg%transaction%temporal_tolerance=1.e-8_real64
 cfg%transaction%mass_tolerance=1.e-13_real64
 cfg%transaction%max_retries=20
 cfg%transaction%retry_scale=.5_real64
 cfg%max_committed_substeps=100000
 allocate(fci04_state_t::a,b,replay)
 select type(a);type is(fci04_state_t);a%water=1._real64;end select
 select type(b);type is(fci04_state_t);b%water=1._real64;end select
 select type(replay);type is(fci04_state_t);replay%water=1._real64;end select
 call run_canonical_interval(ma,a,forcing,interval,cfg,ra)
 cfg%retain_accepted_step_proposal=.true.
 call run_canonical_interval(mb,b,forcing,interval,cfg,rb)
 call run_canonical_interval(mr,replay,forcing,interval,cfg,rr)
 select type(a);type is(fci04_state_t);wa=a%water;end select
 select type(b);type is(fci04_state_t);wb=b%water;end select
 select type(replay);type is(fci04_state_t);wrep=replay%water;end select
 call require(ra%completed.and.rb%completed.and.rr%completed,'complete intervals')
 call require(ra%mass%complete.and.rb%mass%complete,'complete hard mass')
 call require(abs(rb%mass%residual)<=1.e-13_real64,'mass unchanged')
 ! Independent analytical ODE solution, not a duplicate controller calculation.
 call require(abs(wa-exp(-1._real64))<1.e-4_real64.and.abs(wb-exp(-1._real64))<1.e-4_real64,'analytic decay oracle')
 call require(wb==wrep.and.rb%diagnostics%attempts==rr%diagnostics%attempts,'deterministic replay')
 call require(rb%diagnostics%attempts*5<ra%diagnostics%attempts,'retry explosion reduced')
 print *, 'POLICY_ATTEMPTS',ra%diagnostics%attempts,rb%diagnostics%attempts
 ! Incomplete and rejected requests leave externally accepted state unchanged.
 do i=1,3
  select type(b);type is(fci04_state_t);b%water=1._real64;end select
  cfg%max_committed_substeps=100000;cfg%transaction%temporal_mode=TX_TEMPORAL_EXTERNAL_FULL_HALF
  mb%inject_mass_defect=.false.
  if(i==1)cfg%max_committed_substeps=1
  if(i==2)then
   mb%inject_mass_defect=.true.;mb%mass_defect=1.e-3_real64
  end if
  if(i==3)cfg%transaction%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE
  call run_canonical_interval(mb,b,forcing,interval,cfg,rb)
  call require(.not.rb%completed.and.rb%diagnostics%external_commits==0,'failure is externally atomic')
  select type(b);type is(fci04_state_t);call require(b%water==1._real64,'failed candidate rollback');end select
 end do
 cfg%transaction%temporal_mode=TX_TEMPORAL_EXTERNAL_FULL_HALF
 mb%inject_mass_defect=.false.
 call run_canonical_interval(mb,b,forcing,interval,cfg,rb,selector)
 call require(rb%status==CANONICAL_STATUS_INVALID_REQUEST,'external selector fails closed')
 cfg%transaction%temporal_tolerance=1.e300_real64
 mb%extreme_indicator=.true.
 call run_canonical_interval(mb,b,forcing,interval,cfg,rb)
 call require(rb%completed.and.rb%mass%complete,'finite clamped proposal for extreme indicator ratio')
 print '(A)','LOW_AIR_STEP_POLICY_CONTRACT=PASS'
contains
 subroutine require(ok,label)
  logical,intent(in)::ok
  character(*),intent(in)::label
  if(.not.ok)then
   print *,label
   error stop 1
  end if
 end subroutine
 subroutine selector(cursor,requested_t1,target_t1,max_retries_cap,valid)
  real(real64),intent(in)::cursor,requested_t1
  real(real64),intent(out)::target_t1
  integer,intent(out)::max_retries_cap
  logical,intent(out)::valid
  target_t1=requested_t1;max_retries_cap=20;valid=.true.
 end subroutine
end program
