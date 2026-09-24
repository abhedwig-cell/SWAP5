module mod_ahl26f_pdi_lookup
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t
  use mod_ahl26f_pdi_analytical, only: pdi_params_t,pdi_analytical_provider_t,bind_pdi_analytical_provider
  implicit none
  private
  real(real64),parameter::HMAX=-1.0_real64,HMIN=-1.0e7_real64,LN10=log(10.0_real64)
  type,extends(constitutive_hydraulics_provider_t),public::pdi_lookup_provider_t
    type(pdi_params_t)::p
    type(pdi_analytical_provider_t)::analytical
    real(real64),allocatable::xr(:),zr(:),mr(:),xk(:),lk(:)
    logical::ready=.false.
  contains
    procedure::evaluate=>eval_provider
  end type
  public::bind_pdi_lookup_provider
contains
  subroutine bind_pdi_lookup_provider(provider,path,ok)
    type(pdi_lookup_provider_t),intent(out)::provider
    character(len=*),intent(in)::path
    logical,intent(out)::ok
    integer::u,ios,nr,nk,i
    character(len=1)::tag
    real(real64)::modelr
    ok=.false.;provider%ready=.false.
    open(newunit=u,file=trim(path),status='old',action='read',iostat=ios);if(ios/=0)return
    read(u,*,iostat=ios)modelr,provider%p%tr,provider%p%ts,provider%p%a1,provider%p%n1,provider%p%m1,provider%p%a2,provider%p%n2,provider%p%m2,provider%p%w1,provider%p%w2,provider%p%h0,provider%p%ha,provider%p%apar,provider%p%omegaK,provider%p%ksat,provider%p%lpar
    provider%p%model=nint(modelr)
    if(ios/=0)then;close(u);return;end if
    read(u,*,iostat=ios)nr,nk;if(ios/=0.or.nr<2.or.nk<2)then;close(u);return;end if
    allocate(provider%xr(nr),provider%zr(nr),provider%mr(nr),provider%xk(nk),provider%lk(nk))
    do i=1,nr;read(u,*,iostat=ios)tag,provider%xr(i),provider%zr(i),provider%mr(i);if(ios/=0)then;close(u);return;end if;end do
    do i=1,nk;read(u,*,iostat=ios)tag,provider%xk(i),provider%lk(i);if(ios/=0)then;close(u);return;end if;end do
    close(u);call bind_pdi_analytical_provider(provider%analytical,provider%p);provider%ready=.true.;ok=.true.
  end subroutine
  subroutine eval_provider(self,pressure_head,water_content,conductivity,capacity,dconductivity_dhead)
    class(pdi_lookup_provider_t),intent(in)::self
    real(real64),intent(in)::pressure_head(:)
    real(real64),intent(out)::water_content(:),conductivity(:),capacity(:),dconductivity_dhead(:)
    real(real64)::ta(size(pressure_head)),ka(size(pressure_head)),ca(size(pressure_head)),da(size(pressure_head))
    real(real64)::x,f,dx,t,h00,h10,h01,h11,dh00,dh10,dh01,dh11,z,dzdx,q
    integer::i,ir,ik
    if(.not.self%ready)error stop 'pdi lookup not ready'
    if(any(pressure_head>HMAX).or.any(pressure_head<HMIN))call self%analytical%evaluate(pressure_head,ta,ka,ca,da)
    do i=1,size(pressure_head)
      if(pressure_head(i)<=HMAX.and.pressure_head(i)>=HMIN)then
        x=log10(-pressure_head(i));call locate(self%xr,x,ir,f);dx=self%xr(ir+1)-self%xr(ir);t=f
        h00=2*t**3-3*t**2+1;h10=t**3-2*t**2+t;h01=-2*t**3+3*t**2;h11=t**3-t**2
        z=h00*self%zr(ir)+h10*dx*self%mr(ir)+h01*self%zr(ir+1)+h11*dx*self%mr(ir+1)
        dh00=6*t*t-6*t;dh10=3*t*t-4*t+1;dh01=-6*t*t+6*t;dh11=3*t*t-2*t
        dzdx=(dh00*self%zr(ir)+dh10*dx*self%mr(ir)+dh01*self%zr(ir+1)+dh11*dx*self%mr(ir+1))/dx
        if(z>=0)then;q=1/(1+exp(-z));else;q=exp(z)/(1+exp(z));end if
        water_content(i)=self%p%ts*q
        capacity(i)=self%p%ts*q*(1-q)*dzdx/(pressure_head(i)*LN10)
        call locate(self%xk,x,ik,f);conductivity(i)=exp(self%lk(ik)+f*(self%lk(ik+1)-self%lk(ik)))
        dconductivity_dhead(i)=0
      else
        water_content(i)=ta(i);conductivity(i)=ka(i);capacity(i)=ca(i);dconductivity_dhead(i)=da(i)
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
    do while(hi-lo>1);mid=(lo+hi)/2;if(x(mid)<=v)then;lo=mid;else;hi=mid;end if;end do
    idx=lo;f=(v-x(lo))/(x(lo+1)-x(lo))
  end subroutine
end module
