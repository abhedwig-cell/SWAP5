program test_saturated_trial
  use, intrinsic::iso_fortran_env,only:real64,int64
  use mod_ppa_wu05a4_saturated_trial
  use mod_ppa_wu05a4_trial_exchange
  use mod_ppa_wu05a4_matrix_level
  implicit none
  type(saturated_domain_inputs)::input
  type(macro_exchange_evaluation)::e
  type(macro_trial_key)::key
  type(macro_used_exchange)::slot
  real(real64)::storage,residual(2),diagonal(2),level
  integer::zone_top
  real(real64),allocatable::amount(:)
  logical::ok
  input%z=[-0.5_real64,-1.5_real64]; input%dz=[1.0_real64,1.0_real64]
  input%volume=[0.25_real64,0.25_real64]; input%resistance_inverse=[0.25_real64,0.25_real64]
  input%matrix_top=2; input%pore_saturated_top=1; input%saturated_fraction=0.5_real64
  input%bottom=-2; input%matrix_level=-1; input%pore_level=-0.5_real64; input%storage=0.375_real64
  call matrix_level_from_heads([-0.5_real64,0.5_real64],input%z,input%dz,0.0_real64,level,zone_top,ok)
  call check(ok.and.abs(level+1.0_real64)<1.e-14_real64.and.zone_top==1,37)
  ! Source nodlev puts a water level exactly on a cell bottom in that upper cell.
  call matrix_level_from_heads([-0.5_real64,0.25_real64],input%z,input%dz,0.0_real64,level,zone_top,ok)
  call check(ok.and.abs(level+7.0_real64/6.0_real64)<1.e-14_real64.and.zone_top==2,38)
  call matrix_level_from_heads([-0.5_real64,-0.25_real64],input%z,input%dz,0.0_real64,level,zone_top,ok)
  call check(ok.and.abs(level-999.0_real64)<1.e-14_real64.and.zone_top==3,39)
  call matrix_level_from_heads([0.5_real64,-0.25_real64],input%z,input%dz,0.0_real64,level,zone_top,ok)
  call check(.not.ok,40)
  call matrix_level_from_heads([0.5_real64,1.5_real64],input%z,input%dz,0.125_real64,level,zone_top,ok)
  call check(ok.and.abs(level-0.125_real64)<1.e-14_real64.and.zone_top==1,41)
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
  ! Repeated nonlinear evaluations are rebuilt from unchanged physical history.
  key%attempt=3; key%evaluation=1; residual=0
  call evaluate_saturated_residual(input,[-0.5_real64,0.5_real64],1.0_real64,key,residual,slot,storage,ok)
  call check(ok.and.abs(residual(2)+0.125_real64)<1.e-14_real64,12)
  key%evaluation=2; residual=0
  call evaluate_saturated_residual(input,[-0.5_real64,0.75_real64],1.0_real64,key,residual,slot,storage,ok)
  call check(ok.and.abs(residual(2)+0.0625_real64)<1.e-14_real64,13)
  call copy_matrix_transfer(slot,key,amount,ok)
  call check(ok,14)
  call check(abs(storage-input%storage+sum(amount))<1.e-14_real64,15)
  key%evaluation=1
  call copy_matrix_transfer(slot,key,amount,ok)
  call check(.not.ok.and..not.allocated(amount),16)
  key%evaluation=3; residual=7
  input%pore_level=-2
  call evaluate_saturated_residual(input,[-0.5_real64,0.5_real64],1.0_real64,key,residual,slot,storage,ok)
  call check(.not.ok.and.maxval(abs(residual-7))<1.e-14_real64,17)
  call copy_matrix_transfer(slot,key,amount,ok)
  call check(.not.ok.and..not.allocated(amount),18)
  key%evaluation=2
  call copy_matrix_transfer(slot,key,amount,ok)
  call check(.not.ok,19)
  input%pore_level=-0.5_real64
  key%evaluation=4; residual=0
  call evaluate_saturated_residual(input,[-0.5_real64,0.5_real64],1.0_real64,key,residual,slot,storage,ok)
  call check(ok.and.abs(residual(2)+0.125_real64)<1.e-14_real64,20)
  call check(abs(input%storage-0.375_real64)<1.e-14_real64,21)
  key%evaluation=5; residual=9
  call evaluate_saturated_residual(input,[-0.5_real64,0.5_real64],1.0_real64,key,residual(1:1),slot,storage,ok)
  call check(.not.ok.and.maxval(abs(residual-9))<1.e-14_real64,22)
  call check(abs(storage)<tiny(storage),23)
  key%evaluation=4
  call copy_matrix_transfer(slot,key,amount,ok)
  call check(.not.ok,24)
  input%storage=0.25_real64
  call prepare_saturated_trial(input,[-0.5_real64,0.5_real64],1.0_real64,key,e,storage,ok)
  call check(.not.ok.and..not.allocated(e%rate),25)
  input%storage=0.375_real64; input%z(1)=-0.25_real64
  call prepare_saturated_trial(input,[-0.5_real64,0.5_real64],1.0_real64,key,e,storage,ok)
  call check(.not.ok.and..not.allocated(e%rate),26)
  input%z(1)=-0.5_real64; input%bottom=-2.25_real64
  call prepare_saturated_trial(input,[-0.5_real64,0.5_real64],1.0_real64,key,e,storage,ok)
  call check(.not.ok.and..not.allocated(e%rate),27)
  input%bottom=-2; input%volume(1)=1.25_real64
  call prepare_saturated_trial(input,[-0.5_real64,0.5_real64],1.0_real64,key,e,storage,ok)
  call check(.not.ok.and..not.allocated(e%rate),28)
  input%volume(1)=0.25_real64
  call prepare_saturated_trial(input,[-0.5_real64,0.5_real64],1.0_real64,key,e,storage,ok)
  call check(ok.and.abs(storage-0.25_real64)<1.e-14_real64,29)
  key%attempt=4; key%evaluation=1; residual=0; diagonal=1
  call evaluate_saturated_system(input,[-0.5_real64,0.5_real64],1.0_real64,key,.true., &
      residual,diagonal,slot,storage,ok)
  call check(ok,30)
  call check(abs(residual(2)+0.125_real64)+abs(diagonal(2)-1.25_real64)<1.e-14_real64,31)
  key%evaluation=2; residual=7; diagonal=3
  call evaluate_saturated_system(input,[-0.5_real64,0.5_real64],1.0_real64,key,.true., &
      residual,diagonal(1:1),slot,storage,ok)
  call check(.not.ok.and.maxval(abs(residual-7))+maxval(abs(diagonal-3))<1.e-14_real64,32)
  call check(abs(storage)<tiny(storage),33)
  key%evaluation=1
  call copy_matrix_transfer(slot,key,amount,ok)
  call check(.not.ok.and..not.allocated(amount),34)
  key%evaluation=3; residual=0; diagonal=1
  call evaluate_saturated_system(input,[-0.5_real64,0.5_real64],1.0_real64,key,.false., &
      residual,diagonal,slot,storage,ok)
  call check(ok.and.maxval(abs(diagonal-1))<1.e-14_real64,35)
  call check(abs(residual(2)+0.125_real64)<1.e-14_real64,36)
  ! Ignore intentionally stale caller matrix metadata in the derived route.
  input%matrix_top=-9; input%matrix_level=999
  call prepare_saturated_from_heads(input,[-0.5_real64,0.5_real64],0.0_real64,1.0_real64, &
      key,e,storage,ok)
  call check(ok.and.abs(storage-0.25_real64)<1.e-14_real64,42)
  call check(abs(e%rate(2)-0.125_real64)<1.e-14_real64,43)
  call prepare_saturated_from_heads(input,[-0.5_real64,0.25_real64],0.0_real64,1.0_real64, &
      key,e,storage,ok)
  call check(ok.and.abs(storage-5.0_real64/24.0_real64)<1.e-14_real64,44)
  call check(abs(e%rate(2)-1.0_real64/6.0_real64)<1.e-14_real64,45)
  call check(abs(e%derivative(2)+2.0_real64/9.0_real64)<1.e-14_real64,46)
  call check(input%matrix_top==-9.and.abs(input%matrix_level-999.0_real64)<1.e-14_real64,47)
  call prepare_saturated_from_heads(input,[-0.5_real64,-0.25_real64],0.0_real64,1.0_real64, &
      key,e,storage,ok)
  call check(.not.ok.and..not.allocated(e%rate),48)
  call prepare_saturated_from_heads(input,[0.5_real64,-0.25_real64],0.0_real64,1.0_real64, &
      key,e,storage,ok)
  call check(.not.ok.and..not.allocated(e%rate),49)
  input%matrix_top=2; input%matrix_level=-1
  input%pore_level=-2
  call prepare_saturated_trial(input,[-0.5_real64,0.5_real64],1.0_real64,key,e,storage,ok)
  call check(.not.ok.and..not.allocated(e%rate),11)
  print '(a)','PPA_WU05A4_SATURATED_TRIAL_GEOMETRY_RATE_TANGENT=PASS'
  print '(a)','PPA_WU05A4_SATURATED_TRIAL_RETRY_FAIL_CLOSED=PASS'
  print '(a)','PPA_WU05A4_SATURATED_RESIDUAL_REEVALUATION=PASS'
  print '(a)','PPA_WU05A4_SATURATED_GEOMETRY_CONSISTENCY=PASS'
  print '(a)','PPA_WU05A4_SATURATED_SYSTEM_ATOMIC=PASS'
  print '(a)','PPA_WU05A4_MATRIX_LEVEL_HEAD_BRANCHES=PASS'
  print '(a)','PPA_WU05A4_DERIVED_MATRIX_TRIAL=PASS'
contains
  subroutine check(condition,code)
    logical,intent(in)::condition
    integer,intent(in)::code
    if(condition)return
    print *,code
    error stop 1
  end subroutine
end program
