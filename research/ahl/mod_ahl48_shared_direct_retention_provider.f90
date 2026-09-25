module mod_ahl48_shared_direct_retention_provider
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t, &
       CONSTITUTIVE_DEMAND_WATER_CONTENT, CONSTITUTIVE_DEMAND_CAPACITY
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  implicit none
  private

  integer, parameter :: NINT=64

  type :: ahl48_representation_t
    integer(int64) :: authority_bits(42)=0_int64
    logical :: ksatexm=.false.
    real(real64) :: theta_tab(0:NINT,0:5)=0.0_real64
    real(real64) :: c_tab(0:NINT,0:5)=0.0_real64
  end type

  type(ahl48_representation_t), allocatable, save :: pool(:)
  integer, save :: build_count=0, hit_count=0
  logical, save :: frozen=.false.

  type, extends(constitutive_hydraulics_provider_t), public :: ahl48_shared_provider_t
    type(b110_default_mvg_provider_t) :: analytical
    integer :: slot=0
    logical :: ready=.false.
  contains
    procedure :: evaluate => ahl48_evaluate
    procedure :: evaluate_demand => ahl48_evaluate_demand
  end type

  public :: bind_ahl48_shared_provider
  public :: ahl48_shared_pool_stats
  public :: ahl48_freeze_shared_pool
  public :: ahl48_reset_shared_pool

contains

  subroutine bind_ahl48_shared_provider(self,p,dt,ok,was_hit)
    type(ahl48_shared_provider_t),intent(out)::self
    type(b110_default_mvg_parameters_t),target,intent(in)::p
    real(real64),intent(in)::dt
    logical,intent(out)::ok,was_hit
    integer(int64)::bits(42)
    integer::i,n
    type(ahl48_representation_t),allocatable::grown(:)

    ok=.false.;was_hit=.false.;self%slot=0;self%ready=.false.
    if(p%active_nodes<=0 .or. .not.allocated(p%cofgen))return
    if(size(p%cofgen,1)<42)return
    if(p%active_nodes>1)then
      if(any(p%cofgen(:,2:p%active_nodes)/=spread(p%cofgen(:,1),2,p%active_nodes-1)))return
    end if
    call bind_b110_default_mvg_provider(self%analytical,p,dt)
    bits=transfer(p%cofgen(1:42,1),bits)

    if(allocated(pool))then
      do i=1,size(pool)
        if(pool(i)%ksatexm .eqv. p%ksatexm_extension_enabled)then
          if(all(pool(i)%authority_bits==bits))then
            self%slot=i;self%ready=.true.;was_hit=.true.;hit_count=hit_count+1;ok=.true.;return
          end if
        end if
      end do
    end if

    if(frozen)return

    if(.not.allocated(pool))then
      allocate(pool(1));n=1
    else
      n=size(pool)+1
      allocate(grown(n));grown(1:n-1)=pool
      call move_alloc(grown,pool)
    end if
    pool(n)%authority_bits=bits
    pool(n)%ksatexm=p%ksatexm_extension_enabled
    call build_representation(pool(n),p,dt)
    build_count=build_count+1
    self%slot=n;self%ready=.true.;ok=.true.
  end subroutine

  subroutine build_representation(rep,p,dt)
    type(ahl48_representation_t),intent(inout)::rep
    type(b110_default_mvg_parameters_t),intent(in)::p
    real(real64),intent(in)::dt
    type(b110_default_mvg_parameters_t),target::one
    type(b110_default_mvg_provider_t)::sampler
    real(real64)::cof(42,1),h(1),w(1),k(1),c(1),d(1),lo,hi,x
    integer::dec,j
    cof(:,1)=p%cofgen(1:42,1)
    call initialize_b110_default_mvg_parameters(one,cof,p%ksatexm_extension_enabled)
    call bind_b110_default_mvg_provider(sampler,one,dt)
    do dec=0,5
      lo=10.0_real64**dec;hi=10.0_real64**(dec+1)
      do j=0,NINT
        x=lo+(hi-lo)*real(j,real64)/real(NINT,real64);h(1)=-x
        call sampler%evaluate_demand(h,CONSTITUTIVE_DEMAND_WATER_CONTENT,w,k,c,d)
        rep%theta_tab(j,dec)=w(1)
        call sampler%evaluate_demand(h,CONSTITUTIVE_DEMAND_CAPACITY,w,k,c,d)
        rep%c_tab(j,dec)=c(1)
      end do
    end do
  end subroutine

  subroutine ahl48_evaluate(self,pressure_head,water_content,conductivity,capacity,dconductivity_dhead)
    class(ahl48_shared_provider_t),intent(in)::self
    real(real64),intent(in)::pressure_head(:)
    real(real64),intent(out)::water_content(:),conductivity(:),capacity(:),dconductivity_dhead(:)
    if(.not.self%ready)error stop 'AHL48 shared provider not ready'
    call self%analytical%evaluate(pressure_head,water_content,conductivity,capacity,dconductivity_dhead)
  end subroutine

  subroutine ahl48_evaluate_demand(self,pressure_head,demand_mask,water_content,conductivity,capacity,dconductivity_dhead)
    class(ahl48_shared_provider_t),intent(in)::self
    real(real64),intent(in)::pressure_head(:)
    integer,intent(in)::demand_mask
    real(real64),intent(out)::water_content(:),conductivity(:),capacity(:),dconductivity_dhead(:)
    integer::i
    real(real64)::tt,cc
    if(.not.self%ready .or. .not.allocated(pool))error stop 'AHL48 shared provider not ready'
    if(self%slot<1 .or. self%slot>size(pool))error stop 'AHL48 shared provider invalid slot'
    if(demand_mask/=CONSTITUTIVE_DEMAND_WATER_CONTENT .and. demand_mask/=CONSTITUTIVE_DEMAND_CAPACITY)then
      call self%analytical%evaluate_demand(pressure_head,demand_mask,water_content,conductivity,capacity,dconductivity_dhead)
      return
    end if
    do i=1,size(pressure_head)
      if(pressure_head(i)>-1.0_real64 .or. pressure_head(i)<-1.0e6_real64)then
        call self%analytical%evaluate_demand(pressure_head(i:i),demand_mask,water_content(i:i),conductivity(i:i), &
             capacity(i:i),dconductivity_dhead(i:i))
      else
        call direct_eval(pressure_head(i),pool(self%slot)%theta_tab,pool(self%slot)%c_tab,tt,cc)
        if(demand_mask==CONSTITUTIVE_DEMAND_WATER_CONTENT)water_content(i)=tt
        if(demand_mask==CONSTITUTIVE_DEMAND_CAPACITY)capacity(i)=cc
      end if
    end do
  end subroutine

  pure subroutine direct_eval(head,t,c,theta,cap)
    real(real64),intent(in)::head,t(0:NINT,0:5),c(0:NINT,0:5)
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
    dx=(hi-lo)/real(NINT,real64);q=(x-lo)/dx;j=min(NINT-1,max(0,int(q)));u=q-real(j,real64)
    h00=2*u**3-3*u**2+1;h10=u**3-2*u**2+u;h01=-2*u**3+3*u**2;h11=u**3-u**2
    theta=h00*t(j,dec)+h10*dx*(-c(j,dec))+h01*t(j+1,dec)+h11*dx*(-c(j+1,dec))
    dh00=6*u*u-6*u;dh10=3*u*u-4*u+1;dh01=-6*u*u+6*u;dh11=3*u*u-2*u
    dthdx=(dh00*t(j,dec)+dh10*dx*(-c(j,dec))+dh01*t(j+1,dec)+dh11*dx*(-c(j+1,dec)))/dx
    cap=-dthdx
  end subroutine

  subroutine ahl48_shared_pool_stats(entries,builds,hits,raw_payload_bytes,provider_bytes,is_frozen)
    integer,intent(out)::entries,builds,hits
    integer(int64),intent(out)::raw_payload_bytes,provider_bytes
    logical,intent(out)::is_frozen
    type(ahl48_shared_provider_t)::probe
    if(allocated(pool))then;entries=size(pool);else;entries=0;end if
    builds=build_count;hits=hit_count
    raw_payload_bytes=int(entries,int64)*int(2*(NINT+1)*6*8,int64)
    provider_bytes=int(storage_size(probe)/8,int64)
    is_frozen=frozen
  end subroutine

  subroutine ahl48_freeze_shared_pool()
    frozen=.true.
  end subroutine

  subroutine ahl48_reset_shared_pool()
    if(allocated(pool))deallocate(pool)
    build_count=0;hit_count=0;frozen=.false.
  end subroutine

end module mod_ahl48_shared_direct_retention_provider
