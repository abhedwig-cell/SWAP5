module mod_ahl12b_exact_retention_klookup_provider
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       bind_b110_default_mvg_provider
  implicit none
  private

  real(real64), parameter :: LOOKUP_H_MAX=-1.0_real64
  real(real64), parameter :: HCRIT=-1.0e-2_real64

  type,extends(constitutive_hydraulics_provider_t),public::ahl12b_exact_retention_klookup_provider_t
    private
    type(b110_default_mvg_provider_t)::analytical
    real(real64),pointer::cofgen(:,:)=>null()
    real(real64),allocatable::xk(:),logk(:)
    real(real64)::step_duration=0.0_real64
    logical::ready=.false.
  contains
    procedure::evaluate=>eval_provider
  end type

  public::bind_ahl12b_exact_retention_klookup_provider

contains

  subroutine bind_ahl12b_exact_retention_klookup_provider(provider,parameters,step_duration,k_path,valid)
    type(ahl12b_exact_retention_klookup_provider_t),intent(out)::provider
    type(b110_default_mvg_parameters_t),target,intent(in)::parameters
    real(real64),intent(in)::step_duration
    character(len=*),intent(in)::k_path
    logical,intent(out)::valid
    integer::u,ios,n,i
    valid=.false.;provider%ready=.false.;provider%step_duration=step_duration
    call bind_b110_default_mvg_provider(provider%analytical,parameters,step_duration)
    if(.not.allocated(parameters%cofgen))return
    provider%cofgen=>parameters%cofgen
    open(newunit=u,file=trim(k_path),status='old',action='read',iostat=ios);if(ios/=0)return
    read(u,*,iostat=ios)n
    if(ios/=0.or.n<2)then;close(u);return;end if
    allocate(provider%xk(n),provider%logk(n))
    do i=1,n
      read(u,*,iostat=ios)provider%xk(i),provider%logk(i)
      if(ios/=0)then;close(u);return;end if
    end do
    close(u)
    if(any(provider%xk(2:)<=provider%xk(:n-1)))return
    provider%ready=.true.;valid=.true.
  end subroutine

  subroutine eval_provider(self,pressure_head,water_content,conductivity,capacity,dconductivity_dhead)
    class(ahl12b_exact_retention_klookup_provider_t),intent(in)::self
    real(real64),intent(in)::pressure_head(:)
    real(real64),intent(out)::water_content(:),conductivity(:),capacity(:),dconductivity_dhead(:)
    real(real64)::wa(size(pressure_head)),ka(size(pressure_head)),ca(size(pressure_head)),da(size(pressure_head))
    real(real64)::xv,f
    integer::i,ik
    if(.not.self%ready.or..not.associated(self%cofgen))error stop 'AHL12B provider not ready'
    if(any(pressure_head>LOOKUP_H_MAX).or.any(pressure_head < -1.0e6_real64))then
      call self%analytical%evaluate(pressure_head,wa,ka,ca,da)
    end if
    do i=1,size(pressure_head)
      if(pressure_head(i)<=LOOKUP_H_MAX.and.pressure_head(i)>=-1.0e6_real64)then
        water_content(i)=exact_theta(self%cofgen(:,i),pressure_head(i))
        capacity(i)=exact_capacity(self%cofgen(:,i),pressure_head(i),self%step_duration)
        xv=log10(-pressure_head(i))
        call locate(self%xk,xv,ik,f)
        conductivity(i)=exp(self%logk(ik)+f*(self%logk(ik+1)-self%logk(ik)))
        dconductivity_dhead(i)=0.0_real64
      else
        water_content(i)=wa(i);conductivity(i)=ka(i);capacity(i)=ca(i);dconductivity_dhead(i)=da(i)
      end if
    end do
  end subroutine

  pure real(real64) function exact_theta(c,head) result(theta)
    real(real64),intent(in)::c(:),head
    real(real64)::help,h105
    if(head>=0.0_real64)then
      theta=c(2)
    else if(c(9)>HCRIT)then
      if(head>HCRIT)then
        theta=min(c(26)+c(27)*(head-HCRIT),c(2))
      else
        help=(1.0_real64+abs(c(4)*head)**c(6))**c(7)
        theta=c(1)+c(25)/help
      end if
    else
      h105=1.05_real64*c(9)
      if(head>=h105)then
        theta=c(2)+c(42)*head/(1.0_real64+c(41)*head)
      else
        help=(1.0_real64+abs(c(4)*head)**c(6))**c(7)
        theta=c(1)+c(25)/(help*c(28))
      end if
    end if
  end function

  pure real(real64) function exact_capacity(c,head,dt) result(capacity)
    real(real64),intent(in)::c(:),head,dt
    real(real64)::alphah,h105,term1,term2
    if(head>=0.0_real64)then
      capacity=dt*1.0e-7_real64
    else
      alphah=abs(c(4)*head)
      if(c(9)>HCRIT)then
        if(head>HCRIT)then
          capacity=c(27)
        else
          term1=alphah**c(30)
          term2=c(25)/((1.0_real64+term1*alphah)**c(31))
          capacity=c(29)*term2*term1
        end if
      else
        h105=1.05_real64*c(9)
        if(head>=h105)then
          capacity=c(42)/((1.0_real64+c(41)*head)**2)
        else
          term1=alphah**c(30)
          term2=(1.0_real64+term1*alphah)**c(31)
          term2=c(25)/term2
          capacity=c(29)*term2*term1/c(28)
        end if
      end if
      if(head>-1.0_real64.and.capacity<dt*1.0e-7_real64)capacity=dt*1.0e-7_real64
    end if
  end function

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
end module mod_ahl12b_exact_retention_klookup_provider
