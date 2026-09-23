program test_rate_composition
  use, intrinsic::iso_fortran_env,only:real64,int64
  use mod_ppa_wu05a4_inflow_limit
  use mod_ppa_wu05a4_outflow_limit
  use mod_ppa_wu05a4_redistribution
  use mod_ppa_wu05a4_trial_exchange
  implicit none
  type(redistribution_candidate)::redistributed
  type(macro_exchange_evaluation)::evaluation
  type(macro_used_exchange)::used
  real(real64)::dt,storage(2),top(2),outgoing(2),temporary(2),deficit(2),excess(2),rejected(2)
  real(real64)::rates(2,2),incoming(1),matrix_in(1),f,maximum,sr(1),ur(1),rr(1),matrix_rate(2)
  real(real64)::final_storage(2),residual(2),balance
  real(real64),allocatable::amount(:)
  integer::i,j
  logical::ok
  do j=1,4
    dt=real(j,real64)/4
    storage=[0.875_real64,0.125_real64]
    top=[0.5_real64,0.125_real64]; outgoing=[0.0_real64,0.5_real64]
    do i=1,2
      call limit_domain_inflow(storage(i),1.0_real64,0.0_real64,dt,top(i),0.0_real64, &
          0.0_real64,0.0_real64,outgoing(i),[0.0_real64],[0.0_real64], &
          f,temporary(i),maximum,rejected(i),rates(:,i),incoming,matrix_in,ok)
      call check(ok,1)
      ! Source standard-domain minimum storage is zero in this fixture.
      excess(i)=max(0.0_real64,-temporary(i))
      deficit(i)=max(0.0_real64,1.0_real64-temporary(i))
    end do
    call redistribute_top_excess(dt,sum(rejected),sum(deficit),deficit/0.5_real64, &
        [0.5_real64,0.5_real64],deficit,excess,top,[0.0_real64,0.0_real64],rates(1,:),rates(2,:),redistributed)
    call check(redistributed%valid,2)
    call check(abs(redistributed%remaining)<tiny(dt),3)
    do i=1,2
      call limit_domain_outflow(dt,outgoing(i),redistributed%outflow_excess(i),[outgoing(i)], &
          [0.0_real64],[0.0_real64],f,sr,ur,rr,ok)
      call check(ok,4)
      matrix_rate(i)=sr(1)+ur(1)
      final_storage(i)=storage(i)+(redistributed%vertical_rate(i)+redistributed%lateral_rate(i) &
          -matrix_rate(i)-rr(1))*dt
    end do
    call check(maxval(abs(final_storage-[1.0_real64,0.125_real64]))<1.e-14_real64,5)
    evaluation%key=macro_trial_key(1_int64,0_int64,int(j,int64),1_int64)
    evaluation%dt=dt; evaluation%head=[1.0_real64,1.0_real64]
    evaluation%rate=matrix_rate; evaluation%derivative=[0.0_real64,0.0_real64]
    residual=0
    call apply_macro_residual(evaluation,evaluation%key,evaluation%head,residual,used,ok)
    call check(ok,6)
    call copy_matrix_transfer(used,evaluation%key,amount,ok)
    call check(ok,7)
    call check(maxval(abs(amount-[0.0_real64,0.5_real64]))<1.e-14_real64,8)
    ! Candidate macro storage + matrix transfer equals external top input.
    ! This is not a solved matrix storage balance or a canonical mass receipt.
    balance=sum(final_storage-storage)+sum(amount)-sum(top)
    call check(abs(balance)<1.e-14_real64,9)
  end do
  print '(a)','PPA_WU05A4_RATE_COMPOSITION_FOUR_DT=PASS'
  print '(a)','PPA_WU05A4_RATE_COMPOSITION_INTERNAL_TRANSFER=PASS'
contains
  subroutine check(condition,code)
    logical,intent(in)::condition
    integer,intent(in)::code
    if(condition)return
    print *,code
    error stop 1
  end subroutine
end program
