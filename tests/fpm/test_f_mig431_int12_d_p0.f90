program test_int12d_p0
 use, intrinsic::iso_fortran_env,only:int64,real64
 use mod_gash_interception_process
 use mod_gash_source_window_binding
 use mod_interception_source_window_runtime
 implicit none
 type(gash_source_window_input_t)::x
 type(gash_source_window_result_t)::g
 type(interception_source_window_t)::w,w2
 type(interception_progress_t)::p,p2
 type(interception_trial_t)::tr
 type(interception_restart_t)::rr
 real(real64)::a,total
 integer::s
 call tab(x%free_throughfall,[0d0],[0.2d0]);call tab(x%stemflow,[0d0],[0.1d0]);call tab(x%canopy_storage_cm,[0d0],[0.14d0])
 call tab(x%average_precipitation,[0d0],[2d0]);call tab(x%average_evaporation,[0d0],[0.2d0]);x%gross_rain_cm=2d0
 call initialize_gash_source_window(12_int64,0d0,1d0,x,g,w,p,s);call req(s==GASH_BIND_OK,'init')
 call prepare_interception_trial(w,p,0.3d0,tr,s);call req(s==INTWIN_OK,'trial1');a=tr%apportioned_amount()
 ! rejection: intentionally do not accept; progress must remain zero
 call req(p%accepted_amount(w)==0d0,'rejected immutable')
 call prepare_interception_trial(w,p,0.4d0,tr,s);call req(s==INTWIN_OK,'retry');call accept_interception_trial(w,tr,p,s);call req(s==INTWIN_OK,'accept retry')
 total=tr%apportioned_amount();call export_interception_restart(w,p,rr,s);call req(s==INTWIN_OK,'restart export')
 call restore_interception_restart(rr,w2,p2,s);call req(s==INTWIN_OK,'restart restore')
 call prepare_interception_trial(w2,p2,1d0,tr,s);call req(s==INTWIN_OK,'remainder');total=total+tr%apportioned_amount()
 call accept_interception_trial(w2,tr,p2,s);call req(s==INTWIN_OK.and.p2%complete(w2),'complete')
 call req(total==g%interception_cm,'bitwise aggregate closure')
 print *,'F-MIG431-INT12-D P0 COMPOSITION PASS'
contains
 subroutine tab(t,a,b);type(gash_table_t),intent(out)::t;real(real64),intent(in)::a(:),b(:);allocate(t%time(size(a)),t%value(size(b)));t%time=a;t%value=b;end subroutine
 subroutine req(q,m);logical,intent(in)::q;character(*),intent(in)::m;if(.not.q)then;print *,m;error stop 1;end if;end subroutine
end program
