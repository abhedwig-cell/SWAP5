module mod_gash_source_window_binding
 use, intrinsic::iso_fortran_env,only:int64,real64
 use mod_gash_interception_process
 use mod_interception_source_window_runtime
 implicit none
 private
 integer,parameter,public::GASH_BIND_OK=0,GASH_BIND_PROCESS_REJECTED=1,GASH_BIND_RUNTIME_REJECTED=2
 public::initialize_gash_source_window
contains
 subroutine initialize_gash_source_window(id,t0,t1,input,result,window,progress,status)
  integer(int64),intent(in)::id
  real(real64),intent(in)::t0,t1
  type(gash_source_window_input_t),intent(in)::input
  type(gash_source_window_result_t),intent(out)::result
  type(interception_source_window_t),intent(out)::window
  type(interception_progress_t),intent(out)::progress
  integer,intent(out)::status
  integer::s
  call evaluate_gash_source_window(input,result,s)
  if(s/=GASH_OK)then;status=GASH_BIND_PROCESS_REJECTED;return;end if
  call initialize_interception_window(id,t0,t1,result%interception_cm,window,s)
  if(s/=INTWIN_OK)then;status=GASH_BIND_RUNTIME_REJECTED;return;end if
  call initialize_interception_progress(window,progress,s)
  if(s/=INTWIN_OK)then;status=GASH_BIND_RUNTIME_REJECTED;return;end if
  status=GASH_BIND_OK
 end subroutine
end module mod_gash_source_window_binding
