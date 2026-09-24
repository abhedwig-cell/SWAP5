module mod_ahl11_decoupled_provider
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       bind_b110_default_mvg_provider
  implicit none
  private
  real(real64),parameter::LOOKUP_H_MAX=-1.0_real64,LN10=log(10.0_real64)
  type,extends(constitutive_hydraulics_provider_t),public::ahl11_decoupled_provider_t
    private
    type(b110_default_mvg_provider_t)::analytical
    real(real64),pointer::cofgen(:,:)=>null()
    real(real64),allocatable::xr(:),z(:),dzdx(:),xk(:),logk(:)
    logical::ready=.false.
  contains
    procedure::evaluate=>eval
  end type
  public::bind_ahl11_decoupled_provider
contains
  subroutine bind_ahl11_decoupled_provider(provider,parameters,step_duration,ret_path,k_path,valid)
    type(ahl11_decoupled_provider_t),intent(out)::provider
    type(b110_default_mvg_parameters_t),target,intent(in)::parameters
    real(real64),intent(in)::step_duration
    character(len=*),intent(in)::ret_path,k_path
    logical,intent(out)::valid
    integer::u,ios,n,i
    real(real64)::ignore6(6),ignore
    valid=.false.;provider%ready=.false.
    call bind_b110_default_mvg_provider(provider%analytical,parameters,step_duration)
    if(.not.allocated(parameters%cofgen))return
    provider%cofgen=>parameters%cofgen
    open(newunit=u,file=trim(ret_path),status='old',action='read',iostat=ios);if(ios/=0)return
    read(u,*,iostat=ios)ignore6;if(ios/=0)then;close(u);return;end if
    read(u,*,iostat=ios)n;if(ios/=0.or.n<2)then;close(u);return;end if
    allocate(provider%xr(n),provider%z(n),provider%dzdx(n))
    do i=1,n
      read(u,*,iostat=ios)provider%xr(i),provider%z(i),provider%dzdx(i),ignore
      if(ios/=0)then;close(u);return;end if
    end do
    close(u)
    open(newunit=u,file=trim(k_path),status='old',action='read',iostat=ios);if(ios/=0)return
    read(u,*,iostat=ios)n;if(ios/=0.or.n<2)then;close(u);return;end if
    allocate(provider%xk(n),provider%logk(n))
    do i=1,n
      read(u,*,iostat=ios)provider%xk(i),provider%logk(i)
      if(ios/=0)then;close(u);return;end if
    end do
    close(u)
    provider%ready=.true.;valid=.true.
  end subroutine

  subroutine eval(self,pressure_head,water_content,conductivity,capacity,dconductivity_dhead)
    class(ahl11_decoupled_provider_t),intent(in)::self
    real(real64),intent(in)::pressure_head(:)
    real(real64),intent(out)::water_content(:),conductivity(:),capacity(:),dconductivity_dhead(:)
    real(real64)::wa(size(pressure_head)),ka(size(pressure_head)),ca(size(pressure_head)),da(size(pressure_head))
    real(real64)::xv,f,dx,t,h00,h10,h01,h11,dh00,dh10,dh01,dh11,zz,dzx,se,span
    integer::i,ir,ik
    if(.not.self%ready)error stop 'AHL11 provider not ready'
    if(any(pressure_head>LOOKUP_H_MAX).or.any(pressure_head < -1.0e6_real64)) call self%analytical%evaluate(pressure_head,wa,ka,ca,da)
    do i=1,size(pressure_head)
      if(pressure_head(i)<=LOOKUP_H_MAX.and.pressure_head(i)>=-1.0e6_real64)then
        xv=log10(-pressure_head(i))
        call locate(self%xr,xv,ir,f);dx=self%xr(ir+1)-self%xr(ir);t=f
        h00=2*t**3-3*t**2+1;h10=t**3-2*t**2+t;h01=-2*t**3+3*t**2;h11=t**3-t**2
        zz=h00*self%z(ir)+h10*dx*self%dzdx(ir)+h01*self%z(ir+1)+h11*dx*self%dzdx(ir+1)
        dh00=6*t*t-6*t;dh10=3*t*t-4*t+1;dh01=-6*t*t+6*t;dh11=3*t*t-2*t
        dzx=(dh00*self%z(ir)+dh10*dx*self%dzdx(ir)+dh01*self%z(ir+1)+dh11*dx*self%dzdx(ir+1))/dx
        if(zz>=0)then;se=1/(1+exp(-zz));else;se=exp(zz)/(1+exp(zz));end if
        span=self%cofgen(2,i)-self%cofgen(1,i)
        water_content(i)=self%cofgen(1,i)+span*se
        capacity(i)=(span*se*(1-se)*dzx)/(pressure_head(i)*LN10)
        call locate(self%xk,xv,ik,f)
        conductivity(i)=exp(self%logk(ik)+f*(self%logk(ik+1)-self%logk(ik)))
        dconductivity_dhead(i)=0.0_real64
      else
        water_content(i)=wa(i);conductivity(i)=ka(i);capacity(i)=ca(i);dconductivity_dhead(i)=da(i)
      end if
    end do
  end subroutine

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
  end subroutine
end module mod_ahl11_decoupled_provider
