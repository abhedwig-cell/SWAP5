program test_age_process
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
 use mod_solute_compartment_state
 use mod_b111_age_tracer_substep
 use historical_age_oracle
 implicit none
 type(b111_age_tracer_substep_forcing_t)::f,g
 type(solute_compartment_state_t)::s,c
 type(b111_age_tracer_substep_receipt_t)::r
 real(real64)::density(3),age(3),before(3),expected(3),production,root,drain,bottom
 integer::code,j,direction,step
 f%dz_cm=[2d0,3d0,5d0];f%theta_previous=[.25d0,.3d0,.35d0];f%theta=f%theta_previous
 f%dt_day=.001d0;f%root_sink_cm_day=[.001d0,.002d0,.003d0]
 f%qdra_cm_day=reshape([.001d0,-.002d0,.003d0,-.001d0,.002d0,-.003d0],[2,3])
 f%face_left_weight=[.6d0,.625d0];f%face_right_weight=1d0-f%face_left_weight
 f%face_distance_cm=[2.5d0,4d0];f%theta_sat_left=[.45d0,.45d0];f%dispersivity_cm=[.2d0,.3d0]
 f%molecular_diffusion_cm2_day=.05d0;f%drain_age_day=42d0
 do direction=-1,1
  age=[1d0,10d0,100d0]
  call initialize_solute_compartment_state([.1d0,.2d0,.3d0],.4d0,.5d0,age*f%theta*f%dz_cm,s,code)
  do step=1,50
   f%q_face_up_cm_day=[0d0,.1d0*direction,-.05d0*direction,.2d0*direction]
   f%theta_previous=f%theta
   ! Exact water continuity for all three nodes with signed lateral exchange.
   do j=1,3
    f%theta(j)=f%theta_previous(j)+(f%q_face_up_cm_day(j+1)-f%q_face_up_cm_day(j)- &
      f%root_sink_cm_day(j)-sum(f%qdra_cm_day(:,j)))*f%dt_day/f%dz_cm(j)
   end do
   before=s%age_amount;density=before/f%dz_cm;age=density/f%theta_previous
   call literal_age_step(f,age,density,production,root,drain,bottom)
   expected=density*f%dz_cm
   call advance_b111_age_tracer_substep(s,f,c,r)
   call require(r%status==B111_AGE_SUBSTEP_OK,'process accepts conservative input')
   call require(maxval(abs(c%age_amount-expected))<1d-11,'literal unchanged B1.11 loop endpoint')
   call require(abs(r%production_amount_cm_day-production)<1d-12,'trapezoidal water-age production')
   call require(abs(r%root_export_cm_day-root)<1d-12,'root age no chemical TSCF')
   call require(abs(r%drain_export_cm_day-r%drain_input_cm_day-drain)<1d-12,'signed drainage receipt')
   call require(abs(r%bottom_input_cm_day-r%bottom_export_cm_day-bottom)<1d-12,'signed lower boundary')
   call require(abs(r%balance_residual_cm_day)<1d-11,'total age production-transfer balance')
   call require(all(s%age_amount==before),'input does not mutate')
   call require(c%solute_total()==s%solute_total(),'age never changes chemical mass')
   s=c
  end do
 end do
 ! Quiescent water ages exactly one elapsed day, independent of layer thickness.
 f%dt_day=1d0;f%q_face_up_cm_day=0d0;f%root_sink_cm_day=0d0;f%qdra_cm_day=0d0
 f%molecular_diffusion_cm2_day=0d0;f%dispersivity_cm=0d0;f%theta_previous=f%theta
 s%age_amount=0d0
 call advance_b111_age_tracer_substep(s,f,c,r)
 call require(r%status==0,'zero age allowed')
 call require(maxval(abs(c%age_amount/(f%theta*f%dz_cm)-1d0))<1d-14,'cm day divided by cm equals day')
 before=s%age_amount
 do j=1,12
  g=f
  select case(j)
  case(1);g%dt_day=0d0
  case(2);g%dt_day=ieee_value(0d0,ieee_quiet_nan)
  case(3);g%theta(1)=0d0
  case(4);g%theta_previous(1)=-1d0
  case(5);g%dz_cm(1)=0d0
  case(6);g%root_sink_cm_day(1)=-1d0
  case(7);g%q_face_up_cm_day(1)=.1d0
  case(8);g%drain_age_day=-1d0
  case(9);g%face_left_weight(1)=.1d0
  case(10);g%qdra_cm_day=reshape([0d0],[1,1])
  case(11);g%q_face_up_cm_day(2)=ieee_value(0d0,ieee_quiet_nan)
  case(12);g%rain_rate_cm_day=.1d0
  end select
  call advance_b111_age_tracer_substep(s,g,c,r)
  call require(r%status/=0,'invalid process inputs reject')
  call require(all(c%age_amount==before),'invalid candidate restores input')
 end do
 s%age_amount=[1d0,0d0,0d0];g=f;g%root_sink_cm_day(1)=100d0
 call advance_b111_age_tracer_substep(s,g,c,r)
 call require(r%status==B111_AGE_SUBSTEP_NEGATIVE,'physical overdraw rejects without clipping')
 call require(all(c%age_amount==s%age_amount),'overdraw restores entire candidate')
 g%dt_day=1d-6
 call advance_b111_age_tracer_substep(s,g,c,r)
 call require(r%status==0,'smaller process retry succeeds')
 print '(A)','AGE_LITERAL_150_STEPS_PRODUCTION_UNITS_BALANCE_INVALID_RETRY=PASS'
contains
 subroutine require(ok,label)
  logical,intent(in)::ok
  character(*),intent(in)::label
  if(.not.ok)then
   print *,label
   error stop 1
  end if
 end subroutine
end program
