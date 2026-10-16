program test_int12e_sequence
 use,intrinsic::iso_fortran_env,only:int64,real64
 use mod_detailed_interception_process
 implicit none
 type(detailed_interception_state_t)::s,snap
 type(detailed_interception_restart_t)::rr
 type(detailed_interception_trial_t)::tr
 real(real64),parameter::rain(4)=[0.10d0,0.00d0,0.30d0,0.00d0],ew(4)=[2d0,2d0,1d0,4d0]
 real(real64)::oracle_rest,interc,w,total_wet
 integer::i,st
 call initialize_detailed_interception_day(77_int64,s,st);call req(st==DETINT_OK,'init')
 oracle_rest=0d0;total_wet=0d0
 do i=1,4
  call prepare_detailed_interception_record(s,i,0.4d0,rain(i),0.12d0,0.28d0,0.25d0,ew(i),tr,st);call req(st==DETINT_OK,'prepare')
  interc=oracle_rest+0.12d0*rain(i)/0.4d0
  if(ew(i)<0.0001d0)then;w=0d0;else;w=max(min(interc*10d0/ew(i)/0.25d0,1d0),0d0);end if
  oracle_rest=max(interc-w*0.25d0*ew(i)*0.1d0,0d0)
  call req(abs(tr%interc_cm-interc)<1d-14.and.abs(tr%wfrac-w)<1d-14.and.abs(tr%next_restint_cm-oracle_rest)<1d-14,'oracle')
  if(i==2)then
   snap=s
   call prepare_detailed_interception_record(s,i,0.4d0,rain(i),0.12d0,0.28d0,0.25d0,ew(i),tr,st)
   call req(s%next_record==snap%next_record.and.abs(s%restint_cm-snap%restint_cm)<tiny(1d0),'reject immutable')
  end if
  total_wet=total_wet+tr%wfrac
  call accept_detailed_interception_record(s,tr,st);call req(st==DETINT_OK,'accept')
  if(i==2)then
   snap=s
   call export_detailed_interception_restart(s,rr,st);call req(st==DETINT_OK,'restart export')
  end if
 end do
 call req(s%next_record==5,'cursor')
 ! restart-equivalence: serialized snapshot after record 2, replay records 3-4
 call restore_detailed_interception_restart(rr,s,st);call req(st==DETINT_OK,'restart restore')
 do i=3,4
  call prepare_detailed_interception_record(s,i,0.4d0,rain(i),0.12d0,0.28d0,0.25d0,ew(i),tr,st);call req(st==DETINT_OK,'restart prepare')
  call accept_detailed_interception_record(s,tr,st);call req(st==DETINT_OK,'restart accept')
 end do
 call req(s%next_record==5,'restart cursor')
 print *,'F-MIG431-INT12-E SEQUENCE ORACLE PASS'
contains
 subroutine req(q,m);logical,intent(in)::q;character(*),intent(in)::m;if(.not.q)then;print *,m;error stop 1;end if;end subroutine
end program
