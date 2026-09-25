module mod_ahl47_direct_retention_provider
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t, &
       CONSTITUTIVE_DEMAND_WATER_CONTENT, CONSTITUTIVE_DEMAND_CAPACITY
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  implicit none
  private
  integer, parameter :: NINT_MAX=256
  type, extends(constitutive_hydraulics_provider_t), public :: ahl47_provider_t
    type(b110_default_mvg_provider_t) :: analytical
    real(real64) :: theta_tab(0:NINT_MAX,0:5)=0.0_real64
    real(real64) :: c_tab(0:NINT_MAX,0:5)=0.0_real64
    integer :: nint=256
    logical :: ready=.false.
  contains
    procedure :: evaluate => ahl47_evaluate
    procedure :: evaluate_demand => ahl47_evaluate_demand
  end type
  public :: bind_ahl47_provider
contains
  subroutine bind_ahl47_provider(self,p,dt,ok,intervals_per_decade)
    type(ahl47_provider_t),intent(out)::self
    type(b110_default_mvg_parameters_t),target,intent(in)::p
    real(real64),intent(in)::dt
    logical,intent(out)::ok
    integer,intent(in),optional::intervals_per_decade
    type(b110_default_mvg_parameters_t),target::one
    type(b110_default_mvg_provider_t)::sampler
    real(real64)::cof(42,1),h(1),w(1),k(1),c(1),d(1),lo,hi,x
    integer::dec,j
    ok=.false.
    self%nint=256
    if(present(intervals_per_decade))self%nint=intervals_per_decade
    if(self%nint<1 .or. self%nint>NINT_MAX)return
    if(p%active_nodes<=0 .or. .not.allocated(p%cofgen))return
    if(any(p%cofgen(:,2:p%active_nodes)/=spread(p%cofgen(:,1),2,max(0,p%active_nodes-1))))then
      return
    end if
    call bind_b110_default_mvg_provider(self%analytical,p,dt)
    cof(:,1)=p%cofgen(:,1)
    call initialize_b110_default_mvg_parameters(one,cof,p%ksatexm_extension_enabled)
    call bind_b110_default_mvg_provider(sampler,one,dt)
    do dec=0,5
      lo=10.0_real64**dec;hi=10.0_real64**(dec+1)
      do j=0,self%nint
        x=lo+(hi-lo)*real(j,real64)/real(self%nint,real64);h(1)=-x
        call sampler%evaluate_demand(h,CONSTITUTIVE_DEMAND_WATER_CONTENT,w,k,c,d)
        self%theta_tab(j,dec)=w(1)
        call sampler%evaluate_demand(h,CONSTITUTIVE_DEMAND_CAPACITY,w,k,c,d)
        self%c_tab(j,dec)=c(1)
      end do
    end do
    self%ready=.true.;ok=.true.
  end subroutine
  subroutine ahl47_evaluate(self,pressure_head,water_content,conductivity,capacity,dconductivity_dhead)
    class(ahl47_provider_t),intent(in)::self
    real(real64),intent(in)::pressure_head(:)
    real(real64),intent(out)::water_content(:),conductivity(:),capacity(:),dconductivity_dhead(:)
    if(.not.self%ready)error stop 'AHL47 provider not ready'
    call self%analytical%evaluate(pressure_head,water_content,conductivity,capacity,dconductivity_dhead)
  end subroutine
  subroutine ahl47_evaluate_demand(self,pressure_head,demand_mask,water_content,conductivity,capacity,dconductivity_dhead)
    class(ahl47_provider_t),intent(in)::self
    real(real64),intent(in)::pressure_head(:)
    integer,intent(in)::demand_mask
    real(real64),intent(out)::water_content(:),conductivity(:),capacity(:),dconductivity_dhead(:)
    integer::i
    real(real64)::tt,cc
    if(.not.self%ready)error stop 'AHL47 provider not ready'
    if(demand_mask/=CONSTITUTIVE_DEMAND_WATER_CONTENT .and. demand_mask/=CONSTITUTIVE_DEMAND_CAPACITY)then
      call self%analytical%evaluate_demand(pressure_head,demand_mask,water_content,conductivity,capacity,dconductivity_dhead);return
    end if
    do i=1,size(pressure_head)
      if(pressure_head(i)>-1.0_real64 .or. pressure_head(i)<-1.0e6_real64)then
        call self%analytical%evaluate_demand(pressure_head(i:i),demand_mask,water_content(i:i),conductivity(i:i),capacity(i:i),dconductivity_dhead(i:i))
      else
        call direct_eval(pressure_head(i),self%theta_tab,self%c_tab,self%nint,tt,cc)
        if(demand_mask==CONSTITUTIVE_DEMAND_WATER_CONTENT)water_content(i)=tt
        if(demand_mask==CONSTITUTIVE_DEMAND_CAPACITY)capacity(i)=cc
      end if
    end do
  end subroutine
  pure subroutine direct_eval(head,t,c,nint,theta,cap)
    integer,intent(in)::nint
    real(real64),intent(in)::head,t(0:NINT_MAX,0:5),c(0:NINT_MAX,0:5)
    real(real64),intent(out)::theta,cap
    real(real64)::x,lo,hi,q,u,dx,h00,h10,h01,h11,dh00,dh10,dh01,dh11,dthdx
    integer::dec,j
    x=-head
    if(x<10)then;dec=0;lo=1;hi=10
    else if(x<100)then;dec=1;lo=10;hi=100
    else if(x<1000)then;dec=2;lo=100;hi=1000
    else if(x<10000)then;dec=3;lo=1000;hi=10000
    else if(x<100000)then;dec=4;lo=10000;hi=100000
    else;dec=5;lo=100000;hi=1000000;end if
    dx=(hi-lo)/real(nint,real64);q=(x-lo)/dx;j=min(nint-1,max(0,int(q)));u=q-real(j,real64)
    h00=2*u**3-3*u**2+1;h10=u**3-2*u**2+u;h01=-2*u**3+3*u**2;h11=u**3-u**2
    theta=h00*t(j,dec)+h10*dx*(-c(j,dec))+h01*t(j+1,dec)+h11*dx*(-c(j+1,dec))
    dh00=6*u*u-6*u;dh10=3*u*u-4*u+1;dh01=-6*u*u+6*u;dh11=3*u*u-2*u
    dthdx=(dh00*t(j,dec)+dh10*dx*(-c(j,dec))+dh01*t(j+1,dec)+dh11*dx*(-c(j+1,dec)))/dx
    cap=-dthdx
  end subroutine
end module
