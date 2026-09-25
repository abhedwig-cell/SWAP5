module mod_b110_adaptive_hydraulic_provider
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_adaptive_hydraulic_builder, only: b110_adaptive_hydraulic_table_t
  use mod_b110_adaptive_hydraulic_cache, only: b110_adaptive_hydraulic_cache_t, b110_adaptive_hydraulic_cache_key_t, &
       make_b110_adaptive_hydraulic_key, b110_adaptive_hydraulic_keys_equal
  implicit none
  private

  real(real64), parameter :: LOOKUP_H_MAX=-1.0_real64
  real(real64), parameter :: LN10=log(10.0_real64)
  integer, parameter :: POLICY_VERSION=4, BRANCH_POLICY_VERSION=2
  character(len=*), parameter :: MODEL_ID='B110_DEFAULT_MVG'

  type(b110_adaptive_hydraulic_cache_t), save :: shared_cache

  type :: b110_adaptive_hydraulic_representation_t
    type(b110_adaptive_hydraulic_table_t) :: table
    type(b110_adaptive_hydraulic_cache_key_t) :: key
    logical :: key_valid=.false.
  end type b110_adaptive_hydraulic_representation_t

  type, extends(constitutive_hydraulics_provider_t), public :: b110_adaptive_hydraulic_provider_t
    private
    type(b110_default_mvg_provider_t) :: analytical
    real(real64), pointer :: cofgen(:,:) => null()
    type(b110_adaptive_hydraulic_representation_t), allocatable :: representation(:)
    integer, allocatable :: node_representation(:)
    integer :: representation_count=0
    logical :: ready=.false.
  contains
    procedure :: evaluate => b110_adaptive_hydraulic_evaluate
  end type b110_adaptive_hydraulic_provider_t

  public :: bind_b110_adaptive_hydraulic_provider
  public :: b110_adaptive_hydraulic_cache_stats

contains

  subroutine bind_b110_adaptive_hydraulic_provider(provider,parameters,step_duration,ok,was_hit,prefer_registry_handle)
    type(b110_adaptive_hydraulic_provider_t),intent(inout)::provider
    type(b110_default_mvg_parameters_t),target,intent(in)::parameters
    real(real64),intent(in)::step_duration
    logical,intent(out)::ok,was_hit
    logical,intent(in),optional::prefer_registry_handle

    type(b110_default_mvg_parameters_t),target :: sampler_parameters
    type(b110_default_mvg_provider_t) :: sampler
    type(b110_adaptive_hydraulic_cache_key_t) :: key
    real(real64) :: one_node_input(42,1)
    logical :: same_profile,rep_hit,rep_ok,all_hit
    integer :: node,r,existing

    ! prefer_registry_handle is retained in the call signature for source
    ! compatibility with research harnesses, but canonical admission deliberately
    ! does not retain shared-cache handles during solve-time evaluation.
    if(present(prefer_registry_handle))then
      continue
    end if

    ok=.false.;was_hit=.false.
    if(parameters%active_nodes<=0 .or. .not.allocated(parameters%cofgen))then
      provider%ready=.false.
      return
    end if
    if(size(parameters%cofgen,1)<42 .or. size(parameters%cofgen,2)/=parameters%active_nodes)then
      provider%ready=.false.
      return
    end if

    ! Step-dependent analytical semantics are always rebound. Only immutable,
    ! provider-local adaptive representations may survive a same-profile rebind.
    call bind_b110_default_mvg_provider(provider%analytical,parameters,step_duration)
    provider%cofgen=>parameters%cofgen

    same_profile=provider%ready .and. same_profile_authority(provider,parameters)
    if(same_profile)then
      was_hit=.true.
      ok=.true.
      return
    end if

    provider%ready=.false.
    provider%representation_count=0
    if(allocated(provider%representation))deallocate(provider%representation)
    if(allocated(provider%node_representation))deallocate(provider%node_representation)
    allocate(provider%representation(parameters%active_nodes))
    allocate(provider%node_representation(parameters%active_nodes))
    provider%node_representation=0
    all_hit=.true.

    do node=1,parameters%active_nodes
      key=make_b110_adaptive_hydraulic_key(parameters,MODEL_ID,POLICY_VERSION,BRANCH_POLICY_VERSION,node)

      ! Reuse a representation already acquired for an identical authority in
      ! this profile. Equality is bit-exact over initialized B1.10 coefficients.
      existing=0
      do r=1,provider%representation_count
        if(provider%representation(r)%key_valid)then
          if(b110_adaptive_hydraulic_keys_equal(provider%representation(r)%key,key))then
            existing=r
            exit
          end if
        end if
      end do
      if(existing>0)then
        provider%node_representation(node)=existing
        cycle
      end if

      provider%representation_count=provider%representation_count+1
      r=provider%representation_count
      provider%node_representation(node)=r
      provider%representation(r)%key=key
      provider%representation(r)%key_valid=.true.

      one_node_input(:,1)=parameters%cofgen(1:42,node)
      call initialize_b110_default_mvg_parameters(sampler_parameters,one_node_input, &
           parameters%ksatexm_extension_enabled)
      call bind_b110_default_mvg_provider(sampler,sampler_parameters,step_duration)

      rep_hit=.false.;rep_ok=.false.
      ! The cache is a bind-time optimization only. Under OpenMP all mutable
      ! shared-cache acquisition is serialized; the returned table is copied
      ! into provider-local immutable state before the solve begins.
!$omp critical(b110_ahl_cache_bind)
      call shared_cache%lookup(key,provider%representation(r)%table,rep_hit)
      if(rep_hit)then
        rep_ok=.true.
      else
        call shared_cache%get_or_build(key,sampler_parameters,sampler,provider%representation(r)%table,rep_hit,rep_ok)
      end if
!$omp end critical(b110_ahl_cache_bind)
      if(.not.rep_ok)return
      all_hit=all_hit .and. rep_hit
    end do

    provider%ready=.true.
    was_hit=all_hit
    ok=.true.
  end subroutine bind_b110_adaptive_hydraulic_provider

  pure logical function same_profile_authority(provider,parameters) result(equal)
    type(b110_adaptive_hydraulic_provider_t),intent(in)::provider
    type(b110_default_mvg_parameters_t),intent(in)::parameters
    integer::node,r
    equal=.false.
    if(.not.allocated(provider%representation) .or. .not.allocated(provider%node_representation))return
    if(size(provider%node_representation)/=parameters%active_nodes)return
    if(.not.allocated(parameters%cofgen) .or. size(parameters%cofgen,1)<42)return
    do node=1,parameters%active_nodes
      r=provider%node_representation(node)
      if(r<1 .or. r>provider%representation_count)return
      if(.not.provider%representation(r)%key_valid)return
      if(.not.same_node_authority(provider%representation(r)%key,parameters,node))return
    end do
    equal=.true.
  end function same_profile_authority

  pure logical function same_node_authority(key,parameters,node) result(equal)
    type(b110_adaptive_hydraulic_cache_key_t),intent(in)::key
    type(b110_default_mvg_parameters_t),intent(in)::parameters
    integer,intent(in)::node
    integer(int64)::key_bits(42),parameter_bits(42)

    equal=.false.
    if(.not.allocated(parameters%cofgen))return
    if(node<1 .or. node>parameters%active_nodes .or. size(parameters%cofgen,1)<42)return
    if(key%ksatexm_extension_enabled .neqv. parameters%ksatexm_extension_enabled)return
    key_bits=transfer(key%coeff,key_bits)
    parameter_bits=transfer(parameters%cofgen(1:42,node),parameter_bits)
    equal=all(key_bits==parameter_bits)
  end function same_node_authority

  subroutine b110_adaptive_hydraulic_evaluate(self,pressure_head,water_content,conductivity,capacity,dconductivity_dhead)
    class(b110_adaptive_hydraulic_provider_t),intent(in)::self
    real(real64),intent(in)::pressure_head(:)
    real(real64),intent(out)::water_content(:),conductivity(:),capacity(:),dconductivity_dhead(:)

    real(real64) :: wa(size(pressure_head)),ka(size(pressure_head)),ca(size(pressure_head)),da(size(pressure_head))
    real(real64) :: xv,f,dx,t,h00,h10,h01,h11,dh00,h10d,dh01,dh11,zz,dz_x,se,span
    integer :: node,idx,r
    logical :: need_fallback

    if(.not.self%ready .or. .not.associated(self%cofgen))error stop 'B110 adaptive hydraulic provider not ready'
    if(.not.allocated(self%representation) .or. .not.allocated(self%node_representation)) &
         error stop 'B110 adaptive hydraulic provider mapping missing'
    if(size(pressure_head)/=size(self%node_representation))error stop 'B110 adaptive hydraulic provider shape mismatch'

    need_fallback=any(pressure_head>LOOKUP_H_MAX)
    do node=1,size(pressure_head)
      if(pressure_head(node)>LOOKUP_H_MAX)cycle
      r=self%node_representation(node)
      if(r<1 .or. r>self%representation_count)error stop 'B110 adaptive hydraulic provider invalid mapping'
      if(.not.allocated(self%representation(r)%table%x))error stop 'B110 adaptive hydraulic provider table missing'
      xv=log10(-pressure_head(node))
      if(xv<self%representation(r)%table%x(1) .or. &
           xv>self%representation(r)%table%x(self%representation(r)%table%n))need_fallback=.true.
    end do
    if(need_fallback)call self%analytical%evaluate(pressure_head,wa,ka,ca,da)

    do node=1,size(pressure_head)
      r=self%node_representation(node)
      if(pressure_head(node)<=LOOKUP_H_MAX)then
        xv=log10(-pressure_head(node))
      else
        xv=0.0_real64
      end if

      if(pressure_head(node)<=LOOKUP_H_MAX .and. xv>=self%representation(r)%table%x(1) .and. &
           xv<=self%representation(r)%table%x(self%representation(r)%table%n))then
        call locate(self%representation(r)%table%x,xv,idx,f)
        dx=self%representation(r)%table%x(idx+1)-self%representation(r)%table%x(idx);t=f
        h00=2*t**3-3*t**2+1;h10=t**3-2*t**2+t;h01=-2*t**3+3*t**2;h11=t**3-t**2
        zz=h00*self%representation(r)%table%z(idx)+h10*dx*self%representation(r)%table%dzdx(idx)+ &
           h01*self%representation(r)%table%z(idx+1)+h11*dx*self%representation(r)%table%dzdx(idx+1)
        dh00=6*t*t-6*t;h10d=3*t*t-4*t+1;dh01=-6*t*t+6*t;dh11=3*t*t-2*t
        dz_x=(dh00*self%representation(r)%table%z(idx)+h10d*dx*self%representation(r)%table%dzdx(idx)+ &
             dh01*self%representation(r)%table%z(idx+1)+dh11*dx*self%representation(r)%table%dzdx(idx+1))/dx
        if(zz>=0.0_real64)then
          se=1.0_real64/(1.0_real64+exp(-zz))
        else
          se=exp(zz)/(1.0_real64+exp(zz))
        end if
        span=self%cofgen(2,node)-self%cofgen(1,node)
        water_content(node)=self%cofgen(1,node)+span*se
        capacity(node)=(span*se*(1.0_real64-se)*dz_x)/(pressure_head(node)*LN10)
        conductivity(node)=exp(self%representation(r)%table%logk(idx)+ &
             f*(self%representation(r)%table%logk(idx+1)-self%representation(r)%table%logk(idx)))
        dconductivity_dhead(node)=0.0_real64
      else
        water_content(node)=wa(node);conductivity(node)=ka(node)
        capacity(node)=ca(node);dconductivity_dhead(node)=da(node)
      end if
    end do
  end subroutine b110_adaptive_hydraulic_evaluate

  subroutine b110_adaptive_hydraulic_cache_stats(builds,hits,misses,entries)
    integer,intent(out)::builds,hits,misses,entries
!$omp critical(b110_ahl_cache_bind)
    call shared_cache%stats(builds,hits,misses,entries)
!$omp end critical(b110_ahl_cache_bind)
  end subroutine b110_adaptive_hydraulic_cache_stats

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

end module mod_b110_adaptive_hydraulic_provider
