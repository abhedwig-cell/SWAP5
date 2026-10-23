program sink_fct_process
 use iso_fortran_env,only:real64
 use mod_research_sink_fct
 use mod_research_composed_fct
 use mod_b111_reactive_solute_substep
 use mod_solute_mobile_salt_state
 use mod_solute_compartment_state
 implicit none
 integer,parameter::n=16
 type(mobile_salt_state_t)::m,old,next,plain,test
 type(solute_compartment_state_t)::s,old_s,next_s,plain_s,test_s
 type(b111_reactive_solute_substep_forcing_t)::f,bad,zero
 type(b111_reactive_solute_substep_receipt_t)::r,rp,rt
 real(real64)::initial(n),before(n),exponent,uptake,dt,startmass,l1,corrections,worst,account(5)
 real(real64),allocatable::delta(:)
 integer::mode,kind,steps,k,i,j,code
 character(64)::arg
 call get_command_argument(1,arg);read(arg,*)mode
 call get_command_argument(2,arg);read(arg,*)exponent
 call get_command_argument(3,arg);read(arg,*)uptake
 call get_command_argument(4,arg);read(arg,*)kind
 call get_command_argument(5,arg);read(arg,*)steps
 dt=1d0/steps
 f%transport_scheme=B111_TRANSPORT_IMPLICIT_UPWIND;f%dt_day=dt;f%tscf=uptake
 f%theta=spread(.3d0,1,n);f%theta_previous=f%theta;f%dz_cm=spread(1d0,1,n)
 f%q_face_up_cm_day=spread(0d0,1,n+1);f%root_sink_cm_day=0d0*f%theta;allocate(f%qdra_cm_day(2,n));f%qdra_cm_day=0d0
 if(kind/=2)f%root_sink_cm_day=.02d0
 if(kind/=1)then
  f%qdra_cm_day(1,:)=.006d0;f%qdra_cm_day(2,:)=.004d0
 end if
 f%temperature_active=.true.;f%temperature_c=20d0+0d0*f%theta;f%gampar=0d0*f%theta
 f%rtheta=.3d0+0d0*f%theta;f%bexp=1d0+0d0*f%theta;f%decpot=0d0*f%theta;f%fdepth=1d0+0d0*f%theta
 f%bulk_density=1.3d0+0d0*f%theta;f%kf=.2d0+0d0*f%theta;f%frexp=exponent
 f%face_distance_cm=spread(1d0,1,n-1);f%face_left_weight=spread(.5d0,1,n-1)
 f%face_right_weight=f%face_left_weight;f%theta_sat_left=spread(.423d0,1,n-1)
 f%dispersivity_cm=spread(0d0,1,n-1);f%rain_c_mg_cm3=.05d0
 initial=.5d0
 if(mode>0)initial=[(.05d0+exp(-.5d0*((i-.5d0)-8d0)**2),i=1,n)]
 if(mode==2)then
  f%q_face_up_cm_day=-.15d0;f%rain_rate_cm_day=.15d0
  f%molecular_diffusion_cm2_day=.2d0;f%dispersivity_cm=.25d0;f%decpot=.1d0
 end if
 call initialize_mobile_salt_state(f%dz_cm,f%theta,initial,m,code)
 if(code/=SOLUTE_OK)error stop 'process mobile'
 call initialize_solute_compartment_state(.26d0*initial**exponent,0d0,0d0,0d0*f%theta,s,code)
 if(code/=SOLCOMP_OK)error stop 'process companion'
 startmass=sum(m%mass_mg_cm2)+s%solute_total();account=0d0;corrections=0d0;worst=0d0
 print '(A,1X,3(I0,1X),2(ES25.16E3,1X))','SINK_CASE',mode,kind,steps,exponent,uptake
 do k=1,steps
  f%theta_previous=f%theta
  f%theta=f%theta_previous-dt*(f%root_sink_cm_day+sum(f%qdra_cm_day,dim=1))
  before=m%concentration_mg_cm3;old=m;old_s=s
  call advance_research_sink_fct(m,s,f,.false.,test,test_s,rt)
  call advance_b111_reactive_solute_substep(m,s,f,plain,plain_s,rp,exact_empty_pond_limit=.true.)
  if(rt%status/=0.or.rp%status/=0)error stop 'off solve'
  call same(test,test_s,plain,plain_s)
  if(any([rt%external_output_mg_cm2,rt%decay_output_mg_cm2,rt%root_output_mg_cm2,rt%drain_output_mg_cm2]/= &
   [rp%external_output_mg_cm2,rp%decay_output_mg_cm2,rp%root_output_mg_cm2,rp%drain_output_mg_cm2]))error stop 'off ledger'
  ! The sink-free path must preserve the exact admitted predecessor.
  zero=f;zero%theta=f%theta_previous;zero%root_sink_cm_day=0d0;zero%qdra_cm_day=0d0
  call advance_research_sink_fct(m,s,zero,.true.,test,test_s,rt)
  call advance_research_composed_fct(m,s,zero,.true.,plain,plain_s,rp)
  if(rt%status/=0.or.rp%status/=0)error stop 'zero solve'
  call same(test,test_s,plain,plain_s)
  if(rt%external_output_mg_cm2/=rp%external_output_mg_cm2)error stop 'zero ledger'
  call advance_research_sink_fct(m,s,f,.true.,next,next_s,r,l1,delta)
  if(r%status/=0)then
   print *,'SINK_FAILED',mode,exponent,k,r%status;error stop 'sink solve'
  end if
  do j=1,5
   bad=f
   select case(j)
   case(1)
    bad%theta(1)=bad%theta(1)+.001d0
   case(2)
    bad%qdra_cm_day(1,1)=-.001d0
   case(3)
    bad%tscf=1.01d0
   case(4)
    bad%decpot(1)=-.01d0
   case(5)
    bad%q_face_up_cm_day(2)=.01d0
   end select
   call advance_research_sink_fct(m,s,bad,.true.,test,test_s,rt)
   if(rt%status==0)error stop 'invalid accepted'
   call same(m,s,test,test_s);call same(old,old_s,m,s)
  end do
  print '(A,1X,I0,1X,6(ES25.16E3,1X))','STEP',k,f%theta_previous(1),f%theta(1), &
   r%external_input_mg_cm2,r%external_output_mg_cm2,r%root_output_mg_cm2,r%drain_output_mg_cm2
  do i=1,n
   print '(A,1X,I0,1X,5(ES25.16E3,1X))','CELL',i,before(i),next%concentration_mg_cm3(i), &
    next%mass_mg_cm2(i),next_s%sorbed_matrix_mass(i),delta(i)
  end do
  m=next;s=next_s
  account=account+[r%external_input_mg_cm2,r%external_output_mg_cm2,r%decay_output_mg_cm2,r%root_output_mg_cm2,r%drain_output_mg_cm2]
  corrections=corrections+l1;worst=max(worst,abs(r%balance_residual_mg_cm2))
 end do
 if(mode==2.and.corrections<=1d-8)error stop 'correction inactive'
 if(mode==0.and.uptake==1d0.and.maxval(abs(m%concentration_mg_cm3-.5d0))>1d-12)error stop 'constant concentration'
 if(mode==0.and.kind/=2.and.uptake<1d0.and.minval(m%concentration_mg_cm3)<=.5d0)error stop 'concentration increase clipped'
 print '(A,1X,8(ES25.16E3,1X))','BUDGET',startmass,account,worst,corrections
 print '(A)','EXACT_OFF_ZERO_SINK_AND_FIVE_ATOMIC_REJECTIONS_PER_STEP_PASS'
contains
 subroutine same(a,b,c,d)
  type(mobile_salt_state_t),intent(in)::a,c
  type(solute_compartment_state_t),intent(in)::b,d
  if(any(a%mass_mg_cm2/=c%mass_mg_cm2).or.any(a%concentration_mg_cm3/=c%concentration_mg_cm3).or. &
   any(b%sorbed_matrix_mass/=d%sorbed_matrix_mass))error stop 'process atomic drift'
 end subroutine
end program
