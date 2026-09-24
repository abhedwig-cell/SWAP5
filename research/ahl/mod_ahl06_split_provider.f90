module mod_ahl06_split_provider
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       bind_b110_default_mvg_provider
  implicit none
  private

  real(real64), parameter :: LOOKUP_H_MAX=-1.0_real64
  real(real64), parameter :: HCRIT=-1.0e-2_real64

  type, extends(constitutive_hydraulics_provider_t), public :: ahl06_split_provider_t
    private
    type(b110_default_mvg_provider_t) :: analytical
    real(real64), pointer :: cofgen(:,:) => null()
    real(real64), allocatable :: x(:), logc(:), logk(:)
    logical :: ready=.false.
  contains
    procedure :: evaluate => split_evaluate
  end type ahl06_split_provider_t

  public :: bind_ahl06_split_provider

contains

  subroutine bind_ahl06_split_provider(provider, parameters, step_duration, table_path, valid)
    type(ahl06_split_provider_t), intent(out) :: provider
    type(b110_default_mvg_parameters_t), target, intent(in) :: parameters
    real(real64), intent(in) :: step_duration
    character(len=*), intent(in) :: table_path
    logical, intent(out) :: valid
    integer :: u,ios,n,i
    real(real64) :: ignored

    valid=.false.; provider%ready=.false.
    call bind_b110_default_mvg_provider(provider%analytical,parameters,step_duration)
    if (.not. allocated(parameters%cofgen)) return
    provider%cofgen=>parameters%cofgen
    open(newunit=u,file=trim(table_path),status='old',action='read',iostat=ios)
    if (ios/=0) return
    read(u,*,iostat=ios) n
    if (ios/=0 .or. n<2) then; close(u); return; end if
    allocate(provider%x(n),provider%logc(n),provider%logk(n))
    do i=1,n
      read(u,*,iostat=ios) provider%x(i),ignored,provider%logc(i),provider%logk(i)
      if (ios/=0) then; close(u); return; end if
    end do
    close(u)
    if (any(provider%x(2:)<=provider%x(:n-1))) return
    provider%ready=.true.; valid=.true.
  end subroutine bind_ahl06_split_provider

  subroutine split_evaluate(self,pressure_head,water_content,conductivity,capacity,dconductivity_dhead)
    class(ahl06_split_provider_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:)
    real(real64), intent(out) :: water_content(:),conductivity(:),capacity(:),dconductivity_dhead(:)
    real(real64), allocatable :: h_exact(:),w_exact(:),k_exact(:),c_exact(:),d_exact(:)
    real(real64) :: xv,f
    integer :: i,idx,n

    if (.not.self%ready .or. .not.associated(self%cofgen)) error stop 'AHL06 provider not ready'
    n=size(pressure_head)
    allocate(h_exact(n),w_exact(n),k_exact(n),c_exact(n),d_exact(n))
    h_exact=pressure_head

    ! Exact analytical fallback is evaluated only when at least one node lies
    ! outside the frozen lookup domain. For the lookup-domain nodes theta is
    ! evaluated directly from the authoritative B1.10 retention relation.
    if (any(pressure_head>LOOKUP_H_MAX) .or. any(pressure_head < -1.0e6_real64)) then
      call self%analytical%evaluate(pressure_head,w_exact,k_exact,c_exact,d_exact)
    else
      w_exact=0.0_real64; k_exact=0.0_real64; c_exact=0.0_real64; d_exact=0.0_real64
    end if

    do i=1,n
      if (pressure_head(i)<=LOOKUP_H_MAX .and. pressure_head(i)>=-1.0e6_real64) then
        water_content(i)=exact_theta(self%cofgen(:,i),pressure_head(i))
        xv=log10(-pressure_head(i))
        call locate(self%x,xv,idx,f)
        capacity(i)=exp(self%logc(idx)+f*(self%logc(idx+1)-self%logc(idx)))
        conductivity(i)=exp(self%logk(idx)+f*(self%logk(idx+1)-self%logk(idx)))
        dconductivity_dhead(i)=0.0_real64
      else
        water_content(i)=w_exact(i)
        capacity(i)=c_exact(i)
        conductivity(i)=k_exact(i)
        dconductivity_dhead(i)=d_exact(i)
      end if
    end do
  end subroutine split_evaluate

  pure real(real64) function exact_theta(c,head) result(theta)
    real(real64), intent(in) :: c(:),head
    real(real64) :: help,h105
    if (head>=0.0_real64) then
      theta=c(2)
    else if (c(9)>HCRIT) then
      if (head>HCRIT) then
        theta=min(c(26)+c(27)*(head-HCRIT),c(2))
      else
        help=(1.0_real64+abs(c(4)*head)**c(6))**c(7)
        theta=c(1)+c(25)/help
      end if
    else
      h105=1.05_real64*c(9)
      if (head>=h105) then
        theta=c(2)+c(42)*head/(1.0_real64+c(41)*head)
      else
        help=(1.0_real64+abs(c(4)*head)**c(6))**c(7)
        theta=c(1)+c(25)/(help*c(28))
      end if
    end if
  end function exact_theta

  pure subroutine locate(x,value,idx,fraction)
    real(real64), intent(in) :: x(:),value
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
end module mod_ahl06_split_provider
