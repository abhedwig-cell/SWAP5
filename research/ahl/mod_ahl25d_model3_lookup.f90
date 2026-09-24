module mod_ahl25d_model3_lookup
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t
  use mod_ahl25d_model3_analytical, only: model3_parameters_t, model3_analytical_provider_t, bind_model3_analytical_provider
  implicit none
  private
  real(real64),parameter::HMAX=-1.0_real64,HMIN=-1.0e6_real64,LN10=log(10.0_real64)
  type,extends(constitutive_hydraulics_provider_t),public::model3_lookup_provider_t
    type(model3_parameters_t)::p
    type(model3_analytical_provider_t)::analytical
    real(real64),allocatable::xr(:),zr(:),mr(:),xk(:),lk(:)
    logical::ready=.false.,exact_retention=.false.,exact_k=.false.
  contains
    procedure::evaluate=>eval_lookup
  end type
  public::bind_model3_lookup_provider
contains
  subroutine bind_model3_lookup_provider(provider,path,ok,exact_retention,exact_k)
    type(model3_lookup_provider_t),intent(out)::provider
    character(len=*),intent(in)::path
    logical,intent(out)::ok
    logical,intent(in),optional::exact_retention,exact_k
    integer::u,ios,nr,nk,i
    character(len=1)::tag
    ok=.false.;provider%ready=.false.;provider%exact_retention=.false.;provider%exact_k=.false.
    if(present(exact_retention))provider%exact_retention=exact_retention
    if(present(exact_k))provider%exact_k=exact_k
    open(newunit=u,file=trim(path),status='old',action='read',iostat=ios);if(ios/=0)return
    read(u,*,iostat=ios) provider%p%tr,provider%p%ts,provider%p%a1,provider%p%n1,provider%p%m1, &
      provider%p%a2,provider%p%n2,provider%p%m2,provider%p%w,provider%p%ksat,provider%p%lambda
    if(ios/=0)then;close(u);return;end if
    read(u,*,iostat=ios)nr,nk
    if(ios/=0.or.nr<2.or.nk<2)then;close(u);return;end if
    allocate(provider%xr(nr),provider%zr(nr),provider%mr(nr),provider%xk(nk),provider%lk(nk))
    do i=1,nr
      read(u,*,iostat=ios)tag,provider%xr(i),provider%zr(i),provider%mr(i);if(ios/=0)then;close(u);return;end if
    end do
    do i=1,nk
      read(u,*,iostat=ios)tag,provider%xk(i),provider%lk(i);if(ios/=0)then;close(u);return;end if
    end do
    close(u)
    call bind_model3_analytical_provider(provider%analytical,provider%p)
    provider%ready=.true.;ok=.true.
  end subroutine
  subroutine eval_lookup(self,pressure_head,water_content,conductivity,capacity,dconductivity_dhead)
    class(model3_lookup_provider_t),intent(in)::self
    real(real64),intent(in)::pressure_head(:)
    real(real64),intent(out)::water_content(:),conductivity(:),capacity(:),dconductivity_dhead(:)
    real(real64)::ta(size(pressure_head)),ka(size(pressure_head)),ca(size(pressure_head)),da(size(pressure_head))
    real(real64)::x,f,dx,t,H00,H10,H01,H11,dH00,dH10,dH01,dH11,z,dzdx,se,span
    integer::i,ir,ik
    if(.not.self%ready)error stop 'model3 lookup not ready'
    if(any(pressure_head>HMAX).or.any(pressure_head<HMIN).or.self%exact_retention.or.self%exact_k)call self%analytical%evaluate(pressure_head,ta,ka,ca,da)
    span=self%p%ts-self%p%tr
    do i=1,size(pressure_head)
      if(pressure_head(i)<=HMAX.and.pressure_head(i)>=HMIN)then
        x=log10(-pressure_head(i))
        call locate(self%xr,x,ir,f);dx=self%xr(ir+1)-self%xr(ir);t=f
        H00=2*t**3-3*t**2+1;H10=t**3-2*t**2+t;H01=-2*t**3+3*t**2;H11=t**3-t**2
        z=H00*self%zr(ir)+H10*dx*self%mr(ir)+H01*self%zr(ir+1)+H11*dx*self%mr(ir+1)
        dH00=6*t*t-6*t;dH10=3*t*t-4*t+1;dH01=-6*t*t+6*t;dH11=3*t*t-2*t
        dzdx=(dH00*self%zr(ir)+dH10*dx*self%mr(ir)+dH01*self%zr(ir+1)+dH11*dx*self%mr(ir+1))/dx
        if(z>=0.0_real64)then;se=1/(1+exp(-z));else;se=exp(z)/(1+exp(z));end if
        water_content(i)=self%p%tr+span*se
        capacity(i)=span*se*(1-se)*dzdx/(pressure_head(i)*LN10)
        if(self%exact_retention)then
          water_content(i)=ta(i);capacity(i)=ca(i)
        end if
        call locate(self%xk,x,ik,f)
        conductivity(i)=exp(self%lk(ik)+f*(self%lk(ik+1)-self%lk(ik)))
        if(self%exact_k)conductivity(i)=ka(i)
        dconductivity_dhead(i)=0.0_real64
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
    do while(hi-lo>1)
      mid=(lo+hi)/2
      if(x(mid)<=v)then;lo=mid;else;hi=mid;end if
    end do
    idx=lo;f=(v-x(lo))/(x(lo+1)-x(lo))
  end subroutine
end module
