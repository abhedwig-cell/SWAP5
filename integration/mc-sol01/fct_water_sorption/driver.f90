program storage_fct_contract
 use iso_fortran_env,only:real64
 use mod_research_storage_fct
 use mod_solute_mobile_salt_state
 use mod_solute_compartment_state
 use mod_b111_reactive_solute_substep
 implicit none
 integer,parameter::n=24
 type(mobile_salt_state_t)::m,low,next,off,bad,out
 type(solute_compartment_state_t)::s,low_s,next_s,off_s,bad_s,out_s
 type(b111_reactive_solute_substep_forcing_t)::f,g
 type(b111_reactive_solute_substep_receipt_t)::r,lr,orr,br
 real(real64)::initial(n),water(n),flux(n+1),dt,kf,exponent,direction,h,x,change
 integer::shape,i,j,code
 character(80)::arg
 call get_command_argument(1,arg);read(arg,*)exponent
 call get_command_argument(2,arg);read(arg,*)kf
 call get_command_argument(3,arg);read(arg,*)direction
 call get_command_argument(4,arg);read(arg,*)shape
 call get_command_argument(5,arg);read(arg,*)dt
 h=.5d0
 do i=1,n
  x=(i-.5d0)*h;water(i)=.25d0+.03d0*cos(acos(-1d0)*x/(n*h))
  select case(shape)
  case(0);initial(i)=.05d0+exp(-.5d0*((x-5d0)/.8d0)**2)
  case(1);initial(i)=0d0;if(x>=4d0.and.x<=6d0)initial(i)=1d0
  case(2);initial(i)=.7d0
  case(3);initial(i)=0d0
  end select
 end do
 do i=1,n+1
  flux(i)=.25d0*(1d0+direction*.5d0*sin(acos(-1d0)*(i-1)/n))
 end do
 call initialize_mobile_salt_state(h+0d0*water,water,initial,m,code)
 if(code/=SOLUTE_OK)error stop 1
 call initialize_solute_compartment_state(1.3d0*kf*initial**exponent*h,0d0,0d0,0d0*water,s,code)
 if(code/=SOLCOMP_OK)error stop 2
 f=b111_reactive_solute_substep_forcing_t();f%transport_scheme=B111_TRANSPORT_IMPLICIT_UPWIND
 f%dt_day=dt;f%dz_cm=h+0d0*water;f%theta_previous=water
 f%theta=water+dt*(flux(:n)-flux(2:))/h;f%q_face_up_cm_day=-flux
 f%root_sink_cm_day=0d0*water;allocate(f%qdra_cm_day(0,n))
 f%temperature_active=.true.;f%temperature_c=20d0+0d0*water;f%gampar=0d0*water
 f%rtheta=water;f%bexp=1d0+0d0*water;f%decpot=0d0*water;f%fdepth=1d0+0d0*water
 f%bulk_density=1.3d0+0d0*water;f%kf=kf+0d0*water;f%frexp=exponent
 f%face_distance_cm=f%dz_cm(:n-1);f%face_left_weight=[(.5d0,i=1,n-1)]
 f%face_right_weight=f%face_left_weight;f%theta_sat_left=[(.4d0,i=1,n-1)]
 f%dispersivity_cm=0d0*f%face_distance_cm;f%rain_rate_cm_day=flux(1)
 f%rain_c_mg_cm3=0d0;if(shape==2)f%rain_c_mg_cm3=.7d0
 call advance_b111_reactive_solute_substep(m,s,f,low,low_s,lr)
 if(lr%status/=B111_REACTIVE_OK)error stop 3
 call advance_research_storage_fct(m,s,f,.false.,off,off_s,orr)
 if(orr%status/=lr%status.or.any(ledger(orr)/=ledger(lr)))error stop 4
 call same(off,off_s,low,low_s)
 call advance_research_storage_fct(m,s,f,.true.,next,next_s,r)
 if(r%status/=B111_REACTIVE_OK)then
  print *,'STATUS',r%status;error stop 5
 end if
 if(any(next%mass_mg_cm2<0d0).or.any(next_s%sorbed_matrix_mass<0d0))error stop 6
 if(any(ledger(r)/=ledger(lr)))error stop 7
 if(maxval(next%concentration_mg_cm3)>maxval(initial)+1d-12)error stop 8
 if(abs(r%balance_residual_mg_cm2)>1d-12)error stop 9
 if(shape>=2.and.maxval(abs(next%concentration_mg_cm3-initial))>1d-12)error stop 10
 change=sum(abs(next%mass_mg_cm2+next_s%sorbed_matrix_mass-low%mass_mg_cm2-low_s%sorbed_matrix_mass))
 if(shape<=1.and.change<=1d-10)error stop 11
 print '(A,1X,I0,1X,8(ES25.16E3,1X))','SUMMARY',n,exponent,kf,direction,dt, &
  r%mass_before_mg_cm2,r%mass_after_mg_cm2,r%balance_residual_mg_cm2,change
 print '(A,1X,3(ES25.16E3,1X))','BOUNDARY',r%external_input_mg_cm2,r%external_output_mg_cm2,f%rain_c_mg_cm3
 do i=1,n
  print '(A,1X,I0,1X,12(ES25.16E3,1X))','CELL',i,water(i),f%theta(i),flux(i),flux(i+1),initial(i), &
   low%concentration_mg_cm3(i),low%mass_mg_cm2(i),low_s%sorbed_matrix_mass(i), &
   next%concentration_mg_cm3(i),next%mass_mg_cm2(i),next_s%sorbed_matrix_mass(i),h
 end do
 do j=1,15
  g=f;bad=m;bad_s=s
  select case(j)
  case(1);g%theta(1)=g%theta(1)+.01d0
  case(2);g%dt_day=10d0
  case(3);g%q_face_up_cm_day(2)=.1d0
  case(4);g%dispersivity_cm(1)=.01d0
  case(5);g%decpot(1)=.01d0
  case(6);g%root_sink_cm_day(1)=.01d0
  case(7);deallocate(g%qdra_cm_day);allocate(g%qdra_cm_day(1,n));g%qdra_cm_day=.01d0
  case(8);g%pond_end_cm=.1d0
  case(9);g%runoff_depth_cm=.1d0
  case(10);g%dz_cm(1)=h*2d0
  case(11);g%frexp=.25d0
  case(12);g%molecular_diffusion_cm2_day=.001d0
  case(13);bad_s%pond_mass=.01d0
  case(14);bad%mass_mg_cm2(1)=bad%mass_mg_cm2(1)+.1d0
  case(15);deallocate(g%theta_previous)
  end select
  call advance_research_storage_fct(bad,bad_s,g,.true.,out,out_s,br)
  if(br%status==B111_REACTIVE_OK)error stop 12
  call same(out,out_s,bad,bad_s)
 end do
 ! OFF also remains exact outside the research domain (physical dispersion).
 g=f;g%dispersivity_cm=.01d0
 call advance_b111_reactive_solute_substep(m,s,g,low,low_s,lr)
 call advance_research_storage_fct(m,s,g,.false.,off,off_s,orr)
 if(lr%status/=B111_REACTIVE_OK.or.orr%status/=lr%status.or.any(ledger(orr)/=ledger(lr)))error stop 13
 call same(off,off_s,low,low_s)
 print '(A)','FIFTEEN_ATOMIC_REJECTIONS_AND_OFF_DELEGATION_PASS'
contains
 function ledger(a) result(v)
  type(b111_reactive_solute_substep_receipt_t),intent(in)::a
  real(real64)::v(13)
  v=[a%external_input_mg_cm2,a%external_output_mg_cm2,a%decay_output_mg_cm2,a%root_output_mg_cm2, &
   a%drain_output_mg_cm2,a%drain_input_mg_cm2,a%bottom_output_mg_cm2,a%bottom_input_mg_cm2, &
   a%pond_to_soil_mg_cm2,a%runoff_output_mg_cm2,a%mass_before_mg_cm2,real(a%nonlinear_sweeps,real64),0d0]
 end function
 subroutine same(a,b,c,d)
  type(mobile_salt_state_t),intent(in)::a,c
  type(solute_compartment_state_t),intent(in)::b,d
  if(any(a%mass_mg_cm2/=c%mass_mg_cm2).or.any(a%concentration_mg_cm3/=c%concentration_mg_cm3))error stop 14
  if(any(b%sorbed_matrix_mass/=d%sorbed_matrix_mass).or.any(b%age_amount/=d%age_amount).or. &
   b%pond_mass/=d%pond_mass.or.b%aquifer_mass/=d%aquifer_mass.or. &
   b%age_pond_previous_concentration/=d%age_pond_previous_concentration)error stop 15
 end subroutine
end program
