module mod_b110_direct_retention_core
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_soil_water_solver_contract, only: CONSTITUTIVE_DEMAND_WATER_CONTENT, CONSTITUTIVE_DEMAND_CAPACITY
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  implicit none
  private

  integer, parameter, public :: B110_DIRECT_RETENTION_INTERVALS_PER_DECADE = 64

  type :: direct_retention_representation_t
    integer(int64) :: authority_bits(42)=0_int64
    logical :: ksatexm=.false.
    real(real64) :: theta(0:B110_DIRECT_RETENTION_INTERVALS_PER_DECADE,0:5)=0.0_real64
    real(real64) :: capacity(0:B110_DIRECT_RETENTION_INTERVALS_PER_DECADE,0:5)=0.0_real64
  end type direct_retention_representation_t

  type(direct_retention_representation_t), allocatable, save :: pool(:)
  logical, save :: frozen=.false.
  integer, save :: build_count=0, hit_count=0
  logical, save :: application_owner_active=.false.

  public :: acquire_b110_direct_retention_slot
  public :: sample_b110_direct_retention
  public :: freeze_b110_direct_retention_pool
  public :: reset_b110_direct_retention_pool
  public :: b110_direct_retention_pool_stats
  public :: begin_b110_direct_retention_application
  public :: end_b110_direct_retention_application

contains

  subroutine begin_b110_direct_retention_application(ok)
    logical,intent(out)::ok
    ok=.false.
    if(application_owner_active)return
    call clear_b110_direct_retention_pool()
    application_owner_active=.true.
    ok=.true.
  end subroutine begin_b110_direct_retention_application

  subroutine end_b110_direct_retention_application()
    if(.not.application_owner_active)return
    call clear_b110_direct_retention_pool()
    application_owner_active=.false.
  end subroutine end_b110_direct_retention_application

  subroutine acquire_b110_direct_retention_slot(parameters,slot,ok,was_hit)
    type(b110_default_mvg_parameters_t),intent(in)::parameters
    integer,intent(out)::slot
    logical,intent(out)::ok,was_hit
    integer(int64)::bits(42)
    integer::i,n
    type(direct_retention_representation_t),allocatable::grown(:)

    slot=0
    ok=.false.
    was_hit=.false.
    if(parameters%active_nodes<=0 .or. .not.allocated(parameters%cofgen))return
    if(size(parameters%cofgen,1)<42)return
    if(parameters%active_nodes>1)then
      if(any(parameters%cofgen(:,2:parameters%active_nodes)/= &
           spread(parameters%cofgen(:,1),2,parameters%active_nodes-1)))return
    end if
    bits=transfer(parameters%cofgen(1:42,1),bits)

    if(allocated(pool))then
      do i=1,size(pool)
        if((pool(i)%ksatexm .eqv. parameters%ksatexm_extension_enabled) .and. &
             all(pool(i)%authority_bits==bits))then
          slot=i
          ok=.true.
          was_hit=.true.
          hit_count=hit_count+1
          return
        end if
      end do
    end if
    if(frozen)return

    if(.not.allocated(pool))then
      allocate(pool(1))
      n=1
    else
      n=size(pool)+1
      allocate(grown(n))
      grown(1:n-1)=pool
      call move_alloc(grown,pool)
    end if
    pool(n)%authority_bits=bits
    pool(n)%ksatexm=parameters%ksatexm_extension_enabled
    call build_representation(pool(n),parameters)
    build_count=build_count+1
    slot=n
    ok=.true.
  end subroutine acquire_b110_direct_retention_slot

  subroutine build_representation(rep,parameters)
    type(direct_retention_representation_t),intent(inout)::rep
    type(b110_default_mvg_parameters_t),intent(in)::parameters
    type(b110_default_mvg_parameters_t),target::one
    type(b110_default_mvg_provider_t)::sampler
    real(real64)::cofgen(42,1),head(1),water(1),conductivity(1),capacity(1),dkdh(1)
    real(real64)::lo,hi,x
    integer::dec,j

    cofgen(:,1)=parameters%cofgen(1:42,1)
    call initialize_b110_default_mvg_parameters(one,cofgen,parameters%ksatexm_extension_enabled)
    call bind_b110_default_mvg_provider(sampler,one,1.0_real64)

    do dec=0,5
      lo=10.0_real64**dec
      hi=10.0_real64**(dec+1)
      do j=0,B110_DIRECT_RETENTION_INTERVALS_PER_DECADE
        x=lo+(hi-lo)*real(j,real64)/real(B110_DIRECT_RETENTION_INTERVALS_PER_DECADE,real64)
        head(1)=-x
        call sampler%evaluate_demand(head,CONSTITUTIVE_DEMAND_WATER_CONTENT, &
             water,conductivity,capacity,dkdh)
        rep%theta(j,dec)=water(1)
        call sampler%evaluate_demand(head,CONSTITUTIVE_DEMAND_CAPACITY, &
             water,conductivity,capacity,dkdh)
        rep%capacity(j,dec)=capacity(1)
      end do
    end do
  end subroutine build_representation

  subroutine sample_b110_direct_retention(slot,head,theta,capacity,inside)
    integer,intent(in)::slot
    real(real64),intent(in)::head
    real(real64),intent(out)::theta,capacity
    logical,intent(out)::inside
    real(real64)::x,lo,hi,q,u,dx,h00,h10,h01,h11,dh00,dh10,dh01,dh11,dthdx
    integer::dec,j

    theta=0.0_real64
    capacity=0.0_real64
    inside=.false.
    if(.not.allocated(pool))return
    if(slot<1 .or. slot>size(pool))return
    if(head>-1.0_real64 .or. head< -1.0e6_real64)return

    x=-head
    if(x<10.0_real64)then;dec=0;lo=1.0_real64;hi=10.0_real64
    else if(x<100.0_real64)then;dec=1;lo=10.0_real64;hi=100.0_real64
    else if(x<1000.0_real64)then;dec=2;lo=100.0_real64;hi=1000.0_real64
    else if(x<10000.0_real64)then;dec=3;lo=1000.0_real64;hi=10000.0_real64
    else if(x<100000.0_real64)then;dec=4;lo=10000.0_real64;hi=100000.0_real64
    else;dec=5;lo=100000.0_real64;hi=1000000.0_real64;end if

    dx=(hi-lo)/real(B110_DIRECT_RETENTION_INTERVALS_PER_DECADE,real64)
    q=(x-lo)/dx
    j=min(B110_DIRECT_RETENTION_INTERVALS_PER_DECADE-1,max(0,int(q)))
    u=q-real(j,real64)

    h00=2*u**3-3*u**2+1
    h10=u**3-2*u**2+u
    h01=-2*u**3+3*u**2
    h11=u**3-u**2
    theta=h00*pool(slot)%theta(j,dec)+h10*dx*(-pool(slot)%capacity(j,dec))+ &
          h01*pool(slot)%theta(j+1,dec)+h11*dx*(-pool(slot)%capacity(j+1,dec))

    dh00=6*u*u-6*u
    dh10=3*u*u-4*u+1
    dh01=-6*u*u+6*u
    dh11=3*u*u-2*u
    dthdx=(dh00*pool(slot)%theta(j,dec)+dh10*dx*(-pool(slot)%capacity(j,dec))+ &
           dh01*pool(slot)%theta(j+1,dec)+dh11*dx*(-pool(slot)%capacity(j+1,dec)))/dx
    capacity=-dthdx
    inside=.true.
  end subroutine sample_b110_direct_retention

  subroutine freeze_b110_direct_retention_pool()
    frozen=.true.
  end subroutine freeze_b110_direct_retention_pool

  subroutine reset_b110_direct_retention_pool()
    if(application_owner_active)return
    call clear_b110_direct_retention_pool()
  end subroutine reset_b110_direct_retention_pool

  subroutine clear_b110_direct_retention_pool()
    if(allocated(pool))deallocate(pool)
    frozen=.false.
    build_count=0
    hit_count=0
  end subroutine clear_b110_direct_retention_pool

  subroutine b110_direct_retention_pool_stats(entries,builds,hits,payload_bytes,is_frozen)
    integer,intent(out)::entries,builds,hits
    integer(int64),intent(out)::payload_bytes
    logical,intent(out)::is_frozen
    if(allocated(pool))then
      entries=size(pool)
    else
      entries=0
    end if
    builds=build_count
    hits=hit_count
    payload_bytes=int(entries,int64)*6240_int64
    is_frozen=frozen
  end subroutine b110_direct_retention_pool_stats

end module mod_b110_direct_retention_core
