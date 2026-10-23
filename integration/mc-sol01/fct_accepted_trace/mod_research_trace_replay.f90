module mod_research_trace_replay
 use iso_fortran_env,only:real64
 use mod_solute_mobile_salt_state
 use mod_solute_compartment_state
 use mod_b111_reactive_solute_substep
 use mod_research_storage_fct
 implicit none
 private
 public::consume_research_trace
contains
 subroutine consume_research_trace(m,s,clock,water,t0,t1,forcing,enabled,next,next_s,next_clock,next_water,status,completed,ledger)
  type(mobile_salt_state_t),intent(in)::m
  type(solute_compartment_state_t),intent(in)::s
  real(real64),intent(in)::clock,water(:),t0(:),t1(:)
  type(b111_reactive_solute_substep_forcing_t),intent(in)::forcing(:)
  logical,intent(in)::enabled
  type(mobile_salt_state_t),intent(out)::next
  type(solute_compartment_state_t),intent(out)::next_s
  real(real64),intent(out)::next_clock
  real(real64),allocatable,intent(out)::next_water(:)
  integer,intent(out)::status,completed
  real(real64),intent(out)::ledger(4)
  type(mobile_salt_state_t)::work,candidate
  type(solute_compartment_state_t)::work_s,candidate_s
  type(b111_reactive_solute_substep_receipt_t)::r
  real(real64),allocatable::w(:)
  real(real64)::t,account(4)
  integer::i
  next=m;next_s=s;next_clock=clock;next_water=water;status=100;completed=0;ledger=0d0
  if(size(t0)/=size(t1).or.size(t0)/=size(forcing).or.size(t0)==0)return
  work=m;work_s=s;t=clock;w=water;account=0d0
  do i=1,size(forcing)
   if(t0(i)/=t.or.t1(i)<=t0(i))return
   if(.not.allocated(forcing(i)%theta_previous))return
   if(size(forcing(i)%theta_previous)/=size(w))return
   if(any(forcing(i)%theta_previous/=w).or.forcing(i)%dt_day/=t1(i)-t0(i))return
   call advance_research_storage_fct(work,work_s,forcing(i),enabled,candidate,candidate_s,r)
   if(r%status/=B111_REACTIVE_OK)then
    status=r%status;return
   end if
   account(1)=account(1)+r%external_input_mg_cm2;account(2)=account(2)+r%external_output_mg_cm2
   account(3)=max(account(3),abs(r%balance_residual_mg_cm2))
   work=candidate;work_s=candidate_s;t=t1(i);w=forcing(i)%theta;completed=i
  end do
  account(4)=sum(work%mass_mg_cm2)+work_s%solute_total()-sum(m%mass_mg_cm2)-s%solute_total()-account(1)+account(2)
  if(abs(account(4))>8192d0*epsilon(1d0)*max(1d0,sum(m%mass_mg_cm2)+s%solute_total()))then
   status=B111_REACTIVE_BALANCE;return
  end if
  next=work;next_s=work_s;next_clock=t;next_water=w;ledger=account;status=0
 end subroutine
end module
