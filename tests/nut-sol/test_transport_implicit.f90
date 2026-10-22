program test_transport_implicit
 use iso_fortran_env,only:real64
 use mod_solute_mobile_salt_state
 use mod_solute_compartment_state
 use mod_b111_solute_sorption
 use mod_b111_reactive_solute_substep
 implicit none
 type(mobile_salt_state_t)::m,next,repeat
 type(solute_compartment_state_t)::s,next_s,repeat_s
 type(b111_reactive_solute_substep_forcing_t)::f
 type(b111_reactive_solute_substep_receipt_t)::r,r2
 type(b111_sorption_result_t)::equilibrium
 real(real64)::dt,flow,exponent,width(2),c0(2),before,aa,bb,g,d1,d2,rhs1,rhs2,det,expected(2),error
 integer::direction,power,mode,e,i,code,count
 real(real64),parameter::exponents(6)=[.5d0,.75d0,1d0,1.25d0,1.5d0,2d0]
 real(real64)::h,x,errors(3),start,total,expected_total
 real(real64),allocatable::initial_c(:),depth(:),water(:)
 integer::n,j,k,steps
 count=0
 do direction=-1,1,2
  do power=1,3
   do e=1,6
    exponent=exponents(e)
    dt=10d0**(-power);flow=.1d0*direction;width=[10d0,7d0];c0=[1d0,0d0]
    if(direction<0)c0=[0d0,1d0]
    call initialize_mobile_salt_state(width,[.2d0,.2d0],c0,m,code)
    if(code/=SOLUTE_OK)error stop 1
    call initialize_solute_compartment_state([0d0,0d0],0d0,0d0,[0d0,0d0],s,code)
    f=b111_reactive_solute_substep_forcing_t()
    f%dt_day=dt;f%dz_cm=width;f%theta_previous=[.2d0,.2d0]
    f%theta=[.2d0+flow*dt/width(1),.2d0-flow*dt/width(2)]
    f%q_face_up_cm_day=[0d0,flow,0d0];f%root_sink_cm_day=[0d0,0d0]
    allocate(f%qdra_cm_day(0,2))
    f%temperature_c=[20d0,20d0];f%gampar=[0d0,0d0];f%rtheta=[.2d0,.2d0]
    f%bexp=[1d0,1d0];f%decpot=[0d0,0d0];f%fdepth=[1d0,1d0]
    f%bulk_density=[1.3d0,1.3d0];f%kf=[.2d0,.1d0];f%frexp=exponent;f%cref_mg_cm3=1d0
    f%face_distance_cm=[8.5d0];f%face_left_weight=[7d0/17d0];f%face_right_weight=[10d0/17d0]
    f%theta_sat_left=[.4d0];f%dispersivity_cm=[.01d0];f%molecular_diffusion_cm2_day=0d0
    do i=1,2
     call b111_sorption_storage_from_concentration(.2d0,f%bulk_density(i),f%kf(i),1d0,exponent,c0(i),equilibrium)
     s%sorbed_matrix_mass(i)=equilibrium%sorbed_density*width(i)
    end do
    before=sum(m%mass_mg_cm2)+s%solute_total()
    call advance_b111_reactive_solute_substep(m,s,f,next,next_s,r)
    if(r%status/=B111_REACTIVE_NEGATIVE)error stop 2
    if(any(next%mass_mg_cm2/=m%mass_mg_cm2).or.next_s%solute_total()/=s%solute_total())error stop 3
    f%transport_scheme=B111_TRANSPORT_IMPLICIT_UPWIND
    call advance_b111_reactive_solute_substep(m,s,f,next,next_s,r)
    if(r%status/=B111_REACTIVE_OK)then
     print *, 'failed',direction,power,exponent,r%status;error stop 4
    end if
    if(any(next%mass_mg_cm2<0d0).or.any(next%concentration_mg_cm3<0d0).or.any(next_s%sorbed_matrix_mass<0d0))error stop 5
    if(abs(sum(next%mass_mg_cm2)+next_s%solute_total()-before)>1d-12)error stop 6
    if(exponent==1d0)then
     ! Independent two-cell linear BE equations, solved by the 2x2 determinant.
     g=.01d0*abs(flow)/8.5d0;aa=min(flow,0d0)-g;bb=max(flow,0d0)+g
     d1=(f%theta(1)+1.3d0*.2d0)*width(1)-dt*aa
     d2=(f%theta(2)+1.3d0*.1d0)*width(2)+dt*bb
     rhs1=(.2d0+1.3d0*.2d0)*width(1)*c0(1);rhs2=(.2d0+1.3d0*.1d0)*width(2)*c0(2)
     det=d1*d2+dt*dt*aa*bb
     expected=[(rhs1*d2+dt*bb*rhs2)/det,(d1*rhs2-dt*aa*rhs1)/det]
     if(maxval(abs(next%concentration_mg_cm3-expected))>1d-14)error stop 7
    end if
    call advance_b111_reactive_solute_substep(m,s,f,repeat,repeat_s,r2)
    if(any(repeat%mass_mg_cm2/=next%mass_mg_cm2).or.any(repeat_s%sorbed_matrix_mass/=next_s%sorbed_matrix_mass))error stop 8
    f%transport_scheme=-1
    call advance_b111_reactive_solute_substep(m,s,f,repeat,repeat_s,r2)
    if(r2%status/=B111_REACTIVE_INVALID.or.any(repeat%mass_mg_cm2/=m%mass_mg_cm2))error stop 9
    count=count+1
    print *, 'IMPLICIT',direction,power,exponent,r%nonlinear_sweeps,r%balance_residual_mg_cm2
   end do
  end do
 end do
 if(count/=36)error stop 10
 ! One cell with rain, bottom and signed drainage sources; implicit decay and
 ! root/drain losses, checked against the scalar physical balance for every p.
 do e=1,6
  f=b111_reactive_solute_substep_forcing_t()
  f%transport_scheme=B111_TRANSPORT_IMPLICIT_UPWIND;f%dt_day=.1d0;f%dz_cm=[10d0]
  f%theta_previous=[.2d0];f%theta=[.2024d0];f%q_face_up_cm_day=[-.2d0,.05d0]
  f%root_sink_cm_day=[.02d0];allocate(f%qdra_cm_day(2,1));f%qdra_cm_day(:,1)=[.03d0,-.04d0]
  f%rain_rate_cm_day=.2d0;f%rain_c_mg_cm3=3d0;f%pond_end_cm=0d0
  f%cdrain_mg_cm3=2d0;f%cseep_mg_cm3=4d0;f%tscf=.5d0
  f%temperature_active=.true.;f%temperature_c=[20d0];f%gampar=[.05d0];f%rtheta=[.2d0]
  f%bexp=[1d0];f%decpot=[.1d0];f%fdepth=[1d0]
  f%bulk_density=[1.3d0];f%kf=[.2d0];f%frexp=exponents(e);f%cref_mg_cm3=1d0
  call initialize_mobile_salt_state([10d0],[.2d0],[1d0],m,code)
  call b111_sorption_storage_from_concentration(.2d0,1.3d0,.2d0,1d0,f%frexp,1d0,equilibrium)
  call initialize_solute_compartment_state([10d0*equilibrium%sorbed_density],0d0,0d0,[0d0],s,code)
  before=sum(m%mass_mg_cm2)+s%solute_total()
  call advance_b111_reactive_solute_substep(m,s,f,next,next_s,r)
  if(r%status/=B111_REACTIVE_OK)error stop 11
  total=sum(next%mass_mg_cm2)+next_s%solute_total()
  expected_total=before+.1d0*(.2d0*3d0+.05d0*4d0+.04d0*2d0)- &
    .1d0*(.1d0*total+(.5d0*.02d0+.03d0)*next%concentration_mg_cm3(1))
  if(abs(total-expected_total)>1d-12.or.next_s%pond_mass/=0d0)error stop 12
  print *, 'SOURCES',f%frexp,total,r%balance_residual_mg_cm2
 end do
 ! Independent analytic advection of a smooth pulse. Refine space and time
 ! together; fixed physical q/theta/length, zero physical diffusion/dispersion.
 do j=1,3
  n=20*2**(j-1);h=20d0/n;dt=.05d0*h;steps=nint(2d0/dt)
  allocate(depth(n),water(n),initial_c(n));depth=h;water=.25d0
  do i=1,n
   x=(i-.5d0)*h;initial_c(i)=exp(-.5d0*(x-7d0)**2)
  end do
  call initialize_mobile_salt_state(depth,water,initial_c,m,code)
  call initialize_solute_compartment_state(0d0*water,0d0,0d0,0d0*water,s,code)
  f=b111_reactive_solute_substep_forcing_t();f%transport_scheme=B111_TRANSPORT_IMPLICIT_UPWIND
  f%dt_day=dt;f%dz_cm=depth;f%theta_previous=water;f%theta=water
  f%q_face_up_cm_day=[(-.25d0,i=1,n+1)];f%root_sink_cm_day=0d0*water
  allocate(f%qdra_cm_day(0,n))
  f%temperature_c=20d0+0d0*water;f%gampar=0d0*water;f%rtheta=water;f%bexp=1d0+0d0*water
  f%decpot=0d0*water;f%fdepth=1d0+0d0*water;f%bulk_density=1d0+0d0*water;f%kf=0d0*water
  f%face_distance_cm=depth(:n-1);f%face_left_weight=[(.5d0,i=1,n-1)];f%face_right_weight=f%face_left_weight
  f%theta_sat_left=[(.4d0,i=1,n-1)];f%dispersivity_cm=0d0*depth(:n-1);f%rain_rate_cm_day=.25d0
  start=sum(m%mass_mg_cm2);expected_total=start
  do k=1,steps
   f%rain_c_mg_cm3=exp(-.5d0*(7d0+k*dt)**2)
   call advance_b111_reactive_solute_substep(m,s,f,next,next_s,r)
   if(r%status/=B111_REACTIVE_OK)error stop 13
   expected_total=expected_total+r%external_input_mg_cm2-r%external_output_mg_cm2
   m=next;s=next_s
  end do
  if(abs(sum(m%mass_mg_cm2)-expected_total)>1d-12)error stop 14
  errors(j)=0d0
  do i=1,n
   x=(i-.5d0)*h;errors(j)=errors(j)+h*abs(m%concentration_mg_cm3(i)-exp(-.5d0*(x-9d0)**2))
  end do
  if(j>1)then
   if(errors(j)>=.8d0*errors(j-1))error stop 15
  end if
  print *, 'CONVERGENCE',n,dt,errors(j)
  deallocate(depth,water,initial_c)
 end do
 print '(A)','TRANSPORT_IMPLICIT_POSITIVE_MASS_ORACLE_REFERENCE_REJECTION_PASS'
end program
