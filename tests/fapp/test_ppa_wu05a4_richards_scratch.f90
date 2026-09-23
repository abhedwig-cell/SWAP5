program test_scratch_binding
  use, intrinsic::iso_fortran_env,only:real64,int64
  use mod_reference_richards_workspace
  use mod_ppa_wu05a4_richards_scratch_binding
  use mod_ppa_wu05a4_saturated_trial
  use mod_ppa_wu05a4_trial_exchange
  implicit none
  type(reference_richards_workspace_t)::ws
  type(saturated_domain_inputs)::input
  type(reference_trial_transfer)::used
  type(macro_trial_key)::key
  real(real64)::storage
  real(real64),allocatable::amount(:)
  integer(int64)::generation
  logical::ok
  input%z=[-0.5_real64,-1.5_real64]; input%dz=[1.0_real64,1.0_real64]
  input%volume=[0.25_real64,0.25_real64]; input%resistance_inverse=[0.25_real64,0.25_real64]
  input%matrix_top=2; input%pore_saturated_top=1; input%saturated_fraction=0.5_real64
  input%bottom=-2; input%matrix_level=-1; input%pore_level=-0.5_real64; input%storage=0.375_real64
  key=macro_trial_key(6_int64,0_int64,1_int64,1_int64)
  call initialize_reference_workspace(ws,2)
  generation=ws%generation
  ws%dfdh_main=1; ws%dfdh_lower=3; ws%dfdh_upper=4; ws%source=5; ws%sink=6
  call run(generation)
  call check(ok,1)
  call check(abs(ws%residual(2)+0.125_real64)+abs(ws%dfdh_main(2)-1.25_real64)<1.e-14_real64,2)
  call check(maxval(abs(ws%source-5))+maxval(abs(ws%sink-6))<1.e-14_real64,3)
  call check(maxval(abs(ws%dfdh_lower-3))+maxval(abs(ws%dfdh_upper-4))<1.e-14_real64,4)
  call copy_reference_transfer(ws,used,key,amount,ok)
  call check(ok,5)
  call check(abs(storage-input%storage+sum(amount))<1.e-14_real64,6)
  call initialize_reference_workspace(ws,2)
  call copy_reference_transfer(ws,used,key,amount,ok)
  call check(.not.ok.and..not.allocated(amount),12)
  call run(generation)
  call check(.not.ok.and.maxval(abs(ws%residual))<1.e-14_real64,7)
  call copy_reference_transfer(ws,used,key,amount,ok)
  call check(.not.ok.and..not.allocated(amount),8)
  generation=ws%generation
  call poison_reference_workspace(ws)
  call run(generation)
  call check(.not.ok.and.ws%poisoned,9)
  call reset_reference_workspace(ws)
  ws%dfdh_main=1
  call run(generation)
  call check(ok,10)
  call poison_reference_workspace(ws)
  call copy_reference_transfer(ws,used,key,amount,ok)
  call check(.not.ok.and..not.allocated(amount),13)
  call reset_reference_workspace(ws)
  call copy_reference_transfer(ws,used,key,amount,ok)
  call check(.not.ok,14)
  ws%dfdh_main=1
  call run(generation)
  call check(ok,15)
  call discard_reference_transfer(used)
  call copy_reference_transfer(ws,used,key,amount,ok)
  call check(.not.ok,16)
  call reset_reference_workspace(ws)
  ws%dfdh_main=1
  call run(generation)
  call check(ok,17)
  call release_reference_workspace(ws)
  call copy_reference_transfer(ws,used,key,amount,ok)
  call check(.not.ok,18)
  call run(generation)
  call check(.not.ok,11)
  print '(a)','PPA_WU05A4_REFERENCE_SCRATCH_BINDING=PASS'
  print '(a)','PPA_WU05A4_REFERENCE_SCRATCH_GENERATION_POISON=PASS'
  print '(a)','PPA_WU05A4_REFERENCE_TRANSFER_LIFETIME=PASS'
contains
  subroutine run(expected)
    integer(int64),intent(in)::expected
    call apply_saturated_reference_scratch(input,[-0.5_real64,0.5_real64],1.0_real64,key, &
        expected,.true.,ws,used,storage,ok)
  end subroutine
  subroutine check(condition,code)
    logical,intent(in)::condition
    integer,intent(in)::code
    if(condition)return
    print *,code
    error stop 1
  end subroutine
end program
