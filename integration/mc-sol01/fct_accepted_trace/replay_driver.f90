program accepted_trace_replay
 use iso_fortran_env,only:real64
 use mod_research_trace_replay
 use mod_solute_mobile_salt_state
 use mod_solute_compartment_state
 use mod_b111_reactive_solute_substep
 implicit none
 type(b111_reactive_solute_substep_forcing_t),allocatable::f(:),bad(:)
 type(mobile_salt_state_t)::m,low,next,split,finish,failed
 type(solute_compartment_state_t)::s,low_s,next_s,split_s,finish_s,failed_s
 real(real64),allocatable::t0(:),t1(:),initial(:),w(:),begin_water(:),end_water(:),other_water(:),row(:),b0(:),b1(:)
 real(real64)::exponent,h,rain,clock,other_clock,ledger(4),lowledger(4),unused(4),x1,x2,pi
 integer::n,nt,i,j,u,ios,code,status,completed,shape,trial,mid
 character(1024)::path,arg,line
 call get_command_argument(1,path)
 call get_command_argument(2,arg);read(arg,*)exponent
 call get_command_argument(3,arg);read(arg,*)shape
 open(newunit=u,file=trim(path),status='old',action='read');read(u,*)n
 nt=0
 do
  read(u,'(A)',iostat=ios)line
  if(ios/=0)exit
  nt=nt+1
 end do
 rewind(u);read(u,*)n
 allocate(f(nt),t0(nt),t1(nt),row(5+3*n),initial(n),w(n));w=0d0;h=40d0/n;pi=acos(-1d0)
 do j=1,nt
  read(u,*)row;t0(j)=row(1);t1(j)=row(2)
  f(j)%transport_scheme=B111_TRANSPORT_IMPLICIT_UPWIND;f(j)%dt_day=t1(j)-t0(j)
  f(j)%theta_previous=row(5:4+n);f(j)%theta=row(5+n:4+2*n)
  f(j)%q_face_up_cm_day=-row(5+2*n:);f(j)%dz_cm=h+0d0*w
  f(j)%root_sink_cm_day=0d0*w;allocate(f(j)%qdra_cm_day(0,n))
  f(j)%temperature_active=.true.;f(j)%temperature_c=20d0+0d0*w;f(j)%gampar=0d0*w
  f(j)%rtheta=.3d0+0d0*w;f(j)%bexp=1d0+0d0*w;f(j)%decpot=0d0*w;f(j)%fdepth=1d0+0d0*w
  f(j)%bulk_density=1.3d0+0d0*w;f(j)%kf=.2d0+0d0*w;f(j)%frexp=exponent
  f(j)%face_distance_cm=[(h,i=1,n-1)];f(j)%face_left_weight=[(.5d0,i=1,n-1)]
  f(j)%face_right_weight=f(j)%face_left_weight;f(j)%theta_sat_left=[(.423d0,i=1,n-1)]
  f(j)%dispersivity_cm=0d0*f(j)%face_distance_cm;f(j)%rain_rate_cm_day=row(3)
 end do
 close(u)
 do i=1,n
  x1=((i-1)*h-15d0)/sqrt(2d0);x2=(i*h-15d0)/sqrt(2d0)
  initial(i)=.05d0+sqrt(pi/2d0)*(erf(x2)-erf(x1))/h
 end do
 rain=.05d0
 if(shape==1)then
  initial=.7d0;rain=.7d0
 end if
 do j=1,nt
  f(j)%rain_c_mg_cm3=rain
 end do
 begin_water=f(1)%theta_previous
 call initialize_mobile_salt_state(h+0d0*begin_water,begin_water,initial,m,code)
 if(code/=SOLUTE_OK)error stop 'mobile initialization'
 call initialize_solute_compartment_state(1.3d0*.2d0*initial**exponent*h,0d0,0d0,0d0*begin_water,s,code)
 if(code/=SOLCOMP_OK)error stop 'companion initialization'
 call consume_research_trace(m,s,0d0,begin_water,t0,t1,f,.false.,low,low_s,clock,end_water,status,completed,lowledger)
 if(status/=0.or.completed/=nt)then
  print *,'LOW_FAILED_STATUS_PREFIX',status,completed,nt;error stop 'low replay'
 end if
 call consume_research_trace(m,s,0d0,begin_water,t0,t1,f,.true.,next,next_s,clock,end_water,status,completed,ledger)
 if(status/=0.or.completed/=nt)then
  print *,'FAILED_STATUS_PREFIX',status,completed;error stop 'corrected replay'
 end if
 if(clock/=2d0.or.any(next%mass_mg_cm2<0d0).or.any(next_s%sorbed_matrix_mass<0d0))error stop 'final state'
 if(maxval(next%concentration_mg_cm3)>maxval(initial)+1d-10)error stop 'maximum principle'
 if(shape==1.and.maxval(abs(next%concentration_mg_cm3-initial))>1d-10)error stop 'constant solution'
 mid=nt/2
 call consume_research_trace(m,s,0d0,begin_water,t0(:mid),t1(:mid),f(:mid),.true.,split,split_s,clock,w,status,completed,unused)
 if(status/=0)error stop 'first split'
 call consume_research_trace(split,split_s,clock,w,t0(mid+1:),t1(mid+1:),f(mid+1:),.true.,finish,finish_s,other_clock,other_water,status,completed,unused)
 if(status/=0)error stop 'second split'
 call same(next,next_s,finish,finish_s)
 if(other_clock/=2d0.or.any(other_water/=end_water))error stop 'split clock water'
 do trial=1,5
  bad=f;b0=t0;b1=t1
  select case(trial)
  case(1);b0(nt)=0d0
  case(2);bad(nt)%theta_previous(1)=bad(nt)%theta_previous(1)+.01d0
  case(3);bad(nt)%q_face_up_cm_day=-bad(nt)%q_face_up_cm_day
  case(4);bad(nt)%decpot(1)=.01d0
  case(5);bad=[f,f(1)];b0=[t0,t0(1)];b1=[t1,t1(1)]
  end select
  call consume_research_trace(m,s,0d0,begin_water,b0,b1,bad,.true.,failed,failed_s,clock,w,status,completed,unused)
  if(status==0.or.completed<nt-1)error stop 'late rejection'
  call same(m,s,failed,failed_s)
  if(clock/=0d0.or.any(w/=begin_water).or.any(unused/=0d0))error stop 'failed prefix published'
 end do
 print '(A,1X,3(I0,1X),ES25.16E3)','REPLAY',n,nt,shape,exponent
 print '(A,1X,4(ES25.16E3,1X))','LOW_LEDGER',lowledger
 print '(A,1X,4(ES25.16E3,1X))','CORRECTED_LEDGER',ledger
 do i=1,n
  print '(A,1X,I0,1X,7(ES25.16E3,1X))','CELL',i,initial(i),low%concentration_mg_cm3(i), &
   low%mass_mg_cm2(i),low_s%sorbed_matrix_mass(i),next%concentration_mg_cm3(i),next%mass_mg_cm2(i),next_s%sorbed_matrix_mass(i)
 end do
 print '(A)','FIVE_LATE_BATCH_REJECTIONS_EXACT_SPLIT_CONTINUATION_PASS'
contains
 subroutine same(a,b,c,d)
  type(mobile_salt_state_t),intent(in)::a,c
  type(solute_compartment_state_t),intent(in)::b,d
  if(any(a%mass_mg_cm2/=c%mass_mg_cm2).or.any(a%concentration_mg_cm3/=c%concentration_mg_cm3))error stop 'mobile drift'
  if(any(b%sorbed_matrix_mass/=d%sorbed_matrix_mass).or.any(b%age_amount/=d%age_amount).or. &
   b%pond_mass/=d%pond_mass.or.b%aquifer_mass/=d%aquifer_mass.or.b%age_pond_previous_concentration/=d%age_pond_previous_concentration)error stop 'companion drift'
 end subroutine
end program
