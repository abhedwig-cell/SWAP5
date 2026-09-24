module mod_ahl08_klookup_provider
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       bind_b110_default_mvg_provider
  implicit none
  private

  real(real64), parameter :: LOOKUP_H_MAX=-1.0_real64
  real(real64), parameter :: HCRIT=-1.0e-2_real64

  type, extends(constitutive_hydraulics_provider_t), public :: ahl08_klookup_provider_t
    private
    type(b110_default_mvg_provider_t) :: analytical
    real(real64), pointer :: cofgen(:,:) => null()
    real(real64), allocatable :: x(:), logk(:)
    real(real64) :: step_duration=0.0_real64
    logical :: ready=.false.
  contains
    procedure :: evaluate => klookup_evaluate
  end type ahl08_klookup_provider_t

  public :: bind_ahl08_klookup_provider

contains

  subroutine bind_ahl08_klookup_provider(provider,parameters,step_duration,table_path,valid)
    type(ahl08_klookup_provider_t), intent(out) :: provider
    type(b110_default_mvg_parameters_t), target, intent(in) :: parameters
    real(real64), intent(in) :: step_duration
    character(len=*), intent(in) :: table_path
    logical, intent(out) :: valid
    integer :: u,ios,n,i
    real(real64) :: ignored1,ignored2

    valid=.false.;provider%ready=.false.;provider%step_duration=step_duration
    call bind_b110_default_mvg_provider(provider%analytical,parameters,step_duration)
    if(.not.allocated(parameters%cofgen)) return
    provider%cofgen=>parameters%cofgen
    open(newunit=u,file=trim(table_path),status='old',action='read',iostat=ios)
    if(ios/=0) return
    read(u,*,iostat=ios) n
    if(ios/=0 .or. n<2) then;close(u);return;end if
    allocate(provider%x(n),provider%logk(n))
    do i=1,n
      read(u,*,iostat=ios) provider%x(i),ignored1,ignored2,provider%logk(i)
      if(ios/=0) then;close(u);return;end if
    end do
    close(u)
    if(any(provider%x(2:)<=provider%x(:n-1))) return
    provider%ready=.true.;valid=.true.
  end subroutine bind_ahl08_klookup_provider

  subroutine klookup_evaluate(self,pressure_head,water_content,conductivity,capacity,dconductivity_dhead)
    class(ahl08_klookup_provider_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:)
    real(real64), intent(out) :: water_content(:),conductivity(:),capacity(:),dconductivity_dhead(:)
    real(real64) :: w_exact(size(pressure_head)),k_exact(size(pressure_head)), &
         c_exact(size(pressure_head)),d_exact(size(pressure_head))
    real(real64) :: xv,f
    integer :: i,idx

    if(.not.self%ready .or. .not.associated(self%cofgen)) error stop 'AHL08 provider not ready'
    if(any(pressure_head>LOOKUP_H_MAX) .or. any(pressure_head < -1.0e6_real64)) then
      call self%analytical%evaluate(pressure_head,w_exact,k_exact,c_exact,d_exact)
    end if

    do i=1,size(pressure_head)
      if(pressure_head(i)<=LOOKUP_H_MAX .and. pressure_head(i)>=-1.0e6_real64) then
        water_content(i)=exact_theta(self%cofgen(:,i),pressure_head(i))
        capacity(i)=exact_capacity(self%cofgen(:,i),pressure_head(i),self%step_duration)
        xv=log10(-pressure_head(i))
        call locate(self%x,xv,idx,f)
        conductivity(i)=exp(self%logk(idx)+f*(self%logk(idx+1)-self%logk(idx)))
        dconductivity_dhead(i)=0.0_real64
      else
        water_content(i)=w_exact(i)
        conductivity(i)=k_exact(i)
        capacity(i)=c_exact(i)
        dconductivity_dhead(i)=d_exact(i)
      end if
    end do
  end subroutine klookup_evaluate

  pure real(real64) function exact_theta(c,head) result(theta)
    real(real64),intent(in)::c(:),head
    real(real64)::help,h105
    if(head>=0.0_real64) then
      theta=c(2)
    else if(c(9)>HCRIT) then
      if(head>HCRIT) then
        theta=min(c(26)+c(27)*(head-HCRIT),c(2))
      else
        help=(1.0_real64+abs(c(4)*head)**c(6))**c(7)
        theta=c(1)+c(25)/help
      end if
    else
      h105=1.05_real64*c(9)
      if(head>=h105) then
        theta=c(2)+c(42)*head/(1.0_real64+c(41)*head)
      else
        help=(1.0_real64+abs(c(4)*head)**c(6))**c(7)
        theta=c(1)+c(25)/(help*c(28))
      end if
    end if
  end function exact_theta

  pure real(real64) function exact_capacity(c,head,dt) result(capacity)
    real(real64),intent(in)::c(:),head,dt
    real(real64)::alphah,h105,term1,term2
    if(head>=0.0_real64) then
      capacity=dt*1.0e-7_real64
    else
      alphah=abs(c(4)*head)
      if(c(9)>HCRIT) then
        if(head>HCRIT) then
          capacity=c(27)
        else
          term1=alphah**c(30)
          term2=c(25)/((1.0_real64+term1*alphah)**c(31))
          capacity=c(29)*term2*term1
        end if
      else
        h105=1.05_real64*c(9)
        if(head>=h105) then
          capacity=c(42)/((1.0_real64+c(41)*head)**2)
        else
          term1=alphah**c(30)
          term2=(1.0_real64+term1*alphah)**c(31)
          term2=c(25)/term2
          capacity=c(29)*term2*term1/c(28)
        end if
      end if
      if(head>-1.0_real64 .and. capacity<dt*1.0e-7_real64) capacity=dt*1.0e-7_real64
    end if
  end function exact_capacity

  pure subroutine locate(x,value,idx,fraction)
    real(real64),intent(in)::x(:),value
    integer,intent(out)::idx
    real(real64),intent(out)::fraction
    integer::lo,hi,mid,n
    n=size(x)
    if(value<=x(1))then;idx=1;fraction=0.0_real64;return
    else if(value>=x(n))then;idx=n-1;fraction=1.0_real64;return
    end if
    lo=1;hi=n
    do while(hi-lo>1)
      mid=(lo+hi)/2
      if(x(mid)<=value)then;lo=mid;else;hi=mid;end if
    end do
    idx=lo;fraction=(value-x(lo))/(x(lo+1)-x(lo))
  end subroutine locate
end module mod_ahl08_klookup_provider
