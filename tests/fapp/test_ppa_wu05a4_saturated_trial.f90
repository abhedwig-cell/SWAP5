program test_saturated_trial
  use, intrinsic::iso_fortran_env,only:real64,int64
  use mod_ppa_wu05a4_saturated_trial
  use mod_ppa_wu05a4_trial_exchange
  implicit none
  type(saturated_domain_inputs)::input
  type(macro_exchange_evaluation)::e
  type(macro_trial_key)::key
  type(macro_used_exchange)::slot
  real(real64)::storage,residual(2),diagonal(2)
  real(real64),allocatable::amount(:)
  logical::ok
  input%z=[-0.5_real64,-1.5_real64]; input%dz=[1.0_real64,1.0_real64]
  input%volume=[0.25_real64,0.25_real64]; input%resistance_inverse=[0.25_real64,0.25_real64]
  input%matrix_top=2; input%pore_saturated_top=1; input%saturated_fraction=0.5_real64
  input%bottom=-2; input%matrix_level=-1; input%pore_level=-0.5_real64; input%storage=0.375_real64
  key=macro_trial_key(5_int64,0_int64,1_int64,1_int64)
  call prepare_saturated_trial(input,[-0.5_real64,0.5_real64],1.0_real64,key,e,storage,ok)
  call check(ok,1)
  call check(abs(storage-0.25_real64)<1.e-14_real64,2)
  call check(maxval(abs(e%rate-[0.0_real64,0.125_real64]))<1.e-14_real64,3)
  residual=0; diagonal=1
  call apply_macro_residual(e,key,e%head,residual,slot,ok)
  call check(ok,4)
  call apply_macro_diagonal(slot,key,.true.,diagonal,ok)
  call check(ok.and.abs(diagonal(2)-1.25_real64)<1.e-14_real64,5)
  call copy_matrix_transfer(slot,key,amount,ok)
  call check(ok,6)
  call check(abs(storage-input%storage+sum(amount))<1.e-14_real64,7)
  key%attempt=2
  call prepare_saturated_trial(input,[-0.5_real64,0.5_real64],2.0_real64,key,e,storage,ok)
  call check(ok.and.abs(storage-0.25_real64)<1.e-14_real64,8)
  call check(abs(e%rate(2)-0.0625_real64)+abs(e%derivative(2)+0.125_real64)<1.e-14_real64,9)
  call check(abs(input%storage-0.375_real64)<1.e-14_real64,10)
  input%pore_level=-2
  call prepare_saturated_trial(input,[-0.5_real64,0.5_real64],1.0_real64,key,e,storage,ok)
  call check(.not.ok.and..not.allocated(e%rate),11)
  print '(a)','PPA_WU05A4_SATURATED_TRIAL_GEOMETRY_RATE_TANGENT=PASS'
  print '(a)','PPA_WU05A4_SATURATED_TRIAL_RETRY_FAIL_CLOSED=PASS'
contains
  subroutine check(condition,code)
    logical,intent(in)::condition
    integer,intent(in)::code
    if(condition)return
    print *,code
    error stop 1
  end subroutine
end program
