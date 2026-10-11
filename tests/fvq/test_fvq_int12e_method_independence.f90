program test_fvq_int12e_method_independence
 use,intrinsic::iso_fortran_env,only:int64,real64
 use mod_detailed_interception_process
 implicit none
 type(detailed_interception_state_t)::a,b
 type(detailed_interception_trial_t)::ta,tb
 integer::s,i
 real(real64),parameter::rain(3)=[0.2d0,0.1d0,0.3d0],ew(3)=[1.5d0,2.0d0,1.0d0]
 real(real64)::sum_net_a,sum_net_b
 call initialize_detailed_interception_day(1_int64,a,s);call initialize_detailed_interception_day(2_int64,b,s)
 sum_net_a=0d0;sum_net_b=0d0
 do i=1,3
  ! representative SWINTER=1 and SWINTER=2 daily aggregates; record law must be method-neutral
  call prepare_detailed_interception_record(a,i,0.6d0,rain(i),0.09d0,0.51d0,1d0/3d0,ew(i),ta,s);call req(s==DETINT_OK,'A')
  call prepare_detailed_interception_record(b,i,0.6d0,rain(i),0.15d0,0.45d0,1d0/3d0,ew(i),tb,s);call req(s==DETINT_OK,'B')
  sum_net_a=sum_net_a+ta%net_rain_rate_cm_per_day/3d0
  sum_net_b=sum_net_b+tb%net_rain_rate_cm_per_day/3d0
  call accept_detailed_interception_record(a,ta,s);call accept_detailed_interception_record(b,tb,s)
 end do
 call req(abs(sum_net_a-0.51d0)<1d-14,'SWINTER1 rain closure')
 call req(abs(sum_net_b-0.45d0)<1d-14,'SWINTER2 rain closure')
 call req(a%next_record==4.and.b%next_record==4,'method-neutral cursor')
 print *,'F-VQ INT12-E METHOD-INDEPENDENT RECORD LAW PASS'
contains
 subroutine req(q,m);logical,intent(in)::q;character(*),intent(in)::m;if(.not.q)then;print *,m;error stop 1;end if;end subroutine
end program
