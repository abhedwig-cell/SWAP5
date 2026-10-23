program transport_accuracy
 use iso_fortran_env,only:real64
 use mod_solute_mobile_salt_state
 use mod_solute_compartment_state
 use mod_b111_reactive_solute_substep
 implicit none
 type(mobile_salt_state_t)::m,next
 type(solute_compartment_state_t)::s,next_s
 type(b111_reactive_solute_substep_forcing_t)::f
 type(b111_reactive_solute_substep_receipt_t)::r
 real(real64),allocatable::dz(:),water(:),initial(:)
 real(real64)::h,dt,kf,alpha,start,expected,decayed,bottom,max_balance,x1,x2
 real(real64),parameter::theta=.25d0,rho=1.3d0,q=.25d0,pi=acos(-1d0)
 integer::n,steps,case_id,i,k,code
 character(100)::arg
 call get_command_argument(1,arg);read(arg,*)n
 call get_command_argument(2,arg);read(arg,*)dt
 call get_command_argument(3,arg);read(arg,*)case_id
 if(n<2.or.dt<=0d0.or.(case_id/=1.and.case_id/=2))error stop 1
 steps=nint(2d0/dt)
 if(abs(steps*dt-2d0)>1d-13)error stop 2
 h=40d0/n;kf=merge(0d0,.2d0,case_id==1);alpha=merge(.01d0,.02d0,case_id==1)
 allocate(dz(n),water(n),initial(n));dz=h;water=theta
 do i=1,n
  x1=((i-1)*h-15d0)/sqrt(2d0);x2=(i*h-15d0)/sqrt(2d0)
  initial(i)=sqrt(pi/2d0)*(erf(x2)-erf(x1))/h
 end do
 call initialize_mobile_salt_state(dz,water,initial,m,code)
 if(code/=SOLUTE_OK)error stop 3
 call initialize_solute_compartment_state(rho*kf*initial*dz,0d0,0d0,0d0*water,s,code)
 if(code/=SOLCOMP_OK)error stop 4
 f=b111_reactive_solute_substep_forcing_t();f%transport_scheme=B111_TRANSPORT_IMPLICIT_UPWIND
 f%dt_day=dt;f%dz_cm=dz;f%theta_previous=water;f%theta=water
 f%q_face_up_cm_day=[(-q,i=1,n+1)];f%root_sink_cm_day=0d0*water
 allocate(f%qdra_cm_day(0,n))
 f%temperature_active=.true.;f%temperature_c=20d0+0d0*water;f%gampar=0d0*water
 f%rtheta=water;f%bexp=1d0+0d0*water;f%decpot=.05d0+0d0*water;f%fdepth=1d0+0d0*water
 f%bulk_density=rho+0d0*water;f%kf=kf+0d0*water;f%frexp=1d0
 f%face_distance_cm=dz(:n-1);f%face_left_weight=[(.5d0,i=1,n-1)]
 f%face_right_weight=f%face_left_weight;f%theta_sat_left=[(.4d0,i=1,n-1)]
 f%dispersivity_cm=alpha+0d0*dz(:n-1);f%rain_rate_cm_day=q;f%rain_c_mg_cm3=0d0
 start=sum(m%mass_mg_cm2)+s%solute_total();expected=start
 decayed=0d0;bottom=0d0;max_balance=0d0
 do k=1,steps
  call advance_b111_reactive_solute_substep(m,s,f,next,next_s,r)
  if(r%status/=B111_REACTIVE_OK)then
   print *,'FAILED',k,r%status;error stop 5
  end if
  if(any(next%mass_mg_cm2<0d0).or.any(next%concentration_mg_cm3<0d0).or. &
    any(next_s%sorbed_matrix_mass<0d0))error stop 6
  if(abs(r%balance_residual_mg_cm2)>1d-10)error stop 7
  max_balance=max(max_balance,abs(r%balance_residual_mg_cm2))
  expected=expected+r%external_input_mg_cm2-r%external_output_mg_cm2
  decayed=decayed+r%decay_output_mg_cm2;bottom=bottom+r%bottom_output_mg_cm2
  m=next;s=next_s
 end do
 if(abs(sum(m%mass_mg_cm2)+s%solute_total()-expected)>1d-10)error stop 8
 print '(A,1X,3(I0,1X),10(ES25.16E3,1X))','SUMMARY',case_id,n,steps,dt,kf,alpha,start, &
  sum(m%mass_mg_cm2)+s%solute_total(),decayed,bottom,max_balance, &
  sum(m%mass_mg_cm2)+s%solute_total()-expected,expected
 do i=1,n
  print '(A,1X,I0,1X,4(ES25.16E3,1X))','PROFILE',i,(i-.5d0)*h,m%concentration_mg_cm3(i), &
   m%mass_mg_cm2(i),s%sorbed_matrix_mass(i)
 end do
end program
