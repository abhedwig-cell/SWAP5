program test_f_mig431_int12_p0
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_interception_source_window_runtime
  implicit none
  type(interception_source_window_t)::w,wr
  type(interception_progress_t)::p,pd,pr,pa,pb
  type(interception_trial_t)::tr,tr2
  type(interception_restart_t)::rst
  real(real64)::sum_parts,before,retry_amt,direct_amt,a1,a2,b,final_amount
  integer::s
  call initialize_interception_window(43112_int64,10.0_real64,11.0_real64,0.37_real64,w,s)
  call req(s==INTWIN_OK,"init")
  call initialize_interception_progress(w,p,s); call req(s==INTWIN_OK,"progress")

  sum_parts=0.0_real64
  call prepare_interception_trial(w,p,10.125_real64,tr,s); call req(s==INTWIN_OK,"part1")
  sum_parts=sum_parts+tr%apportioned_amount(); call accept_interception_trial(w,tr,p,s); call req(s==INTWIN_OK,"accept1")

  before=p%accepted_amount(w)
  call prepare_interception_trial(w,p,10.5_real64,tr,s); call req(s==INTWIN_OK,"reject candidate")
  call req(same_bits(p%accepted_amount(w),before),"rejected trial immutable")
  call prepare_interception_trial(w,p,10.25_real64,tr2,s); call req(s==INTWIN_OK,"retry")
  retry_amt=tr2%apportioned_amount()
  call accept_interception_trial(w,tr2,p,s); call req(s==INTWIN_OK,"retry accept")
  sum_parts=sum_parts+retry_amt

  call initialize_interception_progress(w,pd,s)
  call prepare_interception_trial(w,pd,10.125_real64,tr,s); call accept_interception_trial(w,tr,pd,s)
  call prepare_interception_trial(w,pd,10.25_real64,tr,s); direct_amt=tr%apportioned_amount()
  call req(same_bits(retry_amt,direct_amt),"failed then accepted equals direct")

  call export_interception_restart(w,p,rst,s); call req(s==INTWIN_OK,"restart export")
  call restore_interception_restart(rst,wr,pr,s); call req(s==INTWIN_OK,"restart restore")
  call req(same_bits(pr%accepted_amount(wr),p%accepted_amount(w)),"restart progress identity")
  call prepare_interception_trial(wr,pr,10.625_real64,tr,s); sum_parts=sum_parts+tr%apportioned_amount()
  call accept_interception_trial(wr,tr,pr,s); call req(s==INTWIN_OK,"post restart")
  call prepare_interception_trial(wr,pr,11.0_real64,tr,s); sum_parts=sum_parts+tr%apportioned_amount()
  call accept_interception_trial(wr,tr,pr,s); call req(s==INTWIN_OK,"final")
  call req(pr%complete(wr),"complete")
  final_amount=pr%accepted_amount(wr)
  call req(same_bits(pr%accepted_amount(wr),w%aggregate_value()),"aggregate exact endpoint")
  call req(abs(sum_parts-w%aggregate_value())<=8.0_real64*epsilon(1.0_real64),"partition conservation")

  call initialize_interception_progress(w,pa,s)
  call prepare_interception_trial(w,pa,10.4_real64,tr,s); a1=tr%apportioned_amount()
  call initialize_interception_window(99_int64,20.0_real64,21.0_real64,0.11_real64,wr,s)
  call initialize_interception_progress(wr,pb,s)
  call prepare_interception_trial(wr,pb,20.7_real64,tr2,s); b=tr2%apportioned_amount()
  call prepare_interception_trial(w,pa,10.4_real64,tr,s); a2=tr%apportioned_amount()
  call req(same_bits(a1,a2) .and. b>0.0_real64,"ABA deterministic")

  print '(a)',"F-MIG431-INT12-P0 PASS"
  print '(a,es24.16)',"aggregate=",p%accepted_amount(w)
  print '(a,es24.16)',"final=",final_amount
contains
  pure logical function same_bits(x,y)
    real(real64),intent(in)::x,y
    same_bits=transfer(x,0_int64)==transfer(y,0_int64)
  end function
  subroutine req(ok,label)
    logical,intent(in)::ok; character(len=*),intent(in)::label
    if(.not.ok) then; print '(a)',"FAIL "//trim(label); error stop 1; end if
  end subroutine
end program
