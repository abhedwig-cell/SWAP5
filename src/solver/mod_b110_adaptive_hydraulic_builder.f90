module mod_b110_adaptive_hydraulic_builder
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_b110_default_mvg_provider, only: b110_default_mvg_provider_t
  implicit none
  private

  integer, parameter :: MAX_SUPPORT=4096
  integer, parameter :: NSAMPLE=15
  real(real64), parameter :: H_MIN=-1.0e6_real64, H_MAX=-1.0_real64
  real(real64), parameter :: THETA_TOL=1.0e-5_real64, LOGC_TOL=1.0e-2_real64
  real(real64), parameter :: K_TOL_GLOBAL=1.0e-3_real64, K_TOL_WET=3.0e-4_real64
  real(real64), parameter :: WET_H_MIN=-25.0_real64, WET_H_MAX=-1.0_real64
  real(real64), parameter :: K_FLOOR=1.0e-10_real64
  real(real64), parameter :: LN10=log(10.0_real64)

  type, public :: b110_adaptive_hydraulic_table_t
    integer :: n=0
    real(real64), allocatable :: x(:), z(:), dzdx(:), logk(:)
  end type b110_adaptive_hydraulic_table_t

  public :: build_b110_adaptive_hydraulic_table, validate_b110_adaptive_hydraulic_table

contains

  subroutine build_b110_adaptive_hydraulic_table(provider,theta_r,theta_s,table,ok)
    type(b110_default_mvg_provider_t),intent(in)::provider
    real(real64),intent(in)::theta_r,theta_s
    type(b110_adaptive_hydraulic_table_t),intent(out)::table
    logical,intent(out)::ok
    real(real64) :: tx(MAX_SUPPORT),tz(MAX_SUPPORT),tm(MAX_SUPPORT),tk(MAX_SUPPORT)
    integer :: n
    logical :: local_ok

    n=0;ok=.false.
    call refine_interval(H_MAX,H_MIN,provider,theta_r,theta_s,0,tx,tz,tm,tk,n,local_ok)
    if(.not.local_ok)return
    call append_node(H_MIN,provider,theta_r,theta_s,tx,tz,tm,tk,n,local_ok)
    if(.not.local_ok)return
    table%n=n
    allocate(table%x(n),table%z(n),table%dzdx(n),table%logk(n))
    table%x=tx(:n);table%z=tz(:n);table%dzdx=tm(:n);table%logk=tk(:n)
    ok=.true.
  end subroutine build_b110_adaptive_hydraulic_table

  recursive subroutine refine_interval(h0,h1,provider,tr,ts,depth,x,z,m,lk,n,ok)
    real(real64),intent(in)::h0,h1,tr,ts
    type(b110_default_mvg_provider_t),intent(in)::provider
    integer,intent(in)::depth
    real(real64),intent(inout)::x(:),z(:),m(:),lk(:)
    integer,intent(inout)::n
    logical,intent(out)::ok
    real(real64)::score,hm
    logical::eok

    call interval_score(h0,h1,provider,tr,ts,score,eok)
    if(.not.eok)then;ok=.false.;return;end if
    if(score<=1.0_real64)then
      call append_node(h0,provider,tr,ts,x,z,m,lk,n,ok)
      return
    end if
    if(depth>=40)then;ok=.false.;return;end if
    hm=head_from_x(0.5_real64*(x_from_head(h0)+x_from_head(h1)))
    call refine_interval(h0,hm,provider,tr,ts,depth+1,x,z,m,lk,n,ok)
    if(.not.ok)return
    call refine_interval(hm,h1,provider,tr,ts,depth+1,x,z,m,lk,n,ok)
  end subroutine refine_interval

  subroutine interval_score(h0,h1,provider,tr,ts,score,ok)
    real(real64),intent(in)::h0,h1,tr,ts
    type(b110_default_mvg_provider_t),intent(in)::provider
    real(real64),intent(out)::score
    logical,intent(out)::ok
    real(real64)::z0,m0,k0,z1,m1,k1,xx,x0,x1,h,f,zi,dz,sei,thi,ci,ki
    real(real64)::th,c,k,dk,span,et,ec,ek,mt,mc,mk,ktol
    integer::j
    logical::q0,q1,qt

    span=ts-tr
    call sample_authority(h0,provider,tr,ts,z0,m0,k0,th,c,k,dk,q0)
    call sample_authority(h1,provider,tr,ts,z1,m1,k1,th,c,k,dk,q1)
    if(.not.q0.or..not.q1)then;ok=.false.;score=huge(1.0_real64);return;end if
    x0=x_from_head(h0);x1=x_from_head(h1)
    mt=0.0_real64;mc=0.0_real64;mk=0.0_real64
    do j=1,NSAMPLE
      f=real(j,real64)/real(NSAMPLE+1,real64);xx=x0+f*(x1-x0);h=head_from_x(xx)
      call sample_authority(h,provider,tr,ts,zi,dz,ki,th,c,k,dk,qt)
      if(.not.qt)then;ok=.false.;score=huge(1.0_real64);return;end if
      call hermite_value_derivative(xx,x0,x1,z0,z1,m0,m1,zi,dz)
      sei=logistic(zi);thi=tr+span*sei
      ci=(span*sei*(1.0_real64-sei)*dz)/(h*LN10)
      ki=exp(k0+f*(k1-k0))
      et=abs(thi-th)/span
      ec=abs(log(max(ci,tiny(1.0_real64)))-log(max(c,tiny(1.0_real64))))
      ek=abs(log(max(ki,K_FLOOR))-log(max(k,K_FLOOR)))
      mt=max(mt,et);mc=max(mc,ec);mk=max(mk,ek)
    end do
    if(max(h0,h1)>=WET_H_MIN .and. min(h0,h1)<=WET_H_MAX)then
      ktol=K_TOL_WET
    else
      ktol=K_TOL_GLOBAL
    end if
    score=max(mt/THETA_TOL,mc/LOGC_TOL,mk/ktol)
    ok=.true.
  end subroutine interval_score

  subroutine sample_authority(h,provider,tr,ts,z,dzdx,logk,theta,c,k,dk,ok)
    real(real64),intent(in)::h,tr,ts
    type(b110_default_mvg_provider_t),intent(in)::provider
    real(real64),intent(out)::z,dzdx,logk,theta,c,k,dk
    logical,intent(out)::ok
    real(real64)::hh(1),ww(1),kk(1),cc(1),dd(1),se,span
    hh(1)=h
    call provider%evaluate(hh,ww,kk,cc,dd)
    theta=ww(1);c=cc(1);k=kk(1);dk=dd(1);span=ts-tr
    se=(theta-tr)/span
    if(se<=0.0_real64.or.se>=1.0_real64.or.c<=0.0_real64.or.k<0.0_real64)then
      ok=.false.;return
    end if
    z=log(se/(1.0_real64-se))
    dzdx=((c/span)/(se*(1.0_real64-se)))*h*LN10
    logk=log(max(k,K_FLOOR))
    ok=.true.
  end subroutine sample_authority

  subroutine append_node(h,provider,tr,ts,x,z,m,lk,n,ok)
    real(real64),intent(in)::h,tr,ts
    type(b110_default_mvg_provider_t),intent(in)::provider
    real(real64),intent(inout)::x(:),z(:),m(:),lk(:)
    integer,intent(inout)::n
    logical,intent(out)::ok
    real(real64)::zz,mm,ll,th,c,k,dk
    if(n>=size(x))then;ok=.false.;return;end if
    call sample_authority(h,provider,tr,ts,zz,mm,ll,th,c,k,dk,ok)
    if(.not.ok)return
    n=n+1;x(n)=x_from_head(h);z(n)=zz;m(n)=mm;lk(n)=ll
  end subroutine append_node

  subroutine validate_b110_adaptive_hydraulic_table(provider,tr,ts,table,max_theta,max_logc,max_logk,ok)
    type(b110_default_mvg_provider_t),intent(in)::provider
    real(real64),intent(in)::tr,ts
    type(b110_adaptive_hydraulic_table_t),intent(in)::table
    real(real64),intent(out)::max_theta,max_logc,max_logk
    logical,intent(out)::ok
    real(real64)::score
    integer::i
    max_theta=0.0_real64;max_logc=0.0_real64;max_logk=0.0_real64
    ! Reuse independent denser fractions by scanning 31 points per interval.
    do i=1,table%n-1
      call validate_interval(table,i,provider,tr,ts,max_theta,max_logc,max_logk,ok)
      if(.not.ok)return
    end do
    ok=.true.
  end subroutine validate_b110_adaptive_hydraulic_table

  subroutine validate_interval(table,i,provider,tr,ts,mt,mc,mk,ok)
    type(b110_adaptive_hydraulic_table_t),intent(in)::table
    integer,intent(in)::i
    type(b110_default_mvg_provider_t),intent(in)::provider
    real(real64),intent(in)::tr,ts
    real(real64),intent(inout)::mt,mc,mk
    logical,intent(out)::ok
    real(real64)::f,xx,h,z,dz,se,thi,ci,ki,th,c,k,dk,za,ma,lka,span
    real(real64)::et,ec,ek,ktol
    integer::j
    logical::q
    span=ts-tr
    ok=.true.
    do j=1,31
      f=real(j,real64)/32.0_real64
      xx=table%x(i)+f*(table%x(i+1)-table%x(i));h=head_from_x(xx)
      call hermite_value_derivative(xx,table%x(i),table%x(i+1),table%z(i),table%z(i+1), &
           table%dzdx(i),table%dzdx(i+1),z,dz)
      se=logistic(z);thi=tr+span*se;ci=(span*se*(1.0_real64-se)*dz)/(h*LN10)
      ki=exp(table%logk(i)+f*(table%logk(i+1)-table%logk(i)))
      call sample_authority(h,provider,tr,ts,za,ma,lka,th,c,k,dk,q)
      if(.not.q)then;ok=.false.;return;end if
      et=abs(thi-th)/span
      ec=abs(log(max(ci,tiny(1.0_real64)))-log(max(c,tiny(1.0_real64))))
      ek=abs(log(max(ki,K_FLOOR))-log(max(k,K_FLOOR)))
      mt=max(mt,et);mc=max(mc,ec);mk=max(mk,ek)
      ktol=K_TOL_GLOBAL
      if(h>=WET_H_MIN .and. h<=WET_H_MAX)ktol=K_TOL_WET
      if(et>THETA_TOL .or. ec>LOGC_TOL .or. ek>ktol)ok=.false.
    end do
  end subroutine validate_interval

  pure subroutine hermite_value_derivative(x,x0,x1,y0,y1,m0,m1,y,dydx)
    real(real64),intent(in)::x,x0,x1,y0,y1,m0,m1
    real(real64),intent(out)::y,dydx
    real(real64)::dx,t,h00,h10,h01,h11,dh00,dh10,dh01,dh11
    dx=x1-x0;t=(x-x0)/dx
    h00=2*t**3-3*t**2+1;h10=t**3-2*t**2+t;h01=-2*t**3+3*t**2;h11=t**3-t**2
    y=h00*y0+h10*dx*m0+h01*y1+h11*dx*m1
    dh00=6*t*t-6*t;dh10=3*t*t-4*t+1;dh01=-6*t*t+6*t;dh11=3*t*t-2*t
    dydx=(dh00*y0+dh10*dx*m0+dh01*y1+dh11*dx*m1)/dx
  end subroutine hermite_value_derivative

  pure real(real64) function x_from_head(h) result(x)
    real(real64),intent(in)::h
    x=log10(-h)
  end function x_from_head
  pure real(real64) function head_from_x(x) result(h)
    real(real64),intent(in)::x
    h=-(10.0_real64**x)
  end function head_from_x
  pure real(real64) function logistic(z) result(se)
    real(real64),intent(in)::z
    if(z>=0.0_real64)then
      se=1.0_real64/(1.0_real64+exp(-z))
    else
      se=exp(z)/(1.0_real64+exp(z))
    end if
  end function logistic
end module mod_b110_adaptive_hydraulic_builder
