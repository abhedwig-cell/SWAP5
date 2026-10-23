program reactive_pulse
 use iso_fortran_env,only:real64
 use mod_research_composed_fct
 use mod_b111_reactive_solute_substep
 use mod_solute_mobile_salt_state
 use mod_solute_compartment_state
 implicit none
 type(mobile_salt_state_t)::m,next
 type(solute_compartment_state_t)::s,next_s
 type(b111_reactive_solute_substep_forcing_t)::f
 type(b111_reactive_solute_substep_receipt_t)::r
 real(real64),allocatable::initial(:)
 real(real64)::h,dt,x1,x2,startmass,ins,outs,decay,worst,corrections,l1
 integer::n,steps,flag,k,i,code
 character(64)::arg
 call get_command_argument(1,arg);read(arg,*)n
 call get_command_argument(2,arg);read(arg,*)steps
 call get_command_argument(3,arg);read(arg,*)flag
 h=80d0/n;dt=8d0/steps;allocate(initial(n))
 f%transport_scheme=B111_TRANSPORT_IMPLICIT_UPWIND;f%dt_day=dt
 f%theta=spread(.3d0,1,n);f%theta_previous=f%theta;f%dz_cm=spread(h,1,n)
 f%q_face_up_cm_day=spread(-.3d0,1,n+1);f%root_sink_cm_day=0d0*f%theta;allocate(f%qdra_cm_day(0,n))
 f%temperature_active=.true.;f%temperature_c=20d0+0d0*f%theta;f%gampar=0d0*f%theta
 f%rtheta=.3d0+0d0*f%theta;f%bexp=1d0+0d0*f%theta;f%decpot=.05d0+0d0*f%theta;f%fdepth=1d0+0d0*f%theta
 f%bulk_density=1.3d0+0d0*f%theta;f%kf=.2d0+0d0*f%theta;f%frexp=1d0
 f%face_distance_cm=spread(h,1,n-1);f%face_left_weight=spread(.5d0,1,n-1)
 f%face_right_weight=f%face_left_weight;f%theta_sat_left=spread(.423d0,1,n-1)
 f%dispersivity_cm=spread(.25d0,1,n-1);f%molecular_diffusion_cm2_day=.02d0;f%rain_rate_cm_day=.3d0
 do i=1,n
  x1=((i-1)*h-25d0)/(sqrt(2d0)*2d0);x2=(i*h-25d0)/(sqrt(2d0)*2d0)
  initial(i)=1d-6+2d0*sqrt(acos(-1d0)/2d0)*(erf(x2)-erf(x1))/h
 end do
 call initialize_mobile_salt_state(f%dz_cm,f%theta,initial,m,code)
 if(code/=SOLUTE_OK)error stop 'pulse mobile'
 call initialize_solute_compartment_state(.26d0*h*initial,0d0,0d0,0d0*f%theta,s,code)
 if(code/=SOLCOMP_OK)error stop 'pulse companion'
 startmass=sum(m%mass_mg_cm2)+s%solute_total();ins=0d0;outs=0d0;decay=0d0;worst=0d0;corrections=0d0
 do k=1,steps
  f%rain_c_mg_cm3=1d-6/(1d0+.05d0*dt)**k
  call advance_research_composed_fct(m,s,f,flag==1,next,next_s,r,l1)
  if(r%status/=0)then
   print *,'PULSE_FAILED',n,steps,flag,k,r%status;error stop 'pulse process'
  end if
  m=next;s=next_s;ins=ins+r%external_input_mg_cm2;outs=outs+r%external_output_mg_cm2
  decay=decay+r%decay_output_mg_cm2;worst=max(worst,abs(r%balance_residual_mg_cm2));corrections=corrections+l1
 end do
 if(flag==1.and.corrections<=1d-8)error stop 'pulse inactive correction'
 if(any(m%mass_mg_cm2<0d0).or.any(s%sorbed_matrix_mass<0d0))error stop 'pulse negative'
 print '(A,1X,3(I0,1X),6(ES25.16E3,1X))','PULSE_PASS',n,steps,flag,startmass,ins,outs,decay,worst,corrections
 do i=1,n
  print '(A,1X,I0,1X,4(ES25.16E3,1X))','CELL',i,initial(i),m%concentration_mg_cm3(i),m%mass_mg_cm2(i),s%sorbed_matrix_mass(i)
 end do
end program
