module mod_ahl09_dc_provider
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       bind_b110_default_mvg_provider
  implicit none
  private

  real(real64), parameter :: LOOKUP_H_MAX=-1.0_real64
  real(real64), parameter :: LN10=log(10.0_real64)

  type, extends(constitutive_hydraulics_provider_t), public :: ahl09_dc_provider_t
    private
    type(b110_default_mvg_provider_t) :: analytical
    real(real64), pointer :: cofgen(:,:) => null()
    real(real64), allocatable :: x(:), z(:), dzdx(:), logk(:)
    logical :: ready=.false.
  contains
    procedure :: evaluate => dc_evaluate
  end type ahl09_dc_provider_t

  public :: bind_ahl09_dc_provider

contains

  subroutine bind_ahl09_dc_provider(provider,parameters,step_duration,table_path,valid)
    type(ahl09_dc_provider_t),intent(out)::provider
    type(b110_default_mvg_parameters_t),target,intent(in)::parameters
    real(real64),intent(in)::step_duration
    character(len=*),intent(in)::table_path
    logical,intent(out)::valid
    integer::u,ios,n,i
    real(real64)::pignore(6)

    valid=.false.;provider%ready=.false.
    call bind_b110_default_mvg_provider(provider%analytical,parameters,step_duration)
    if(.not.allocated(parameters%cofgen))return
    provider%cofgen=>parameters%cofgen
    open(newunit=u,file=trim(table_path),status='old',action='read',iostat=ios)
    if(ios/=0)return
    read(u,*,iostat=ios)pignore
    if(ios/=0)then;close(u);return;end if
    read(u,*,iostat=ios)n
    if(ios/=0.or.n<2)then;close(u);return;end if
    allocate(provider%x(n),provider%z(n),provider%dzdx(n),provider%logk(n))
    do i=1,n
      read(u,*,iostat=ios)provider%x(i),provider%z(i),provider%dzdx(i),provider%logk(i)
      if(ios/=0)then;close(u);return;end if
    end do
    close(u)
    if(any(provider%x(2:)<=provider%x(:n-1)))return
    provider%ready=.true.;valid=.true.
  end subroutine bind_ahl09_dc_provider

  subroutine dc_evaluate(self,pressure_head,water_content,conductivity,capacity,dconductivity_dhead)
    class(ahl09_dc_provider_t),intent(in)::self
    real(real64),intent(in)::pressure_head(:)
    real(real64),intent(out)::water_content(:),conductivity(:),capacity(:),dconductivity_dhead(:)
    real(real64)::wa(size(pressure_head)),ka(size(pressure_head)),ca(size(pressure_head)),da(size(pressure_head))
    real(real64)::xv,f,dx,t,h00,h10,h01,h11,dh00,dh10,dh01,dh11,zz,dz_x,se,span
    integer::i,idx

    if(.not.self%ready.or..not.associated(self%cofgen))error stop 'AHL09 provider not ready'
    if(any(.not.in_lookup_domain(self,pressure_head)))then
      call self%analytical%evaluate(pressure_head,wa,ka,ca,da)
    end if

    do i=1,size(pressure_head)
      if(in_lookup_domain_scalar(self,pressure_head(i)))then
        xv=log10(-pressure_head(i))
        call locate(self%x,xv,idx,f)
        dx=self%x(idx+1)-self%x(idx);t=f
        h00=2*t**3-3*t**2+1;h10=t**3-2*t**2+t;h01=-2*t**3+3*t**2;h11=t**3-t**2
        zz=h00*self%z(idx)+h10*dx*self%dzdx(idx)+h01*self%z(idx+1)+h11*dx*self%dzdx(idx+1)
        dh00=6*t*t-6*t;dh10=3*t*t-4*t+1;dh01=-6*t*t+6*t;dh11=3*t*t-2*t
        dz_x=(dh00*self%z(idx)+dh10*dx*self%dzdx(idx)+dh01*self%z(idx+1)+dh11*dx*self%dzdx(idx+1))/dx
        if(zz>=0.0_real64)then
          se=1.0_real64/(1.0_real64+exp(-zz))
        else
          se=exp(zz)/(1.0_real64+exp(zz))
        end if
        span=self%cofgen(2,i)-self%cofgen(1,i)
        water_content(i)=self%cofgen(1,i)+span*se
        capacity(i)=(span*se*(1.0_real64-se)*dz_x)/(pressure_head(i)*LN10)
        conductivity(i)=exp(self%logk(idx)+f*(self%logk(idx+1)-self%logk(idx)))
        dconductivity_dhead(i)=0.0_real64
      else
        water_content(i)=wa(i);conductivity(i)=ka(i);capacity(i)=ca(i);dconductivity_dhead(i)=da(i)
      end if
    end do
  end subroutine dc_evaluate

  pure elemental logical function in_lookup_domain_scalar(self,head) result(ok)
    class(ahl09_dc_provider_t),intent(in)::self
    real(real64),intent(in)::head
    real(real64)::xv
    ok=.false.
    if(head>LOOKUP_H_MAX .or. head>=0.0_real64) return
    xv=log10(-head)
    ok=(xv>=self%x(1) .and. xv<=self%x(size(self%x)))
  end function in_lookup_domain_scalar

  pure function in_lookup_domain(self,heads) result(mask)
    class(ahl09_dc_provider_t),intent(in)::self
    real(real64),intent(in)::heads(:)
    logical::mask(size(heads))
    integer::j
    do j=1,size(heads)
      mask(j)=in_lookup_domain_scalar(self,heads(j))
    end do
  end function in_lookup_domain

  pure subroutine locate(x,value,idx,fraction)
    real(real64),intent(in)::x(:),value
    integer,intent(out)::idx
    real(real64),intent(out)::fraction
    integer::lo,hi,mid,n
    n=size(x)
    if(value<=x(1))then;idx=1;fraction=0.0_real64;return;end if
    if(value>=x(n))then;idx=n-1;fraction=1.0_real64;return;end if
    lo=1;hi=n
    do while(hi-lo>1)
      mid=(lo+hi)/2
      if(x(mid)<=value)then;lo=mid;else;hi=mid;end if
    end do
    idx=lo;fraction=(value-x(lo))/(x(lo+1)-x(lo))
  end subroutine locate
end module mod_ahl09_dc_provider
