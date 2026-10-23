program reactive_fct_process
 use iso_fortran_env,only:real64
 use mod_research_composed_fct
 use mod_research_storage_fct
 use mod_b111_reactive_solute_substep
 use mod_solute_mobile_salt_state
 use mod_solute_compartment_state
 implicit none
 integer,parameter::n=16
 type(mobile_salt_state_t)::m,old,next,plain,delegate,off
 type(solute_compartment_state_t)::s,old_s,next_s,plain_s,delegate_s,off_s
 type(b111_reactive_solute_substep_forcing_t)::f,bad
 type(b111_reactive_solute_substep_receipt_t)::r,rp,rd,ro
 real(real64)::initial(n),before(n),exponent,dt,pi,inmass,outmass,decayed,startmass,l1,corrections,worst
 real(real64),allocatable::delta(:)
 integer::mode,steps,k,i,code
 character(64)::arg
 call get_command_argument(1,arg);read(arg,*)mode
 call get_command_argument(2,arg);read(arg,*)exponent
 call get_command_argument(3,arg);read(arg,*)steps
 pi=acos(-1d0);dt=1d0/steps
 f%transport_scheme=B111_TRANSPORT_IMPLICIT_UPWIND;f%dt_day=dt
 f%theta=spread(.3d0,1,n);f%theta_previous=f%theta;f%dz_cm=spread(1d0,1,n)
 f%q_face_up_cm_day=spread(0d0,1,n+1);f%root_sink_cm_day=0d0*f%theta;allocate(f%qdra_cm_day(0,n))
 f%temperature_active=.true.;f%temperature_c=20d0+0d0*f%theta;f%gampar=0d0*f%theta
 f%rtheta=.3d0+0d0*f%theta;f%bexp=1d0+0d0*f%theta;f%decpot=0d0*f%theta;f%fdepth=1d0+0d0*f%theta
 f%bulk_density=1.3d0+0d0*f%theta;f%kf=.2d0+0d0*f%theta;f%frexp=exponent
 f%face_distance_cm=spread(1d0,1,n-1);f%face_left_weight=spread(.5d0,1,n-1)
 f%face_right_weight=f%face_left_weight;f%theta_sat_left=spread(.423d0,1,n-1)
 f%dispersivity_cm=spread(0d0,1,n-1);f%rain_c_mg_cm3=.05d0
 do i=1,n
  initial(i)=.05d0+exp(-.5d0*((i-.5d0)-8d0)**2)
 end do
 if(mode==1)then
  f%molecular_diffusion_cm2_day=.2d0;f%decpot=.1d0
  initial=[(.5d0+.2d0*cos(pi*(i-.5d0)/n),i=1,n)]
 else
  f%q_face_up_cm_day=-.15d0;f%rain_rate_cm_day=.15d0
  if(mode==2)then
   f%molecular_diffusion_cm2_day=.2d0;f%dispersivity_cm=.25d0;f%decpot=.1d0
  end if
 end if
 call initialize_mobile_salt_state(f%dz_cm,f%theta,initial,m,code)
 if(code/=SOLUTE_OK)error stop 'process mobile'
 call initialize_solute_compartment_state(.26d0*initial**exponent,0d0,0d0,0d0*f%theta,s,code)
 if(code/=SOLCOMP_OK)error stop 'process companion'
 startmass=sum(m%mass_mg_cm2)+s%solute_total();inmass=0d0;outmass=0d0;decayed=0d0;corrections=0d0;worst=0d0
 do k=1,steps
  before=m%concentration_mg_cm3;old=m;old_s=s
  call advance_research_composed_fct(m,s,f,.false.,off,off_s,ro)
  call advance_b111_reactive_solute_substep(m,s,f,plain,plain_s,rp,exact_empty_pond_limit=.true.)
  if(ro%status/=0.or.rp%status/=0)error stop 'off solve'
  call same(off,off_s,plain,plain_s)
  if(ro%external_output_mg_cm2/=rp%external_output_mg_cm2.or.ro%decay_output_mg_cm2/=rp%decay_output_mg_cm2)error stop 'off ledger'
  call advance_research_composed_fct(m,s,f,.true.,next,next_s,r,l1,delta)
  if(r%status/=0)then
   print *,'PROCESS_FAILED',mode,exponent,k,r%status;error stop 'process solve'
  end if
  if(mode==0)then
   call advance_research_storage_fct(m,s,f,.true.,delegate,delegate_s,rd)
   if(rd%status/=0)error stop 'delegate solve'
   call same(next,next_s,delegate,delegate_s)
   if(r%external_output_mg_cm2/=rd%external_output_mg_cm2)error stop 'delegate ledger'
  end if
  bad=f;bad%decpot(1)=-.01d0
  call advance_research_composed_fct(m,s,bad,.true.,delegate,delegate_s,rd)
  if(rd%status==0)error stop 'negative rate accepted'
  call same(m,s,delegate,delegate_s);call same(old,old_s,m,s)
  m=next;s=next_s;inmass=inmass+r%external_input_mg_cm2;outmass=outmass+r%external_output_mg_cm2
  decayed=decayed+r%decay_output_mg_cm2;corrections=corrections+l1;worst=max(worst,abs(r%balance_residual_mg_cm2))
 end do
 if(mode==2.and.corrections<=1d-8)error stop 'correction never active'
 if(mode>0.and.decayed<=0d0)error stop 'decay never active'
 print '(A,1X,2(I0,1X),2(ES25.16E3,1X))','PROCESS_PASS',mode,steps,exponent,dt
 print '(A,1X,6(ES25.16E3,1X))','BUDGET',startmass,inmass,outmass,decayed,corrections,worst
 do i=1,n
  print '(A,1X,I0,1X,5(ES25.16E3,1X))','CELL',i,before(i),m%concentration_mg_cm3(i),m%mass_mg_cm2(i),s%sorbed_matrix_mass(i),delta(i)
 end do
 print '(A)','EXACT_OFF_ZERO_PROCESS_DELEGATION_AND_NEGATIVE_RATE_REJECTION_PASS'
contains
 subroutine same(a,b,c,d)
  type(mobile_salt_state_t),intent(in)::a,c
  type(solute_compartment_state_t),intent(in)::b,d
  if(any(a%mass_mg_cm2/=c%mass_mg_cm2).or.any(a%concentration_mg_cm3/=c%concentration_mg_cm3).or. &
   any(b%sorbed_matrix_mass/=d%sorbed_matrix_mass))error stop 'process atomic drift'
 end subroutine
end program
