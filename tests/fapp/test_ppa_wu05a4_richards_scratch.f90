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
  call reset_reference_workspace(ws)
  ws%dfdh_main=1
  input%matrix_top=-9; input%matrix_level=999
  key%evaluation=2
  call apply_saturated_reference_scratch(input,[-0.5_real64,0.25_real64],1.0_real64,key, &
      generation,.true.,ws,used,storage,ok,pond=0.0_real64)
  call check(ok,19)
  call check(abs(ws%residual(2)+1.0_real64/6)<1.e-14_real64,20)
  call check(abs(ws%dfdh_main(2)-11.0_real64/9)<1.e-14_real64,21)
  call copy_reference_transfer(ws,used,key,amount,ok)
  call check(ok,22)
  call check(abs(storage-input%storage+sum(amount))<1.e-14_real64,23)
  call check(input%matrix_top==-9.and.abs(input%matrix_level-999)<1.e-14_real64,24)
  key%evaluation=3
  call apply_saturated_reference_scratch(input,[-0.5_real64,-0.25_real64],1.0_real64,key, &
      generation,.true.,ws,used,storage,ok,pond=0.0_real64)
  call check(.not.ok,25)
  call check(abs(ws%residual(2)+1.0_real64/6)<1.e-14_real64,26)
  call check(abs(ws%dfdh_main(2)-11.0_real64/9)<1.e-14_real64,27)
  call copy_reference_transfer(ws,used,key,amount,ok)
  call check(.not.ok.and..not.allocated(amount),28)
  call reset_reference_workspace(ws)
  ws%dfdh_main=7
  key%evaluation=4
  call apply_saturated_reference_residual(input,[-0.5_real64,0.25_real64],0.0_real64,1.0_real64, &
      key,generation,ws,used,storage,ok)
  call check(ok,29)
  call check(maxval(abs(ws%dfdh_main-7))<1.e-14_real64,30)
  call check(abs(ws%residual(2)+1.0_real64/6)<1.e-14_real64,31)
  ! Rebuilding the ordinary Jacobian happens later. Altering physical input
  ! here must not affect the derivative already captured by the residual.
  input%resistance_inverse=99
  ws%dfdh_main=1
  call apply_reference_trial_diagonal(ws,used,key,.true.,ok)
  call check(ok,32)
  call check(abs(ws%dfdh_main(2)-11.0_real64/9)<1.e-14_real64,33)
  call check(abs(ws%residual(2)+1.0_real64/6)<1.e-14_real64,34)
  ws%dfdh_main=2
  call apply_reference_trial_diagonal(ws,used,key,.false.,ok)
  call check(ok.and.maxval(abs(ws%dfdh_main-2))<1.e-14_real64,35)
  call copy_reference_transfer(ws,used,key,amount,ok)
  call check(ok,36)
  call check(abs(storage-input%storage+sum(amount))<1.e-14_real64,37)
  key%evaluation=5
  call apply_reference_trial_diagonal(ws,used,key,.true.,ok)
  call check(.not.ok.and.maxval(abs(ws%dfdh_main-2))<1.e-14_real64,38)
  key%evaluation=4
  call copy_reference_transfer(ws,used,key,amount,ok)
  call check(.not.ok.and..not.allocated(amount),39)
  input%resistance_inverse=0.25_real64
  ws%residual=0
  call apply_saturated_reference_residual(input,[-0.5_real64,0.25_real64],0.0_real64,1.0_real64, &
      key,generation,ws,used,storage,ok)
  call check(ok,40)
  call initialize_reference_workspace(ws,2)
  ws%dfdh_main=3
  call apply_reference_trial_diagonal(ws,used,key,.true.,ok)
  call check(.not.ok.and.maxval(abs(ws%dfdh_main-3))<1.e-14_real64,41)
  generation=ws%generation
  call apply_saturated_reference_residual(input,[-0.5_real64,0.25_real64],0.0_real64,1.0_real64, &
      key,generation,ws,used,storage,ok)
  call check(ok,42)
  ws%dfdh_main=[3.0_real64]
  call apply_reference_trial_diagonal(ws,used,key,.true.,ok)
  call check(.not.ok.and.abs(ws%dfdh_main(1)-3)<1.e-14_real64,43)
  call copy_reference_transfer(ws,used,key,amount,ok)
  call check(.not.ok.and..not.allocated(amount),44)
  ws%residual=0
  call apply_saturated_reference_residual(input,[-0.5_real64,0.25_real64],0.0_real64,1.0_real64, &
      key,generation,ws,used,storage,ok)
  call check(ok,45)
  key%evaluation=5
  call apply_saturated_reference_residual(input,[-0.5_real64,-0.25_real64],0.0_real64,1.0_real64, &
      key,generation,ws,used,storage,ok)
  call check(.not.ok.and.abs(ws%residual(2)+1.0_real64/6)<1.e-14_real64,46)
  call copy_reference_transfer(ws,used,key,amount,ok)
  call check(.not.ok.and..not.allocated(amount),47)
  call release_reference_workspace(ws)
  call copy_reference_transfer(ws,used,key,amount,ok)
  call check(.not.ok,18)
  call run(generation)
  call check(.not.ok,11)
  print '(a)','PPA_WU05A4_REFERENCE_SCRATCH_BINDING=PASS'
  print '(a)','PPA_WU05A4_REFERENCE_SCRATCH_GENERATION_POISON=PASS'
  print '(a)','PPA_WU05A4_REFERENCE_TRANSFER_LIFETIME=PASS'
  print '(a)','PPA_WU05A4_REFERENCE_HEAD_DERIVED_ASSEMBLY=PASS'
  print '(a)','PPA_WU05A4_REFERENCE_SPLIT_CALLBACKS=PASS'
  call nonlinear_callback_sequence()
  print '(a)','PPA_WU05A4_REDUCED_NONLINEAR_CALLBACK_RETRY=PASS'
contains
  ! Manufactured scalar matrix residual, NOT the full Richards equation.
  ! The macro part is the real bounded evaluator, including head-derived caps.
  subroutine nonlinear_callback_sequence()
    type(reference_richards_workspace_t),allocatable::trial_ws
    type(reference_trial_transfer)::capture
    type(macro_trial_key)::trial_key,old_key
    real(real64)::h,dt,q,expected,trial_store,step
    real(real64),allocatable::transfer(:)
    logical::valid,converged
    integer::attempt,iteration
    allocate(trial_ws)
    call initialize_reference_workspace(trial_ws,2)
    do attempt=1,3
      dt=0.5_real64*2.0_real64**(attempt-1)
      trial_key=macro_trial_key(7_int64,0_int64,int(attempt,int64),1_int64)
      call discard_reference_transfer(capture)
      ! A rejected head trial must not advance the immutable beginning store.
      trial_ws%residual=0
      call apply_saturated_reference_residual(input,[-0.5_real64,-0.25_real64],0.0_real64,dt, &
          trial_key,trial_ws%generation,trial_ws,capture,trial_store,valid)
      call check(.not.valid,101)
      h=0.25_real64; converged=.false.
      do iteration=1,100
        trial_key%evaluation=int(iteration+1,int64)
        trial_ws%residual=[0.0_real64,h-0.2_real64]
        call apply_saturated_reference_residual(input,[-0.5_real64,h],0.0_real64,dt, &
            trial_key,trial_ws%generation,trial_ws,capture,trial_store,valid)
        call check(valid,102)
        ! Independent analytic rate for this grid: Darcy outflow, limited by
        ! initial store minus the head-derived groundwater inventory.
        q=min(0.25_real64*(1-h),0.125_real64/((h+0.5_real64)*dt))
        call check(abs(trial_ws%residual(2)-(h-0.2_real64-q))<1.e-14_real64,103)
        if(abs(trial_ws%residual(2))<1.e-12_real64)then
          converged=.true.; exit
        end if
        trial_ws%dfdh_main=1
        call apply_reference_trial_diagonal(trial_ws,capture,trial_key,.true.,valid)
        call check(valid,104)
        step=trial_ws%residual(2)/trial_ws%dfdh_main(2)
        h=h-step
      end do
      call check(converged,105)
      if(attempt==1)then
        expected=0.36_real64
      else
        expected=(-0.3_real64+sqrt(0.49_real64+0.5_real64/dt))/2
      end if
      call check(abs(h-expected)<2.e-12_real64,106)
      ! Account the last residual's actual captured amount; no reevaluation.
      call copy_reference_transfer(trial_ws,capture,trial_key,transfer,valid)
      call check(valid,107)
      call check(abs(sum(transfer)-q*dt)<1.e-14_real64,108)
      call check(abs(trial_store-input%storage+sum(transfer))<1.e-14_real64,109)
      call check(abs(input%storage-0.375_real64)<1.e-14_real64,110)
      old_key=trial_key
      old_key%attempt=old_key%attempt+1
      call copy_reference_transfer(trial_ws,capture,old_key,transfer,valid)
      call check(.not.valid.and..not.allocated(transfer),111)
    end do
    call discard_reference_transfer(capture)
    call release_reference_workspace(trial_ws)
  end subroutine

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
