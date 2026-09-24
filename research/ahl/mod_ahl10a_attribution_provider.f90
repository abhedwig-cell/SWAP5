module mod_ahl10a_attribution_provider
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       bind_b110_default_mvg_provider
  implicit none
  private

  integer, parameter, public :: AHL10A_BASE=1
  integer, parameter, public :: AHL10A_DC_EXACTK=2
  integer, parameter, public :: AHL10A_EXACTRC_LOOKUPK=3
  real(real64), parameter :: LOOKUP_H_MAX=-1.0_real64
  real(real64), parameter :: LN10=log(10.0_real64)
  real(real64), parameter :: HCRIT=-1.0e-2_real64
  real(real64), parameter :: KSMALL=1.0e-10_real64

  type, extends(constitutive_hydraulics_provider_t), public :: ahl10a_provider_t
    private
    type(b110_default_mvg_provider_t) :: analytical
    real(real64), pointer :: cofgen(:,:) => null()
    real(real64), allocatable :: x(:), z(:), dzdx(:), logk(:)
    integer :: mode=AHL10A_BASE
    logical :: ready=.false.
  contains
    procedure :: evaluate => eval_provider
  end type ahl10a_provider_t

  public :: bind_ahl10a_provider

contains

  subroutine bind_ahl10a_provider(provider,parameters,step_duration,table_path,mode,valid)
    type(ahl10a_provider_t),intent(out)::provider
    type(b110_default_mvg_parameters_t),target,intent(in)::parameters
    real(real64),intent(in)::step_duration
    character(len=*),intent(in)::table_path
    integer,intent(in)::mode
    logical,intent(out)::valid
    integer::u,ios,n,i
    real(real64)::ignore(6)

    valid=.false.; provider%ready=.false.; provider%mode=mode
    call bind_b110_default_mvg_provider(provider%analytical,parameters,step_duration)
    if(.not.allocated(parameters%cofgen))return
    provider%cofgen=>parameters%cofgen
    open(newunit=u,file=trim(table_path),status='old',action='read',iostat=ios)
    if(ios/=0)return
    read(u,*,iostat=ios)ignore
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
    if(mode<AHL10A_BASE.or.mode>AHL10A_EXACTRC_LOOKUPK)return
    provider%ready=.true.;valid=.true.
  end subroutine bind_ahl10a_provider

  subroutine eval_provider(self,pressure_head,water_content,conductivity,capacity,dconductivity_dhead)
    class(ahl10a_provider_t),intent(in)::self
    real(real64),intent(in)::pressure_head(:)
    real(real64),intent(out)::water_content(:),conductivity(:),capacity(:),dconductivity_dhead(:)
    real(real64)::wa(size(pressure_head)),ka(size(pressure_head)),ca(size(pressure_head)),da(size(pressure_head))
    real(real64)::xv,f,dx,t,h00,h10,h01,h11,dh00,dh10,dh01,dh11,zz,dz_x,se,span
    integer::i,idx

    if(.not.self%ready.or..not.associated(self%cofgen))error stop 'AHL10A provider not ready'
    call self%analytical%evaluate(pressure_head,wa,ka,ca,da)

    do i=1,size(pressure_head)
      if(pressure_head(i)<=LOOKUP_H_MAX.and.pressure_head(i)>=-1.0e6_real64)then
        xv=log10(-pressure_head(i))
        call locate(self%x,xv,idx,f)
        if(self%mode==AHL10A_EXACTRC_LOOKUPK)then
          water_content(i)=wa(i)
          capacity(i)=ca(i)
        else
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
        end if

        if(self%mode==AHL10A_DC_EXACTK)then
          conductivity(i)=exact_k(self%cofgen(:,i),pressure_head(i),water_content(i))
        else
          conductivity(i)=exp(self%logk(idx)+f*(self%logk(idx+1)-self%logk(idx)))
        end if
        dconductivity_dhead(i)=0.0_real64
      else
        water_content(i)=wa(i);conductivity(i)=ka(i);capacity(i)=ca(i);dconductivity_dhead(i)=da(i)
      end if
    end do
  end subroutine eval_provider

  pure real(real64) function exact_k(c,head,theta) result(k)
    real(real64),intent(in)::c(:),head,theta
    real(real64)::relsat,term1,term2,se
    relsat=(theta-c(1))/c(25)
    if(c(9)>HCRIT)then
      if(head < -1.0e14_real64)then
        k=KSMALL
      else if(relsat > 1.0_real64-1.0e-6_real64)then
        k=c(3)
      else
        term1=(1.0_real64-relsat**c(32))**c(7)
        k=c(3)*(relsat**c(5))*(1.0_real64-term1)**2
      end if
    else
      if(head < -1.0e14_real64)then
        k=KSMALL
      else if(head>=c(9))then
        k=c(3)
      else
        se=((1.0_real64+abs(c(4)*head)**c(6))**(-c(7)))/c(28)
        term1=(1.0_real64-(se*c(28))**c(32))**c(7)
        term2=(1.0_real64-c(28)**c(32))**c(7)
        k=c(3)*se**c(5)*((1.0_real64-term1)/(1.0_real64-term2))**2
      end if
    end if
    k=min(k,c(3))
  end function exact_k

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
end module mod_ahl10a_attribution_provider
