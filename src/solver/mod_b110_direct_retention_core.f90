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

  public :: acquire_b110_direct_retention_slot
  public :: sample_b110_direct_retention
  public :: freeze_b110_direct_retention_pool
  public :: reset_b110_direct_retention_pool
  public :: b110_direct_retention_pool_stats

contains

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

end module mod_b110_direct_retention_core
