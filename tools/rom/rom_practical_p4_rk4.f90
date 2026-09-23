! Research only: frozen P3 S4/G8 equations, classical RK4, no state clipping.
program rom_practical_p4
  use iso_fortran_env, only: real64, int64
  use ieee_arithmetic, only: ieee_is_finite
  implicit none
  integer, parameter :: MAXN=8, NDAYS=60
  real(real64), parameter :: LEDGER_GATE=1.0e-8_real64
  character(len=256) :: purpose, material, paramfile, arg, mode, history
  real(real64) :: tr,ts,alpha,nvg,mvg,ks,lambda,dt
  namelist /material_parameters/ tr,ts,alpha,nvg,ks,lambda
  integer :: n,day,hidx,sub,s,ios,u,stage,j,argc
  integer(int64) :: rhs_evals
  real(real64) :: dz(MAXN),theta(MAXN),cumtop,cumbot,k0,psi0,maxledger
  real(real64) :: storage0,ledger,prevbot,initial_theta,theta_probe(MAXN)
  real(real64) :: dprobe(MAXN),qtprobe,qbprobe,psiprobe(MAXN),kprobe(MAXN)
  real(real64) :: c0,c1,wall_s
  integer(int64) :: tick0,tick1,tickrate
  logical :: ok
  argc=command_argument_count()
  if(argc<4.or.argc>5) error stop 'usage: purpose material parameters.nml dt [probe]'
  call get_command_argument(1,purpose)
  call get_command_argument(2,material)
  call get_command_argument(3,paramfile)
  call get_command_argument(4,arg)
  read(arg,*,iostat=ios) dt
  if(ios/=0) error stop 'invalid dt'
  if (.not.ieee_is_finite(dt)) error stop 'nonfinite dt'
  if(abs(dt-0.01_real64)>1.0e-15_real64.and.abs(dt-0.005_real64)>1.0e-15_real64) &
    error stop 'P4 only authorizes 0.01 and 0.005 day'
  sub=nint(1.0_real64/dt)
  mode='run'
  if(argc==5)call get_command_argument(5,mode)
  if(trim(mode)/='run'.and.trim(mode)/='probe')error stop 'invalid mode'
  open(newunit=u,file=trim(paramfile),status='old',action='read',iostat=ios)
  if(ios/=0) error stop 'missing material namelist'
  read(u,nml=material_parameters,iostat=ios)
  close(u)
  if(ios/=0) error stop 'invalid material namelist'
  if(.not.all(ieee_is_finite([tr,ts,alpha,nvg,ks,lambda])))error stop 'nonfinite parameters'
  if(ts<=tr.or.alpha<=0.0_real64.or.nvg<=1.0_real64.or.ks<=0.0_real64)error stop 'invalid parameters'
  mvg=1.0_real64-1.0_real64/nvg
  dz=0.0_real64
  select case(trim(purpose))
  case('SURF_P')
    n=4; dz(1:n)=[20.0_real64,20.0_real64,40.0_real64,80.0_real64]
  case('GW_LB')
    n=8
    dz=[80.0_real64,20.0_real64,20.0_real64,10.0_real64,10.0_real64,10.0_real64,5.0_real64,5.0_real64]
  case default
    error stop 'invalid purpose'
  end select
  rhs_evals=0;day=0;s=0;stage=0
  if(trim(mode)=='probe')then
    read(*,*,iostat=ios)hidx,day
    if(ios/=0.or.hidx<1.or.hidx>2.or.day<1.or.day>60)error stop 'invalid probe index'
    call initialize(hidx)
    theta_probe=0.0_real64
    read(*,*,iostat=ios)theta_probe(1:n)
    if(ios/=0)error stop 'invalid probe state'
    call deriv(theta_probe,day,dprobe,qtprobe,qbprobe,ok)
    if(.not.ok)call fail('PROBE_DOMAIN')
    do j=1,n
      call psi_k_scalar(theta_probe(j),psiprobe(j),kprobe(j),ok)
      if(.not.ok)call fail('PROBE_CONSTITUTIVE')
      write(*,'(a,i0,3(a,es25.17))') &
        'P4_PROBE|LAYER=',j,'|PSI=',psiprobe(j),'|K=',kprobe(j),'|DTH=',dprobe(j)
    enddo
    write(*,'(a,es25.17,a,es25.17)')'P4_PROBE_BOUNDARY|QT=',qtprobe,'|QB=',qbprobe
    stop
  endif
  call cpu_time(c0)
  call system_clock(tick0,tickrate)
  do hidx=1,2
    call initialize(hidx)
    do day=1,NDAYS
      do s=1,sub
        call rk4_step()
        ledger=sum(theta(1:n)*dz(1:n))-storage0-(cumtop-cumbot)
        if(.not.ieee_is_finite(ledger))call fail('NONFINITE_LEDGER')
        maxledger=max(maxledger,abs(ledger))
        if(maxledger>LEDGER_GATE)call fail('WATER_LEDGER')
      enddo
      call emit()
    enddo
    write(*,'(a,a,a,es25.17,a,i0)') &
      'P4_HISTORY_PASS|HISTORY=',trim(history),'|MAX_LEDGER=',maxledger,'|RHS_EVALS=',rhs_evals
  enddo
  call cpu_time(c1)
  call system_clock(tick1)
  wall_s=real(tick1-tick0,real64)/real(tickrate,real64)
  write(*,'(a,es25.17,a,es25.17)')'P4_TIMING|CPU_S=',c1-c0,'|WALL_S=',wall_s
  write(*,'(a)')'P4_EXECUTION_COMPLETE=PASS'
contains
  subroutine initialize(ih)
    integer,intent(in)::ih
    real(real64)::se
    if(trim(purpose)=='SURF_P')then
      history=merge('SD01','SD02',ih==1)
      se=merge(0.72_real64,0.86_real64,ih==1)
    else
      history=merge('GD01','GD02',ih==1)
      se=merge(0.72_real64,0.88_real64,ih==1)
    endif
    initial_theta=tr+se*(ts-tr)
    theta=0.0_real64;theta(1:n)=initial_theta
    call psi_k_scalar(initial_theta,psi0,k0,ok)
    if(.not.ok)call fail('INITIAL_DOMAIN')
    storage0=sum(theta(1:n)*dz(1:n))
    cumtop=0.0_real64;cumbot=0.0_real64;prevbot=0.0_real64;maxledger=0.0_real64
    rhs_evals=0
  end subroutine
  subroutine psi_k_scalar(th,psi,k,valid)
    real(real64),intent(in)::th
    real(real64),intent(out)::psi,k
    logical,intent(out)::valid
    real(real64)::se,term
    valid=.false.;psi=0.0_real64;k=0.0_real64
    if(.not.ieee_is_finite(th))return
    se=(th-tr)/(ts-tr)
    if(se<=0.0_real64.or.se>=1.0_real64)return
    psi=(se**(-1.0_real64/mvg)-1.0_real64)**(1.0_real64/nvg)/alpha
    term=1.0_real64-(1.0_real64-se**(1.0_real64/mvg))**mvg
    k=ks*se**lambda*term*term
    valid=ieee_is_finite(psi).and.ieee_is_finite(k).and.psi>0.01_real64.and.k>=0.0_real64
  end subroutine
  subroutine deriv(th,iday,dth,qt,qb,valid)
    real(real64),intent(in)::th(MAXN)
    integer,intent(in)::iday
    real(real64),intent(out)::dth(MAXN),qt,qb
    logical,intent(out)::valid
    real(real64)::psi(MAXN),kk(MAXN),qint(MAXN),kij,psib,grad
    integer::l
    logical::v
    rhs_evals=rhs_evals+1
    valid=.false.;dth=0.0_real64;qint=0.0_real64;qt=0.0_real64;qb=0.0_real64
    do l=1,n
      call psi_k_scalar(th(l),psi(l),kk(l),v)
      if(.not.v)return
    enddo
    do l=1,n-1
      kij=(dz(l+1)*kk(l)+dz(l)*kk(l+1))/(dz(l)+dz(l+1))
      qint(l)=kij*(1.0_real64+2.0_real64*(psi(l+1)-psi(l))/(dz(l)+dz(l+1)))
    enddo
    qt=k0
    if(trim(purpose)=='SURF_P')then
      if(history=='SD01')then
        if(iday<=15)then;qt=k0+0.12_real64
        else if(iday<=30)then;qt=k0-0.08_real64
        else if(iday<=45)then;qt=k0+0.06_real64
        else;qt=k0-0.04_real64;endif
      else
        if(iday<=20)then;qt=k0-0.06_real64
        else if(iday<=30)then;qt=k0+0.10_real64
        else if(iday<=50)then;qt=k0-0.03_real64
        else;qt=k0+0.08_real64;endif
      endif
      qb=k0
    else
      ! P3 HOLD means prescribed flux k0, NOT prescribed head psi0.
      if((history=='GD01'.and.iday>40).or.(history=='GD02'.and.iday>45))then
        qb=k0
      else
        if(history=='GD01')then
          psib=merge(0.97_real64,1.03_real64,iday<=20)*psi0
        else
          psib=merge(1.03_real64,0.97_real64,iday<=15)*psi0
        endif
        grad=1.0_real64+2.0_real64*(psib-psi(n))/dz(n)
        qb=kk(n)*grad
      endif
    endif
    dth(1)=(qt-qint(1))/dz(1)
    do l=2,n-1
      dth(l)=(qint(l-1)-qint(l))/dz(l)
    enddo
    dth(n)=(qint(n-1)-qb)/dz(n)
    valid=all(ieee_is_finite(dth(1:n))).and.ieee_is_finite(qt).and.ieee_is_finite(qb)
  end subroutine
  subroutine rk4_step()
    real(real64)::k1(MAXN),k2(MAXN),k3(MAXN),k4(MAXN),tmp(MAXN),next(MAXN)
    real(real64)::qt1,qb1,qt2,qb2,qt3,qb3,qt4,qb4,pp,kp,newtop,newbot
    integer::l
    stage=1;call deriv(theta,day,k1,qt1,qb1,ok)
    if(.not.ok)call fail('STAGE_DOMAIN')
    tmp=theta+0.5_real64*dt*k1
    stage=2;call deriv(tmp,day,k2,qt2,qb2,ok)
    if(.not.ok)call fail('STAGE_DOMAIN')
    tmp=theta+0.5_real64*dt*k2
    stage=3;call deriv(tmp,day,k3,qt3,qb3,ok)
    if(.not.ok)call fail('STAGE_DOMAIN')
    tmp=theta+dt*k3
    stage=4;call deriv(tmp,day,k4,qt4,qb4,ok)
    if(.not.ok)call fail('STAGE_DOMAIN')
    next=theta+dt*(k1+2.0_real64*k2+2.0_real64*k3+k4)/6.0_real64
    stage=5
    do l=1,n
      call psi_k_scalar(next(l),pp,kp,ok)
      if(.not.ok)call fail('ACCEPTED_STATE_DOMAIN')
    enddo
    newtop=cumtop+dt*(qt1+2.0_real64*qt2+2.0_real64*qt3+qt4)/6.0_real64
    newbot=cumbot+dt*(qb1+2.0_real64*qb2+2.0_real64*qb3+qb4)/6.0_real64
    ledger=sum(next(1:n)*dz(1:n))-storage0-(newtop-newbot)
    if(.not.ieee_is_finite(ledger))call fail('NONFINITE_LEDGER')
    if(abs(ledger)>LEDGER_GATE)call fail('WATER_LEDGER')
    theta=next;cumtop=newtop;cumbot=newbot
  end subroutine
  subroutine fail(reason)
    character(len=*),intent(in)::reason
    write(*,'(a,a,a,a,3(a,i0),a,i0)')'P4_FAILURE|REASON=',reason,'|HISTORY=',trim(history), &
      '|DAY=',day,'|SUBSTEP=',s,'|STAGE=',stage,'|RHS_EVALS=',rhs_evals
    error stop 11
  end subroutine
  subroutine emit()
    integer::l
    real(real64)::qday
    qday=cumbot-prevbot;prevbot=cumbot
    write(*,'(a,a,a,i0,6(a,es25.17))')'P4_STATE|HISTORY=',trim(history),'|DAY=',day, &
      '|TOTAL=',sum(theta(1:n)*dz(1:n)),'|S20=',integral(20.0_real64), &
      '|S40=',integral(40.0_real64),'|S80=',integral(80.0_real64),'|CUMBOT=',cumbot,'|QBOT=',qday
    do l=1,n
      write(*,'(a,a,a,i0,a,i0,a,es25.17)') &
        'P4_LAYER|HISTORY=',trim(history),'|DAY=',day,'|LAYER=',l,'|THETA=',theta(l)
    enddo
  end subroutine
  real(real64) function integral(depth) result(v)
    real(real64),intent(in)::depth
    real(real64)::z,w
    integer::l
    v=0.0_real64;z=0.0_real64
    do l=1,n
      w=max(0.0_real64,min(depth,z+dz(l))-z)
      v=v+theta(l)*w;z=z+dz(l)
      if(z>=depth)exit
    enddo
  end function
end program
