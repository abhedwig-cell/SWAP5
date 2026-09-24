module mod_ahl17_self_builder
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t
  implicit none
  private

  integer, parameter :: MAX_KNOTS=4096
  real(real64), parameter :: HMIN=-1.0e6_real64, HMAX=-1.0_real64
  real(real64), parameter :: THETA_TOL=1.0e-5_real64, LOGC_TOL=1.0e-2_real64
  real(real64), parameter :: K_FLOOR=1.0e-10_real64
  real(real64), parameter :: K_TOL_GLOBAL=1.0e-3_real64, K_TOL_WET=3.0e-4_real64
  real(real64), parameter :: WET_MIN=-25.0_real64, WET_MAX=-1.0_real64
  real(real64), parameter :: LN10=log(10.0_real64)

  type, public :: ahl17_representation_t
    real(real64) :: theta_r=0.0_real64, theta_s=0.0_real64
    real(real64), allocatable :: x(:), z(:), dzdx(:), logk(:)
  contains
    procedure :: evaluate_scalar => ahl17_evaluate_scalar
  end type ahl17_representation_t

  public :: build_ahl17_representation
  public :: validate_ahl17_representation

contains

  subroutine sample_authority(provider,h,theta,c,k)
    type(b110_default_mvg_provider_t),intent(in)::provider
    real(real64),intent(in)::h
    real(real64),intent(out)::theta,c,k
    real(real64)::ha(1),ta(1),ka(1),ca(1),da(1)
    ha(1)=h
    call provider%evaluate(ha,ta,ka,ca,da)
    theta=ta(1);c=ca(1);k=ka(1)
  end subroutine sample_authority

  subroutine node_values(provider,tr,ts,x,z,m,lk)
    type(b110_default_mvg_provider_t),intent(in)::provider
    real(real64),intent(in)::tr,ts,x
    real(real64),intent(out)::z,m,lk
    real(real64)::h,theta,c,k,se,span,dzdh
    h=-10.0_real64**x
    call sample_authority(provider,h,theta,c,k)
    span=ts-tr
    se=min(max((theta-tr)/span,1.0e-15_real64),1.0_real64-1.0e-15_real64)
    z=log(se/(1.0_real64-se))
    dzdh=(c/span)/(se*(1.0_real64-se))
    m=dzdh*h*LN10
    lk=log(max(k,K_FLOOR))
  end subroutine node_values

  subroutine interp(rep,xv,theta,c,k)
    class(ahl17_representation_t),intent(in)::rep
    real(real64),intent(in)::xv
    real(real64),intent(out)::theta,c,k
    integer::idx
    real(real64)::f,dx,t,h00,h10,h01,h11,dh00,dh10,dh01,dh11,zz,dz_x,se,h,span
    call locate(rep%x,xv,idx,f)
    dx=rep%x(idx+1)-rep%x(idx);t=f
    h00=2*t**3-3*t**2+1;h10=t**3-2*t**2+t;h01=-2*t**3+3*t**2;h11=t**3-t**2
    zz=h00*rep%z(idx)+h10*dx*rep%dzdx(idx)+h01*rep%z(idx+1)+h11*dx*rep%dzdx(idx+1)
    dh00=6*t*t-6*t;dh10=3*t*t-4*t+1;dh01=-6*t*t+6*t;dh11=3*t*t-2*t
    dz_x=(dh00*rep%z(idx)+dh10*dx*rep%dzdx(idx)+dh01*rep%z(idx+1)+dh11*dx*rep%dzdx(idx+1))/dx
    if(zz>=0.0_real64)then
      se=1.0_real64/(1.0_real64+exp(-zz))
    else
      se=exp(zz)/(1.0_real64+exp(zz))
    end if
    span=rep%theta_s-rep%theta_r
    theta=rep%theta_r+span*se
    h=-10.0_real64**xv
    c=(span*se*(1.0_real64-se)*dz_x)/(h*LN10)
    k=exp(rep%logk(idx)+f*(rep%logk(idx+1)-rep%logk(idx)))
  end subroutine interp

  logical function interval_passes(provider,tr,ts,x0,x1) result(ok)
    type(b110_default_mvg_provider_t),intent(in)::provider
    real(real64),intent(in)::tr,ts,x0,x1
    type(ahl17_representation_t)::tmp
    real(real64),parameter::fr(5)=[0.125_real64,0.25_real64,0.5_real64,0.75_real64,0.875_real64]
    real(real64)::z0,m0,k0,z1,m1,k1,xv,h,th,c,k,thi,ci,ki,span,ktol
    integer::j
    allocate(tmp%x(2),tmp%z(2),tmp%dzdx(2),tmp%logk(2))
    tmp%theta_r=tr;tmp%theta_s=ts;tmp%x=[x0,x1]
    call node_values(provider,tr,ts,x0,z0,m0,k0)
    call node_values(provider,tr,ts,x1,z1,m1,k1)
    tmp%z=[z0,z1];tmp%dzdx=[m0,m1];tmp%logk=[k0,k1]
    span=ts-tr
    ok=.true.
    do j=1,5
      xv=x0+fr(j)*(x1-x0);h=-10.0_real64**xv
      call sample_authority(provider,h,th,c,k)
      call interp(tmp,xv,thi,ci,ki)
      ktol=K_TOL_GLOBAL
      if(h>=WET_MIN .and. h<=WET_MAX)ktol=K_TOL_WET
      if(abs(thi-th)/span>THETA_TOL .or. abs(log(max(ci,1.0e-300_real64))-log(max(c,1.0e-300_real64)))>LOGC_TOL .or. &
         abs(log(max(ki,K_FLOOR))-log(max(k,K_FLOOR)))>ktol) then
        ok=.false.;exit
      end if
    end do
  end function interval_passes

  subroutine build_ahl17_representation(parameters,provider,rep,ok)
    type(b110_default_mvg_parameters_t),intent(in)::parameters
    type(b110_default_mvg_provider_t),intent(in)::provider
    type(ahl17_representation_t),intent(out)::rep
    logical,intent(out)::ok
    real(real64)::work(MAX_KNOTS),mid
    integer::n,i,j
    logical::changed
    if(parameters%active_nodes/=1 .or. .not.allocated(parameters%cofgen))then;ok=.false.;return;end if
    rep%theta_r=parameters%cofgen(1,1);rep%theta_s=parameters%cofgen(2,1)
    work(1)=log10(-HMAX);work(2)=log10(-HMIN);n=2
    do
      changed=.false.
      do i=1,n-1
        if(.not.interval_passes(provider,rep%theta_r,rep%theta_s,work(i),work(i+1)))then
          if(n>=MAX_KNOTS)then;ok=.false.;return;end if
          mid=0.5_real64*(work(i)+work(i+1))
          do j=n,i+1,-1
            work(j+1)=work(j)
          end do
          work(i+1)=mid;n=n+1;changed=.true.;exit
        end if
      end do
      if(.not.changed)exit
    end do
    allocate(rep%x(n),rep%z(n),rep%dzdx(n),rep%logk(n))
    rep%x=work(1:n)
    do i=1,n
      call node_values(provider,rep%theta_r,rep%theta_s,rep%x(i),rep%z(i),rep%dzdx(i),rep%logk(i))
    end do
    ok=.true.
  end subroutine build_ahl17_representation

  subroutine validate_ahl17_representation(parameters,provider,rep,ncheck,max_theta,max_logc,max_logk,ok)
    type(b110_default_mvg_parameters_t),intent(in)::parameters
    type(b110_default_mvg_provider_t),intent(in)::provider
    type(ahl17_representation_t),intent(in)::rep
    integer,intent(in)::ncheck
    real(real64),intent(out)::max_theta,max_logc,max_logk
    logical,intent(out)::ok
    integer::i
    real(real64)::xv,h,th,c,k,thi,ci,ki,span,ktol,ke
    max_theta=0;max_logc=0;max_logk=0;span=parameters%cofgen(2,1)-parameters%cofgen(1,1);ok=.true.
    do i=0,ncheck-1
      xv=real(i,real64)*6.0_real64/real(ncheck-1,real64);h=-10.0_real64**xv
      call sample_authority(provider,h,th,c,k)
      call interp(rep,xv,thi,ci,ki)
      max_theta=max(max_theta,abs(thi-th)/span)
      max_logc=max(max_logc,abs(log(max(ci,1.0e-300_real64))-log(max(c,1.0e-300_real64))))
      ke=abs(log(max(ki,K_FLOOR))-log(max(k,K_FLOOR)));max_logk=max(max_logk,ke)
      ktol=K_TOL_GLOBAL;if(h>=WET_MIN.and.h<=WET_MAX)ktol=K_TOL_WET
      if(abs(thi-th)/span>THETA_TOL .or. abs(log(max(ci,1.0e-300_real64))-log(max(c,1.0e-300_real64)))>LOGC_TOL .or. ke>ktol) ok=.false.
    end do
  end subroutine validate_ahl17_representation

  subroutine ahl17_evaluate_scalar(self,h,theta,c,k)
    class(ahl17_representation_t),intent(in)::self
    real(real64),intent(in)::h
    real(real64),intent(out)::theta,c,k
    call interp(self,log10(-h),theta,c,k)
  end subroutine ahl17_evaluate_scalar

  pure subroutine locate(x,v,idx,f)
    real(real64),intent(in)::x(:),v
    integer,intent(out)::idx
    real(real64),intent(out)::f
    integer::lo,hi,mid,n
    n=size(x)
    if(v<=x(1))then;idx=1;f=0;return;end if
    if(v>=x(n))then;idx=n-1;f=1;return;end if
    lo=1;hi=n
    do while(hi-lo>1)
      mid=(lo+hi)/2
      if(x(mid)<=v)then;lo=mid;else;hi=mid;end if
    end do
    idx=lo;f=(v-x(lo))/(x(lo+1)-x(lo))
  end subroutine locate
end module mod_ahl17_self_builder
