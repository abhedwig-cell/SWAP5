program test_fahl45_direct_index_screen
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_soil_water_solver_contract, only: CONSTITUTIVE_DEMAND_WATER_CONTENT, CONSTITUTIVE_DEMAND_CAPACITY
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  implicit none

  integer, parameter :: nvec=60, nprobe=20001, nsizes=4
  integer, parameter :: sizes(nsizes)=[257,513,1025,2049]
  integer, parameter :: reps=250000
  real(real64), parameter :: dt=1.0e-4_real64, xmin=0.0_real64, xmax=6.0_real64
  real(real64), parameter :: ln10=log(10.0_real64)
  type(b110_default_mvg_parameters_t),target :: hp
  type(b110_default_mvg_provider_t) :: analytical
  real(real64) :: cof(42,nvec),hvec(nvec),wa(nvec),ka(nvec),ca(nvec),da(nvec)
  real(real64) :: wd(nvec),kd(nvec),cd(nvec),dd(nvec)
  integer(int64) :: c0,c1,rate
  integer :: isz,r
  real(real64) :: seconds,analytical_ns,checksum

  call make_parameters(cof)
  call initialize_b110_default_mvg_parameters(hp,cof)
  call bind_b110_default_mvg_provider(analytical,hp,dt)

  hvec=-75.0_real64
  checksum=0.0_real64
  call system_clock(c0,rate)
  do r=1,reps
    call analytical%evaluate_demand(hvec,CONSTITUTIVE_DEMAND_WATER_CONTENT,wd,kd,cd,dd)
    checksum=checksum+wd(1)+wd(nvec)
  end do
  call system_clock(c1)
  seconds=real(c1-c0,real64)/real(rate,real64)
  analytical_ns=1.0e9_real64*seconds/real(reps,real64)
  write(*,'(*(g0))') 'FAHL45_ANALYTICAL_THETA|N=',nvec,'|NS_PER=',analytical_ns,'|CHECKSUM=',checksum

  do isz=1,nsizes
    call screen_size(sizes(isz),analytical_ns)
  end do
  write(*,'(A)') 'FAHL45_DIRECT_INDEX_SCREEN=PASS'

contains

  subroutine screen_size(ntab,reference_ns)
    integer,intent(in)::ntab
    real(real64),intent(in)::reference_ns
    real(real64),allocatable::x(:),z(:),dzdx(:)
    real(real64)::dx,inv_dx,h,theta_ref,c_ref,theta_cand,c_cand,max_dtheta,max_rel_c
    real(real64)::xv,se,span,theta_s,theta_r,rel_c,elapsed,check
    integer::i,q
    real(real64)::oneh(1),ow(1),okv(1),oc(1),od(1)
    type(b110_default_mvg_parameters_t),target::hp1
    type(b110_default_mvg_provider_t)::a1
    real(real64)::cof1(42,1)

    allocate(x(ntab),z(ntab),dzdx(ntab))
    dx=(xmax-xmin)/real(ntab-1,real64);inv_dx=1.0_real64/dx
    cof1(:,1)=cof(:,1)
    call initialize_b110_default_mvg_parameters(hp1,cof1)
    call bind_b110_default_mvg_provider(a1,hp1,dt)
    theta_r=cof1(1,1);theta_s=cof1(2,1);span=theta_s-theta_r

    do i=1,ntab
      x(i)=xmin+dx*real(i-1,real64)
      oneh(1)=-10.0_real64**x(i)
      call a1%evaluate(oneh,ow,okv,oc,od)
      se=(ow(1)-theta_r)/span
      se=max(1.0e-15_real64,min(1.0_real64-1.0e-15_real64,se))
      z(i)=log(se/(1.0_real64-se))
      dzdx(i)=oc(1)*oneh(1)*ln10/(span*se*(1.0_real64-se))
    end do

    max_dtheta=0.0_real64;max_rel_c=0.0_real64
    do q=1,nprobe
      xv=xmin+(xmax-xmin)*real(q-1,real64)/real(nprobe-1,real64)
      h=-10.0_real64**xv
      oneh(1)=h
      call a1%evaluate(oneh,ow,okv,oc,od)
      theta_ref=ow(1);c_ref=oc(1)
      call direct_eval(xv,h,theta_r,span,x,z,dzdx,inv_dx,theta_cand,c_cand)
      max_dtheta=max(max_dtheta,abs(theta_cand-theta_ref))
      if(c_ref>=1.0e-13_real64)then
        rel_c=abs(c_cand-c_ref)/max(abs(c_ref),1.0e-300_real64)
        max_rel_c=max(max_rel_c,rel_c)
      end if
      if(.not.ieee_is_finite(theta_cand) .or. .not.ieee_is_finite(c_cand))error stop 'FAHL45 nonfinite'
    end do

    check=0.0_real64
    call system_clock(c0)
    do r=1,reps
      do i=1,nvec
        xv=log10(-hvec(i))
        call direct_eval(xv,hvec(i),theta_r,span,x,z,dzdx,inv_dx,wd(i),cd(i))
      end do
      check=check+wd(1)+wd(nvec)
    end do
    call system_clock(c1)
    elapsed=real(c1-c0,real64)/real(rate,real64)
    write(*,'(*(g0))') 'FAHL45_DIRECT|NTAB=',ntab,'|MAX_DTHETA=',max_dtheta,'|MAX_REL_C=',max_rel_c, &
         '|NS_PER=',1.0e9_real64*elapsed/real(reps,real64),'|RATIO=', &
         (1.0e9_real64*elapsed/real(reps,real64))/reference_ns,'|CHECKSUM=',check
    deallocate(x,z,dzdx)
  end subroutine screen_size

  subroutine direct_eval(xv,h,theta_r,span,x,z,m,inv_dx,theta,capacity)
    real(real64),intent(in)::xv,h,theta_r,span,x(:),z(:),m(:),inv_dx
    real(real64),intent(out)::theta,capacity
    integer::idx,n
    real(real64)::f,t,dxloc,h00,h10,h01,h11,dh00,h10d,dh01,dh11,zz,dzx,se
    n=size(x)
    idx=int(floor((xv-x(1))*inv_dx))+1
    idx=max(1,min(n-1,idx))
    dxloc=x(idx+1)-x(idx)
    f=(xv-x(idx))/dxloc
    f=max(0.0_real64,min(1.0_real64,f));t=f
    h00=2*t**3-3*t**2+1;h10=t**3-2*t**2+t;h01=-2*t**3+3*t**2;h11=t**3-t**2
    zz=h00*z(idx)+h10*dxloc*m(idx)+h01*z(idx+1)+h11*dxloc*m(idx+1)
    dh00=6*t*t-6*t;h10d=3*t*t-4*t+1;dh01=-6*t*t+6*t;dh11=3*t*t-2*t
    dzx=(dh00*z(idx)+h10d*dxloc*m(idx)+dh01*z(idx+1)+dh11*dxloc*m(idx+1))/dxloc
    if(zz>=0.0_real64)then
      se=1.0_real64/(1.0_real64+exp(-zz))
    else
      se=exp(zz)/(1.0_real64+exp(zz))
    end if
    theta=theta_r+span*se
    capacity=(span*se*(1.0_real64-se)*dzx)/(h*ln10)
  end subroutine direct_eval

  subroutine make_parameters(c)
    real(real64),intent(out)::c(42,nvec)
    integer::k
    c=0.0_real64
    do k=1,nvec
      c(1,k)=0.032_real64;c(2,k)=0.423_real64;c(3,k)=4.75_real64
      c(4,k)=0.0135_real64;c(5,k)=0.365_real64;c(6,k)=1.455_real64
      c(7,k)=1.0_real64-1.0_real64/c(6,k);c(8,k)=c(4,k)
      c(9,k)=0.0_real64;c(10,k)=c(3,k);c(11,k)=0.999_real64
      c(12,k)=0.99_real64*c(3,k);c(22,k)=-1.0e6_real64;c(23,k)=1.0e-12_real64
    end do
  end subroutine make_parameters
end program
