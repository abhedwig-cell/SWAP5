program component
  use,intrinsic::iso_fortran_env,only:real64
  use,intrinsic::ieee_arithmetic,only:ieee_value,ieee_quiet_nan
  use mod_solute_compartment_state
  use mod_b111_age_tracer_substep
  use mod_direct_soil_age_substep
  implicit none
  type(solute_compartment_state_t)::s,a,b,c,base,nextbase,trial
  type(b111_age_tracer_substep_forcing_t)::f,g
  type(b111_age_tracer_substep_receipt_t)::old
  type(direct_soil_age_receipt_t)::r
  real(real64)::qssdi(2),age,nan,errors(3),exact(2),delta(2),dt,elapsed,initial
  integer::i,j,k,nt,status
  nan=ieee_value(1d0,ieee_quiet_nan)
  call initialize_solute_compartment_state([0d0,0d0],0d0,0d0,[30d0,30d0],s,status)
  if(status/=SOLCOMP_OK)error stop 'State initialization failed'
  f%dt_day=.1d0;f%theta=[.3d0,.3d0];f%theta_previous=f%theta
  f%production_theta_mean=f%theta;f%dz_cm=[1d0,1d0]
  f%q_face_up_cm_day=[0d0,-.1d0,-.1d0];f%root_sink_cm_day=[0d0,0d0]
  allocate(f%qdra_cm_day(1,2));f%qdra_cm_day=0d0
  f%face_left_weight=[1d0];f%face_right_weight=[0d0]
  f%face_distance_cm=[1d0];f%theta_sat_left=[.5d0];f%dispersivity_cm=[0d0]
  f%accepted_surface_age_available=.true.;f%evaporative_top_retains_age=.true.
  call advance_b111_age_tracer_substep(s,f,a,old)
  if(old%status/=B111_AGE_SUBSTEP_OK)error stop 'Real transport fixture refused'
  do i=1,2
    qssdi=[0d0,0d0];age=20d0
    if(i==2)then
      qssdi=[.2d0,.3d0];age=0d0
    end if
    call advance_direct_soil_age_substep(s,f,qssdi,age,b,r)
    if(r%status/=DIRECT_AGE_OK.or.any(a%age_amount/=b%age_amount))error stop 'Zero source changed literal transport'
    if(r%total_direct_input_cm_day/=0d0)error stop 'Zero source invented input'
  end do
  do i=1,2
    qssdi=[.2d0,0d0]
    if(i==2)qssdi=[.08d0,.12d0]
    call advance_direct_soil_age_substep(s,f,qssdi,20d0,b,r)
    if(r%status/=DIRECT_AGE_OK)error stop 'Positive real composed provider refused'
    if(any(abs((b%age_amount-a%age_amount)-qssdi*20d0*f%dt_day)>1d-13)) &
      error stop 'Direct input changed layer or units'
    if(abs(r%total_direct_input_cm_day-.4d0)>1d-14)error stop 'Incorrect cm day input'
    if(any(s%age_amount/=[30d0,30d0]))error stop 'Provider mutated committed age'
  end do
  do i=1,10
    g=f;qssdi=[.2d0,0d0];age=20d0
    select case(i)
    case(1);qssdi(1)=-1d0
    case(2);qssdi(1)=nan
    case(3);age=-1d0
    case(4);age=1001d0
    case(5);age=nan
    case(6);g%dt_day=0d0
    case(7);g%root_sink_cm_day(1)=-1d0
    case(8);qssdi(1)=1d6+1d0
    case(9);g%dt_day=nan
    case(10);g%theta(1)=0d0
    end select
    call advance_direct_soil_age_substep(s,g,qssdi,age,b,r)
    if(r%status==DIRECT_AGE_OK.or.any(b%age_amount/=s%age_amount))error stop 'Invalid source/transport accepted or mutated'
  end do
  call advance_direct_soil_age_substep(s,f,[.2d0],20d0,b,r)
  if(r%status==DIRECT_AGE_OK.or.any(b%age_amount/=s%age_amount))error stop 'Foreign shape accepted'
  c=s;c%age_amount=1d12
  g=f;g%q_face_up_cm_day=0d0;g%dt_day=1000d0
  call advance_direct_soil_age_substep(c,g,[1d6,1d6],1000d0,b,r)
  if(r%status==DIRECT_AGE_OK.or.any(b%age_amount/=c%age_amount))error stop 'Age ceiling accepted or state changed'
  ! Rejected candidates have no influence on the next evaluation.
  call advance_direct_soil_age_substep(s,f,[.2d0,0d0],20d0,b,r)
  call advance_direct_soil_age_substep(s,f,[.2d0,0d0],20d0,c,r)
  if(any(b%age_amount/=c%age_amount))error stop 'Rejected call contaminated subsequent state'
  ! Actual coupled provider convergence against a two-cell linear transport
  ! solution. Subtract the identical zero-source age-clock baseline.
  exact=[1.2d0*(1d0-exp(-1d0/3d0)),1.2d0*(1d0-exp(-1d0/3d0)*(1d0+1d0/3d0))]
  do k=1,3
    nt=10*2**(k-1);dt=1d0/nt;g=f;g%dt_day=dt;b=s;base=s
    initial=sum(s%age_amount);elapsed=0d0
    do j=1,nt
      call advance_direct_soil_age_substep(b,g,[.02d0,0d0],20d0,c,r)
      if(r%status/=DIRECT_AGE_OK)error stop 'Actual refinement integration refused'
      if(abs(r%balance_residual_cm_day)>r%tolerance_cm_day)error stop 'Composed conservation failed'
      call advance_b111_age_tracer_substep(base,g,nextbase,old)
      if(old%status/=B111_AGE_SUBSTEP_OK)error stop 'Actual baseline integration refused'
      b=c;base=nextbase;elapsed=elapsed+r%total_direct_input_cm_day
    end do
    if(abs(elapsed-.4d0)>1d-14)error stop 'Subcycle direct age source not conserved'
    delta=b%age_amount-base%age_amount;errors(k)=maxval(abs(delta-exact))
  end do
  if(any(errors(2:3)>=.6d0*errors(1:2)))error stop 'Transport/input split failed temporal convergence'
  write(*,'(a,3(1x,es25.17e3))')'ACTUAL_DIRECT_SOIL_AGE_COMPONENT_PASS',errors
end program
