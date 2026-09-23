program rom_practical_p4
  use iso_fortran_env, only: real64
  implicit none
  integer, parameter :: MAXN=8, NDAYS=60, SUB=100
  real(real64), parameter :: DT=0.01_real64, TOL=1.0e-12_real64
  character(len=16) :: purpose, material, history
  real(real64) :: tr,ts,alpha,nvg,mvg,ks,lambda
  integer :: n,i,hidx
  real(real64) :: dz(MAXN),theta(MAXN),theta0(MAXN),cumtop,cumbot,k0,psi0,maxledger
  real(real64) :: storage0, ledger
  if(command_argument_count()/=2) error stop 2
  call get_command_argument(1,purpose); call get_command_argument(2,material)
  call material_params(trim(material),tr,ts,alpha,nvg,ks,lambda)
  mvg=1.0_real64-1.0_real64/nvg
  if(trim(purpose)=='SURF_P')then
    n=4; dz=0.0_real64; dz(1:4)=[20.0_real64,20.0_real64,40.0_real64,80.0_real64]
  else if(trim(purpose)=='GW_LB')then
    n=8; dz=[80.0_real64,20.0_real64,20.0_real64,10.0_real64,10.0_real64,10.0_real64,5.0_real64,5.0_real64]
  else
    error stop 3
  endif
  do hidx=1,2
    if(trim(purpose)=='SURF_P')then
      history=merge('SD01','SD02',hidx==1)
      call init_se(merge(0.72_real64,0.86_real64,hidx==1))
    else
      history=merge('GD01','GD02',hidx==1)
      call init_se(merge(0.72_real64,0.88_real64,hidx==1))
    endif
    theta0=theta; storage0=sum(theta(1:n)*dz(1:n)); cumtop=0.;cumbot=0.;maxledger=0.
    call psi_k_scalar(theta(1),psi0,k0)
    do i=1,NDAYS
      call advance_day(i,trim(history))
      ledger=sum(theta(1:n)*dz(1:n))-storage0-(cumtop-cumbot)
      maxledger=max(maxledger,abs(ledger))
      call emit(i,trim(history))
    enddo
    write(*,'(a,a,a,es24.16,a,i0)') 'P4_HISTORY_PASS|HISTORY=',trim(history),'|MAX_LEDGER=',maxledger,'|RHS_EVALS=',NDAYS*SUB*4
  enddo
contains
  subroutine init_se(se)
    real(real64),intent(in)::se
    theta=0.; theta(1:n)=tr+se*(ts-tr)
  end subroutine
  subroutine psi_k_scalar(th,psi,k)
    real(real64),intent(in)::th
    real(real64),intent(out)::psi,k
    real(real64)::se,term
    se=(th-tr)/(ts-tr)
    if(.not.(se>0._real64.and.se<1._real64)) error stop 11
    psi=(se**(-1._real64/mvg)-1._real64)**(1._real64/nvg)/alpha
    term=1._real64-(1._real64-se**(1._real64/mvg))**mvg
    k=ks*se**lambda*term*term
    if(.not.(psi>0.01_real64.and.k>=0._real64)) error stop 12
  end subroutine
  subroutine deriv(th,day,hist,dth,qt,qb)
    real(real64),intent(in)::th(MAXN)
    integer,intent(in)::day
    character(len=*),intent(in)::hist
    real(real64),intent(out)::dth(MAXN),qt,qb
    real(real64)::psi(MAXN),kk(MAXN),qint(MAXN),kij,psib,grad
    integer::j
    dth=0.;qint=0.
    do j=1,n; call psi_k_scalar(th(j),psi(j),kk(j)); enddo
    do j=1,n-1
      kij=(dz(j+1)*kk(j)+dz(j)*kk(j+1))/(dz(j)+dz(j+1))
      qint(j)=kij*(1._real64+2._real64*(psi(j+1)-psi(j))/(dz(j)+dz(j+1)))
    enddo
    qt=k0
    if(trim(purpose)=='SURF_P')then
      if(hist=='SD01')then
        if(day<=15) qt=k0+0.12_real64
        if(day>15.and.day<=30) qt=k0-0.08_real64
        if(day>30.and.day<=45) qt=k0+0.06_real64
        if(day>45) qt=k0-0.04_real64
      else
        if(day<=20) qt=k0-0.06_real64
        if(day>20.and.day<=30) qt=k0+0.10_real64
        if(day>30.and.day<=50) qt=k0-0.03_real64
        if(day>50) qt=k0+0.08_real64
      endif
      qb=k0
    else
      psib=psi0
      if(hist=='GD01')then
        if(day<=20) psib=0.97_real64*psi0
        if(day>20.and.day<=40) psib=1.03_real64*psi0
      else
        if(day<=15) psib=1.03_real64*psi0
        if(day>15.and.day<=45) psib=0.97_real64*psi0
      endif
      if((hist=='GD01'.and.day>40).or.(hist=='GD02'.and.day>45))then
        qb=k0
      else
        grad=1._real64+2._real64*(psib-psi(n))/dz(n)
        qb=kk(n)*grad
      endif
    endif
    do j=1,n
      if(j==1)then; dth(j)=(qt-qint(j))/dz(j)
      else if(j==n)then; dth(j)=(qint(j-1)-qb)/dz(j)
      else; dth(j)=(qint(j-1)-qint(j))/dz(j); endif
    enddo
  end subroutine
  subroutine advance_day(day,hist)
    integer,intent(in)::day
    character(len=*),intent(in)::hist
    integer::s
    real(real64)::k1(MAXN),k2(MAXN),k3(MAXN),k4(MAXN),tmp(MAXN),qt1,qb1,qt2,qb2,qt3,qb3,qt4,qb4
    do s=1,SUB
      call deriv(theta,day,hist,k1,qt1,qb1)
      tmp=theta+0.5_real64*DT*k1; call deriv(tmp,day,hist,k2,qt2,qb2)
      tmp=theta+0.5_real64*DT*k2; call deriv(tmp,day,hist,k3,qt3,qb3)
      tmp=theta+DT*k3; call deriv(tmp,day,hist,k4,qt4,qb4)
      theta=theta+DT*(k1+2*k2+2*k3+k4)/6._real64
      cumtop=cumtop+DT*(qt1+2*qt2+2*qt3+qt4)/6._real64
      cumbot=cumbot+DT*(qb1+2*qb2+2*qb3+qb4)/6._real64
    enddo
  end subroutine
  subroutine emit(day,hist)
    integer,intent(in)::day
    character(len=*),intent(in)::hist
    integer::j
    real(real64)::tot,s20,s40,s80,qday
    real(real64),save::prevbot=0._real64
    if(day==1) prevbot=0._real64
    tot=sum(theta(1:n)*dz(1:n)); s20=integral(20._real64);s40=integral(40._real64);s80=integral(80._real64)
    qday=cumbot-prevbot;prevbot=cumbot
    write(*,'(a,a,a,i0,a,es24.16,a,es24.16,a,es24.16,a,es24.16,a,es24.16,a,es24.16)') &
      'P4_STATE|HISTORY=',hist,'|DAY=',day,'|TOTAL=',tot,'|S20=',s20,'|S40=',s40,'|S80=',s80,'|CUMBOT=',cumbot,'|QBOT=',qday
    do j=1,n
      write(*,'(a,a,a,i0,a,i0,a,es24.16)') 'P4_LAYER|HISTORY=',hist,'|DAY=',day,'|LAYER=',j,'|THETA=',theta(j)
    enddo
  end subroutine
  real(real64) function integral(depth) result(v)
    real(real64),intent(in)::depth
    real(real64)::z,w
    integer::j
    v=0.;z=0.
    do j=1,n
      w=max(0._real64,min(depth,z+dz(j))-z)
      v=v+theta(j)*w;z=z+dz(j)
      if(z>=depth)exit
    enddo
  end function
  subroutine material_params(id,a,b,c,d,e,f)
    character(len=*),intent(in)::id
    real(real64),intent(out)::a,b,c,d,e,f
    select case(id)
    case('B02'); a=0.01;b=0.395343;c=0.025954;d=1.507425;e=18.526447;f=0.207691
    case('B05'); a=0.02;b=0.390767;c=0.013479;d=1.438767;e=14.755405;f=0.365894
    case('B11'); a=0.02;b=0.472756;c=0.008791;d=1.521076;e=8.298931;f=0.713827
    case('B16'); a=0.02;b=0.468142;c=0.006711;d=1.389496;e=4.191104;f=0.665723
    case default; error stop 20
    end select
  end subroutine
end program
