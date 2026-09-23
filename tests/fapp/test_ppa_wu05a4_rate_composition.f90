program test_rate_composition
  use, intrinsic::iso_fortran_env,only:real64,int64
  use mod_ppa_wu05a4_inflow_limit
  use mod_ppa_wu05a4_outflow_limit
  use mod_ppa_wu05a4_redistribution
  use mod_ppa_wu05a4_trial_exchange
  use mod_ppa_wu05a3_satflow_exchange
  use mod_ppa_wu05a3_satflow_derivative
  use mod_ppa_wu05a4_storage_bounds
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
  call check_generated_satflow()
  call check_geometry_bounds()
contains
  subroutine check_geometry_bounds()
    real(real64)::ground,minimum,limit,tmp,mx,rejected_top,toprate(2),qi(2),qm(2),sr(2),ur(2),rr(2)
    logical::valid
    call domain_storage_bounds(-2.0_real64,2,[1.0_real64,1.0_real64],[0.25_real64,0.5_real64], &
        0.75_real64,0.375_real64,-1.5_real64,-1.75_real64,.true.,ground,minimum,valid)
    call check(valid,30)
    call check(abs(ground-0.25_real64)+abs(minimum-0.125_real64)<tiny(ground),31)
    ! Geometry-derived minimum feeds the final outgoing availability calculation.
    call limit_domain_outflow(0.5_real64,0.5_real64,minimum-(0.375_real64-0.5_real64), &
        [0.0_real64,0.5_real64],[0.0_real64,0.0_real64],[0.0_real64,0.0_real64],limit,sr,ur,rr,valid)
    call check(valid.and.abs(sum(sr)*0.5_real64-0.25_real64)<tiny(ground),32)
    call domain_storage_bounds(-2.0_real64,2,[1.0_real64,1.0_real64],[0.25_real64,0.5_real64], &
        0.75_real64,0.125_real64,-1.5_real64,-1.75_real64,.false.,ground,minimum,valid)
    call check(valid.and.abs(minimum-0.125_real64)<tiny(ground),33)
    ! Matrix-only input is capped by the geometry-derived groundwater volume.
    call limit_domain_inflow(0.125_real64,0.75_real64,ground,0.5_real64,0.0_real64,0.0_real64, &
        0.0_real64,0.5_real64,0.0_real64,[0.0_real64,0.0_real64],[0.0_real64,0.5_real64], &
        limit,tmp,mx,rejected_top,toprate,qi,qm,valid)
    call check(valid.and.abs(mx-0.25_real64)+abs(sum(qm)*0.5_real64-0.125_real64)<tiny(ground),34)
    call domain_storage_bounds(-2.0_real64,2,[1.0_real64,1.0_real64],[0.25_real64,0.5_real64], &
        0.75_real64,0.375_real64,999.0_real64,-1.75_real64,.true.,ground,minimum,valid)
    call check(valid.and.abs(ground)+abs(minimum)<tiny(ground),35)
    call domain_storage_bounds(-2.0_real64,2,[0.0_real64,1.0_real64],[0.25_real64,0.5_real64], &
        0.75_real64,0.375_real64,999.0_real64,-2.0_real64,.false.,ground,minimum,valid)
    call check(.not.valid,36)
    print '(a)','PPA_WU05A4_GEOMETRY_STORAGE_BOUNDS_COMPOSITION=PASS'
  end subroutine
  subroutine check_generated_satflow()
    type(macro_exchange_evaluation)::e
    type(macro_used_exchange)::captured
    real(real64)::head,difference,potential,step,inpot,outpot,frac,tmp,mx,top_excess
    real(real64)::toprates(2),qin(1),qinternal(1),qout(1),quns(1),qrapid(1),hout(1),derivative(1)
    real(real64)::equation(1),diagonal(1),store,expected_rate,initial_store,expected_derivative,out_excess
    real(real64),allocatable::transfer_amount(:)
    integer::sign_case,k,status,limited
    logical::valid
    do limited=0,1
    do sign_case=1,2
      head=real(sign_case,real64)-0.5_real64
      expected_rate=(1.0_real64-head)*0.25_real64
      do k=1,4
        step=real(k,real64)/4
        initial_store=0.5_real64
        expected_rate=(1.0_real64-head)*0.25_real64
        if(limited==1) then
          initial_store=0.015625_real64
          if(sign_case==2) initial_store=1.0_real64-0.015625_real64
          expected_rate=sign(0.015625_real64/step,1.0_real64-head)
        end if
        expected_derivative=-expected_rate/(1.0_real64-head)
        ! Saturated pore head = reference_level-node_elevation = 1 cm.
        ! Fixed geometry/conductance; no partial saturation or seepage branch.
        call ppa_wu05a3_satflow_exchange(head,0.0_real64,-1.0_real64,1.0_real64, &
            0.0_real64,0,0,1,1.0_real64,0.25_real64,0,1.0_real64,1.0_real64, &
            0.5_real64,1.0_real64,acos(-1.0_real64),1.0_real64,step,difference,potential,status)
        call check(status==PPA_WU05A3_SATFLOW_OK,10)
        inpot=max(potential,0.0_real64); outpot=max(-potential,0.0_real64)
        call limit_domain_inflow(initial_store,1.0_real64,real(sign_case-1,real64),step,0.0_real64,0.0_real64, &
            0.0_real64,inpot,outpot,[0.0_real64],[inpot],frac,tmp,mx,top_excess,toprates,qinternal,qin,valid)
        call check(valid,11)
        ! Source minimum = min(VOLUNDR groundwater volume, initial storage).
        ! Groundwater volume is supplied as 0 (outgoing) or 1 (incoming).
        out_excess=max(0.0_real64,min(real(sign_case-1,real64),initial_store)-tmp)
        call limit_domain_outflow(step,outpot,out_excess,[outpot],[0.0_real64],[0.0_real64], &
            frac,qout,quns,qrapid,valid)
        call check(valid,12)
        call ppa_wu05a3_satflow_derivative(1,1,1,[head],[difference],qin,qout,[0.0_real64], &
            hout,derivative,status)
        call check(status==PPA_WU05A3_SATFLOW_DERIVATIVE_OK,13)
        call check(abs(derivative(1)-expected_derivative)<1.e-14_real64,14)
        e%key=macro_trial_key(2_int64,0_int64,int(sign_case+2*limited,int64),int(k,int64))
        e%dt=step; e%head=[head]; e%rate=qout-qin; e%derivative=derivative
        call check(abs(e%rate(1)-expected_rate)<1.e-14_real64,15)
        equation=0; diagonal=1
        call apply_macro_residual(e,e%key,e%head,equation,captured,valid)
        call check(valid,16)
        call apply_macro_diagonal(captured,e%key,.true.,diagonal,valid)
        call check(valid.and.abs(diagonal(1)-(1.0_real64-expected_derivative))<1.e-14_real64,17)
        call copy_matrix_transfer(captured,e%key,transfer_amount,valid)
        call check(valid,18)
        store=initial_store+(qin(1)-qout(1))*step
        call check(abs(store-initial_store+transfer_amount(1))<1.e-14_real64,19)
        if(limited==1) then
          call check(abs(store-real(sign_case-1,real64))<1.e-14_real64,20)
          call check(abs(abs(transfer_amount(1))-0.015625_real64)<1.e-14_real64,21)
        end if
      end do
    end do
    end do
    print '(a)','PPA_WU05A4_GENERATED_SATFLOW_RATE_DERIVATIVE=PASS'
    print '(a)','PPA_WU05A4_LIMITED_SATFLOW_SOURCE_DERIVATIVE=PASS'
  end subroutine
  subroutine check(condition,code)
    logical,intent(in)::condition
    integer,intent(in)::code
    if(condition)return
    print *,code
    error stop 1
  end subroutine
end program
